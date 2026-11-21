local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local MainFrame = LootUI.MainFrame;

-- Preview of the notification window ("You Received") while the Loot UI tab of the Settings is open. It is a static
-- window: it stays while settings are changed, with no fade in or out. It runs through the real code, so font size,
-- opacity and the text outline show at once; Items Per Page and the settings that change the rows fill them again, in
-- place (the window does not close). The preview shows two pages in turn. The fade out delay is not seen: the preview
-- never fades out. Nothing here touches the real loot API. Item
-- names and icons come from the item cache when it has them.

-- Two pages that take turns every PAGE_SECONDS (the dots on the left show on the first one, as in the real window).
-- A page is cut to "Items Per Page" entries (page 2 has 5), so a page never needs a second one.
local PAGE_SECONDS = 3;

-- Page 1. {itemID, quantity, mount, owned}. Everything else (name, icon, quality, link) comes from GetItemInfo.
-- owned: the number shown on the icon in the preview (the "Show Number Of Owned Items" setting), so it can be seen
-- without owning the items. The real window counts bags and bank with GetItemCount.
-- The money row is queued first, then these. The junk items come first so that "Combine Similar Items" shows at once.
local ITEMS = {
    {25397, 1},                 -- Eroded Axe (junk)
    {45630, 1},                 -- Invisible Axe (junk)
    {33426, 1},                 -- Chipped Timber Axe (junk)
    {22589, 1},                 -- Atiesh, Greatstaff of the Guardian
    {12360, 5, nil, 34},        -- Arcanite Bar
    {17010, 3, nil, 7},         -- Fiery Core
    {17011, 2, nil, 12},        -- Lava Core
};

-- Page 2: reputation, honor points, arena points and an item currency (Emblem of Triumph).
local EMBLEM_ID = 47241;
local HONOR_ICON = "Interface\\AddOns\\DialogueUI\\Textures\\Icons\\Honor.blp";
local ARENA_ICON = "Interface\\AddOns\\DialogueUI\\Textures\\Icons\\Conquest.blp";

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

local function MakeReputation(name, amount)
    return {
        slotType = Def.SLOT_TYPE_REP,
        slotIndex = 0,
        id = name,
        name = name,
        quantity = amount,
        quality = 1,
        looted = false,
        test = true,
    }
end

local function MakeCurrency(id, name, icon, amount, quality)
    return {
        slotType = Def.SLOT_TYPE_CURRENCY,
        slotIndex = 0,
        id = id,
        name = name,
        icon = icon,
        quantity = amount,
        quality = quality or 1,
        hideCount = false,
        looted = false,
        test = true,
    }
end

-- nil while the Emblem is not in the item cache (it is requested, and Populate runs again shortly).
local function MakeEmblem(amount)
    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(EMBLEM_ID);
    if not name then
        RequestItem(EMBLEM_ID);
        needRetry = true;
        return nil
    end
    local data = MakeCurrency(EMBLEM_ID, name, icon, amount, quality);
    data.link = link;
    return data
end

local function EnsureReady()
    if MainFrame.Init then
        MainFrame:Init();
    end
    LootUI.forceEnabled = true;
end

local page = 1;                      -- the page that is shown (1 or 2)
local pageTimer = 0;

-- Fills the window with the sample rows of the current page, all at once. Rows that are there are replaced in place,
-- the window itself stays.
local function Populate()
    EnsureReady();
    MainFrame.errorMode = nil;
    MainFrame:ReleaseAll();
    LootUI.WipeLootQueue();
    needRetry = false;
    local count = 0;
    local function Queue(data)
        if data and count < Def.MAX_ITEM_PER_PAGE then      -- a page never needs a second one (Items Per Page)
            count = count + 1;
            LootUI.QueueDisplayLoot(data);
        end
    end

    if page == 1 then
        Queue(MakeMoney(128506, 0));
        for _, entry in ipairs(ITEMS) do
            Queue(MakeItem(entry, 0));
        end
    else
        Queue(MakeReputation("Argent Crusade", 250));
        Queue(MakeReputation("Kirin Tor", 125));
        Queue(MakeCurrency(1901, _G.HONOR_POINTS or "Honor Points", HONOR_ICON, 54));
        Queue(MakeCurrency(1900, _G.ARENA_POINTS or "Arena Points", ARENA_ICON, 12));
        Queue(MakeEmblem(2));
    end
    LootUI.FlushLootQueue();
    if page == 1 then
        MainFrame:SetMaxPage(2);        -- the dot of the next page (the real window shows what is still to come)
    end
end

local previewing = false;

local function StartPreview()
    previewing = true;
    page = 1;
    pageTimer = 0;
    LootUI.noFade = true;                   -- no fade in or out: the window appears and goes at once (LootFrame.lua)
    LootUI.testHoldTime = 99999;            -- no auto hide while the preview runs
    Populate();
end

local function StopPreview()
    previewing = false;
    MainFrame:SetMoveMode(false);
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
    if MainFrame:IsInManualMode() then
        return
    end
    if MainFrame:IsMoveMode() then
        -- Move: the page stays (a row that is released under a drag would never see the drop), and a drop that no
        -- row or frame saw (the mouse button came up elsewhere) is finished here.
        pageTimer = 0;
        if MainFrame.isDragging and not IsMouseButtonDown("LeftButton") then
            MainFrame:StopDrag();
        end
    end
    pageTimer = pageTimer + elapsed;
    if pageTimer >= PAGE_SECONDS then
        pageTimer = 0;
        page = (page == 1) and 2 or 1;
        Restore();
    elseif not IsPreviewIntact() then
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
    local onTab = settingsUI and settingsUI.IsOnLootUITab and settingsUI:IsOnLootUITab()
        and addon.GetDBBool("LootUI");      -- no preview while "Use Loot UI" is off
    if onTab and not previewing then
        StartPreview();
        HookHide();
        watcher:Show();
    elseif not onTab and previewing then
        watcher:Hide();
        StopPreview();
    end
end

-- Move ends with the tab (the preview itself follows on Show / Hide).
addon.CallbackRegistry:Register("SettingsUI.TabChanged", function()
    local settingsUI = addon.SettingsUI;
    if not (settingsUI and settingsUI.IsOnLootUITab and settingsUI:IsOnLootUITab()) then
        MainFrame:SetMoveMode(false);
    end
end);

addon.CallbackRegistry:Register("SettingsUI.Show", UpdatePreview);
addon.CallbackRegistry:Register("SettingsUI.Hide", UpdatePreview);
addon.CallbackRegistry:Register("SettingsUI.TabChanged", UpdatePreview);
addon.CallbackRegistry:Register("SettingChanged.LootUI", UpdatePreview);      -- the checkbox turns the preview on / off

-- Settings that change which rows there are: the rows are made again (Combine Similar Items folds the three junk
-- items of the sample into one row, or lists them one by one).
local function RefillPreview()
    if previewing then
        Populate();
    end
end
addon.CallbackRegistry:Register("SettingChanged.LootUI_ItemsPerPage", RefillPreview);
addon.CallbackRegistry:Register("SettingChanged.LootUI_CombineItem", RefillPreview);
addon.CallbackRegistry:Register("SettingChanged.LootUI_HideTitle", RefillPreview);
