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

-- Returns the named quest font object, created on first use. Retail's DUIFontFamily_Serif_<n>.
function FontUtil:GetQuestFont(name, height)
    local fontObject = fontObjects[name];
    if not fontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        fontObject = CreateFont(name);
        fontObject:SetFont(file, height, "");
        fontObject:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3]);
        fontObjects[name] = fontObject;
    end
    return fontObject;
end

-- Same Friz Quadrata (per-alphabet) font with an explicit colour. Used for the item names and the tooltip.
-- color: {r, g, b}. Created on first use, cached by name.
function FontUtil:GetColoredFont(name, height, color)
    local fontObject = fontObjects[name];
    if not fontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        fontObject = CreateFont(name);
        fontObject:SetFont(file, height, "");
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
        fontObject:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE");
        fontObject:SetTextColor(1, 1, 1);
        fontObjects[name] = fontObject;
    end
    return fontObject;
end

-- Returns the shared quest title font object.
function FontUtil:GetQuestTitleFont(height)
    return self:GetQuestFont("DUIFont_Quest_Title", height);
end
