local _, addon = ...;

-- Settings > Hide UI: fades the game UI out when the dialogue opens and back in when it closes.
-- Port of FadeHelper in retail's Camera.lua. Retail ends the fade with SetGameUIShown(false/true); 3.3.5a has no such
-- call, so UIParent is hidden and shown (what Alt+Z does). Our own frames hang on addon.UIRoot, so they stay.
-- Sub-options (chat window, EXP bar, sparkles, unit names, Enhanced Mode) and camera movement are not ported.

local CallbackRegistry = addon.CallbackRegistry;
local InCombatLockdown = InCombatLockdown;
local UIParent = UIParent;

local FADE_OUT_SPEED = 2;       -- alpha per second (retail: 0.5 s)
local FADE_IN_SPEED = 4;        -- (retail: 0.25 s)
local UPDATE_INTERVAL = 1/30;

local HIDE_UI = false;
local HIDE_UI_BOOK = false;         -- the Readables setting

-- Under UIRoot: a frame created without a parent goes under UIParent and would stop running OnUpdate once it is hidden.
local FadeHelper = CreateFrame("Frame", nil, addon.UIRoot);
addon.UIParentFadeHelper = FadeHelper;

-- The UI is never hidden in combat (retail does the same). Showing it is not gated: PLAYER_REGEN_DISABLED may already
-- count as combat, and a UI that stays hidden in a fight is worse than a blocked call.
local function ShowUIParent(state)
    if state then
        UIParent:Show();
    elseif not InCombatLockdown() then
        UIParent:Hide();
    end
end

function FadeHelper:RegisterInterruptEvents(state)
    -- Combat, movies and cinematics need the UI back at once.
    if state then
        self:RegisterEvent("PLAYER_REGEN_DISABLED");
        self:RegisterEvent("PLAY_MOVIE");
        self:RegisterEvent("CINEMATIC_START");
    else
        self:UnregisterEvent("PLAYER_REGEN_DISABLED");
        self:UnregisterEvent("PLAY_MOVIE");
        self:UnregisterEvent("CINEMATIC_START");
    end
end

function FadeHelper:HideUIParentInstantly()
    self:SetScript("OnUpdate", nil);
    self.t = 0;
    self.alpha = 0;

    if not InCombatLockdown() then
        self.fadeDelta = -1;
        UIParent:SetAlpha(1);       -- the alpha of the next Alt+Z or fade-in starts clean
        UIParent:Hide();
    end
end

function FadeHelper:ShowUIParentInstantly()
    self.fadeDelta = 1;         -- so the snap shows UIParent
    self:SnapToFadeResult();
end

function FadeHelper:OnEvent()
    self:ShowUIParentInstantly();
end
FadeHelper:SetScript("OnEvent", FadeHelper.OnEvent);

function FadeHelper:SnapToFadeResult(inCombat)
    self:SetScript("OnUpdate", nil);
    self.t = 0;
    self.alpha = 1;
    self:RegisterInterruptEvents(false);

    if self.fadeDelta then
        UIParent:SetAlpha(1);
        if self.fadeDelta > 0 then
            ShowUIParent(true);
        elseif not inCombat then
            ShowUIParent(false);
        end
        self.fadeDelta = nil;
    end
end

function FadeHelper:FadeIn_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= UPDATE_INTERVAL then
        self.alpha = self.alpha + FADE_IN_SPEED * self.t;
        self.t = self.t - UPDATE_INTERVAL;
        if self.alpha >= 1 then
            self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

function FadeHelper:FadeOut_OnUpdate(elapsed)
    self.t = self.t + elapsed;
    if self.t >= UPDATE_INTERVAL then
        self.alpha = self.alpha - FADE_OUT_SPEED * self.t;
        self.t = self.t - UPDATE_INTERVAL;
        if self.alpha <= 0 then
            self:SnapToFadeResult();
        else
            UIParent:SetAlpha(self.alpha);
        end
    end
end

-- forced: the caller has already checked its own setting (Readables).
function FadeHelper:FadeOutUI(forced)
    if not (HIDE_UI or forced) then return end;

    if self.fadeDelta == -1 or (not UIParent:IsShown()) then
        return
    end
    self.fadeDelta = -1;

    local inCombat = InCombatLockdown();

    if inCombat then
        -- Nothing can be hidden in combat: leave the UI as it is.
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        self.t = 0;
        self:RegisterInterruptEvents(true);
        self:SetScript("OnUpdate", self.FadeOut_OnUpdate);
    end
end

function FadeHelper:FadeInUI()
    if self.fadeDelta == 1 then
        return
    end
    self.fadeDelta = 1;

    local inCombat = InCombatLockdown();

    if inCombat or UIParent:IsVisible() then
        self:SnapToFadeResult(inCombat);
    else
        self.alpha = UIParent:GetAlpha();
        if self.alpha >= 0.999 then
            self.alpha = 0;
        end
        self.t = 0;
        UIParent:SetAlpha(self.alpha);
        ShowUIParent(true);
        self:RegisterInterruptEvents(true);
        self:SetScript("OnUpdate", self.FadeIn_OnUpdate);
    end
end


-- The dialogue appears: fade out. It goes away: fade in. The Move Position sample is only a layout aid, so the
-- game UI stays. Pages that replace each other keep the frame shown and so do not fade.
local function Dialogue_OnShow()
    if addon.DialogueUI:IsEditMode() then
        return
    end
    FadeHelper:FadeOutUI();
end

local function Dialogue_OnHide()
    if HIDE_UI_BOOK and addon.Book:IsShown() and not addon.Book:IsEditMode() then
        return      -- a readable is still open and keeps the UI hidden
    end
    FadeHelper:FadeInUI();
end

CallbackRegistry:Register("ParchmentShown", Dialogue_OnShow);
CallbackRegistry:Register("ParchmentHidden", Dialogue_OnHide);

-- Hide UI turned off or on from the Settings window while the dialogue is open: apply it at once.
CallbackRegistry:Register("SettingChanged.HideUI", function(dbValue, userInput)
    HIDE_UI = dbValue == true;
    if not userInput then
        return
    end
    if addon.DialogueUI.frame:IsShown() and not addon.DialogueUI:IsEditMode() then
        if HIDE_UI then
            FadeHelper:HideUIParentInstantly();
        else
            FadeHelper:ShowUIParentInstantly();
        end
    end
end);


-- Readables: the same fade, with its own setting (BookHideUI). The Move Position sample keeps the game UI.
local function Book_OnShow()
    if HIDE_UI_BOOK and not addon.Book:IsEditMode() then
        FadeHelper:FadeOutUI(true);
    end
end

local function Book_OnHide()
    if HIDE_UI_BOOK and not addon.DialogueUI.frame:IsShown() then
        FadeHelper:FadeInUI();      -- a dialogue that is still open keeps the UI hidden
    end
end

CallbackRegistry:Register("BookShown", Book_OnShow);
CallbackRegistry:Register("BookHidden", Book_OnHide);

CallbackRegistry:Register("SettingChanged.BookHideUI", function(dbValue, userInput)
    HIDE_UI_BOOK = dbValue == true;
    if not userInput then
        return
    end
    if addon.Book:IsShown() and not addon.Book:IsEditMode() and not addon.DialogueUI.frame:IsShown() then
        if HIDE_UI_BOOK then
            FadeHelper:HideUIParentInstantly();
        else
            FadeHelper:ShowUIParentInstantly();
        end
    end
end);
