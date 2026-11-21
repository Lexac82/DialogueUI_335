local _, addon = ...;

-- Loot window. Port of Plumber's LootUI (retail) for 3.3.5a, drawn with this addon's textures.
-- Files: LootDefs (this), LootBackground, LootItemFrame, LootWidgets, LootFrame (the window), LootController (events).
local LootUI = {};
addon.LootUI = LootUI;

local tremove = table.remove;

local Def = {
    -- Slot types. Money sorts to the top (the game's own value for it is 2 in retail, 3.3.5a has none).
    SLOT_TYPE_ITEM = 1,
    SLOT_TYPE_MONEY = 10,
    SLOT_TYPE_CUSTOM = -1,          -- text + icon sent by another module (LootUI.QueueDisplayCustom)

    -- Layout, in UI units. A row is the reward button of the dialogue: 36 px high, 24 px icon in a 36 px border.
    ROW_HEIGHT = 36,
    ROW_WIDTH = 256,                -- widest a row gets: longer names wrap
    ROW_MIN_WIDTH = 120,            -- the window shrinks to fit its rows, but not below this
    ROW_SPACING = 4,
    FRAME_PADDING = 14,             -- between the window edge and the rows
    HEADER_GAP = 6,                 -- "You Received" above the window
    ICON_SIZE = 30,                 -- the border's frame sits at the edge of its 36 px cell (ItemBorder.png: ring
    BORDER_SIZE = 36,               -- at 2..61 of 64), so a 30 px icon fills it with no gap (retail: 24)
    NAME_LEFT = 44,                 -- name x offset inside a row (no count)
    DOT_SIZE = 8,                   -- the dot art fills 26 of its 32 px

    -- Behaviour (the Settings menu will own these)
    MAX_ITEM_PER_PAGE = 6,          -- notifications per page; more are shown on following pages
    FADE_DELAY_PER_ITEM = 0.25,
    MERGE_SIMILAR_ITEMS = true,     -- gray items become one "Junk Items" row
    AUTO_LOOT_ENABLE_TOOLTIP = true,
    BG_OPACITY = 0.5,    -- window background while it is a notification
    USE_HOTKEY = true,
    TAKE_ALL_KEY = "E",
    LOOT_UNDER_MOUSE = false,
    ALWAYS_LISTEN_LOOT_MSG = false, -- also show items that did not come from a loot window (quest rewards, mail ...)
    SHOW_ALL_MONEY_CHANGE = false,
    SHOW_ITEM_COUNT = true,         -- owned count (bags + bank) on the icon of an item row
};
LootUI.Def = Def;


---------------------------------------------------------------------------
-- Object pool (3.3.5a has none)
---------------------------------------------------------------------------

