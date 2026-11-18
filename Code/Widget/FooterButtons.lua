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

local L = addon.L;

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

local function OnClick_Decline()
    DeclineQuest();
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

    if event == "QUEST_DETAIL" then
        return {type = "accept", text = L["Accept"], art = 1, key = "SPACE", onClick = OnClick_Accept}
    elseif event == "QUEST_PROGRESS" then
        local text = L["Continue"];
        if not page.completable then
            return {type = "continue", text = L["Incomplete"], art = 3, enabled = false}
        end
        local lock;
        if page.moneyToGet and self.unlockedPage ~= page then
            lock = CalculateLockDuration(page.moneyToGet);
        end
        return {type = "continue", text = text, art = 1, key = "SPACE", onClick = OnClick_Continue, lock = lock}
    elseif event == "QUEST_COMPLETE" then
        local text = L["Complete Quest"];
        if self.owner:GetRewardChoice() == nil then
            return {type = "complete", text = text, art = 3, enabled = false, onClick = OnClick_Complete}
        end
        return {type = "complete", text = text, art = 1, key = "SPACE", onClick = OnClick_Complete}
    end
end

-- Right button, by page.
function Footer:GetExitConfig()
    local event = self.event;
    if event == "QUEST_DETAIL" then
        return {type = "decline", text = L["Decline"], art = 4, key = "Esc", onClick = OnClick_Decline}
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
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

    local accept, exit = self.accept, self.exit;
    local spaceUsed = false;
    if accept:IsShown() and accept.isEnabled and accept.hasHotkey then
        SetOverrideBindingClick(self.keyOwner, true, "SPACE", ACCEPT_NAME, "LeftButton");
        spaceUsed = true;
    end
    -- Esc belongs to the settings window while it is open (it binds Esc itself).
    local settings = addon.SettingsUI;
    local settingsOpen = settings and settings:IsShown();
    if exit:IsShown() and exit.isEnabled and exit.hasHotkey and not settingsOpen then
        SetOverrideBindingClick(self.keyOwner, true, "ESCAPE", EXIT_NAME, "LeftButton");
    end

    -- F1 opens the settings while the dialogue is shown (it is "target self" in the game otherwise).
    SetOverrideBindingClick(self.keyOwner, true, "F1", SETTINGS_TOGGLE_NAME, "LeftButton");

    -- First-contact page: keys 1-9 click the rows in order. Space takes the first row (retail "Confirm"),
    -- or says goodbye when the page has no rows.
    local rowNames = self.rowNames;
    if rowNames and not spaceUsed then
        for i = 1, #rowNames do
            SetOverrideBindingClick(self.keyOwner, true, tostring(i), rowNames[i], "LeftButton");
        end
        if rowNames[1] then
            SetOverrideBindingClick(self.keyOwner, true, "SPACE", rowNames[1], "LeftButton");
        elseif exit:IsShown() then
            SetOverrideBindingClick(self.keyOwner, true, "SPACE", EXIT_NAME, "LeftButton");
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

-- parent: parchment frame. owner: ParchmentBackground (RequestClose, GetRewardChoice, FlashRewardChoices).
-- width: parchment width. paddingH / paddingBottom: already scaled by the frame size multiplier.
local function CreateFooterButtons(parent, owner, width, paddingH, paddingBottom)
    local self = setmetatable({}, Footer);
    self.parent = parent;
    self.owner = owner;
    self.keyOwner = CreateFrame("Frame", nil, parent);

    local buttonWidth = Round(0.5 * (width - 2 * paddingH - BUTTON_GAP));

    self.accept = addon.CreateOptionButton(parent, ACCEPT_NAME, owner);
    self.accept:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", paddingH, paddingBottom);
    self.accept:SetButtonWidth(buttonWidth);

    self.exit = addon.CreateOptionButton(parent, EXIT_NAME, owner);
    self.exit:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -paddingH, paddingBottom);
    self.exit:SetButtonWidth(buttonWidth);

    -- Measured once with the default label, as retail does with the Goodbye button.
    self:ApplyExit();
    self.footerOffset = Round(self.exit:GetHeight() + paddingBottom + BUTTON_GAP * 2);
    self.accept:Hide();

    -- Esc changes hands when the settings window opens or closes.
    addon.CallbackRegistry:Register("SettingsUI.Show", function()
        self:UpdateKeys();
    end);
    addon.CallbackRegistry:Register("SettingsUI.Hide", function()
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
