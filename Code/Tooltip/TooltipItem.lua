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
local format = string.format;

local RewardTooltip = {};
addon.RewardTooltip = RewardTooltip;

-- FrameXML comparison tooltips (not in wow-docs; ShoppingTooltip1/2/3 as used by GameTooltip_ShowCompareItem).
local SHOPPING_TOOLTIPS = {"ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3"};

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
local compareFrame;                        -- listens for the compare key while the default tooltip shows an item
local compareEntry;                        -- item entry the default tooltip is showing, nil otherwise
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
    if link and not entry.noCompare and TooltipCompare:IsEquippable(link) then
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

-- One "Replace X" block. `equipped` is the item compared with (nil: the one GetReplacedItem picks).
local function AddReplaceBlock(tip, link, equipped)
    local equippedName, _, equippedQuality = GetItemInfo(equipped);
    local nameText = equippedName or L["Equipped Item"];
    if equippedName and equippedQuality then
        -- The name takes the item's rarity colour (same brightened colours as the tooltip title).
        local r, g, b = GetQualityColor(equippedQuality);
        nameText = format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), equippedName);
    end
    tip:AddLine(L["Format Replace Item"]:format(nameText), GOLD[1], GOLD[2], GOLD[3]);

    if TooltipCompare:IsDifferentType(link, equipped) then
        tip:AddLine(L["Different Item Type"], RED[1], RED[2], RED[3]);
    end

    local statLines, identical = TooltipCompare:GetStatLines(link, equipped);
    if identical then
        tip:AddLine(L["Identical Stats"], GOLD[1], GOLD[2], GOLD[3]);
    end
    for i = 1, #statLines do
        tip:AddLine(statLines[i], 1, 1, 1);
    end
end

local function AddComparison(tip, link)
    local equipped = TooltipCompare:GetReplacedItem(link);
    if not equipped then
        return
    end
    tip:AddBlankLine();
    AddReplaceBlock(tip, link, equipped);
end

-- Side tooltip for items with two equipped candidates (rings, trinkets, one-hand weapons): one Replace block per
-- equipped item, so the main tooltip stays small. It sits beside the main tooltip, on the side with room.
--
-- With "Use Separate Tooltip for Comparison" every equipped item gets a tooltip of its own instead (one or two),
-- drawn like the reward's tooltip, with the stat differences at the bottom.
local SIDE_GAP = 2;
local MAX_SIDE_TIPS = 2;
local sideTips = {};                       -- pool of tooltip frames, filled when needed
local sideRequest;                         -- {link, list, separate} set while the main tooltip is rendered

local function HideSideTooltip()
    sideRequest = nil;
    for i = 1, #sideTips do
        sideTips[i]:Hide();
    end
end

local function GetSideTip(index)
    if not sideTips[index] then
        sideTips[index] = addon.CreateTooltipFrame();
    end
    return sideTips[index]
end

-- The equipped item as its own tooltip: its normal tooltip text, then the differences for replacing it.
local function RenderEquippedTooltip(tip, newLink, equippedLink)
    local quality = select(3, GetItemInfo(equippedLink));
    local lines = TooltipScan:ScanHyperlink(equippedLink);
    RenderScannedLines(tip, lines, {quality = quality, noCompare = true}, equippedLink);

    tip:AddBlankLine();
    if TooltipCompare:IsDifferentType(newLink, equippedLink) then
        tip:AddLine(L["Different Item Type"], RED[1], RED[2], RED[3]);
    end
    local statLines, identical = TooltipCompare:GetStatLines(newLink, equippedLink);
    if identical then
        tip:AddLine(L["Identical Stats"], GOLD[1], GOLD[2], GOLD[3]);
    end
    for i = 1, #statLines do
        tip:AddLine(statLines[i], 1, 1, 1);
    end

    -- The large icon in the corner, like the reward's own tooltip.
    if TooltipModel:CanPreview(equippedLink) then
        tip:SetPreviewItem(equippedLink);
    end
