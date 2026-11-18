local _, addon = ...;

-- Footer option button (Accept, Continue, Complete, Decline, Cancel, Goodbye).
-- Port of retail's DUIDialogOptionButtonMixin (UITemplates.lua), DUIDialogHotkeyFrameMixin and
-- DUIDialogOptionButtonLockMixin. Mouse and keyboard only: no controller icons.
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;
local API = addon.API;
local Round = API.Round;

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

local ICON_SIZE = 14;               -- retail BUTTON_ICON_SIZE
local ICON_PADDING = 6;             -- retail ICON_PADDING_H
local PADDING_SMALL = 6;            -- retail BUTTON_PADDING_SMALL (gossip option rows)
local NOTE_PADDING = 8;             -- right-hand note: distance from the right edge
local GOSSIP_GLOW = "ButtonHighlight-Gossip.blp";
local ADD_GLOW = "ButtonHighlight-Add.blp";

-- Art ids as retail's SetButtonArt: 0 gossip option (no background), 1 red (main action), 2 blue,
-- 3 hollow (disabled), 4 grey (exit).
local ART = {
    [0] = {font = "gossip", noBackground = true, glowFile = GOSSIP_GLOW, noFront = true},
    [1] = {background = "OptionBackground-Common.blp", font = "active", glow = {0.62, 0, 0}},
    [2] = {background = "OptionBackground-Blue.blp", font = "active", glow = {0, 0.3, 0.4}},
    [3] = {background = "OptionBackground-Hollow.blp", font = "disabled"},
    [4] = {background = "OptionBackground-Grey.blp", font = "active", glow = {0.23, 0.23, 0.23}},
};

-- {Brown, Dark} color keys of ThemeUtil, from retail's FONT_OBJECT_COLOR.
local FONT_COLOR_ACTIVE = {"Ivory", "DarkModeGold"};                -- DUIFont_Quest_Quest
local FONT_COLOR_DISABLED = {"LightBrown", "DarkModeGrey50"};       -- DUIFont_Quest_Disabled
local FONT_COLOR_GOSSIP = {"DarkBrown", "DarkModeGoldDim"};         -- DUIFont_Quest_Gossip
local FONT_COLOR_NOTE = {"DarkModeGrey70", "DarkModeGrey70"};       -- DUIFont_QuestType_Right
local FONT_COLOR_HOTKEY = {"DarkModeGrey70", "DarkModeGrey70"};

-- The Dark ButtonHighlight-Gossip is 128x32, the Brown one 128x64 (all other glow files are 128x64).
local HIGHLIGHT_SLICE = {left = 40, right = 16, top = 8, bottom = 8};

-- Re-cuts the nine pieces of a CreateEdges slice for a texture of another size.
local function SetSliceCoords(pieces, texW, texH, slice)
    local u = {0, slice.left / texW, 1 - slice.right / texW, 1};
    local v = {0, slice.top / texH, 1 - slice.bottom / texH, 1};
    for row = 1, 3 do
        for col = 1, 3 do
            pieces[(row - 1) * 3 + col]:SetTexCoord(u[col], u[col + 1], v[row], v[row + 1]);
        end
    end
end

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
    ThemeUtil:BindSlice(f.background, "HotkeyBackground.blp");

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
    ThemeUtil:BindTexture(f.progress, "ButtonLockProgress.blp");
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

local OptionButtonMixin = {};

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

function OptionButtonMixin:StartShift(to)
    self.t = 0;
    self.animFrom = self.offset;
    self.animTo = to;
    self:SetScript("OnUpdate", Anim_Shift);
end

-- Hover: the text slides right, the glow appears. Disabled buttons do nothing.
function OptionButtonMixin:ShowHover()
    if self.hovered or not self.isEnabled then
        return
    end
    self.hovered = true;
    self:StartShift(HOVER_OFFSET);
    local art = ART[self.artID];
    if art and (art.glow or art.glowFile) then
        self.highlight:Show();
    end
