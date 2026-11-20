local _, addon = ...;

-- Reward tooltip: builds the content for a reward entry and shows it in our own tooltip frame.
-- Port of retail's RewardTooltipCode.lua CustomTooltip_OnEnter plus Tooltip_Private.lua extras
-- (sell price, item level delta, comparison), using only 3.3.5a APIs.
local L = addon.L;
local GetDBBool = addon.GetDBBool;
local FlipDBBool = addon.FlipDBBool;
local TooltipScan = addon.TooltipScan;
local TooltipCompare = addon.TooltipCompare;
local TooltipModel = addon.TooltipModel;

local UIParent = UIParent;
local GetItemInfo = GetItemInfo;
local GetItemCount = GetItemCount;
local GetItemQualityColor = GetItemQualityColor;
local GetCoinTextureString = GetCoinTextureString;
local UnitXPMax = UnitXPMax;
local floor = math.floor;
local min = math.min;

local RewardTooltip = {};
addon.RewardTooltip = RewardTooltip;

local RETRY_INTERVAL = 0.3;
local RETRY_MAX = 10;
local GOLD = {1, 0.82, 0};
local RED = {1, 0.125, 0.125};
local TRANSMOG_COLOR = {244 / 255, 113 / 255, 245 / 255};     -- |cfff471f5, as in wow-mod-transmog-plus

-- Retail brightens poor/common (grey), rare (blue) and epic (purple) so they read on the dark background.
local QUALITY_OVERRIDE = {
    [0] = {0.9, 0.9, 0.9},
    [1] = {0.9, 0.9, 0.9},
    [3] = {105 / 255, 158 / 255, 1},
    [4] = {185 / 255, 83 / 255, 1},
};

local function GetQualityColor(quality)
    local override = QUALITY_OVERRIDE[quality];
    if override then
        return override[1], override[2], override[3]
    end
    local r, g, b = GetItemQualityColor(quality or 1);
    return r, g, b
end

local tooltip;
local shownEntry;                          -- entry of our tooltip while it is open, for a late transmog answer
local function GetTooltip()
    if not tooltip then
        tooltip = addon.CreateTooltipFrame();
    end
    return tooltip
end

---------------------------------------------------------------------------
-- Content
---------------------------------------------------------------------------

-- Appends " (+N)" to the line showing the item level, when we have a delta. Locale independent:
-- the line is the short one made only of the item's level number (e.g. "Item Level 200").
local function AppendLevelDelta(text, itemLevel, deltaText)
    if deltaText == "" or not text or not itemLevel then
        return text
    end
    if #text > 24 then
        return text
    end
    local number = text:match("(%d+)");
    if number and tonumber(number) == itemLevel and not text:find("[%+%-/]") then
        return text .. " " .. deltaText
    end
    return text
end

