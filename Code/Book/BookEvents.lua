local addonName, addon = ...;

-- Connects the book frame to the game: ITEM_TEXT_* events, page caching, closing rules, Blizzard's own
-- ItemTextFrame. Port of the EventListener section of retail's BookUI.lua.
--
-- Flow: BEGIN (a readable was opened) -> READY (a page is available) -> the page is cached and, if there is a
-- next page, ItemTextNextPage() fires READY again. When the last page is cached the whole book is laid out
-- and shown at once. CLOSED ends it.

local Book = addon.Book;
local BookItem = addon.BookItem;

local CreateFrame = CreateFrame;
local CloseItemText = CloseItemText;
local ItemTextGetItem = ItemTextGetItem;
local ItemTextGetMaterial = ItemTextGetMaterial;
local ItemTextGetPage = ItemTextGetPage;
local ItemTextGetText = ItemTextGetText;
local ItemTextHasNextPage = ItemTextHasNextPage;
local ItemTextNextPage = ItemTextNextPage;

local READABLE_EVENTS = {
    "ITEM_TEXT_BEGIN",
    "ITEM_TEXT_READY",
    "ITEM_TEXT_CLOSED",
    "ITEM_TEXT_TRANSLATION",
};

-- Talking to an NPC or a cutscene closes the book.
local HIDE_EVENTS = {
    "GOSSIP_SHOW",
    "QUEST_GREETING",
    "QUEST_DETAIL",
    "QUEST_PROGRESS",
    "QUEST_COMPLETE",
    "CINEMATIC_START",
    "PLAY_MOVIE",
};

-- FrameXML functions behind the bag keys. Not in wow-docs: each is hooked only when it exists.
local BAG_FUNCTIONS = { "OpenAllBags", "ToggleBackpack", "ToggleAllBags", "ToggleBag" };

local CLOSE_CHECK_DELAY = 0.03;

local events = CreateFrame("Frame");
local turnFrame = CreateFrame("Frame");     -- turns the page on the next frame
local closeFrame = CreateFrame("Frame");    -- decides after CLOSED whether the book stays

local enabled = false;
local begun = false;        -- between BEGIN and CLOSED
local caching = false;      -- pages are still being read
local showText = false;     -- READY arrived after the last CLOSED

local function GetDB()
    DialogueUI_335_DB = DialogueUI_335_DB or {};
    return DialogueUI_335_DB
end

local function StopPageTurn()
    turnFrame:SetScript("OnUpdate", nil);
end

-- ItemTextNextPage is not called inside the READY handler, but on the next frame.
local function RequestNextPage()
    turnFrame:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil);
        if caching then
            ItemTextNextPage();
        end
    end);
end

local function OnBegin()
    local title = ItemTextGetItem();
    local info = BookItem:Resolve(title);
    Book:BeginReading(ItemTextGetMaterial(), title, info);
    begun = true;
    caching = true;
    StopPageTurn();
end

local function OnReady()
    showText = true;
    if not caching then
        return
    end

    local page = ItemTextGetPage();
    Book:AddPage(page, ItemTextGetText());

    if ItemTextHasNextPage() then
        RequestNextPage();
    else
        caching = false;
        Book:FinishReading(page);
    end
end

-- CLOSED also fires in the middle of re-opening a book (Close, Begin, Ready). The book is hidden a moment
-- later, and only if no READY arrived in between.
local function ScheduleCloseCheck()
    local elapsed = 0;
    closeFrame:SetScript("OnUpdate", function(frame, dt)
        elapsed = elapsed + dt;
        if elapsed < CLOSE_CHECK_DELAY then
            return
        end
        frame:SetScript("OnUpdate", nil);
        if (not showText) and Book:IsShown() and GetDB().BookKeepUIOpen ~= true then
            Book:Hide();
        end
    end);
end

local function OnClosed()
    if begun then
        begun = false;
        Book:SavePosition();
        CloseItemText();
    end
    caching = false;
    showText = false;
    StopPageTurn();
    ScheduleCloseCheck();
end

events:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        return
    end
    if event == "ITEM_TEXT_BEGIN" then
        OnBegin();
    elseif event == "ITEM_TEXT_READY" then
        OnReady();
    elseif event == "ITEM_TEXT_CLOSED" then
        OnClosed();
    elseif event == "ITEM_TEXT_TRANSLATION" then
        -- The page arrives with a READY after the translation delay. Blizzard's progress bar is not shown.
        return
    elseif Book:IsShown() then
        Book:Hide();    -- HIDE_EVENTS
    end
end);

-- Called whenever the book frame hides (Esc, close button, right click, ...).
Book.onHide = function()
    begun = false;
    caching = false;
    StopPageTurn();
    CloseItemText();
end

-- Blizzard's ItemTextFrame opens itself from its own OnEvent, so without events it never appears.
local function SetBlizzardFrameEvents(state)
    local blizzard = ItemTextFrame;
    if not blizzard then
        return
    end
    if state then
        for _, event in ipairs(READABLE_EVENTS) do
            blizzard:RegisterEvent(event);
        end
    else
        blizzard:UnregisterAllEvents();
    end
end

function Book:SetEnabled(state)
    state = state and true or false;
    GetDB().BookUIEnabled = state;
    if state == enabled then
        return
    end
    enabled = state;
    if state then
        for _, event in ipairs(READABLE_EVENTS) do
            events:RegisterEvent(event);
        end
        for _, event in ipairs(HIDE_EVENTS) do
            events:RegisterEvent(event);
        end
        SetBlizzardFrameEvents(false);
    else
        events:UnregisterAllEvents();
        SetBlizzardFrameEvents(true);
        Book:Hide();
    end
end

-- Bag keys (B, Shift+B ...) close the book, as in retail.
local function HideOnBagKey()
    if Book:IsShown() then
        Book:Hide();
    end
end

for _, name in ipairs(BAG_FUNCTIONS) do
    if type(_G[name]) == "function" then
        hooksecurefunc(name, HideOnBagKey);
    end
end

-- Saved variables are available after ADDON_LOADED.
local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function(frame, _, name)
    if name == addonName then
        frame:UnregisterEvent("ADDON_LOADED");
        Book:SetEnabled(GetDB().BookUIEnabled ~= false);
    end
end);
