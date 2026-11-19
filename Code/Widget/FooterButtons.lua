local _, addon = ...;

-- The two buttons under the quest text, their text and action for each page, and the Space / Esc keys.
-- Port of retail's AcquireAcceptButton / AcquireExitButton and the Handle* functions (DialogueUI.lua).
local Round = addon.API.Round;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local SetOverrideBindingClick = SetOverrideBindingClick;
local ClearOverrideBindings = ClearOverrideBindings;
local GetMoney = GetMoney;
local GetNumQuestChoices = GetNumQuestChoices;
local AcceptQuest = AcceptQuest;
local DeclineQuest = DeclineQuest;
local CompleteQuest = CompleteQuest;
local GetQuestReward = GetQuestReward;
local max = math.max;

local BUTTON_GAP = 8;               -- retail BUTTON_HORIZONTAL_GAP
local ACCEPT_NAME = "DialogueUI335AcceptButton";
local EXIT_NAME = "DialogueUI335ExitButton";
local SETTINGS_TOGGLE_NAME = "DialogueUI335SettingsToggle";     -- created in Settings.lua
local ESCAPE_NAME = "DialogueUI335EscapeKey";                  -- hidden button the Esc key clicks (Press Escape To Decline Quest)
local SCROLL_NAME ="DialogueUI335ScrollOrAccept";             -- hidden button the Confirm key clicks (Press Button To Scroll Down)
local CYCLE_NAME ="DialogueUI335CycleReward";                  -- hidden buttons the Tab keys click (created below)
local CYCLE_BACK_NAME = "DialogueUI335CycleRewardBack";

local L = addon.L;
local BindingUtil = addon.BindingUtil;

-- Continue is locked while the quest takes gold: 1 s, or 4 s above 500g or 5% of the player's money.
local function CalculateLockDuration(copper)
    local money = max(GetMoney() or 0, 1);
    if copper > 5000000 or copper / money > 0.05 then
        return 4
    end
    return 1
end

local Footer = {};
Footer.__index = Footer;

---------------------------------------------------------------------------
-- Click actions
---------------------------------------------------------------------------

local function OnClick_Accept()
    AcceptQuest();
end

-- Retail SetButtonDeclineQuest / SetButtonCancelQuestProgress: a quest that was chosen from a list (gossip or
-- greeting) goes back to the previous page with DeclineQuest, any other one closes the conversation.
local function OnClick_Decline(button)
    local owner = button.owner;
    if owner:IsQuestFromGossip() then
        DeclineQuest();
    else
        owner:RequestClose();
    end
end

local function OnClick_Continue()
    CompleteQuest();
end

local function OnClick_Close(button)
    button.owner:RequestClose();
end

local function OnClick_Complete(button)
    local numChoices = GetNumQuestChoices() or 0;
    local choice;
    if numChoices == 0 then
        choice = 0;
    elseif numChoices == 1 then
        choice = 1;
    else
        choice = button.owner:GetRewardChoice();
    end
    if choice == nil then
        button.owner:FlashRewardChoices();
        return
    end
    GetQuestReward(choice);
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------

-- Left button, by page. Returns nil when the button is not shown (gossip, greeting).
function Footer:GetAcceptConfig()
    local event, page = self.event, self.page or {};
    local confirmKey = BindingUtil:GetActiveConfirmKey();       -- nil: no key, so no key badge on the button

    if event == "QUEST_DETAIL" then
        return {type = "accept", text = L["Accept"], art = 1, key = confirmKey, onClick = OnClick_Accept}
    elseif event == "QUEST_PROGRESS" then
        local text = L["Continue"];
        if not page.completable then
            return {type = "continue", text = L["Incomplete"], art = 3, enabled = false}
        end
        local lock;
        if page.moneyToGet and self.unlockedPage ~= page then
            lock = CalculateLockDuration(page.moneyToGet);
        end
        return {type = "continue", text = text, art = 1, key = confirmKey, onClick = OnClick_Continue, lock = lock}
    elseif event == "QUEST_COMPLETE" then
        local text = L["Complete Quest"];
        if self.owner:GetRewardChoice() == nil then
            return {type = "complete", text = text, art = 3, enabled = false, onClick = OnClick_Complete}
        end
        return {type = "complete", text = text, art = 1, key = confirmKey, onClick = OnClick_Complete}
    end
