local _, addon = ...;

-- Font objects for the parchment frame. Same fonts as retail's DUIFontFamily_Serif_18.
local FontUtil = {};
addon.FontUtil = FontUtil;

-- Friz Quadrata for Latin and Cyrillic, the client's own CJK fonts for Asian locales.
local TITLE_FONT_FILE = {
    roman = "Interface\\AddOns\\DialogueUI_335\\Fonts\\frizqt__.ttf",
    korean = "Fonts\\2002.TTF",
    simplifiedchinese = "Fonts\\ARKai_T.ttf",
    traditionalchinese = "Fonts\\blei00d.TTF",
    russian = "Interface\\AddOns\\DialogueUI_335\\Fonts\\frizqt___cyr.ttf",
};

local TITLE_COLOR = { 0.19, 0.17, 0.13 };

local AlphabetLocales = {
    roman = { "enUS", "frFR", "deDE", "esES", "esMX", "ptBR", "itIT" },
    korean = { "koKR" },
    simplifiedchinese = { "zhCN" },
    traditionalchinese = { "zhTW" },
    russian = { "ruRU" },
};

-- The client locale is fixed for the session, so resolve the alphabet once.
local clientAlphabet;

local function GetAlphabetForClient()
    if not clientAlphabet then
        local clientLocale = GetLocale() or "enUS";
        for alphabet, locales in pairs(AlphabetLocales) do
            for _, locale in ipairs(locales) do
                if locale == clientLocale then
                    clientAlphabet = alphabet;
                end
            end
        end
        clientAlphabet = clientAlphabet or "roman";
    end
    return clientAlphabet;
end

local fontObjects = {};

-- Font size setting ("FontSizeBase" 0..3, retail's FONT_SIZE_INDEX / FONT_OBJECT_HEIGHT). The paragraph font is the
-- base: 10, 12, 14, 16. Each font below has its own heights per choice; fonts not listed keep the height they were
-- created with. Font objects are created by name, so a listed name gets its height from here.
--   "FontSizeChanged"   (baseFontSize, id)   after the font objects were resized (and once at load)
local BASE_SIZES = { [0] = 10, [1] = 12, [2] = 14, [3] = 16 };
local DEFAULT_SIZE_ID = 1;
local HEIGHT_1 = { [0] = 10, 12, 14, 16 };                  -- same as the base
local HEIGHT_2 = { [0] = 8, 10, 12, 14 };                   -- secondary text (items, hotkeys, tooltip body)

local FONT_HEIGHT = {
    DUI335_Quest_Paragraph = HEIGHT_1,
    DUI335_Quest_SubHeader = HEIGHT_1,
    DUI335_Option_active = HEIGHT_1,
    DUI335_Option_disabled = HEIGHT_1,
    DUI335_Option_gossip = HEIGHT_1,
    DUI335_Tooltip_Large = HEIGHT_1,

    DUI335_Tooltip_Medium = HEIGHT_2,
    DUI335_Item = HEIGHT_2,
    DUI335_ItemSelect = HEIGHT_2,
    DUI335_Hotkey = HEIGHT_2,
    DUI335_QuestType = HEIGHT_2,

    DUI335_ItemCount = { [0] = 8, 10, 10, 12 },
};

local sizeID = DEFAULT_SIZE_ID;

-- Height of the named font for the current size choice, or the given default for a font that does not follow it.
local function ResolveHeight(name, height)
    local heights = FONT_HEIGHT[name];
    return heights and heights[sizeID] or height
end

-- Colors of a font follow the theme (see ThemeUtil:RegisterFont). Quest text default: retail DUIFont_Quest_Title.
local DEFAULT_COLOR_KEYS = { "DarkBrown", "DarkModeGrey90" };

-- Returns the named quest font object, created on first use. Retail's DUIFontFamily_Serif_<n>.
-- colors: {BrownColorKey, DarkColorKey} from ThemeUtil (default: title color), or false for a font that keeps
-- a fixed color and sets it itself (the Book).
function FontUtil:GetQuestFont(name, height, colors)
    local fontObject = fontObjects[name];
    if not fontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        fontObject = CreateFont(name);
        fontObject:SetFont(file, ResolveHeight(name, height), "");
        fontObjects[name] = fontObject;
        if colors == false then
            fontObject:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3]);
        else
            addon.ThemeUtil:RegisterFont(fontObject, colors or DEFAULT_COLOR_KEYS);
        end
    end
    return fontObject;
end

-- Same Friz Quadrata (per-alphabet) font with an explicit colour. Used for the item names and the tooltip.
-- color: {r, g, b} (fixed), or {BrownColorKey, DarkColorKey} (follows the theme). Created on first use, cached by name.
function FontUtil:GetColoredFont(name, height, color)
    local fontObject = fontObjects[name];
    if not fontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        fontObject = CreateFont(name);
        fontObject:SetFont(file, ResolveHeight(name, height), "");
        fontObjects[name] = fontObject;
        if type(color[1]) == "string" then
            addon.ThemeUtil:RegisterFont(fontObject, color);
        else
            fontObject:SetTextColor(color[1], color[2], color[3]);
        end
    end
    return fontObject;
end

-- Same per-alphabet font with an outline. Used for the quest accepted alert (retail DUIFont_AlertFont).
function FontUtil:GetOutlinedFont(name, height, color)
    local fontObject = fontObjects[name];
    if not fontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        fontObject = CreateFont(name);
        fontObject:SetFont(file, height, "OUTLINE");
        fontObject:SetTextColor(color[1], color[2], color[3]);
        fontObjects[name] = fontObject;
    end
    return fontObject;
end

-- Item stack count font: retail uses ARIALN 10 with outline. The client's own copy is used here.
function FontUtil:GetCountFont()
    local name = "DUI335_ItemCount";
    local fontObject = fontObjects[name];
    if not fontObject then
        fontObject = CreateFont(name);
        fontObject:SetFont("Fonts\\ARIALN.TTF", ResolveHeight(name, 10), "OUTLINE");
        fontObject:SetTextColor(1, 1, 1);
        fontObjects[name] = fontObject;
    end
    return fontObject;
end

-- Returns the shared quest title font object.
function FontUtil:GetQuestTitleFont(height)
    return self:GetQuestFont("DUIFont_Quest_Title", height);
end

function FontUtil:GetBaseFontSize()
    return BASE_SIZES[sizeID]
end

-- Sets the heights of every listed font that already exists (the others pick theirs up when created), then announces it.
local function ApplyFontSize(id)
    if not BASE_SIZES[id] or id == sizeID then
        return
    end
    sizeID = id;
    for name, heights in pairs(FONT_HEIGHT) do
        local fontObject = fontObjects[name];
        if fontObject then
            local file, _, flags = fontObject:GetFont();
            fontObject:SetFont(file, heights[id], flags);
        end
    end
    addon.CallbackRegistry:Trigger("FontSizeChanged", BASE_SIZES[id], id);
end

-- Registered here, before the parts that listen to "FontSizeChanged" (FontUtil loads before them).
addon.CallbackRegistry:Register("SettingChanged.FontSizeBase", ApplyFontSize);

-- The title follows the frame size: set the new height on the existing font object (its FontStrings follow).
function FontUtil:SetQuestTitleFontHeight(height)
    local fontObject = self:GetQuestTitleFont(height);
    local file = fontObject:GetFont();
    fontObject:SetFont(file, height, "");
end
