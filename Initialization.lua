local VERSION_TEXT = "0.1.0";


local addonName, addon = ...;

local L = {};       --Locale
local API = {};     --Custom APIs used by this addon
local DB;

-- A missing translation falls back to its own key, so a typo shows up as readable text and not as an error.
setmetatable(L, {
    __index = function(_, key)
        return key
    end,
});

addon.L = L;
addon.API = API;
addon.VERSION_TEXT = VERSION_TEXT;

-- Same key names as retail's DefaultValues, so the future settings menu can reuse retail's definitions.
-- Where our default differs from retail's it is noted.
local DefaultValues = {
    --Appearance
    Theme = 1,                                  --1 Brown, 2 Dark
    FrameSize = 2,                              --0..3 = 0.9, 1.0, 1.1, 1.25 (retail default 2, see FrameSize.lua)

    --Reward tooltip
    UseBlizzardTooltip = false,
    TooltipShowItemComparison = false,

    --Quest rewards
    MarkHighestSellPrice = true,                --Retail: false

    --Quest Item Display
    QuestItemDisplay = true,                    --Retail: false
        QuestItemDisplayHideSeen = false,
        QuestItemDisplayAwaitWorldMap = false,
        QuestItemDisplayFontSize = 14,          --Not in retail (it follows FontSizeBase)

    --Book Settings
    BookUIEnabled = true,
        BookUISize = 1,                         --0..4 = 0.9, 1.0, 1.1, 1.25, 1.4
        BookFontSize = 12,                      --Not in retail (it follows FontSizeBase)
        BookKeepUIOpen = false,
        BookShowLocation = true,                --Retail: false
        BookUIItemDescription = true,           --Retail: false
        BookDarkenScreen = true,

    --Not shown in the Settings. Accessible by other means
    DebugGossip = false,                        --Prints the raw gossip lists: /run DialogueUI_335_DB.DebugGossip = true

    --ParchmentPosition = {point, relativePoint, x, y}
    --BookPosition = {point, relativePoint, x, y}
    --QuestItemDisplayPosition = {x, y}
    --QuestItems = {[itemID] = true}            --Items the Quest Item Display has shown
};

-- Keys that were renamed to match retail. The old value is moved to the new key once.
local RenamedKeys = {
    {"BookSizeIndex", "BookUISize"},
    {"QuestItemDisplayEnabled", "QuestItemDisplay"},
};

local function GetDBValue(dbKey)
    if DB then
        return DB[dbKey]
    end
    --Saved variables are not loaded yet (file load time)
    return DefaultValues[dbKey]
end
addon.GetDBValue = GetDBValue;

local function SetDBValue(dbKey, value, userInput)
    if not DB then return end;
    DB[dbKey] = value;
    addon.CallbackRegistry:Trigger("SettingChanged."..dbKey, value, userInput);
end
addon.SetDBValue = SetDBValue;

local function GetDBBool(dbKey)
    return GetDBValue(dbKey) == true
end
addon.GetDBBool = GetDBBool;

local function FlipDBBool(dbKey, userInput)
    SetDBValue(dbKey, not GetDBBool(dbKey), userInput);
end
addon.FlipDBBool = FlipDBBool;

local function IsDBValue(dbKey, value)
    return GetDBValue(dbKey) == value
end
addon.IsDBValue = IsDBValue;

local function LoadDatabase()
    DialogueUI_335_DB = DialogueUI_335_DB or {};
    DB = DialogueUI_335_DB;

    for _, v in ipairs(RenamedKeys) do
        local oldKey, newKey = v[1], v[2];
        if DB[oldKey] ~= nil then
            if DB[newKey] == nil then
                DB[newKey] = DB[oldKey];
            end
            DB[oldKey] = nil;
        end
    end

    local type = type;

    for dbKey, defaultValue in pairs(DefaultValues) do
        --Some settings are inter-connected so we load all values first
        if DB[dbKey] == nil or type(DB[dbKey]) ~= type(defaultValue) then
            DB[dbKey] = defaultValue;
        end
    end

    --Every setting announces its value once, so modules can apply it from their SettingChanged callback
    for dbKey in pairs(DefaultValues) do
        SetDBValue(dbKey, DB[dbKey]);
    end

    addon.CallbackRegistry:Trigger("ADDON_LOADED", DB);
end


local EL = CreateFrame("Frame");
EL:RegisterEvent("ADDON_LOADED");
EL:RegisterEvent("PLAYER_ENTERING_WORLD");

EL:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            self:UnregisterEvent(event);
            LoadDatabase();
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent(event);
        addon.CallbackRegistry:Trigger("PLAYER_ENTERING_WORLD");
    end
end);