end

-- Right button, by page.
function Footer:GetExitConfig()
    local event = self.event;
    if event == "QUEST_DETAIL" then
        return {type = "decline", text = L["Decline"], art = 4, key = "Esc", onClick = OnClick_Decline}
    elseif event == "QUEST_PROGRESS" then
        return {type = "cancel", text = L["Cancel"], art = 4, key = "Esc", onClick = OnClick_Decline}
    elseif event == "QUEST_COMPLETE" then
        return {type = "cancel", text = L["Cancel"], art = 4, key = "Esc", onClick = OnClick_Close}
    end
    return {type = "goodbye", text = L["Goodbye"], art = 4, key = "Esc", onClick = OnClick_Close}
end

function Footer:ApplyAccept()
    local button = self.accept;
    local cfg = self:GetAcceptConfig();
    if not cfg then
        button:Hide();
        return
    end
    button:Show();

    if cfg.lock then
        -- Locked: hollow and without a key until the bar is full, then the real button.
        local lock = cfg.lock;
        cfg.lock = nil;
        local page = self.page;
        local locked = {type = cfg.type, text = cfg.text, art = 3, enabled = false};
        button:Configure(locked);
        button:StartLock(lock, function()
            if self.page == page then
                self.unlockedPage = page;
                self:ApplyAccept();
                self:UpdateKeys();
            end
        end);
    else
        button:Configure(cfg);
    end
end

function Footer:ApplyExit()
    self.exit:Show();
    self.exit:Configure(self:GetExitConfig());
end

-- event: the quest or gossip event that opened the page. page: QuestData:GetPage(event).
function Footer:SetPage(event, page)
    self.event, self.page = event, page;
    self.rowNames = nil;        -- only the first-contact page sets them, after SetPage (SetRowKeys)
    self:ApplyAccept();
    self:ApplyExit();
    self:UpdateKeys();
end

-- A reward was chosen: the Complete button becomes usable.
function Footer:OnRewardChoiceChanged()
    if self.event == "QUEST_COMPLETE" then
        self:ApplyAccept();
        self:UpdateKeys();
    end
end

---------------------------------------------------------------------------
-- Keys
---------------------------------------------------------------------------

-- Space clicks the left button and Esc the right one. 3.3.5a has no way to let unused keys through a
-- keyboard frame, so these are override bindings: they replace Space (jump) and Esc (game menu) only
-- while an enabled button needs them. Override bindings cannot be changed in combat.
function Footer:ClearKeys()
    if InCombatLockdown() then
        self.keysDirty = true;
        return
    end
    ClearOverrideBindings(self.keyOwner);
end

