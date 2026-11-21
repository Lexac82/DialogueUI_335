local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local MainFrame = LootUI.MainFrame;

-- Preview of the notification window ("You Received") while the Loot UI tab of the Settings is open. It is a static
-- window: it stays while settings are changed, with no fade in or out. It runs through the real code, so font size,
-- opacity and the text outline show at once; only Items Per Page fills the rows again, in place (the window does not
-- close). The fade out delay is not seen: the preview never fades out. Nothing here touches the real loot API. Item
-- names and icons come from the item cache when it has them.

-- {itemID, quantity, mount, owned}. Everything else (name, icon, quality, link) comes from GetItemInfo.
-- owned: the number shown on the icon in the preview (the "Show Number Of Owned Items" setting), so it can be seen
-- without owning the items. The real window counts bags and bank with GetItemCount.
local ITEMS = {
    {22589, 1},                 -- Atiesh, Greatstaff of the Guardian
    {17010, 3, nil, 7},         -- Fiery Core
    {17011, 2, nil, 12},        -- Lava Core
    {12360, 5, nil, 34},        -- Arcanite Bar
    {25397, 1},                 -- Eroded Axe (junk)
    {45630, 1},                 -- Invisible Axe (junk)
    {33426, 1},                 -- Chipped Timber Axe (junk)
};

-- GetItemInfo knows only items the client has seen. A hidden tooltip asks the server for the others.
local scanner;
local function RequestItem(id)
    scanner = scanner or CreateFrame("GameTooltip", "DUI335LootTestScanner", nil, "GameTooltipTemplate");
    scanner:SetOwner(UIParent, "ANCHOR_NONE");
    scanner:SetHyperlink("item:" .. id);
    scanner:Hide();
end

local needRetry = false;

-- nil while the item is not in the cache (it is requested, and Populate runs again shortly).
local function MakeItem(entry, slotIndex)
    local id, quantity, isMount, owned = unpack(entry);
    local name, link, quality, _, _, _, subType, _, equipSlot, icon = GetItemInfo(id);
    if not name then
        RequestItem(id);
        needRetry = true;
        return nil
    end
    return {
        slotType = Def.SLOT_TYPE_ITEM,
        slotIndex = slotIndex,
        id = id,
        icon = icon,
        name = name,
        quantity = quantity,
        quality = quality,
        link = link,
        testOwned = owned,
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
    needRetry = false;
    for _, entry in ipairs(ITEMS) do
        local item = MakeItem(entry, 0);
        if item then
            LootUI.QueueDisplayLoot(item);
        end
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
local retryTimer = 0;
watcher:SetScript("OnUpdate", function(_, elapsed)
    if not previewing then
        return
    end
    if not IsPreviewIntact() then
        Restore();
    elseif needRetry then
        retryTimer = retryTimer + elapsed;
        if retryTimer >= 0.5 then
            retryTimer = 0;
            Restore();                      -- fills the rows again with the items the server has answered for
        end
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
