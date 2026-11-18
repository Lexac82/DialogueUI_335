local _, addon = ...;

-- Footer option button (Accept, Continue, Complete, Decline, Cancel, Goodbye).
-- Port of retail's DUIDialogOptionButtonMixin (UITemplates.lua), DUIDialogHotkeyFrameMixin and
-- DUIDialogOptionButtonLockMixin. Mouse and keyboard only: no controller icons.
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;
local Round = addon.MathUtil.Round;

local CreateFrame = CreateFrame;
local min = math.min;

local BUTTON_PADDING = 12;          -- retail BUTTON_PADDING_LARGE
local HOTKEY_PADDING = 8;
local HOTKEY_SIZE = 20;
local HOTKEY_ICON_SIZE = 14;
local HOTKEY_CORNER = 6;            -- 8 texture px at retail's pixel-perfect scale (~0.7)
local TEXT_SPACING = 4;
local FONT_SIZE = 12;
local BACKGROUND_SCALE = 0.75;      -- drawn size of one texel of the tiled background (see NineSlice:CreateTiled)
local HOVER_DURATION = 0.25;
local HOVER_OFFSET = 8;
local HIGHLIGHT_FRONT_WIDTH = 18;

-- Art ids as retail's SetButtonArt: 1 red (main action), 2 blue, 3 hollow (disabled), 4 grey (exit).
local ART = {
    [1] = {background = "OptionBackground-Common.blp", font = "active", glow = {0.62, 0, 0}},
    [2] = {background = "OptionBackground-Blue.blp", font = "active", glow = {0, 0.3, 0.4}},
    [3] = {background = "OptionBackground-Hollow.blp", font = "disabled"},
    [4] = {background = "OptionBackground-Grey.blp", font = "active", glow = {0.23, 0.23, 0.23}},
};

local FONT_COLOR_ACTIVE = {0.87, 0.86, 0.75};
local FONT_COLOR_DISABLED = {0.50, 0.36, 0.24};
local FONT_COLOR_HOTKEY = {0.70, 0.70, 0.70};

-- Retail's EasingFunctions.outQuart.
local function OutQuart(t, from, to, duration)
    t = t / duration - 1;
    return from + (to - from) * (1 - t * t * t * t)
end

---------------------------------------------------------------------------
-- Hotkey badge: the small key box left of the label.
---------------------------------------------------------------------------

local function CreateHotkey(button)
    local f = CreateFrame("Frame", nil, button);
    f:SetWidth(HOTKEY_SIZE);
    f:SetHeight(HOTKEY_SIZE);

    f.background = NineSlice:Create(f, ThemeUtil:GetTextureFile("HotkeyBackground.blp"), {32, 32}, 8, HOTKEY_CORNER, "ARTWORK");

    f.keyName = f:CreateFontString(nil, "OVERLAY");
    f.keyName:SetFontObject(FontUtil:GetColoredFont("DUI335_Hotkey", 10, FONT_COLOR_HOTKEY));
    f.keyName:SetJustifyH("CENTER");
    f.keyName:SetJustifyV("MIDDLE");
    f.keyName:SetPoint("CENTER", f, "CENTER", 0, 0);

    f.icon = f:CreateTexture(nil, "OVERLAY");
    f.icon:SetWidth(HOTKEY_ICON_SIZE);
    f.icon:SetHeight(HOTKEY_ICON_SIZE);
    f.icon:SetPoint("CENTER", f, "CENTER", 0, 0);
    f.icon:SetVertexColor(0.72, 0.72, 0.72);
    f.icon:Hide();

    -- key: "SPACE" shows the space bar icon, anything else is printed as text ("Esc").
    function f:SetKey(key)
        local width = HOTKEY_SIZE;
        if key == "SPACE" then
            self.icon:SetTexture(ThemeUtil:GetKeyTextureFile("SPACE.blp"));
            self.icon:Show();
            self.keyName:Hide();
        else
            self.icon:Hide();
            self.keyName:SetText(key);
            self.keyName:Show();
            if #key > 1 then
                width = Round(self.keyName:GetStringWidth() + 12);
            end
        end
        self:SetWidth(width);
    end

    return f
end

---------------------------------------------------------------------------
-- Lock: the progress bar that keeps a button disabled for a moment (Continue when the quest costs gold).
---------------------------------------------------------------------------