end

function OptionButtonMixin:HideHover()
    if not self.hovered then
        return
    end
    self.hovered = false;
    self.highlight:Hide();
    self:StartShift(0);
end

-- Back to the resting state (page change).
function OptionButtonMixin:ResetVisual()
    self:SetScript("OnUpdate", nil);
    self.hovered = false;
    self.offset = 0;
    self.pushOffsetY = 0;
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0);
    self.highlight:Hide();
end

function OptionButtonMixin:SetArt(id)
    local art = ART[id];
    self.artID = id;
    if art.noBackground then
        self.bgSlice:SetShown(false);
    else
        self.bgSlice:SetShown(true);
        self.bgSlice:SetTexture(ThemeUtil:GetTextureFile(art.background));
    end
    local color = FONT_COLOR_ACTIVE;
    if art.font == "disabled" then
        color = FONT_COLOR_DISABLED;
    elseif art.font == "gossip" then
        color = FONT_COLOR_GOSSIP;
    end
    self.name:SetFontObject(FontUtil:GetColoredFont("DUI335_Option_" .. art.font, FONT_SIZE, color));
    self.name:SetSpacing(TEXT_SPACING);

    -- Glow: tinted additive (action buttons) or the plain gossip glow (option rows).
    local glowFile = art.glowFile or ADD_GLOW;
    if self.glowFile ~= glowFile then
        self.glowFile = glowFile;
        NineSlice:SetTexture(self.highlight.back, ThemeUtil:GetTextureFile(glowFile));
        NineSlice:SetBlendMode(self.highlight.back, art.glowFile and "BLEND" or "ADD");
        local texHeight = (glowFile == GOSSIP_GLOW and ThemeUtil:IsDarkMode()) and 32 or 64;
        SetSliceCoords(self.highlight.back, 128, texHeight, HIGHLIGHT_SLICE);
    end
    if art.glow then
        NineSlice:SetVertexColor(self.highlight.back, art.glow[1], art.glow[2], art.glow[3]);
    else
        NineSlice:SetVertexColor(self.highlight.back, 1, 1, 1);
    end
    if art.noFront then
        self.highlight.front:Hide();
    else
        self.highlight.front:Show();
    end
end

function OptionButtonMixin:SetButtonWidth(width)
    self:SetWidth(width);
    self.baseWidth = width;
end

-- Lays out badge, icon, label and right-hand note, then sizes the button to the (wrapped) label.
-- The width is set before the text so the wrap height is right.
function OptionButtonMixin:Layout()
    local padding = self.padding or BUTTON_PADDING;
    local iconOffset, nameOffset = padding, padding;
    if self.hasHotkey then
        iconOffset = HOTKEY_PADDING + self.hotkey:GetWidth() + HOTKEY_PADDING;
        nameOffset = iconOffset;
    end
    local iconSize = self.iconSize or ICON_SIZE;
    if self.iconFile then
        nameOffset = iconOffset + iconSize + ICON_PADDING;
    end

    local noteWidth = 0;
    if self.noteText then
        self.note:SetText(self.noteText);
        self.note:Show();
        noteWidth = Round(self.note:GetStringWidth()) + NOTE_PADDING;
    else
        self.note:Hide();
    end

    self.name:SetWidth(self.baseWidth - nameOffset - noteWidth - HOVER_OFFSET);
    self.name:SetText(self.text or "");
    -- A bigger icon makes the row taller and the label is centred against it.
    local textHeight = self.name:GetStringHeight();
    local contentHeight = textHeight;
    if self.iconFile and iconSize > contentHeight then
        contentHeight = iconSize;
    end
    local height = Round(contentHeight + 2 * padding);
    self:SetHeight(height);
    self.name:ClearAllPoints();
    self.name:SetPoint("TOPLEFT", self.content, "TOPLEFT", nameOffset, -padding - Round((contentHeight - textHeight) / 2));

    if self.iconFile then
        self.icon:SetTexture(self.iconFile);
        self.icon:SetWidth(iconSize);
        self.icon:SetHeight(iconSize);
        self.icon:ClearAllPoints();
        self.icon:SetPoint("TOPLEFT", self.content, "TOPLEFT", iconOffset, -padding - Round((contentHeight - iconSize) / 2) + 1);
        self.icon:Show();
    else
        self.icon:Hide();
    end

    self.highlight.front:SetHeight(height);
    self.bgSlice:Update(self.baseWidth, height);
