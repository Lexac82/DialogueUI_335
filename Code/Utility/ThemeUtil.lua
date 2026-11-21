local _, addon = ...;

-- Theme: 1 = Brown (default), 2 = Dark. Port of retail's ThemeUtil.
-- Textures: Textures\Theme_Brown\ and Textures\Theme_Dark\ hold the same file names. Code asks for a file with
-- GetTextureFile and never writes the folder. Files in SHARED_FILES have no Dark version and are used by both.
-- On a theme change every font registered with RegisterFont is recolored, every texture or slice handed to
-- BindTexture / BindSlice gets the new file, and the "ThemeChanged" callback fires for everything else
-- (widgets that choose a file or color on the fly re-apply themselves there).
local ThemeUtil = {};
addon.ThemeUtil = ThemeUtil;

local CallbackRegistry = addon.CallbackRegistry;

local SetTextureKeepCoords = addon.API.SetTextureKeepCoords;
local ipairs = ipairs;
local gsub = string.gsub;

local ADDON_PATH = "Interface\\AddOns\\DialogueUI\\Textures\\";
local BROWN_PATH = ADDON_PATH .. "Theme_Brown\\";
local DARK_PATH = ADDON_PATH .. "Theme_Dark\\";
local KEY_PATH = ADDON_PATH .. "Keys\\";

local THEME_BROWN = 1;
local THEME_DARK = 2;

local TEXTURE_PATH = BROWN_PATH;
local THEME_ID = THEME_BROWN;

-- No Dark version exists (retail has none, or the file is identical). Always read from Theme_Brown.
local SHARED_FILES = {
    ["Coin-Copper.blp"] = true,
    ["Coin-Silver.blp"] = true,
    ["Coin-Gold.blp"] = true,
    ["XP-Purple.blp"] = true,
    ["ScrollBar-Vertical-Buttons.blp"] = true,
    ["ScrollBar-Vertical-Rail.blp"] = true,
    ["ScrollBar-Vertical-Thumb.blp"] = true,
    ["ButtonHighlight-Add.blp"] = true,
    ["RewardChoice-Highlight.blp"] = true,
    ["RewardChoice-Highlight-Back.blp"] = true,
    ["RewardChoice-Sheen.blp"] = true,
};


---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------

local COLORS = {
    DarkBrown = {0.19, 0.17, 0.13},
    LightBrown = {0.50, 0.36, 0.24},
    MutedBrown = {0.45, 0.36, 0.24},        -- this port: quest tag pills
    Ivory = {0.87, 0.86, 0.75},
    Brick = {0.416, 0.18, 0.165},

    DarkModeGrey90 = {0.9, 0.9, 0.9},
    DarkModeGrey70 = {0.7, 0.7, 0.7},
    DarkModeGrey50 = {0.5, 0.5, 0.5},
    DarkModeGold = {1, 0.98, 0.8},
    DarkModeGoldDim = {0.796, 0.784, 0.584},

    WarningRed = {1.000, 0.125, 0.125},
    BrownRed = {0.61, 0.125, 0.125},        -- |cff9B2020
};

function ThemeUtil:GetColor(key)
    local color = COLORS[key];
    return color[1], color[2], color[3]
end

-- Brown replaces pure red text with a darker red (legibility on paper), Dark replaces pure blue with a lighter blue.
local ColorAdjustment = {
    Red = {
        pattern = {
            "|[cC][fF][fF][fF][fF]0000",
            "|[cC][fF][fF][fF][fF]4040",
        },
        replaceBy = "|cff9B2020",
    },
    Blue = {
        pattern = {
            "|[cC][fF][fF]0000[fF][fF]",
        },
        replaceBy = "|cff0078FF",
    },
};

local ActiveColorLookup = ColorAdjustment.Red;

-- Returns the adjusted text and whether a replacement was made.
function ThemeUtil:AdjustTextColor(text)
    local count = 0;
    for _, pattern in ipairs(ActiveColorLookup.pattern) do
        text, count = gsub(text, pattern, ActiveColorLookup.replaceBy);
        if count > 0 then
            break
        end
    end
    return text, count > 0
end

-- Color of "can't afford / unusable" text.
function ThemeUtil:GetWarningColor()
    if THEME_ID == THEME_DARK then
        return self:GetColor("WarningRed")
    end
    return self:GetColor("BrownRed")
end

-- Item name color: quality color in Dark, plain text color in Brown.
function ThemeUtil:GetQualityColor(quality)
    if THEME_ID == THEME_DARK then
        local r, g, b = GetItemQualityColor(quality or 1);
        return r, g, b
    end
    return self:GetColor("DarkBrown")
