local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local MainFrame = LootUI.MainFrame;

-- Preview of the notification window ("You Received") while the Loot UI tab of the Settings is open. It is a static
-- window: it stays while settings are changed, with no fade in or out. It runs through the real code, so font size,
-- opacity and the text outline show at once; only Items Per Page fills the rows again, in place (the window does not
-- close). The fade out delay is not seen: the preview never fades out. Nothing here touches the real loot API. Item
-- names and icons come from the item cache when it has them.

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark";

-- {itemID, quantity, forced quality or nil, name fallback, mount}
local ITEMS = {
    {49623, 1, nil, "Shadowmourne"},
    {44151, 1, nil, "Reins of the Blue Proto-Drake", true},
    {36908, 2, nil, "Frost Lotus"},
    {33470, 14, nil, "Frostweave Cloth"},
    {2589, 5, 0, "Linen Cloth"},
    {2592, 3, 0, "Wool Cloth"},
    {36912, 7, nil, "Saronite Ore"},
    {36910, 4, nil, "Titanium Ore"},
    {35623, 2, nil, "Eternal Air"},
    {35624, 3, nil, "Eternal Earth"},
    {36903, 5, nil, "Adder's Tongue"},
    {36860, 1, nil, "Eternal Fire"},
    {41163, 2, nil, "Titansteel Bar"},
};

local function MakeItem(entry, slotIndex)
    local id, quantity, forcedQuality, fallbackName, isMount = unpack(entry);
    local name, link, quality, _, _, _, subType, _, equipSlot, icon = GetItemInfo(id);
    return {
        slotType = Def.SLOT_TYPE_ITEM,
        slotIndex = slotIndex,
        id = id,
        icon = icon or FALLBACK_ICON,
        name = name or fallbackName,
        quantity = quantity,
        quality = forcedQuality or quality or 3,
        link = link or ("item:" .. id),
        subType = (isMount and _G.MOUNT) or subType,
        hideCount = equipSlot ~= nil and equipSlot ~= "",
        looted = false,
        test = true,
    }
end

local function MakeMoney(copper, slotIndex)
    return {
        slotType = Def.SLOT_TYPE_MONEY,
        slotIndex = slotIndex,
        copper = copper,
        quantity = copper,
        name = addon.MoneyUtil:GetShortText(copper),
        quality = 1,
        looted = false,
        test = true,
    }
end

local function EnsureReady()
    if MainFrame.Init then
        MainFrame:Init();
    end
    LootUI.forceEnabled = true;
end

-- Fills the window with the sample items, all at once (more than one page of rows: the page dots show). Rows that are
-- there are replaced in place, the window itself stays.
local function Populate()
    EnsureReady();
    MainFrame.errorMode = nil;
    MainFrame:ReleaseAll();
    LootUI.WipeLootQueue();
    LootUI.QueueDisplayLoot(MakeMoney(128506, 0));
    for _, entry in ipairs(ITEMS) do
        LootUI.QueueDisplayLoot(MakeItem(entry, 0));
    end
    LootUI.FlushLootQueue();
end

local previewing = false;

local function StartPreview()
    previewing = true;
    LootUI.noFade = true;                   -- no fade in or out: the window appears and goes at once (LootFrame.lua)
    LootUI.testHoldTime = 99999;            -- no auto hide while the preview runs
    Populate();
end

local function StopPreview()
    previewing = false;
    LootUI.testHoldTime = nil;
    LootUI.WipeLootQueue();
    if not MainFrame.Init then
        MainFrame:TryHide(true);            -- not CloseFromClick: no real CloseLoot for a preview
    end
    LootUI.forceEnabled = nil;
    LootUI.noFade = nil;
end

-- The preview must always be there while the tab is open. Whatever hides it, empties it or changes its opacity
-- (a setting, the module switching on or off ...) is undone at once: the OnHide hook runs before the frame is drawn
-- again, the watcher catches the rest on the next frame. A real loot window in manual mode is left alone.
local restoring = false;

local function Restore()
    if restoring or not previewing or MainFrame:IsInManualMode() then
        return
    end
    restoring = true;
    Populate();
    restoring = false;
end

local function IsPreviewIntact()
    local rows = MainFrame.activeFrames;
    return MainFrame:IsShown() and MainFrame:GetAlpha() >= 0.99 and rows ~= nil and #rows > 0
end

local watcher = CreateFrame("Frame");
watcher:Hide();
watcher:SetScript("OnUpdate", function()
    if previewing and not IsPreviewIntact() then
        Restore();
    end
end);

-- After MainFrame:Init: it sets the frame's own OnHide, which would drop an earlier hook.
local function HookHide()
    if not MainFrame.previewHooked and not MainFrame.Init then
        MainFrame.previewHooked = true;
        MainFrame:HookScript("OnHide", Restore);
    end
end

local function UpdatePreview()
    local settingsUI = addon.SettingsUI;
    local onTab = settingsUI and settingsUI.IsOnLootUITab and settingsUI:IsOnLootUITab();
    if onTab and not previewing then
        StartPreview();
        HookHide();
        watcher:Show();
    elseif not onTab and previewing then
        watcher:Hide();
        StopPreview();
    end
end

addon.CallbackRegistry:Register("SettingsUI.Show", UpdatePreview);
addon.CallbackRegistry:Register("SettingsUI.Hide", UpdatePreview);
addon.CallbackRegistry:Register("SettingsUI.TabChanged", UpdatePreview);

addon.CallbackRegistry:Register("SettingChanged.LootUI_ItemsPerPage", function()
    if previewing then
        Populate();
    end
end);
