local _, addon = ...;

-- Equipped-item comparison for the tooltip. Port of retail's item level delta (ItemEvaluator, API.lua
-- EQUIPLOC_SLOTID) and its stat comparison, using GetItemStatDelta instead of parsing tooltip text.
local TooltipCompare = {};
addon.TooltipCompare = TooltipCompare;

local GetItemInfo = GetItemInfo;
local GetInventoryItemLink = GetInventoryItemLink;
local GetItemStatDelta = GetItemStatDelta;
local sort = table.sort;
local floor = math.floor;

-- GetItemInfo equipSlot (field 9) -> inventory slots to compare against (retail EQUIPLOC_SLOTID).
local EQUIP_SLOTS = {
    INVTYPE_HEAD = {1},
    INVTYPE_NECK = {2},
    INVTYPE_SHOULDER = {3},
    INVTYPE_BODY = {4},
    INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7},
    INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12},
    INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16, 17},
    INVTYPE_SHIELD = {17},
    INVTYPE_2HWEAPON = {16},
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_HOLDABLE = {17},
    INVTYPE_RANGED = {18},
    INVTYPE_RANGEDRIGHT = {18},
    INVTYPE_THROWN = {18},
    INVTYPE_RELIC = {18},
    INVTYPE_TABARD = {19},
};

local GREEN = "|cff19ff19";
local RED = "|cffff2020";
local GREY = "|cff808080";
local ITEM_LEVEL_FLOOR = -13;     -- retail hides the delta for much older items

local function GetEquipSlots(link)
    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(link);
    return equipSlot and EQUIP_SLOTS[equipSlot], equipSlot
end
TooltipCompare.GetEquipSlots = GetEquipSlots;

function TooltipCompare:IsEquippable(link)
    return GetEquipSlots(link) ~= nil
end

-- Returns the equipped item that `link` would replace: its link and item level.
-- For ring / trinket / one-hand weapon, the weaker of the two slots, so the delta is the best case.
function TooltipCompare:GetReplacedItem(link)
    local slots = GetEquipSlots(link);
    if not slots then
        return nil
    end

    local bestLink, bestLevel;
    for i = 1, #slots do
        local equipped = GetInventoryItemLink("player", slots[i]);
        if equipped then
            local level = select(4, GetItemInfo(equipped)) or 0;
            if not bestLevel or level < bestLevel then
                bestLink, bestLevel = equipped, level;
            end
        end
    end
    return bestLink, bestLevel
end

-- Retail's ItemEvaluator (item level based): true when the item is better than what is in one of its slots.
-- Returns isUpgrade, isReady (false while an item is not in the cache yet: ask again later).
-- An empty slot counts as an upgrade, except the second slot of a one-hand weapon (retail skips it too,
-- and ignores a shield / held item there).
function TooltipCompare:IsUpgrade(link)
    local slots, equipSlot = GetEquipSlots(link);
    if not slots then
        return false, true
    end
    local level = select(4, GetItemInfo(link));
    if not level then
        return false, false
    end

    local ready = true;
    local maxDelta;
    local isOneHand = (equipSlot == "INVTYPE_WEAPON");
    for i = 1, #slots do
        local equipped = GetInventoryItemLink("player", slots[i]);
        local delta;
        if equipped then
            local _, _, _, equippedLevel, _, _, _, _, equippedSlot = GetItemInfo(equipped);
            if i == 2 and isOneHand and equippedSlot ~= "INVTYPE_WEAPON" and equippedSlot ~= "INVTYPE_WEAPONOFFHAND" then
                delta = nil;
            elseif equippedLevel then
                delta = level - equippedLevel;
            else
                ready = false;
            end
        elseif not (i == 2 and isOneHand) then
            delta = level;
        end
        if delta and (not maxDelta or delta > maxDelta) then
            maxDelta = delta;
        end
    end
    return (maxDelta ~= nil and maxDelta > 0), ready
end

-- Item level difference against the replaced item, or nil when there is nothing to compare.
function TooltipCompare:GetItemLevelDelta(link)
    local level = select(4, GetItemInfo(link));
    local _, equippedLevel = self:GetReplacedItem(link);
    if not level or not equippedLevel then
        return nil
    end
    local delta = level - equippedLevel;
    if delta <= ITEM_LEVEL_FLOOR then
        return nil
    end
    return delta
end

-- "(+N)" green or "(-N)" grey, like retail's Tooltip_Private.lua 468-489. Empty when zero or unknown.
function TooltipCompare:FormatItemLevelDelta(delta)
    if not delta or delta == 0 then
        return ""
    elseif delta > 0 then
        return GREY .. "(|r" .. GREEN .. "+" .. delta .. "|r" .. GREY .. ")|r"
    end
    return GREY .. "(" .. delta .. ")|r"
end

-- Display name for a stat token. Global strings (ITEM_MOD_*_SHORT, RESISTANCE*_NAME) are FrameXML,
-- not in wow-docs, so the token itself is the fallback.
local function StatName(token)
    local name = _G[token];
    if type(name) == "string" then
        return name
    end
    return (token:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower())
end

-- Whole numbers for every stat, except damage per second: one decimal at most (53.9, not 53.9238...).
-- Returns a number, so "52.0" prints as 52.
local function RoundStat(token, value)
    if token:find("PER_SECOND") then
        return floor(value * 10 + (value >= 0 and 0.5 or -0.5)) / 10
    end
    return floor(value + (value >= 0 and 0.5 or -0.5))
end

-- Lines for the stat comparison: {text} entries, "+N Stat" green or "-N Stat" red.
-- Returns a list of strings and a flag for "identical".
function TooltipCompare:GetStatLines(link)
    local equipped = self:GetReplacedItem(link);
    if not equipped then
        return {}, false
    end

    -- GetItemStatDelta(item1, item2): item1 minus item2 (UNVERIFIED direction, see docs).
    local delta = GetItemStatDelta(link, equipped, {});
    local shown = {};                  -- token -> rounded value; stats that round to 0 are dropped
    local tokens = {};
    for token, value in pairs(delta) do
        if value then
            local rounded = RoundStat(token, value);
            if rounded ~= 0 then
                shown[token] = rounded;
                tokens[#tokens + 1] = token;
            end
        end
    end
    sort(tokens);

    local lines = {};
    for i = 1, #tokens do
        local value = shown[tokens[i]];
        local color = value > 0 and GREEN or RED;
        local sign = value > 0 and "+" or "";
        lines[#lines + 1] = color .. sign .. value .. "|r " .. StatName(tokens[i]);
    end
    return lines, #lines == 0
end

-- True when the item is a different type from the one it would replace (e.g. cloth vs plate).
function TooltipCompare:IsDifferentType(link)
    local equipped = self:GetReplacedItem(link);
    if not equipped then
        return false
    end
    local _, _, _, _, _, class, subclass = GetItemInfo(link);
    local _, _, _, _, _, eClass, eSubclass = GetItemInfo(equipped);
    return class ~= eClass or subclass ~= eSubclass
end
