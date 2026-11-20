local _, addon = ...;
local L = addon.L;

-- Journal: Gear (JournalGearBIS): "On your gear list" for items that are an upgrade for your spec.
-- The addon adds that line by hooking GameTooltip, which our tooltip is not, so we ask it the same question
-- through its public globals (JournalGearBIS.Build and JournalGearBIS.Verdict) and draw the answer ourselves.
-- Its progression stage lives in a local function of its Gear tab. We rebuild it from Journal.state, without
-- the "stage quest already done" refinement, so on a realm that is ahead of what Journal reports the list can
-- be one stage behind.
local UnitClass = UnitClass;
local UnitLevel = UnitLevel;
local GetItemInfo = GetItemInfo;
local tonumber = tonumber;
local pcall = pcall;
local ipairs = ipairs;
local table_concat = table.concat;

local ADDON_NAME = "JournalGearBIS";
local MAX_STAGE = 18;                  -- the same fallback its Gear tab uses
local GOLD = "|cffffd200";

local REQUIRED = {
    "JournalGearBIS",
    "Journal",
};

local function OnAddOnLoaded()
    local G = _G.JournalGearBIS;
    local J = _G.Journal;
    if not (G.Build and G.Verdict and G.Phase and G.LearnInstances) then
        return
    end

    local function GetStage()
        if J.Has and J.HELLO_PROGRESSION and not J.Has(J.HELLO_PROGRESSION) then
            return MAX_STAGE
        end
        return J.state or MAX_STAGE
    end

    -- The view is worked out for the active talents (or the role picked in its tab) and kept until
    -- gear, bags, level or talents change.
    local view, dirty = nil, true;

    local function GetView()
        if dirty then
            dirty = false;
            view = nil;
            local db = _G.JournalGearBISCharDB or {};
            local choice = db.choice == "other" and "active" or db.choice;
            if not G.learned then
                G.learned = true;
                G.LearnInstances();
            end
            local _, class = UnitClass("player");
            if class ~= "DEATHKNIGHT" and G.Phase(UnitLevel("player")) == 0 then
                view = G.Build(choice or "active", GetStage());
            end
        end
        return view
    end

    local function ItemName(id)
        local name = GetItemInfo(id);
        if name then
            return name
        end
        local item = G.Item and G.Item(id);
        return item and item.name or ("item " .. id)
    end

    local function provider(tooltip, link)
        if not addon.GetDBBool("ShowJournalGearTooltip") then
            return
        end
        local id = tonumber(link:match("item:(%d+)"));
        if not id then
            return
        end
        local ok, row, becomes = pcall(function() return G.Verdict(GetView(), id) end);
        if not ok or not (row or becomes) then
            return
        end
        -- Its own line adds "Roll Need", which means nothing for quest rewards.
        tooltip:AddLine(GOLD .. L["On Your Gear List"] .. "|r");
        if becomes then
            local names = {};
            for _, other in ipairs(becomes) do
                names[#names + 1] = ItemName(other);
            end
            tooltip:AddLine(L["Format Exchange It For"]:format(table_concat(names, ", ")), 1, 1, 1);
        end
    end

    local frame = CreateFrame("Frame");
    for _, event in ipairs({
        "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE", "PLAYER_LEVEL_UP", "ACTIVE_TALENT_GROUP_CHANGED",
        "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "QUEST_QUERY_COMPLETE", "PLAYER_ENTERING_WORLD",
    }) do
        frame:RegisterEvent(event);
    end
    frame:SetScript("OnEvent", function() dirty = true; end);

    -- Early: drawn above the transmog line.
    DialogueUI_335_API.RegisterItemTooltipProvider(ADDON_NAME, provider, true);
end

addon.AddSupportedAddOn(ADDON_NAME, OnAddOnLoaded, REQUIRED);