local _, addon = ...;

-- Reads tooltip text from a hidden GameTooltip. 3.3.5a has no C_TooltipInfo, so this is the same
-- approach as retail's Classic fallback (DialogueUI API.lua "DialogueUIVirtualTooltip").
local TooltipScan = {};
addon.TooltipScan = TooltipScan;

local CreateFrame = CreateFrame;

local SCAN_NAME = "DUI335ScanTooltip";
local scanner;

local function GetScanner()
    if not scanner then
        scanner = CreateFrame("GameTooltip", SCAN_NAME, UIParent, "GameTooltipTemplate");
        scanner:SetFrameStrata("TOOLTIP");
        scanner:Hide();
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE");
    scanner:ClearLines();
    return scanner
end

-- Collects the lines the tooltip is showing: {left, right, lr, lg, lb, rr, rg, rb} per line.
local function Collect(tooltip)
    local lines = {};
    for i = 1, tooltip:NumLines() do
        local left = _G[SCAN_NAME .. "TextLeft" .. i];
        local right = _G[SCAN_NAME .. "TextRight" .. i];
        local line = {};
        if left then
            line.left = left:GetText();
            line.lr, line.lg, line.lb = left:GetTextColor();
        end
        if right and right:IsShown() then
            line.right = right:GetText();
            line.rr, line.rg, line.rb = right:GetTextColor();
        end
        lines[i] = line;
    end
    return lines
end

-- Each scan returns the line list, or an empty table when the tooltip has nothing to show.
function TooltipScan:ScanQuestItem(itemType, index)
    local tooltip = GetScanner();
    tooltip:SetQuestItem(itemType, index);
    return Collect(tooltip)
end

function TooltipScan:ScanHyperlink(link)
    local tooltip = GetScanner();
    tooltip:SetHyperlink(link);
    return Collect(tooltip)
end

-- Item in a bag slot (used for readable books and letters).
function TooltipScan:ScanBagItem(bag, slot)
    local tooltip = GetScanner();
    tooltip:SetBagItem(bag, slot);
    return Collect(tooltip)
end

function TooltipScan:ScanRewardSpell()
    local tooltip = GetScanner();
    tooltip:SetQuestRewardSpell();
    return Collect(tooltip)
end

-- True while the client is still fetching the item (the tooltip shows a placeholder or nothing).
function TooltipScan:IsRetrieving(lines)
    if #lines == 0 then
        return true
    end
    local placeholder = _G.RETRIEVING_ITEM_INFO;    -- FrameXML string, not in wow-docs
    local first = lines[1] and lines[1].left;
    if placeholder and first == placeholder then
        return true
    end
    return not first or first == ""
end