end

local function UpdateSideTooltip(main)
    local request = sideRequest;
    sideRequest = nil;
    HideSideTooltip();
    if not request then
        return
    end

    -- Fill the tooltips: one with every Replace block, or one per equipped item.
    local tips = {};
    if request.separate then
        for i = 1, min(#request.list, MAX_SIDE_TIPS) do
            local tip = GetSideTip(i);
            tip:Clear();
            RenderEquippedTooltip(tip, request.link, request.list[i]);
            tips[#tips + 1] = tip;
        end
    else
        local tip = GetSideTip(1);
        tip:Clear();
        for i = 1, #request.list do
            if i > 1 then
                tip:AddBlankLine();
            end
            AddReplaceBlock(tip, request.link, request.list[i]);
        end
        tips[1] = tip;
    end

    local total = 0;
    for i = 1, #tips do
        tips[i]:Layout();
        total = total + tips[i].frame:GetWidth() + SIDE_GAP;
    end

    -- Right of the main tooltip when they all fit on screen, left when only that side has room.
    local mainFrame = main.frame;
    local mainLeft, mainRight = mainFrame:GetLeft(), mainFrame:GetRight();
    local screenLeft, screenRight = UIParent:GetLeft() or 0, UIParent:GetRight();
    local onRight = true;
    if mainLeft and mainRight and screenRight then
        local roomRight = screenRight - mainRight;
        local roomLeft = mainLeft - screenLeft;
        onRight = roomRight >= total or roomRight >= roomLeft;
    end

    local previous = mainFrame;
    for i = 1, #tips do
        local frame = tips[i].frame;
        frame:ClearAllPoints();
        if onRight then
            frame:SetPoint("TOPLEFT", previous, "TOPRIGHT", SIDE_GAP, 0);
        else
            frame:SetPoint("TOPRIGHT", previous, "TOPLEFT", -SIDE_GAP, 0);
        end
        previous = frame;
        tips[i]:Show();
    end
end

-- Lines from other addons (see TooltipExtensions.lua), e.g. Auctionator prices.
-- `early` picks the providers drawn above the transmog line.
local function AddProviderLines(tip, entry, link, early)
    if not link then
        return
    end
    local extra = addon.TooltipExtensions:GetItemLines(link, entry.count, early);
    for i = 1, #extra do
        local line = extra[i];
        if line.right then
            tip:AddDoubleLine(line.left, line.right, line.lr, line.lg, line.lb, line.rr, line.rg, line.rb);
        else
            tip:AddLine(line.left, line.lr, line.lg, line.lb);
        end
    end
end

local function AddItemExtras(tip, entry, link)
    AddProviderLines(tip, entry, link, true);
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

    AddProviderLines(tip, entry, link, false);

    if link and TooltipCompare:IsEquippable(link) then
        local showComparison = GetDBBool("TooltipShowItemComparison");
        if showComparison then
            local list = TooltipCompare:GetReplacedItems(link);
            if GetDBBool("TooltipSeparateCompare") and not GetDBBool("UseBlizzardTooltip") then
                if not list then
                    local single = TooltipCompare:GetReplacedItem(link);
                    list = single and {single};
                end
                if list then
                    sideRequest = {link = link, list = list, separate = true};
                end
            elseif list then
                sideRequest = {link = link, list = list};
            else
                AddComparison(tip, link);
            end
        end
        tip:AddHotkey(_G.SHIFT_KEY_TEXT or "Shift", showComparison and L["Hide Comparison"] or L["Show Comparison"]);
    end

    if link and TooltipModel:CanPreview(link) then
        tip:SetPreviewItem(link);
    end
end

-- Fills the tooltip for one entry. Returns true while the client is still loading the item.
local function Render(tip, entry)
    tip:Clear();
    sideRequest = nil;
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
    UpdateSideTooltip(tip);
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
    HideSideTooltip();
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
    HideSideTooltip();
    if self.gameTooltipTaken then
        GameTooltip:Hide();
    end
    compareEntry = nil;
    if compareFrame then
        compareFrame:UnregisterEvent("MODIFIER_STATE_CHANGED");
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
    -- The comparison tooltips are UIParent children too, so they would stay invisible with UIParent hidden.
    for i = 1, #SHOPPING_TOOLTIPS do
        local shopping = _G[SHOPPING_TOOLTIPS[i]];
        if shopping then
            shopping:Hide();
            shopping:SetParent(self.topFrame);
        end
    end
end

function RewardTooltip:RestoreGameTooltip()
    if not self.gameTooltipTaken then
        return
    end
    self.gameTooltipTaken = nil;
    GameTooltip:Hide();
    GameTooltip:SetParent(UIParent);
    GameTooltip:SetFrameStrata("TOOLTIP");
    for i = 1, #SHOPPING_TOOLTIPS do
        local shopping = _G[SHOPPING_TOOLTIPS[i]];
        if shopping then
            shopping:Hide();
            shopping:SetParent(UIParent);
            shopping:SetFrameStrata("TOOLTIP");
        end
    end
end

-- The server answers after the tooltip opened: draw it again with the new line.
-- Same for the AH bot prices (Code\SupportedAddOns\RetailAH.lua).
addon.CallbackRegistry:Register("AuctionHouseTooltipChanged", function()
    if shownEntry and tooltip and tooltip:IsShown() then
        Render(tooltip, shownEntry);
    end
end);

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

-- Item comparison for the default GameTooltip. The client does not show the comparison tooltips on its own:
-- the stock UI's item buttons call GameTooltip_ShowCompareItem while the compare key is held, so we do too.
-- GameTooltip_ShowCompareItem and ShoppingTooltip1/2 are FrameXML, not in wow-docs (listed by the
-- APIDocumentation addon: GameTooltip_ShowCompareItem(tooltip, shift)).
local function UpdateBlizzardCompare()
    if not compareEntry or not GameTooltip:IsShown() then
        return
    end
    if IsModifiedClick("COMPAREITEMS") then
        if GameTooltip_ShowCompareItem then
            -- Second argument is the "shift" flag the stock function hands on to SetHyperlinkCompareItem.
            GameTooltip_ShowCompareItem(GameTooltip, 1);
        end
    else
        for i = 1, #SHOPPING_TOOLTIPS do
            local shopping = _G[SHOPPING_TOOLTIPS[i]];
            if shopping then
                shopping:Hide();
            end
        end
    end
end

-- The default GameTooltip at the same anchor as our tooltip.
function RewardTooltip:ShowBlizzard(owner, anchor, entry)
    self:TakeOutGameTooltip();
    GameTooltip:SetOwner(owner, "ANCHOR_NONE");
    GameTooltip:ClearAllPoints();
    GameTooltip:SetPoint("BOTTOMLEFT", anchor or owner, "TOPRIGHT", 0, 2);
    compareEntry = nil;
    if entry.kind == "item" then
        GameTooltip:SetQuestItem(entry.itemType, entry.index);
        compareEntry = entry;
    elseif entry.kind == "spell" then
        GameTooltip:SetQuestRewardSpell();
    else
        return
    end
    GameTooltip:Show();

    if compareEntry then
        if not compareFrame then
            compareFrame = CreateFrame("Frame");
            compareFrame:SetScript("OnEvent", UpdateBlizzardCompare);
            -- One retry on the next frame: right after Show the tooltip has no screen position yet, and the
            -- stock function needs it to place the comparison tooltips.
            compareFrame:SetScript("OnUpdate", function(frame)
                frame:Hide();
                UpdateBlizzardCompare();
            end);
        end
        compareFrame:RegisterEvent("MODIFIER_STATE_CHANGED");
        compareFrame:Show();                    -- Shift may already be held: checked on the next frame
    end
end
