local _, addon = ...;

-- The dialogue frame: shows the page for the current conversation step and hides it when the conversation ends.
-- Core.lua listens to the game events and calls ShowUI / HideUI / OnItemUpdate.

local API = addon.API;
local L = addon.L;
local QuestData = addon.QuestData;
local GossipDataProvider = addon.GossipDataProvider;
local After = API.After;

local CloseGossip = CloseGossip;
local CloseQuest = CloseQuest;

local MainFrame = addon.CreateParchmentBackground(addon.UIRoot);     -- on UIRoot so Hide UI can hide UIParent
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
    addon.Clipboard:CloseIfShown();     -- it shows the previous page
    self.isEditMode = nil;      -- a real conversation replaces the Move sample
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

-- Settings > Orientation > Custom > Move: a small sample page, so the frame can be dragged without a conversation.
-- The page has no Accept button; its only button (Goodbye, or Esc) closes it. It also closes when the Settings
-- window closes, leaves the UI tab, or the orientation is no longer Custom.
local EDIT_EVENT = "EDIT_MODE";

function MainFrame:IsEditMode()
    return self.isEditMode and self:IsShown()
end

function MainFrame:ToggleEditMode()
    if self:IsEditMode() then
        self:Hide();
        return
    end
    if self:IsShown() then
        return      -- a conversation is open: it can be dragged as it is
    end

    self.isEditMode = true;
    lastEvent, lastPage = nil, nil;
    self:Show();
    self:UpdatePortrait();
    self:SetTitle(L["Edit Mode Title"]);
    self:SetTags(nil);
    self:SetCompleteIcon(false);
    self:SetQuestText(L["Edit Mode Body"], nil, nil);
    self:SetPage(EDIT_EVENT, {});
end

local function LeaveEditMode()
    if MainFrame:IsEditMode() then
        MainFrame:Hide();
    end
end
addon.CallbackRegistry:Register("SettingsUI.Hide", LeaveEditMode);
addon.CallbackRegistry:Register("SettingChanged.FrameOrientation", function(value)
    if value ~= 3 then
        LeaveEditMode();
    end
end);
addon.CallbackRegistry:Register("SettingsUI.TabChanged", function(tabID)
    if tabID ~= 1 then
        LeaveEditMode();
    end
end);

-- Whichever way the sample closes (button, Esc, the rules above): Esc and the Settings keys are the Footer's and
-- the Settings window's override bindings on the same keys, so the Settings window takes its keys back.
MainFrame.frame:HookScript("OnHide", function()
    if MainFrame.isEditMode then
        MainFrame.isEditMode = nil;
        addon.SettingsUI:RefreshToggles();      -- the Move row is no longer on
        After(0.05, function()
            addon.SettingsUI:UpdateKeys();
        end);
    end
end);

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
addon.CallbackRegistry:Register("SettingChanged.ShowNPCNameOnPage", RedrawPage);    -- text only, the page is kept

-- Settings > Control: the keys changed, so the key labels of a list page are laid out again (quest pages: the Footer
-- updates its own button).
addon.CallbackRegistry:Register("CustomBindingChanged", function()
    if MainFrame:IsShown() and lastPage and LIST_EVENTS[lastEvent] then
        RedrawPage();
    end
end);

-- Quest details page: rebuild the level / difficulty on the type pill (style setting, or the theme: the
-- difficulty colours are used on Dark only).
local function RefreshHeaderType()
    local tag = MainFrame:IsShown() and lastPage and lastPage.tags and lastPage.tags[1];
    if tag and tag.typeText then
        tag.text = addon.GossipDataProvider:FormatHeaderType(tag.typeText, tag.title);
        MainFrame:SetTags(lastPage.tags);
    end
end

-- Settings > Quest Difficulty: level prefix and right-hand note of the quest rows are rebuilt, then the list is redrawn.
addon.CallbackRegistry:Register("SettingChanged.QuestDifficultyStyle", function()
    if MainFrame:IsShown() and lastPage and LIST_EVENTS[lastEvent] then
        addon.GossipDataProvider:RefreshQuestText(lastPage);
        RedrawPage();
    else
        RefreshHeaderType();
    end
end);

-- Settings > Show Quest Type: re-apply the stored page's tags (gossip pages and the Move sample have none).
addon.CallbackRegistry:Register("SettingChanged.ShowQuestType", function()
    if MainFrame:IsShown() and lastPage and not LIST_EVENTS[lastEvent] then
        MainFrame:SetTags(lastPage.tags);
    end
end);

-- Settings > Show Copy Text Button: a small button in the top right corner opens the page's text in the Clipboard
-- window. Nothing to copy while no conversation is open (the Move sample).
local CopyTextButton;

local function CopyTextButton_OnClick(button)
    if addon.Clipboard:CloseIfFromSameSender(button) then
        return
    end
    local text = addon.ClipboardContent:Build(lastEvent, lastPage);
    if text then
        addon.Clipboard:ShowContent(text, button);
    end
end

addon.CallbackRegistry:Register("SettingChanged.ShowCopyTextButton", function(value)
    if value == true then
        if not CopyTextButton then
            local frame = MainFrame.frame;
            CopyTextButton = addon.CreateCopyTextButton(frame, CopyTextButton_OnClick, addon.ThemeUtil:GetThemeID());
            CopyTextButton:SetFrameLevel(frame:GetFrameLevel() + 20);
        end
        MainFrame:AnchorCornerWidget(CopyTextButton);
        CopyTextButton:Show();
    else
        if CopyTextButton then
            CopyTextButton:Hide();
        end
        addon.Clipboard:CloseIfShown();
    end
end);

-- ParchmentBackground has already re-measured itself (it registered first).
addon.CallbackRegistry:Register("FrameSizeChanged", function()
    if CopyTextButton then
        MainFrame:AnchorCornerWidget(CopyTextButton);
    end
end);

addon.CallbackRegistry:Register("ThemeChanged", function(themeID)
    if CopyTextButton then
        CopyTextButton:SetTheme(themeID);
    end
    RefreshHeaderType();
end);

-- The window shows the text of the page it was opened on: a new page or the end of the conversation closes it.
MainFrame.frame:HookScript("OnHide", function()
    addon.Clipboard:CloseIfShown();
end);

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