local function CreateLock(button)
    local f = CreateFrame("Frame", nil, button);
    f:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
    f:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0);
    f:Hide();

    f.progress = f:CreateTexture(nil, "BACKGROUND");
    f.progress:SetTexture(ThemeUtil:GetTextureFile("ButtonLockProgress.blp"));
    f.progress:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
    f.progress:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);

    function f:UpdateProgress()
        local progress = self.t / self.duration;
        self.progress:SetTexCoord(0, self.fullBarCoord * progress, 0, 1);
        self.progress:SetWidth(self.fullWidth * progress);
    end

    function f:Clear()
        self.t = nil;
        self.callback = nil;
        self:SetScript("OnUpdate", nil);
        self:Hide();
    end

    function f:Start(duration, callback)
        local width, height = button:GetWidth(), button:GetHeight();
        self.fullBarCoord = min(1, width / (8 * height));
        self.fullWidth = width;
        self.t = 0.01;
        self.duration = duration;
        self.callback = callback;
        self:UpdateProgress();
        self:SetScript("OnUpdate", function(frame, elapsed)
            frame.t = frame.t + elapsed;
            if frame.t >= frame.duration then
                local fn = frame.callback;
                frame:Clear();
                if fn then
                    fn();
                end
            else
                frame:UpdateProgress();
            end
        end);
        self:Show();
    end

    f:SetScript("OnHide", f.Clear);
    return f
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------

local OptionButton = {};

local function Anim_Shift(button, elapsed)
    button.t = button.t + elapsed;
    if button.t < HOVER_DURATION then
        button.offset = OutQuart(button.t, button.animFrom, button.animTo, HOVER_DURATION);
    else
        button.offset = button.animTo;
        button:SetScript("OnUpdate", nil);
    end
    button.content:SetPoint("TOPLEFT", button, "TOPLEFT", button.offset, button.pushOffsetY);
end

function OptionButton:StartShift(to)
    self.t = 0;
    self.animFrom = self.offset;
    self.animTo = to;
    self:SetScript("OnUpdate", Anim_Shift);
end

-- Hover: the text slides right, the glow appears. Disabled buttons do nothing.
function OptionButton:ShowHover()
    if self.hovered or not self.isEnabled then
        return
    end
    self.hovered = true;
    self:StartShift(HOVER_OFFSET);
    local art = ART[self.artID];
    if art and art.glow then
        self.highlight:Show();
    end
end

function OptionButton:HideHover()
    if not self.hovered then
        return
    end
    self.hovered = false;
    self.highlight:Hide();
    self:StartShift(0);
end

-- Back to the resting state (page change).
function OptionButton:ResetVisual()
    self:SetScript("OnUpdate", nil);
    self.hovered = false;
    self.offset = 0;
    self.pushOffsetY = 0;
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    self.highlight:Hide();
end

function OptionButton:SetArt(id)
    local art = ART[id];
    self.artID = id;
    self.bgSlice:SetTexture(ThemeUtil:GetTextureFile(art.background));
    local color = art.font == "disabled" and FONT_COLOR_DISABLED or FONT_COLOR_ACTIVE;
    self.name:SetFontObject(FontUtil:GetColoredFont("DUI335_Option_" .. art.font, FONT_SIZE, color));
    self.name:SetSpacing(TEXT_SPACING);

    if art.glow then
        NineSlice:SetVertexColor(self.highlight.back, art.glow[1], art.glow[2], art.glow[3]);
    end
end

function OptionButton:SetButtonWidth(width)
    self:SetWidth(width);
    self.baseWidth = width;
end

function OptionButton:Layout()
    local nameOffset = BUTTON_PADDING;
    if self.hasHotkey then
        nameOffset = HOTKEY_PADDING + self.hotkey:GetWidth() + HOTKEY_PADDING;
    end

    self.name:SetWidth(self.baseWidth - nameOffset - HOVER_OFFSET);
    local height = Round(self.name:GetStringHeight() + 2 * BUTTON_PADDING);
    self:SetHeight(height);
    self.name:ClearAllPoints();
    self.name:SetPoint("TOPLEFT", self.content, "TOPLEFT", nameOffset, -BUTTON_PADDING);

    self.highlight.front:SetHeight(height);
    self.bgSlice:Update(self.baseWidth, height);
end

-- Shows or hides the key badge and re-lays the label (the Complete button shows its key only once a reward is chosen).
function OptionButton:SetHotkeyShown(shown)
    self.hasHotkey = shown and true or false;
    if self.hasHotkey then
        self.hotkey:Show();
    else
        self.hotkey:Hide();
    end
    self:Layout();
end