end

function ThemeUtil:GetItemSelectColor()
    if THEME_ID == THEME_DARK then
        return self:GetColor("DarkModeGold")
    end
    return self:GetColor("Ivory")
end


---------------------------------------------------------------------------
-- Fonts, textures, callbacks
---------------------------------------------------------------------------

local registeredFonts = {};     -- {fontObject, brownKey, darkKey}
local boundTextures = {};       -- {texture, fileName}
local boundSlices = {};         -- {slice, fileName}: a NineSlice table (array of textures) or a TiledSlice object

local function ApplyFont(entry)
    local key = (THEME_ID == THEME_DARK) and entry[3] or entry[2];
    local color = COLORS[key];
    entry[1]:SetTextColor(color[1], color[2], color[3]);
end

-- Recolored on every theme change. colorKeys: {BrownColorKey, DarkColorKey}, names from COLORS.
function ThemeUtil:RegisterFont(fontObject, colorKeys)
    local entry = {fontObject, colorKeys[1], colorKeys[2]};
    registeredFonts[#registeredFonts + 1] = entry;
    ApplyFont(entry);
end

local function ApplySlice(slice, file)
    if slice.SetTexture then
        slice:SetTexture(file);                 -- TiledSlice
    else
        for i = 1, #slice do
            SetTextureKeepCoords(slice[i], file);   -- NineSlice:Create / CreateEdges
        end
    end
end

-- The texture follows the theme. Sets it now.
function ThemeUtil:BindTexture(texture, fileName)
    boundTextures[#boundTextures + 1] = {texture, fileName};
    SetTextureKeepCoords(texture, self:GetTextureFile(fileName));
end

-- Same for a 9-slice (NineSlice:Create, CreateEdges or CreateTiled). Sets it now.
function ThemeUtil:BindSlice(slice, fileName)
    boundSlices[#boundSlices + 1] = {slice, fileName};
    ApplySlice(slice, self:GetTextureFile(fileName));
end

function ThemeUtil:SetThemeByID(themeID)
    if themeID == THEME_DARK then
        TEXTURE_PATH = DARK_PATH;
        ActiveColorLookup = ColorAdjustment.Blue;
    else
        themeID = THEME_BROWN;
        TEXTURE_PATH = BROWN_PATH;
        ActiveColorLookup = ColorAdjustment.Red;
    end
    THEME_ID = themeID;

    for _, entry in ipairs(registeredFonts) do
        ApplyFont(entry);
    end
    for _, bound in ipairs(boundTextures) do
        SetTextureKeepCoords(bound[1], self:GetTextureFile(bound[2]));
    end
    for _, bound in ipairs(boundSlices) do
        ApplySlice(bound[1], self:GetTextureFile(bound[2]));
    end

    CallbackRegistry:Trigger("ThemeChanged", themeID);
end


---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

function ThemeUtil:GetTextureFile(fileName)
    if SHARED_FILES[fileName] then
        return BROWN_PATH .. fileName
    end
    return TEXTURE_PATH .. fileName
end

-- Brown file for a part that does not follow the theme (the Book's paper strip, dark text on tan).
function ThemeUtil:GetFixedTextureFile(fileName)
    return BROWN_PATH .. fileName
end

-- Quality / alert / transmog corner overlays: the Brown sheet is used in both themes (the Dark sheet is not wanted).
-- index: 1-based cell of the 8 column grid of 64 px cells, nil hides the texture.
-- mirror: flipped left to right (the corner moves from the top right to the top left).
function ThemeUtil:SetItemOverlay(texture, index, mirror)
    if not index then
        texture:Hide();
        return
    end
    local column = (index - 1) % 8;
    local row = (index - 1 - column) / 8;
    local left, right = column / 8, (column + 1) / 8;
    if mirror then
        left, right = right, left;
    end
    texture:SetTexture(BROWN_PATH .. "ItemOverlays.blp");
    texture:SetTexCoord(left, right, row / 8, (row + 1) / 8);
    texture:Show();
end

-- Key icons (retail Art/Keys), shared by all themes.
function ThemeUtil:GetKeyTextureFile(fileName)
    return KEY_PATH .. fileName
end

function ThemeUtil:GetThemeID()
    return THEME_ID
end

function ThemeUtil:IsDarkMode()
    return THEME_ID == THEME_DARK
end


-- "SettingChanged.Theme" fires once at load (saved value) and on every change.
CallbackRegistry:Register("SettingChanged.Theme", function(dbValue)
    ThemeUtil:SetThemeByID(dbValue);
end);