function LootUI.CreatePool(createFunc, resetFunc)
    local pool = { active = {}, inactive = {} };

    function pool:Acquire()
        local object = tremove(self.inactive);
        if not object then
            object = createFunc();
        end
        self.active[#self.active + 1] = object;
        return object
    end

    function pool:Release(object)
        for i, v in ipairs(self.active) do
            if v == object then
                tremove(self.active, i);
                break
            end
        end
        if resetFunc then
            resetFunc(object);
        end
        self.inactive[#self.inactive + 1] = object;
    end

    function pool:ReleaseAll()
        for i = #self.active, 1, -1 do
            local object = self.active[i];
            if resetFunc then
                resetFunc(object);
            end
            self.inactive[#self.inactive + 1] = object;
            self.active[i] = nil;
        end
    end

    return pool
end


---------------------------------------------------------------------------
-- Easing
---------------------------------------------------------------------------

-- t: time, b: start, c: change, d: duration (Robert Penner's outQuart, as Plumber's EasingFunctions)
function LootUI.OutQuart(t, b, c, d)
    t = t / d - 1;
    return -c * (t * t * t * t - 1) + b
end


---------------------------------------------------------------------------
-- Gray items are merged into one row. Anything else only merges with the same item.
---------------------------------------------------------------------------

-- Returns true when d2 was folded into d1.
function LootUI.MergeSimilarItems(d1, d2)
    if not (d1.id and d2.id) then
        return false
    end
    if not (d1.quality == 0 and d2.quality == 0) then
        return false
    end

    local byID, list = {}, {};
    local function Add(data)
        local known = byID[data.id];
        if known then
            known.quantity = known.quantity + data.quantity;
        else
            byID[data.id] = data;
            list[#list + 1] = data;
        end
    end

    if d1.mergedData then
        for _, data in ipairs(d1.mergedData) do Add(data) end
    else
        Add(d1);
    end
    if d2.mergedData then
        for _, data in ipairs(d2.mergedData) do Add(data) end
    else
        Add(d2);
    end

    d1.mergedData = list;
    d2.mergedData = nil;
    return true
end


---------------------------------------------------------------------------
-- Rare items get a glow (retail: mounts, pets, tertiary stats). 3.3.5a has no item class ids without a query,
-- so mounts and companions are found by their localized sub type.
---------------------------------------------------------------------------

local RareItems = {
    -- [itemID] = true
};

function LootUI.IsRareItem(data)
    if data.slotType ~= Def.SLOT_TYPE_ITEM or not data.id then
        return false
    end
    if RareItems[data.id] then
        return true
    end
    local subType = data.subType;
    if subType and (subType == _G.MOUNT or subType == _G.COMPANION_PETS) then
        return true
    end
    return false
end


---------------------------------------------------------------------------
-- Sorting: unlooted first, money, quest, quality, name
---------------------------------------------------------------------------

function LootUI.SortFunc_LootSlot(a, b)
    if a.looted ~= b.looted then
        return b.looted and true or false
    end
    if a.slotType ~= b.slotType then
        return a.slotType > b.slotType
    end
    if (a.quality or 0) ~= (b.quality or 0) then
        return (a.quality or 0) > (b.quality or 0)
    end
    if (a.name or "") ~= (b.name or "") then
        return (a.name or "") < (b.name or "")
    end
    return (a.slotIndex or 0) < (b.slotIndex or 0)
end


---------------------------------------------------------------------------
-- Text outline, never a shadow. Brown theme: always outlined (light text over paper-colored art). Dark theme: outlined
-- once the background opacity is 70% or less. The text fonts of the loot window (item names, header) come from
-- LootUI.GetFont, so one call restyles all of them.
---------------------------------------------------------------------------

local lootFonts = {};
local OUTLINE_MAX_OPACITY = 0.75;    -- Dark theme: outline at or below 0.7 (the steps are 0.1; margin for rounding)
local textFlags = "OUTLINE";
local bgOpacity = 0.5;                  -- Def.BG_OPACITY, set below

-- Font size ("LootUI_FontSize" 0..3, the same choices as the UI tab's "FontSizeBase" but a setting of its own).
-- Every font object of the loot window is made with its height for choice 1 (the default); each choice is
-- FONT_SIZE_STEP more or less.
local FONT_SIZE_STEP = 2;
local DEFAULT_SIZE_ID = 1;
local sizeID = DEFAULT_SIZE_ID;
local sizedFonts = {};                  -- [fontObject] = height at the default choice

-- Like FontUtil:GetColoredFont, and the font follows the loot window's font size. No outline.
function LootUI.GetSizedFont(name, height, color)
    local fontObject = addon.FontUtil:GetColoredFont(name, height, color);
    if not sizedFonts[fontObject] then
        sizedFonts[fontObject] = height;
        local file, _, flags = fontObject:GetFont();
        fontObject:SetFont(file, height + FONT_SIZE_STEP * (sizeID - DEFAULT_SIZE_ID), flags);
    end
    return fontObject
end

local function ApplyFontSize(id)
    if type(id) ~= "number" or id < 0 or id > 3 or id == sizeID then
        return
    end
    sizeID = id;
    for fontObject, height in pairs(sizedFonts) do
        local file, _, flags = fontObject:GetFont();
        fontObject:SetFont(file, height + FONT_SIZE_STEP * (id - DEFAULT_SIZE_ID), flags);
    end
end

addon.CallbackRegistry:Register("SettingChanged.LootUI_FontSize", ApplyFontSize);

-- Items per page ("LootUI_ItemsPerPage"): read by LootFrame when it splits the queue into pages.
addon.CallbackRegistry:Register("SettingChanged.LootUI_ItemsPerPage", function(value)
    if type(value) == "number" then
        Def.MAX_ITEM_PER_PAGE = math.min(8, math.max(5, math.floor(value)));
    end
end);

-- Fade out delay per item ("LootUI_FadeDelayPerItem"): read by LootFrame when the window shows its rows.
addon.CallbackRegistry:Register("SettingChanged.LootUI_FadeDelayPerItem", function(value)
    if type(value) == "number" then
        Def.FADE_DELAY_PER_ITEM = math.min(1, math.max(0.25, value));
    end
end);

-- Owned count on the icon ("LootUI_ShowItemCount"): rows refresh it through the ItemCountSettingChanged callback.
addon.CallbackRegistry:Register("SettingChanged.LootUI_ShowItemCount", function(value)
    Def.SHOW_ITEM_COUNT = value and true or false;
    addon.CallbackRegistry:Trigger("LootUI.ItemCountSettingChanged");
end);

function LootUI.GetFont(name, height, color)
    local fontObject = LootUI.GetSizedFont(name, height, color);
    if not lootFonts[fontObject] then
        lootFonts[fontObject] = true;
        local file, size = fontObject:GetFont();
        fontObject:SetFont(file, size, textFlags);
        fontObject:SetShadowOffset(0, 0);
    end
    return fontObject
end

bgOpacity = Def.BG_OPACITY;

local function ApplyTextOutline()
    local outline = not addon.ThemeUtil:IsDarkMode() or (bgOpacity or 1) <= OUTLINE_MAX_OPACITY;
    local flags = outline and "OUTLINE" or "";
    if flags == textFlags then
        return
    end
    textFlags = flags;
    for fontObject in pairs(lootFonts) do
        local file, size = fontObject:GetFont();
        fontObject:SetFont(file, size, flags);
        fontObject:SetShadowOffset(0, 0);
    end
end

-- Called whenever the background opacity changes.
function LootUI.UpdateTextOutline(opacity)
    bgOpacity = opacity;
    ApplyTextOutline();
end

addon.CallbackRegistry:Register("ThemeChanged", ApplyTextOutline);
ApplyTextOutline();


---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------

-- Item name color: the quality color in every theme (the window floats over the game, not over parchment).
function LootUI.GetNameColor(quality)
    return LootUI.GetQualityColor(quality)
end

function LootUI.GetQualityColor(quality)
    local r, g, b = GetItemQualityColor(quality or 1);
    return r, g, b
end