-- cfg: text, art (1-4), key ("SPACE", "Esc" or nil), enabled (default true), onClick(button), type.
-- A disabled button is only drawn differently: it still receives the mouse so the Complete button can flash the rewards.
function OptionButton:Configure(cfg)
    self.lock:Clear();
    self:ResetVisual();

    self.type = cfg.type;
    self.onClickFunc = cfg.onClick;
    self.isEnabled = cfg.enabled ~= false;
    self:SetArt(cfg.art);       -- sets the font: it must come before SetText in 3.3.5a
    self.name:SetText(cfg.text);

    if cfg.key then
        self.hotkey:SetKey(cfg.key);
    end
    self:SetHotkeyShown(cfg.key ~= nil);

    -- A new page can appear under the mouse.
    if self:IsMouseOver() then
        self:ShowHover();
    end
end

-- Disables the button for `duration` seconds with a progress bar, then runs callback (retail ButtonLock).
function OptionButton:StartLock(duration, callback)
    self.lock:Start(duration, callback);
end

function OptionButton:OnEnter()
    self:ShowHover();
end

function OptionButton:OnLeave()
    self:HideHover();
end

function OptionButton:OnMouseDown(button)
    if button ~= "LeftButton" then
        return
    end
    if self.isEnabled then
        self.pushOffsetY = -1;
        self.content:SetPoint("TOPLEFT", self, "TOPLEFT", self.offset, self.pushOffsetY);
    elseif self.type == "complete" and self.owner then
        self.owner:FlashRewardChoices();
    end
end

function OptionButton:OnMouseUp()
    self.pushOffsetY = 0;
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", self.offset, 0);
end

function OptionButton:OnClick(button)
    if button == "RightButton" then
        if self.owner then
            self.owner:RequestClose();
        end
        return
    end
    if not self.isEnabled or not self.onClickFunc then
        return
    end
    -- Pressed with a key while the mouse is elsewhere: still show the hover feedback.
    if not self:IsMouseOver() then
        self:ShowHover();
    end
    self.onClickFunc(self);
end

-- name: global name (needed so a key binding can click the button). owner: the parchment (RequestClose, FlashRewardChoices).
local function CreateOptionButton(parent, name, owner)
    local button = CreateFrame("Button", name, parent);
    for key, fn in pairs(OptionButton) do
        button[key] = fn;
    end
    button.owner = owner;
    button.offset = 0;
    button.pushOffsetY = 0;
    button.isEnabled = true;
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    button:SetWidth(256);
    button:SetHeight(36);

    button.bgSlice = NineSlice:CreateTiled(button, ThemeUtil:GetTextureFile(ART[1].background), {256, 64}, 16, BACKGROUND_SCALE, "BACKGROUND");

    local level = button:GetFrameLevel();

    -- Hover glow (retail ButtonHighlight frame): stretched back with uneven margins, plus a bar on the left.
    local highlight = CreateFrame("Frame", nil, button);
    highlight:SetAllPoints(button);
    highlight:SetFrameLevel(level + 1);
    highlight:Hide();
    highlight.back = NineSlice:CreateEdges(highlight, ThemeUtil:GetTextureFile("ButtonHighlight-Add.blp"), {128, 64}, 40, 16, 8, 8, "ARTWORK");
    NineSlice:SetBlendMode(highlight.back, "ADD");
    highlight.front = highlight:CreateTexture(nil, "OVERLAY");
    highlight.front:SetTexture(ThemeUtil:GetTextureFile("ButtonHighlight-Front.blp"));
    highlight.front:SetWidth(HIGHLIGHT_FRONT_WIDTH);
    button.highlight = highlight;

    button.lock = CreateLock(button);
    button.lock:SetFrameLevel(level + 1);

    -- Content moves on hover and press. Retail's is 20x20 on the top left: children are positioned from there.
    local content = CreateFrame("Frame", nil, button);
    content:SetWidth(20);
    content:SetHeight(20);
    content:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
    content:SetFrameLevel(level + 2);
    button.content = content;
    highlight.front:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0);

    button.name = content:CreateFontString(nil, "OVERLAY");
    button.name:SetJustifyH("LEFT");
    button.name:SetJustifyV("TOP");

    local hotkey = CreateHotkey(button);
    hotkey:SetFrameLevel(level + 3);
    hotkey:SetPoint("TOPLEFT", content, "TOPLEFT", HOTKEY_PADDING, -HOTKEY_PADDING);
    hotkey:Hide();
    button.hotkey = hotkey;

    button:SetScript("OnEnter", button.OnEnter);
    button:SetScript("OnLeave", button.OnLeave);
    button:SetScript("OnMouseDown", button.OnMouseDown);
    button:SetScript("OnMouseUp", button.OnMouseUp);
    button:SetScript("OnClick", button.OnClick);

    return button
end

addon.CreateOptionButton = CreateOptionButton;