local function RenderScannedLines(tip, lines, entry, link)
    local itemLevel = link and select(4, GetItemInfo(link));
    local deltaText = "";
    if link and TooltipCompare:IsEquippable(link) then
        deltaText = TooltipCompare:FormatItemLevelDelta(TooltipCompare:GetItemLevelDelta(link));
    end

    -- 3.3.5a item tooltips have no "Item Level" line (retail's Classic fallback adds it by hand too).
    -- Added under the name for equippable items, unless the client already printed one.
    local needLevelLine = itemLevel and itemLevel > 0 and TooltipCompare:IsEquippable(link);
    if needLevelLine then
        for i = 2, min(#lines, 4) do
            local text = lines[i].left;
            local number = text and #text <= 24 and text:match("(%d+)");
            if number and tonumber(number) == itemLevel and not text:find("[%+%-/]") then
                needLevelLine = false;
            end
        end
    end

    for i = 1, #lines do
        local line = lines[i];
        if i == 1 then
            local r, g, b;
            if entry.quality then
                r, g, b = GetQualityColor(entry.quality);
            else
                r, g, b = line.lr, line.lg, line.lb;
            end
            tip:SetTitle(line.left, r, g, b);
            if needLevelLine then
                local label = L["Format Item Level"]:format(itemLevel);
                tip:AddLine(deltaText ~= "" and (label .. " " .. deltaText) or label, GOLD[1], GOLD[2], GOLD[3]);
            end
        elseif line.right then
            tip:AddDoubleLine(line.left, line.right, line.lr, line.lg, line.lb, line.rr, line.rg, line.rb);
        elseif line.left == " " or line.left == "" then
            tip:AddBlankLine();
        else
            tip:AddLine(AppendLevelDelta(line.left, itemLevel, deltaText), line.lr, line.lg, line.lb);
        end
    end
end

local function AddComparison(tip, link)
    local equipped = TooltipCompare:GetReplacedItem(link);
    if not equipped then
        return
    end
    tip:AddBlankLine();
    local equippedName = GetItemInfo(equipped);
    tip:AddLine(L["Format Replace Item"]:format(equippedName or L["Equipped Item"]), GOLD[1], GOLD[2], GOLD[3]);

    if TooltipCompare:IsDifferentType(link) then
        tip:AddLine(L["Different Item Type"], RED[1], RED[2], RED[3]);
    end

    local statLines, identical = TooltipCompare:GetStatLines(link);
    if identical then
        tip:AddLine(L["Identical Stats"], GOLD[1], GOLD[2], GOLD[3]);
    end
    for i = 1, #statLines do
        tip:AddLine(statLines[i], 1, 1, 1);
    end
end

local function AddItemExtras(tip, entry, link)
    -- Appearance not collected yet (server transmog module). Same pink as the module's own tooltip line.
    local TransmogStatus = addon.TransmogStatus;
    if link and entry.itemType ~= "required" and TooltipCompare:IsEquippable(link) then
        entry.itemID = entry.itemID or TransmogStatus:GetItemID(link);
        TransmogStatus:Request(entry.itemID);
        if TransmogStatus:IsUncollected(entry.itemID) then
            tip:AddLine(L["Transmog Not Collected"], TRANSMOG_COLOR[1], TRANSMOG_COLOR[2], TRANSMOG_COLOR[3]);
        end
    end
    -- "You have N" for required items, with a bank variant (retail L["Format You Have X"]).
    if entry.itemType == "required" and link then
        local have = GetItemCount(link) or 0;
        local withBank = GetItemCount(link, true) or 0;
        local text = L["Format You Have"]:format(have);
        if withBank > have then
            text = text .. L["Format In Bank"]:format(withBank - have);
        end
        tip:AddBlankLine();
        tip:AddLine(text, GOLD[1], GOLD[2], GOLD[3]);
    end

    -- Sell price line. Retail shows it under the text, white.
    if link then
        local price = select(11, GetItemInfo(link));
        if price and price > 0 then
            local total = price * (entry.count or 1);
            tip:AddLine(L["Sell Price"] .. ":  " .. GetCoinTextureString(total), 1, 1, 1);
        end
    end

    if link and TooltipCompare:IsEquippable(link) then
        local showComparison = GetDBBool("TooltipShowItemComparison");
        if showComparison then
            AddComparison(tip, link);
        end
        tip:AddHotkey("Shift", showComparison and L["Hide Comparison"] or L["Show Comparison"]);
    end

    if link and TooltipModel:CanPreview(link) then
        tip:SetPreviewItem(link);
    end
end

-- Fills the tooltip for one entry. Returns true while the client is still loading the item.
local function Render(tip, entry)
    tip:Clear();
    local retrieving = false;

    if entry.kind == "item" then
        -- Normally the snapshot taken when the rewards were laid out (Prefetch). Otherwise read it now.
        local lines = entry.lines;
        if not lines then
            if not entry.test then            -- test entries have no open quest
                lines = TooltipScan:ScanQuestItem(entry.itemType, entry.index);
            end
            if (not lines or TooltipScan:IsRetrieving(lines)) and entry.link then
                lines = TooltipScan:ScanHyperlink(entry.link);
            end
        end
        -- Nothing but the name is shown until the whole item is known (sell price, item level and the
        -- comparison all need GetItemInfo), so no half-filled tooltip.
        retrieving = TooltipScan:IsRetrieving(lines) or (entry.link ~= nil and GetItemInfo(entry.link) == nil);
        if retrieving then
            tip:SetTitle(entry.name or "...", GetQualityColor(entry.quality));
        else
            RenderScannedLines(tip, lines, entry, entry.link);
            AddItemExtras(tip, entry, entry.link);
        end
    elseif entry.kind == "spell" then
        local lines = entry.lines or TooltipScan:ScanRewardSpell();
        if #lines == 0 then
            tip:SetTitle(entry.name or "");
        else
            for i = 1, #lines do
                local line = lines[i];
                if i == 1 then
                    tip:SetTitle(line.left, line.lr, line.lg, line.lb);
                elseif line.right then
                    tip:AddDoubleLine(line.left, line.right, line.lr, line.lg, line.lb, line.rr, line.rg, line.rb);
                else
                    tip:AddLine(line.left, line.lr, line.lg, line.lb);
                end
            end
        end
    elseif entry.kind == "title" then
        tip:SetTitle(L["Title"]);
        tip:AddLine(L["Format Reward Title"]:format(entry.name or ""));
    elseif entry.kind == "honor" then
        tip:SetTitle(L["Honor Points"]);
        tip:AddLine(L["Format Reward Honor"]:format(entry.amount));
    elseif entry.kind == "talents" then
        tip:SetTitle(L["Talent Points"]);
        tip:AddLine(L[entry.amount == 1 and "Format Reward Talent Point" or "Format Reward Talent Points"]:format(entry.amount));
    elseif entry.kind == "arena" then
        tip:SetTitle(L["Arena Points"]);
        tip:AddLine(L["Format Reward Arena"]:format(entry.amount));
    elseif entry.kind == "xp" then
        tip:SetTitle(L["Experience"]);
        local max = UnitXPMax("player");
        local percent = (max and max > 0) and L["Format Of Your Level"]:format(floor(entry.amount / max * 100 + 0.5)) or "";
        tip:AddLine(L["Format Reward Experience"]:format(entry.amount, percent));
    else
        return false
    end

    tip:Layout();
    return retrieving
end

---------------------------------------------------------------------------
-- Prefetch: load every item's data when the rewards are shown, so hovering needs no waiting
---------------------------------------------------------------------------

local PREFETCH_INTERVAL = 0.25;
local PREFETCH_TIMEOUT = 30;
local prefetchFrame;
local prefetchPending = {};

-- True when the entry's data is stored in entry.lines. Unknown items are requested from the server by
-- setting their link on the hidden scan tooltip (the only way in 3.3.5a); a later call finds them cached.
local function PrefetchEntry(entry)
    if entry.lines then
        return true
    end
    if entry.kind == "spell" then
        -- Valid only while the quest dialogue is open, which it is when the rewards are laid out.
        entry.lines = TooltipScan:ScanRewardSpell();
        return true
    end
    if entry.kind ~= "item" or not entry.link then
        return true
    end
    if not GetItemInfo(entry.link) then
        TooltipScan:ScanHyperlink(entry.link);          -- asks the server
        return false
    end
    local lines;
    if not entry.test then
        lines = TooltipScan:ScanQuestItem(entry.itemType, entry.index);
    end
    if not lines or TooltipScan:IsRetrieving(lines) then
        lines = TooltipScan:ScanHyperlink(entry.link);
    end
    if TooltipScan:IsRetrieving(lines) then
        return false
    end
    entry.lines = lines;
    return true
end

-- entries: the reward, choice and required entries of the page that was just laid out.
-- Replaces the previous batch: entries of an older page are no longer polled.
function RewardTooltip:Prefetch(entries)
    prefetchPending = {};
    for i = 1, #entries do
        if not PrefetchEntry(entries[i]) then
            prefetchPending[#prefetchPending + 1] = entries[i];
        end
    end

    if not prefetchFrame then
        prefetchFrame = CreateFrame("Frame");
    end
    if #prefetchPending == 0 then
        prefetchFrame:SetScript("OnUpdate", nil);
        return
    end

    local elapsed, total = 0, 0;
    prefetchFrame:SetScript("OnUpdate", function(frame, dt)
        elapsed = elapsed + dt;
        total = total + dt;
        if elapsed < PREFETCH_INTERVAL then
            return
        end
        elapsed = 0;
        local stillPending = {};
        for i = 1, #prefetchPending do
            if not PrefetchEntry(prefetchPending[i]) then
                stillPending[#stillPending + 1] = prefetchPending[i];
            end
        end
        prefetchPending = stillPending;
        if #prefetchPending == 0 or total >= PREFETCH_TIMEOUT then
            frame:SetScript("OnUpdate", nil);
        end
    end);
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------

-- owner: the hovered button. anchor: frame the tooltip sits on (the icon). entry: reward entry from QuestData.
function RewardTooltip:Show(owner, anchor, entry)
    if GetDBBool("UseBlizzardTooltip") then
        self:ShowBlizzard(owner, anchor, entry);
        return
    end

    local tip = GetTooltip();
    tip:Hide();
    shownEntry = entry;
    tip:SetOwnerAnchor(owner, anchor);
    local retrieving = Render(tip, entry);
    tip:Show();

    -- No TOOLTIP_DATA_UPDATE in 3.3.5a: ask again until the item is cached.
    if retrieving then
        local elapsed, tries = 0, 0;
        tip.retry = function(dt)
            elapsed = elapsed + dt;
            if elapsed < RETRY_INTERVAL then
                return
            end
            elapsed = 0;
            tries = tries + 1;
            local still = Render(tip, entry);
            if not still or tries >= RETRY_MAX then
                tip.retry = nil;
            end
        end;
    end

    -- Shift toggles the comparison (retail Tooltip_Private.lua). Only for equippable items.
    tip.onModifier = function(key, state)
        if state == 1 and (key == "LSHIFT" or key == "RSHIFT") and entry.kind == "item" and entry.link
            and TooltipCompare:IsEquippable(entry.link) then
            FlipDBBool("TooltipShowItemComparison", true);
            Render(tip, entry);
        end
    end;
    tip.frame:RegisterEvent("MODIFIER_STATE_CHANGED");
end

function RewardTooltip:Hide()
    shownEntry = nil;
    if tooltip then
        tooltip:Hide();
    end
    if self.gameTooltipTaken then
        GameTooltip:Hide();
    end
end

-- Retail (RewardTooltipCode.lua TakeOutGameTooltip / RestoreGameTooltip): while our tooltip is not used, the
-- GameTooltip is moved under a top frame so it is not hidden with UIParent (Hide UI) and stays above the dialogue.
-- The top frame hangs on addon.UIRoot, which keeps UIParent's scale. Retail also scales it by UIParent's effective
-- scale; here the root already copies it.
function RewardTooltip:TakeOutGameTooltip()
    if self.gameTooltipTaken then
        return
    end
    self.gameTooltipTaken = true;
    if not self.topFrame then
        self.topFrame = CreateFrame("Frame", nil, addon.UIRoot);
        self.topFrame:SetFrameStrata("TOOLTIP");
        self.topFrame:SetFrameLevel(100);
    end
    GameTooltip:Hide();
    GameTooltip:SetParent(self.topFrame);
end

function RewardTooltip:RestoreGameTooltip()
    if not self.gameTooltipTaken then
        return
    end
    self.gameTooltipTaken = nil;
    GameTooltip:Hide();
    GameTooltip:SetParent(UIParent);
    GameTooltip:SetFrameStrata("TOOLTIP");
end

-- The server answers after the tooltip opened: draw it again with the new line.
addon.CallbackRegistry:Register("TransmogStatusChanged", function(itemID)
    if shownEntry and tooltip and tooltip:IsShown() and (not itemID or shownEntry.itemID == itemID) then
        Render(tooltip, shownEntry);
    end
end);

addon.CallbackRegistry:Register("SettingChanged.UseBlizzardTooltip", function(dbValue)
    if dbValue ~= true then
        RewardTooltip:RestoreGameTooltip();
    end
end);

-- The default GameTooltip at the same anchor as our tooltip.
function RewardTooltip:ShowBlizzard(owner, anchor, entry)
    self:TakeOutGameTooltip();
    GameTooltip:SetOwner(owner, "ANCHOR_NONE");
    GameTooltip:ClearAllPoints();
    GameTooltip:SetPoint("BOTTOMLEFT", anchor or owner, "TOPRIGHT", 0, 2);
    if entry.kind == "item" then
        GameTooltip:SetQuestItem(entry.itemType, entry.index);
    elseif entry.kind == "spell" then
        GameTooltip:SetQuestRewardSpell();
    else
        return
    end
    GameTooltip:Show();
end