function Footer:UpdateKeys()
    if InCombatLockdown() then
        self.keysDirty = true;
        return
    end
    self.keysDirty = false;
    ClearOverrideBindings(self.keyOwner);
    if not self.parent:IsShown() then
        return
    end

    -- While a key is being assigned in the settings window, every key belongs to that window.
    if addon.KeybindCapture and addon.KeybindCapture:IsActive() then
        return
    end

    local accept, exit = self.accept, self.exit;
    local confirmKey = BindingUtil:GetActiveConfirmKey();       -- Space unless the player chose another one
    local confirmUsed = false;
    if confirmKey and accept:IsShown() and accept.isEnabled and accept.hasHotkey then
        -- Press Button To Scroll Down: on a quest offer the key goes through a button that scrolls first (a mouse
        -- click on Accept always accepts).
        local target = ACCEPT_NAME;
        if self.event == "QUEST_DETAIL" and addon.GetDBBool("ScrollDownThenAcceptQuest") then
            target = SCROLL_NAME;
        end
        SetOverrideBindingClick(self.keyOwner, true, confirmKey, target, "LeftButton");
        confirmUsed = true;
    end
    -- Esc belongs to the settings window while it is open (it binds Esc itself).
    local settings = addon.SettingsUI;
    local settingsOpen = settings and settings:IsShown();
    if exit:IsShown() and exit.isEnabled and exit.hasHotkey and not settingsOpen then
        SetOverrideBindingClick(self.keyOwner, true, "ESCAPE", ESCAPE_NAME, "LeftButton");
    end

    -- Tab / Shift-Tab choose the next / previous reward while a reward must be chosen (Settings > Control).
    if addon.GetDBBool("CycleRewardHotkeyEnabled") and self.event == "QUEST_COMPLETE" and self.page and self.page.canChoose then
        SetOverrideBindingClick(self.keyOwner, true, "TAB", CYCLE_NAME, "LeftButton");
        SetOverrideBindingClick(self.keyOwner, true, "SHIFT-TAB", CYCLE_BACK_NAME, "LeftButton");
    end

    -- F1 (or the player's key) opens the settings while the dialogue is shown (F1 is "target self" in the game otherwise).
    local settingsKey = BindingUtil:GetActiveActionKey("Settings");
    if settingsKey then
        SetOverrideBindingClick(self.keyOwner, true, settingsKey, SETTINGS_TOGGLE_NAME, "LeftButton");
    end

    -- First-contact page: the keys of Option 1-9 click the rows in order. The Confirm key takes the first row
    -- (retail "Confirm"), or says goodbye when the page has no rows.
    local rowNames = self.rowNames;
    if rowNames and not confirmUsed then
        for i = 1, 9 do
            local key = rowNames[i] and BindingUtil:GetActiveActionKey("Option" .. i);
            if key then
                SetOverrideBindingClick(self.keyOwner, true, key, rowNames[i], "LeftButton");
            end
        end
        if confirmKey then
            if rowNames[1] then
                SetOverrideBindingClick(self.keyOwner, true, confirmKey, rowNames[1], "LeftButton");
            elseif exit:IsShown() then
                SetOverrideBindingClick(self.keyOwner, true, confirmKey, EXIT_NAME, "LeftButton");
            end
        end
    end
end

-- Rows of the first-contact page that have a key (global button names, in key order). nil clears them.
function Footer:SetRowKeys(names)
    self.rowNames = names;
    self:UpdateKeys();
end

-- Distance from the parchment bottom to the footer divider (retail: button height + padding bottom + 2 gaps).
function Footer:GetFooterOffset()
    return self.footerOffset
end

-- The sizes that follow the frame size. width: parchment width. paddingH / paddingBottom: already scaled by
-- the frame size multiplier. Buttons that already show a label are laid out again for the new width.
function Footer:SetSize(width, paddingH, paddingBottom)
    local buttonWidth = Round(0.5 * (width - 2 * paddingH - BUTTON_GAP));
    local parent = self.parent;

    local accept, exit = self.accept, self.exit;
    accept:ClearAllPoints();
    accept:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", paddingH, paddingBottom);
    accept:SetButtonWidth(buttonWidth);
    exit:ClearAllPoints();
    exit:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -paddingH, paddingBottom);
    exit:SetButtonWidth(buttonWidth);

    if accept.text then
        accept:Layout();
    end
    if exit.text then
        exit:Layout();
    end

    -- Measured with the exit button's label (it is shown on every page).
    if not exit.text then
        self:ApplyExit();
    end
    self.footerOffset = Round(exit:GetHeight() + paddingBottom + BUTTON_GAP * 2);
end

