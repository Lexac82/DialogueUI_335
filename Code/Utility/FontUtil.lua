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

local titleFontObject;

-- Returns the shared quest title font object, created on first use.
function FontUtil:GetQuestTitleFont(height)
    if not titleFontObject then
        local file = TITLE_FONT_FILE[GetAlphabetForClient()] or TITLE_FONT_FILE.roman;
        titleFontObject = CreateFont("DUIFont_Quest_Title");
        titleFontObject:SetFont(file, height, "");
        titleFontObject:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3]);
    end
    return titleFontObject;
end
