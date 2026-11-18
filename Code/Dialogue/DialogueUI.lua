local _, addon = ...;

-- The dialogue frame: shows the page for the current conversation step and hides it when the conversation ends.
-- Core.lua listens to the game events and calls ShowUI / HideUI / OnItemUpdate.

local API = addon.API;
local QuestData = addon.QuestData;
local GossipDataProvider = addon.GossipDataProvider;
local After = API.After;

local CloseGossip = CloseGossip;
local CloseQuest = CloseQuest;

local MainFrame = addon.CreateParchmentBackground(UIParent);
addon.DialogueUI = MainFrame;   -- read by QuestItemDisplay (defers readable items while talking) and DevTool

-- First-contact pages: greeting text plus a list of quests and options (no quest header).
local LIST_EVENTS = {
    GOSSIP_SHOW = true,
    QUEST_GREETING = true,
};

local RETRY_DELAY = 0.5;

-- Last page shown, so QUEST_ITEM_UPDATE can redraw it when item data arrives late.
local lastEvent, lastPage;
local retryToken = 0;

-- Goodbye, Cancel, Esc and right click end up here: close the game side, then the frame hides itself.
-- Nothing is open in the DevTool test page (lastEvent is nil), so only the frame closes.
MainFrame:SetCloseHandler(function()
    if lastEvent == "GOSSIP_SHOW" then
        CloseGossip();
    elseif lastEvent then
        CloseQuest();
    end
    lastEvent, lastPage = nil, nil;
end);

-- event: GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS or QUEST_COMPLETE.
-- Quest text is only valid during its own event, so it is read here.
function MainFrame:ShowUI(event)
    if LIST_EVENTS[event] then
        local page = GossipDataProvider:Read(event);
        self:Show();
        self:SetListPage(event, page);
        lastEvent, lastPage = event, page;
    else
        local page = QuestData:GetPage(event);
        self:Show();
        self:UpdatePortrait();
        self:SetTitle(page.title);
        self:SetTags(page.tags);
        self:SetCompleteIcon(event == "QUEST_COMPLETE");
        self:SetQuestText(page.body, page.objective, page);
        self:SetPage(event, page);
        lastEvent, lastPage = event, page;
    end
end

function MainFrame:HideUI()
    self:Hide();
    lastEvent, lastPage = nil, nil;
end

-- The frame size or the font size changed (ParchmentBackground has already resized itself): lay out the open page
-- again for the new text width and heights. The page is the one already read, quest text is only valid during its
-- own event.
local function RedrawPage()
    if not lastEvent then
        return
    end
    local page = lastPage;
    if LIST_EVENTS[lastEvent] then
        MainFrame:SetListPage(lastEvent, page);
    else
        MainFrame:SetQuestText(page.body, page.objective, page);
        if lastEvent == "QUEST_COMPLETE" then
            MainFrame:SetPage(lastEvent, page);     -- the redraw clears the reward choice
        end
    end
    MainFrame.QuestText:StopReveal();               -- no fade-in again
end
addon.CallbackRegistry:Register("FrameSizeChanged", RedrawPage);
addon.CallbackRegistry:Register("FontSizeChanged", RedrawPage);

-- Item data arrived: redraw once (retail re-runs the handler 0.5 s later). A new update restarts the wait.
function MainFrame:OnItemUpdate()
    if not (lastPage and lastPage.incomplete) then
        return
    end

    retryToken = retryToken + 1;
    local token = retryToken;
    After(RETRY_DELAY, function()
        if token ~= retryToken or not lastEvent then
            return
        end
        local page = QuestData:GetPage(lastEvent);
        self:SetQuestText(page.body, page.objective, page);
        if lastEvent == "QUEST_COMPLETE" then
            self:SetPage(lastEvent, page);     -- the redraw clears the reward choice
        end
        lastPage = page;
    end);
end