-- parent: parchment frame. owner: ParchmentBackground (RequestClose, GetRewardChoice, FlashRewardChoices).
-- width, paddingH, paddingBottom: see SetSize.
local function CreateFooterButtons(parent, owner, width, paddingH, paddingBottom)
    local self = setmetatable({}, Footer);
    self.parent = parent;
    self.owner = owner;
    self.keyOwner = CreateFrame("Frame", nil, parent);

    self.accept = addon.CreateOptionButton(parent, ACCEPT_NAME, owner);
    self.exit = addon.CreateOptionButton(parent, EXIT_NAME, owner);

    -- Measured once with the default label, as retail does with the Goodbye button.
    self:SetSize(width, paddingH, paddingBottom);
    self.accept:Hide();

    -- Esc changes hands when the settings window opens or closes.
    addon.CallbackRegistry:Register("SettingsUI.Show", function()
        self:UpdateKeys();
    end);
    addon.CallbackRegistry:Register("SettingsUI.Hide", function()
        self:UpdateKeys();
    end);

    -- Press Escape To Decline Quest (retail HideUI with fromPressingKey): Esc on a quest that was chosen from a list
    -- goes back to the previous page when the option is on, otherwise it closes the conversation. A click on the
    -- Decline / Cancel button is not affected (it always goes back for such a quest).
    local escapeButton = CreateFrame("Button", ESCAPE_NAME, UIParent);
    escapeButton:SetWidth(1);
    escapeButton:SetHeight(1);
    escapeButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0);
    escapeButton:SetScript("OnClick", function()
        local event = self.event;
        if (event == "QUEST_DETAIL" or event == "QUEST_PROGRESS") and owner:IsQuestFromGossip()
            and addon.GetDBBool("EscapeToDeclineQuest") then
            DeclineQuest();
        else
            owner:RequestClose();
        end
    end);

    -- Press Button To Scroll Down: scrolls while the quest text is not fully in view, then clicks Accept.
    local scrollButton = CreateFrame("Button", SCROLL_NAME, UIParent);
    scrollButton:SetWidth(1);
    scrollButton:SetHeight(1);
    scrollButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0);
    scrollButton:SetScript("OnClick", function()
        if not owner:ScrollDownIfNeeded() then
            self.accept:Click();
        end
    end);
    addon.CallbackRegistry:Register("SettingChanged.ScrollDownThenAcceptQuest", function()
        self:UpdateKeys();
    end);

    -- Press Tab To Select Reward: the keys are override bindings that click these 1 px buttons.
    local function CreateCycleButton(name, delta)
        local button = CreateFrame("Button", name, UIParent);
        button:SetWidth(1);
        button:SetHeight(1);
        button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0);
        button:SetScript("OnClick", function()
            owner:CycleRewardChoice(delta);
        end);
    end
    CreateCycleButton(CYCLE_NAME, 1);
    CreateCycleButton(CYCLE_BACK_NAME, -1);
    addon.CallbackRegistry:Register("SettingChanged.CycleRewardHotkeyEnabled", function()
        self:UpdateKeys();
    end);

    -- The player's keys changed (settings > Control): new key badge on the button, new override bindings.
    addon.CallbackRegistry:Register("CustomBindingChanged", function()
        if self.event and self.parent:IsShown() then
            self:ApplyAccept();
        end
        self:UpdateKeys();
    end);
    -- A key is being assigned in the settings window (or it stopped): all the keys are released or taken back.
    addon.CallbackRegistry:Register("KeyCaptureChanged", function()
        self:UpdateKeys();
    end);

    -- Key bindings cannot change in combat: apply them when it ends.
    self.events = CreateFrame("Frame");
    self.events:RegisterEvent("PLAYER_REGEN_ENABLED");
    self.events:SetScript("OnEvent", function()
        if self.keysDirty then
            self:UpdateKeys();
        end
    end);

    return self
end

addon.CreateFooterButtons = CreateFooterButtons;
