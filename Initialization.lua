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
    FontSizeBase = 1,                           --0..3 = 10, 12, 14, 16 (see FontUtil.lua)
    HideUI = true,                              --Fade out the game UI during a conversation (see HideUI.lua)
    ShowCopyTextButton = false,                 --Copy Text button in the top right corner (see Clipboard.lua)
    ShowNPCNameOnPage = false,                  --"Name: " in front of the page text (see QuestTextLayout.lua)
    ShowQuestType = false,                      --Quest type pills (Quest / Daily / Dungeon ...) in the header (not in retail, see HeaderTags.lua)
    QuestDifficultyStyle = 1,                   --0 Off, 1 Level (default), 2 Name, 3 Both (not in retail) (see GossipDataProvider.lua)
    FrameOrientation = 2,                  --1 Left, 2 Right (default), 3 Custom (not in retail: drag the frame, ParchmentPosition)

    --Control
    InputDevice = 1,                            --1 Keyboard & Mouse (the only one in 3.3.5a, no gamepad)
    RightClickToCloseUI = true,                 --Right click on the dialogue or a readable closes it
    CycleRewardHotkeyEnabled = false,           --Tab / Shift-Tab choose the next / previous quest reward (see FooterButtons.lua)
    ScrollDownThenAcceptQuest = false,          --Confirm key scrolls a long quest text down before accepting (see FooterButtons.lua)
    EscapeToDeclineQuest = false,               --Esc on a quest chosen from a list goes back to the list instead of closing (see FooterButtons.lua)
    UseCustomBindings = false,                --Own keys for Confirm / Settings / Option 1-9 (see Keybindings.lua, DB.CustomBindings)

    --Reward tooltip
    UseBlizzardTooltip = false,
    TooltipShowItemComparison = false,

    --Quest rewards
    MarkHighestSellPrice = false,
    ShowUpgradeArrow = true,                    --Green arrow on reward items with a higher item level than the equipped one (see RewardLayout.lua)

    --Quest Item Display
    QuestItemDisplay = true,                    --Retail: false
        QuestItemDisplayHideSeen = false,
        QuestItemDisplayAwaitWorldMap = false,
        QuestItemDisplayFontSize = 14,          --Not in retail (it follows FontSizeBase)

    --Valuable Reward Popup (Widget_QuickSlot.lua). Needs Pawn, like the upgrade arrow
    QuickSlotQuestReward = false,
        QuickSlotUseHotkey = true,              --The Confirm key equips the item (Press Button To Use)

    --Book Settings
    BookUIEnabled = true,
        BookUISize = 1,                         --0..4 = 0.9, 1.0, 1.1, 1.25, 1.4
        BookFontSize = 12,                      --Not in retail (it follows FontSizeBase)
        BookKeepUIOpen = false,
        BookShowLocation = true,                --Retail: false
        BookUIItemDescription = true,           --Retail: false
        BookDarkenScreen = false,

    --Not shown in the Settings. Accessible by other means
    DebugGossip = false,                        --Prints the raw gossip lists: /run DialogueUI_335_DB.DebugGossip = true

    --ParchmentPosition = {point, relativePoint, x, y}
    --BookPosition = {point, relativePoint, x, y}
    --QuestItemDisplayPosition = {x, y}
    --QuickSlotPosition = {x, y}               --Center of the Valuable Reward Popup, from the bottom left of the screen
    --QuestItems = {[itemID] = true}          --Items the Quest Item Display has shown
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
