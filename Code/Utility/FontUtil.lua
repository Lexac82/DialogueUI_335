local _, addon = ...;

-- Font objects for the parchment frame. Same fonts as retail's DUIFontFamily_Serif_18.
local FontUtil = {};
addon.FontUtil = FontUtil;

-- Friz Quadrata for Latin and Cyrillic, the client's own CJK fonts for Asian locales.
local TITLE_FONT_FILE = {
    roman = "Interface\\AddOns\\DialogueUI\\Fonts\\frizqt__.ttf",
    korean = "Fonts\\2002.TTF",
    simplifiedchinese = "Fonts\\ARKai_T.ttf",
    traditionalchinese = "Fonts\\blei00d.TTF",
    russian = "Interface\\AddOns\\DialogueUI\\Fonts\\frizqt___cyr.ttf",
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

-- Font setting ("FontText", retail's key). "default" = Friz Quadrata (per alphabet), "system" = the client's own font,
-- anything else = the file path of a font registered with LibSharedMedia-3.0 (the SharedMedia addon, or any other addon
-- that registers fonts the same way). Applied to every font object made here; the item count keeps its number font.
--   "FontChanged"   (file)   after the font objects got the new font file
local COUNT_FONT_NAME = "DUI335_ItemCount";
local LIB_NAME = "LibSharedMedia-3.0";

local appliedFile;              -- file the font objects have now
local libReady = false;         -- true once all addons have loaded (PLAYER_ENTERING_WORLD): the font list is complete
local usableCache = {};         -- [file] = true / false: the file loaded or not
local testFont;

-- The client's own font: STANDARD_TEXT_FONT is a FrameXML constant, localized by the client.
local function GetSystemFontFile()
    return STANDARD_TEXT_FONT or TITLE_FONT_FILE.roman
end

local function GetDefaultFontFile()
    return TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman
end

-- LibSharedMedia is loaded by whichever addon carries it, so it is looked up each time and never kept.
local function GetLibrary()
    if LibStub and LibStub.GetLibrary then
        return LibStub:GetLibrary(LIB_NAME, true)
    end
end

-- Fonts registered with LibSharedMedia: array of {name, file}, sorted by name. Empty without the library.
-- Built once and kept: every page of the font menu asks for the files of its entries. The Font menu and the
-- Font row ask for a fresh list (GetFontChoices) because an addon may have registered more fonts since.
local installedList, installedSet;

local function BuildInstalledFonts()
    installedList, installedSet = {}, {};
    local lib = GetLibrary();
    if lib then
        local names = lib:List("font");
        local files = lib:HashTable("font");
        for _, name in ipairs(names) do
            local file = files[name];
            if file then
                installedList[#installedList + 1] = { name, file };
                installedSet[file] = true;
            end
        end
    end
end

function FontUtil:GetInstalledFonts()
    if not installedList then
        BuildInstalledFonts();
    end
    return installedList
end

function FontUtil:HasSharedMedia()
    return GetLibrary() ~= nil
end

local function IsFontInstalled(file)
    if not installedSet then
        BuildInstalledFonts();
    end
    return installedSet[file] == true
end

-- Tries the file on a spare font object: a missing or broken file makes SetFont return nil. The answer is kept
-- either way, loading a font file is the slow part and a broken one would be tried again on every page.
local function IsFontUsable(file)
    local known = usableCache[file];
    if known ~= nil then
        return known
    end
    testFont = testFont or CreateFont("DUI335_FontTest");
    known = testFont:SetFont(file, 12, "") and true or false;
    usableCache[file] = known;
    return known
end

-- File for a saved value; falls back to the default when the font is gone (addon disabled or removed).
function FontUtil:GetFontFile(dbValue)
    if dbValue == "system" then
        return GetSystemFontFile()
    elseif type(dbValue) == "string" and dbValue ~= "default" and dbValue ~= "" then
        -- Before the other addons have loaded the font list is not complete, so the file itself is the test.
        if (not libReady or IsFontInstalled(dbValue)) and IsFontUsable(dbValue) then
            return dbValue
        end
    end
    return GetDefaultFontFile()
end

-- File of the font the player chose.
function FontUtil:GetTextFontFile()
    return self:GetFontFile(addon.GetDBValue("FontText"))
end

-- Entries of the Font dropdown: array of {name = shown text, dbValue = saved value}.
function FontUtil:GetFontChoices()
    installedList, installedSet = nil, nil;      -- look at the registered fonts again
    local choices = {
        { name = addon.L["Default Font"], dbValue = "default" },
        { name = addon.L["System Font"], dbValue = "system" },
    };
    for _, data in ipairs(self:GetInstalledFonts()) do
        choices[#choices + 1] = { name = data[1], dbValue = data[2] };
    end
    return choices
end

-- Font size setting ("FontSizeBase" 0..3, retail's FONT_SIZE_INDEX / FONT_OBJECT_HEIGHT). The paragraph font is the
-- base: 11, 12, 13, 14. Each font below has its own heights per choice; fonts not listed keep the height they were
-- created with. Font objects are created by name, so a listed name gets its height from here.
--   "FontSizeChanged"   (baseFontSize, id)   after the font objects were resized (and once at load)
local BASE_SIZES = { [0] = 11, [1] = 12, [2] = 13, [3] = 14 };
local DEFAULT_SIZE_ID = 1;
local HEIGHT_1 = { [0] = 11, 12, 13, 14 };                  -- same as the base
local HEIGHT_2 = { [0] = 9, 10, 11, 12 };                   -- secondary text (items, hotkeys, tooltip body)

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
    DUI335_QuickSlot_Text = HEIGHT_2,       -- Valuable Reward Popup: retail's ButtonText uses DUIFont_Item

    DUI335_ItemCount = { [0] = 9, 10, 11, 12 },
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
        local file = self:GetTextFontFile();
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
        local file = self:GetTextFontFile();
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
        local file = self:GetTextFontFile();
        fontObject = CreateFont(name);
        fontObject:SetFont(file, height, "OUTLINE");
        fontObject:SetTextColor(color[1], color[2], color[3]);
        fontObjects[name] = fontObject;
    end
    return fontObject;
end

-- Item stack count font: retail uses ARIALN 10 with outline. The client's own copy is used here.
function FontUtil:GetCountFont()
    local name = COUNT_FONT_NAME;
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

-- Gives every font object the chosen font file (height and outline stay). Font objects made later ask for the file
-- themselves. Text is laid out again when the file changed: the glyphs have other widths.
local function ApplyUserFont()
    local file = FontUtil:GetTextFontFile();
    -- The first call comes from the saved value, with font objects that were made with the default font.
    local changed = file ~= (appliedFile or GetDefaultFontFile());
    appliedFile = file;
    for name, fontObject in pairs(fontObjects) do
        if name ~= COUNT_FONT_NAME then
            local _, height, flags = fontObject:GetFont();
            fontObject:SetFont(file, height, flags);
        end
    end
    if changed then
        addon.CallbackRegistry:Trigger("FontChanged", file);
        -- Same work as a new font size: sizes that depend on the text are measured again.
        addon.CallbackRegistry:Trigger("FontSizeChanged", BASE_SIZES[sizeID], sizeID);
    end
end

addon.CallbackRegistry:Register("SettingChanged.FontText", ApplyUserFont);

-- All addons have loaded, so LibSharedMedia has its fonts: a saved font that is not among them is gone.
addon.CallbackRegistry:Register("PLAYER_ENTERING_WORLD", function()
    libReady = true;
    ApplyUserFont();
end);

-- The title follows the frame size: set the new height on the existing font object (its FontStrings follow).
function FontUtil:SetQuestTitleFontHeight(height)
    local fontObject = self:GetQuestTitleFont(height);
    local file = fontObject:GetFont();
    fontObject:SetFont(file, height, "");
end
