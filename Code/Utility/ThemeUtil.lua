local _, addon = ...;

-- Texture paths for the active theme. Only the Brown theme exists in this port.
local ThemeUtil = {};
addon.ThemeUtil = ThemeUtil;

local TEXTURE_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Theme_Brown\\";
local KEY_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Keys\\";

function ThemeUtil:GetTextureFile(fileName)
    return TEXTURE_PATH .. fileName;
end

-- Key icons (retail Art/Keys), shared by all themes.
function ThemeUtil:GetKeyTextureFile(fileName)
    return KEY_PATH .. fileName;
end