end

-- Shows or hides the key badge and re-lays the label (the Complete button shows its key only once a reward is chosen).
function OptionButtonMixin:SetHotkeyShown(shown)
    self.hasHotkey = shown and true or false;
    if self.hasHotkey then
        self.hotkey:Show();
    else
        self.hotkey:Hide();
    end
    self:Layout();
end

-- cfg: text, art (0-4), key ("SPACE", "Esc", "1".."9" or nil), enabled (default true), onClick(button), type.
-- List rows also use: icon (texture path), iconSize (default 14), note (small grey text on the right), padding (default 12).
-- A disabled button is only drawn differently: it still receives the mouse so the Complete button can flash the rewards.
function OptionButtonMixin:Configure(cfg)
    self.lock:Clear();
    self:ResetVisual();

    self.type = cfg.type;
    self.onClickFunc = cfg.onClick;
    self.isEnabled = cfg.enabled ~= false;
    self.text = cfg.text;
    self.iconFile = cfg.icon;
    self.iconSize = cfg.iconSize;
    self.noteText = cfg.note;
    self.padding = cfg.padding;
    self:SetArt(cfg.art);       -- sets the font: it must come before SetText in 3.3.5a

    if cfg.key then
        self.hotkey:SetKey(cfg.key);
    end
    self:SetHotkeyShown(cfg.key ~= nil);      -- also runs Layout, which sets the text

    -- A new page can appear under the mouse.
    if self:IsMouseOver() then
        self:ShowHover();
    end
end

-- Disables the button for `duration` seconds with a progress bar, then runs callback (retail ButtonLock).
function OptionButtonMixin:StartLock(duration, callback)
    self.lock:Start(duration, callback);
end

function OptionButtonMixin:OnEnter()
    self:ShowHover();
end

function OptionButtonMixin:OnLeave()
    self:HideHover();
end

function OptionButtonMixin:OnMouseDown(button)
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

function OptionButtonMixin:OnMouseUp()
    self.pushOffsetY = 0;
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", self.offset, 0);
end

function OptionButtonMixin:OnClick(button)
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
    API.Mixin(button, OptionButtonMixin);
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
    ThemeUtil:BindTexture(highlight.front, "ButtonHighlight-Front.blp");
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
    button.name:SetWordWrap(true);

    button.icon = content:CreateTexture(nil, "OVERLAY");
    button.icon:SetWidth(ICON_SIZE);
    button.icon:SetHeight(ICON_SIZE);
    button.icon:Hide();

    -- Quest type note ("Trivial", "Repeatable"): fixed on the button, it does not slide with the content.
    button.note = button:CreateFontString(nil, "OVERLAY");
    button.note:SetFontObject(FontUtil:GetColoredFont("DUI335_QuestType", 10, FONT_COLOR_NOTE));
    button.note:SetJustifyH("RIGHT");
    button.note:SetPoint("RIGHT", button, "RIGHT", -NOTE_PADDING, 0);
    button.note:Hide();

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

    -- The background file and the glow file depend on the art id: apply them again.
    addon.CallbackRegistry:Register("ThemeChanged", function()
        if button.artID then
            button.glowFile = nil;
            button:SetArt(button.artID);
        end
    end);

    return button
end

addon.CreateOptionButton = CreateOptionButton;
addon.OPTION_BUTTON_PADDING_SMALL = PADDING_SMALL;
