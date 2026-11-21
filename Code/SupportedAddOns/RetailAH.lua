local _, addon = ...;

-- Retail Auction House (mod-retail-ah, addon "RetailAH"): what the server's AH bot buyer pays for an item, and for
-- the materials one disenchant gives. The prices live on the server, so they are asked for through the addon's
-- public global RetailAH (RetailAH.Request, RetailAH.Money), the same call its own tooltip uses:
--
--   T:<req>:<entry>  ->  rows  <entry>, <AH bot pays>, <disenchanted, AH bot pays>, <Enchanting needed>, <flags>,
--                              <BiS left>, <BiS limit>, <BiS reset seconds>
--   flags 1: can be disenchanted, 2: the player's Enchanting is high enough, 4: binds on pickup.
--
-- RetailAH hooks GameTooltip, which our tooltip is not, so the lines are added here. The answer comes after the
-- tooltip opened: "AuctionHouseTooltipChanged" draws it again.
-- Shown when "ShowAuctionHouseTooltip" and "ShowRetailAHTooltip" are on (Auctionator has its own setting).
local L = addon.L;
local CallbackRegistry = addon.CallbackRegistry;
local GetDBBool = addon.GetDBBool;

local GetTime = GetTime;
local tonumber = tonumber;
local tostring = tostring;
local type = type;
local floor = math.floor;
local ipairs = ipairs;

local ADDON_NAME = "RetailAH";

-- Flag values 1, 2 and 4 (Lua 5.1 has no bitwise operators, and the bit library is not in wow-docs).
local DISENCHANTABLE, CAN_DISENCHANT, SOULBOUND = 1, 2, 4;

local function HasFlag(flags, flag)
    return floor(flags / flag) % 2 == 1
end
local CACHE_SECONDS = 600;
local BIS_CACHE_SECONDS = 60;           -- "left today" changes as the bot buys
local TIMEOUT = 5;

local GOLD_TEXT = {1, 0.82, 0};
local BIS_TEXT = {0.64, 0.21, 0.93};
local GREY_TEXT = {0.5, 0.5, 0.5};
local BETTER = {0.25, 1, 0.25};
local PLAIN = {1, 1, 1};

local REQUIRED = {
    "RetailAH",
};

local values = {};                      -- itemID -> {pays, disenchanted, skill, flags, bisLeft, bisLimit, bisReset, at}
local asking = {};                      -- itemID -> time asked
local answered = false;                 -- the server answered at least once
local unsupported = false;              -- it cannot (an older module, or RetailAH.Tooltip = 0): stop asking
local timeouts = 0;

local function Money(copper)
    return RetailAH.Money(copper)
end

local function StackText(pays, count)
    if not count or count <= 1 then
        return Money(pays)
    end
    return Money(pays) .. " |cff808080(x" .. count .. ": |r" .. Money(pays * count) .. "|cff808080)|r"
end

local function AddLine(tooltip, label, labelColor, text, textColor)
    tooltip:AddDoubleLine(label, text, labelColor[1], labelColor[2], labelColor[3], textColor[1], textColor[2], textColor[3]);
end

local function AddLines(tooltip, v, count)
    local pays = not HasFlag(v.flags, SOULBOUND) and v.pays or 0;
    local disenchanted = HasFlag(v.flags, DISENCHANTABLE) and v.disenchanted or 0;
    local bis, bisOpen;
    if not HasFlag(v.flags, SOULBOUND) and type(RetailAH.BisBonusText) == "function" then
        bis, bisOpen = RetailAH.BisBonusText(v.bisLeft, v.bisLimit, v.bisReset - (GetTime() - v.at));
    end

    -- Green marks the better of the two when both are there.
    local both = pays > 0 and disenchanted > 0;
    if pays > 0 then
        AddLine(tooltip, L["AH Bot Buys"], GOLD_TEXT, StackText(pays, count), (both and pays >= disenchanted) and BETTER or PLAIN);
    end
    if disenchanted > 0 then
        local able = HasFlag(v.flags, CAN_DISENCHANT);
        local label = able and L["AH Bot Disenchant"] or L["AH Bot Disenchant Skill"]:format(v.skill);
        AddLine(tooltip, label, able and GOLD_TEXT or GREY_TEXT, "~" .. Money(disenchanted), (both and disenchanted > pays) and BETTER or PLAIN);
    end
    if bis then
        AddLine(tooltip, L["AH Bot BiS Bonus"], bisOpen and BIS_TEXT or GREY_TEXT, bis, bisOpen and PLAIN or GREY_TEXT);
    end
end

local function OnAnswer(requested, result, err)
    asking[requested] = nil;
    if err then
        -- "far": a module from before tooltips answers everything away from an auctioneer that way.
        -- "unknown": RetailAH.Tooltip = 0 on the server.
        if err == "far" or err == "unknown" then
            unsupported = true;
        end
        return
    end
    answered = true;
    timeouts = 0;
    local now = GetTime();
    -- An item the server does not list still gets an (empty) entry, so it is not asked for again and again.
    values[requested] = {pays = 0, disenchanted = 0, skill = 0, flags = 0, bisLeft = 0, bisLimit = 0, bisReset = 0, at = now};
    for _, r in ipairs(result and result.rows or {}) do
        local entry = tonumber(r[1]);
        if entry then
            values[entry] = {pays = tonumber(r[2]) or 0, disenchanted = tonumber(r[3]) or 0, skill = tonumber(r[4]) or 0,
                flags = tonumber(r[5]) or 0, bisLeft = tonumber(r[6]) or 0, bisLimit = tonumber(r[7]) or 0,
                bisReset = tonumber(r[8]) or 0, at = now};
        end
    end
    CallbackRegistry:Trigger("AuctionHouseTooltipChanged", requested);
end

local function Ask(entry)
    if unsupported then
        return
    end
    local since = asking[entry];
    if since then
        if GetTime() - since < TIMEOUT then
            return
        end
        -- No answer (no module on the server, or RetailAH.Enable = 0): give up after a few.
        timeouts = timeouts + 1;
        if timeouts >= 3 and not answered then
            unsupported = true;
            return
        end
    end
    asking[entry] = GetTime();
    RetailAH.Request("T", {tostring(entry)}, function(result, err)
        OnAnswer(entry, result, err);
    end);
end

local function OnAddOnLoaded()
    if type(RetailAH.Request) ~= "function" or type(RetailAH.Money) ~= "function" then
        return
    end

    local function provider(tooltip, link, count)
        if not GetDBBool("ShowAuctionHouseTooltip") or not GetDBBool("ShowRetailAHTooltip") then
            return
        end
        local entry = link and tonumber(link:match("item:(%d+)"));
        if not entry then
            return
        end
        local v = values[entry];
        if not v or GetTime() - v.at >= (v.bisLimit > 0 and BIS_CACHE_SECONDS or CACHE_SECONDS) then
            Ask(entry);
        end
        if v then
            AddLines(tooltip, v, count);
        end
    end

    DialogueUI_API.RegisterItemTooltipProvider(ADDON_NAME, provider);
end

addon.AddSupportedAddOn(ADDON_NAME, OnAddOnLoaded, REQUIRED);
