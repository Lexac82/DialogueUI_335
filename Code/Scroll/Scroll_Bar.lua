local _, addon = ...;

-- Vertical scroll bar: up arrow, rail with a draggable thumb, down arrow. Port of retail's Scroll_Bar.lua without
-- the "scroll to bottom" arrow and the new-message dot. Colors per theme as retail (Brown / Dark), applied with
-- vertex colors to the shared textures (ScrollBar-Vertical-Buttons / Rail / Thumb).
--
-- The owner is any frame with GetViewSize(), GetScrollRange(), GetScrollOffset(), ScrollBy(offset) and
-- OnMouseWheel(delta) (retail's scroll view interface). It calls bar:UpdateThumbSize() when the range changes and
-- bar:UpdateThumbPosition() when the offset changes.
local API = addon.API;
local NineSlice = addon.NineSlice;
local ThemeUtil = addon.ThemeUtil;
local CallbackRegistry = addon.CallbackRegistry;

local Round = API.Round;
local GetCursorPosition = GetCursorPosition;

local BUTTON_SIZE = 12;
local RAIL_WIDTH = 4;
local RAIL_GAP = 2;                     -- between the arrows and the rail
local THUMB_MIN_HEIGHT = BUTTON_SIZE;
local THUMB_GROW_SPEED = (BUTTON_SIZE - RAIL_WIDTH) * 10;       -- units per second, the thumb widens on hover
local REPEAT_DELAY = 0.25;

local BUTTONS_FILE = "ScrollBar-Vertical-Buttons.blp";
local RAIL_FILE = "ScrollBar-Vertical-Rail.blp";
local THUMB_FILE = "ScrollBar-Vertical-Thumb.blp";

local ThemeBrown = {
    disabled = {0.45, 0.29, 0.16, 0.2},
    normal = {0.44, 0.20, 0.125, 1},
    highlight = {0.55, 0.30, 0.22, 1},
    pushed = {0.72, 0.52, 0.33, 1},
};

local ThemeDark = {
    disabled = {0.16, 0.16, 0.16, 1},
    normal = {0.33, 0.33, 0.33, 1},
    highlight = {0.6, 0.6, 0.6, 1},
    pushed = {0.72, 0.72, 0.72, 1},
};

local function Paint(target, color)
    -- target: a texture, or a NineSlice table (array of textures)
    if target.SetVertexColor then
        target:SetVertexColor(color[1], color[2], color[3], color[4]);
    else
        NineSlice:SetVertexColor(target, color[1], color[2], color[3], color[4]);
    end
end


local ScrollBarMixin = {};

function ScrollBarMixin:GetColors()
    return ThemeUtil:IsDarkMode() and ThemeDark or ThemeBrown
end

function ScrollBarMixin:UpdateColors()
    local theme = self:GetColors();
    Paint(self.railPieces, theme.disabled);
    for _, button in ipairs({ self.UpArrow, self.DownArrow }) do
        Paint(button.Texture, button:IsEnabled() and theme.normal or theme.disabled);
    end
    local thumb = self.Thumb;
    Paint(thumb.pieces, thumb.mouseDown and theme.pushed or (thumb.isOver and theme.highlight or theme.normal));
end

function ScrollBarMixin:SetOwner(owner)
    self.owner = owner;
    self:OnSizeChanged();
end

-- The bar is as tall as the view it belongs to.
function ScrollBarMixin:OnSizeChanged()
    self.railSize = self.owner:GetViewSize() - 2 * (BUTTON_SIZE + RAIL_GAP);
    self:SetHeight(self.owner:GetViewSize());
    self:UpdateThumbSize();
    self:UpdateThumbPosition();
end

function ScrollBarMixin:UpdateThumbSize()
    local viewSize = self.owner:GetViewSize();
    local scrollRange = self.owner:GetScrollRange();
    local height = BUTTON_SIZE;

    if viewSize <= 0 or scrollRange <= 0 then
        scrollRange = 0;
        self:Hide();
    else
        self:Show();
        height = Round(self.railSize * viewSize / (scrollRange + viewSize));
        if height < THUMB_MIN_HEIGHT then
            height = THUMB_MIN_HEIGHT;
        end
    end

    local thumbRange = self.railSize - height;
    self.cursorScrollSize = (thumbRange > 0) and (scrollRange / thumbRange) or 0;
    self.thumbRange = thumbRange;
    self.Thumb:SetHeight(height);
end

function ScrollBarMixin:UpdateThumbPosition()
    local scrollOffset = self.owner:GetScrollOffset();
    local scrollRange = self.owner:GetScrollRange();
    local progress = 0;

    if scrollRange > 0 and scrollOffset > 0 then
        progress = scrollOffset / scrollRange;
    end

    self.Thumb:SetPoint("TOP", self.Rail, "TOP", 0, -self.thumbRange * progress);

    if scrollRange <= 0 then
        self.UpArrow:Disable();
        self.DownArrow:Disable();
    else
        if progress >= 0.005 then self.UpArrow:Enable() else self.UpArrow:Disable() end
        if progress < 0.995 then self.DownArrow:Enable() else self.DownArrow:Disable() end
    end
end

function ScrollBarMixin:SetScrollOffsetByCursorDelta(cursorDelta)
    self.owner:ScrollBy(self.cursorScrollSize * -cursorDelta);
end

function ScrollBarMixin:OnHide()
    self.Thumb:StopDrag();
end


---------------------------------------------------------------------------
-- Arrow buttons
---------------------------------------------------------------------------

local function Arrow_OnEnter(self)
    if self:IsEnabled() then
        local theme = self.bar:GetColors();
        Paint(self.Texture, self.mouseDown and theme.pushed or theme.highlight);
    end
end

local function Arrow_OnLeave(self)
    if self:IsEnabled() and not self.mouseDown then
        Paint(self.Texture, self.bar:GetColors().normal);
    end
end

-- Holding the button repeats the click.
local function Arrow_OnUpdate(self, elapsed)
    self.holdTime = self.holdTime + elapsed;
    if self.holdTime >= REPEAT_DELAY then
        self.holdTime = 0;
        if self:IsEnabled() then
            self:Click();
        else
            self:SetScript("OnUpdate", nil);
        end
    end
end

local function Arrow_OnMouseDown(self)
    if not self:IsEnabled() then return end
    self.mouseDown = true;
    Paint(self.Texture, self.bar:GetColors().pushed);
    self.holdTime = -REPEAT_DELAY;
    self:SetScript("OnUpdate", Arrow_OnUpdate);
end

local function Arrow_OnMouseUp(self)
    self.mouseDown = nil;
    self:SetScript("OnUpdate", nil);
    if self:IsEnabled() then
        local theme = self.bar:GetColors();
        Paint(self.Texture, self:IsMouseOver() and theme.highlight or theme.normal);
    end
end

local function Arrow_OnEnable(self)
    Paint(self.Texture, self.bar:GetColors().normal);
end

local function Arrow_OnDisable(self)
    self.mouseDown = nil;
    self:SetScript("OnUpdate", nil);
    Paint(self.Texture, self.bar:GetColors().disabled);
end

local function CreateArrowButton(bar, delta, texCoords)
    local b = CreateFrame("Button", nil, bar);
    b.bar = bar;
    b:SetWidth(BUTTON_SIZE);
    b:SetHeight(BUTTON_SIZE);
    b:SetScript("OnEnter", Arrow_OnEnter);
    b:SetScript("OnLeave", Arrow_OnLeave);
    b:SetScript("OnMouseDown", Arrow_OnMouseDown);
    b:SetScript("OnMouseUp", Arrow_OnMouseUp);
    b:SetScript("OnEnable", Arrow_OnEnable);
    b:SetScript("OnDisable", Arrow_OnDisable);
    b:SetScript("OnHide", Arrow_OnMouseUp);
    b:SetScript("OnClick", function()
        bar.owner:OnMouseWheel(delta);
    end);

    b.Texture = b:CreateTexture(nil, "ARTWORK");
    b.Texture:SetAllPoints(b);
    b.Texture:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4]);
    ThemeUtil:BindTexture(b.Texture, BUTTONS_FILE);
    return b
end


---------------------------------------------------------------------------
-- Thumb
---------------------------------------------------------------------------

local function Thumb_OnUpdate(self, elapsed)
    local bar = self.bar;
    local width = self.width;
    -- Grows while hovered or dragged, shrinks back after.
    if self.isOver or self.mouseDown then
        if width < BUTTON_SIZE then
            width = math.min(BUTTON_SIZE, width + THUMB_GROW_SPEED * elapsed);
        end
    elseif width > RAIL_WIDTH then
        width = math.max(RAIL_WIDTH, width - THUMB_GROW_SPEED * elapsed);
    end
    if width ~= self.width then
        self.width = width;
        self.art:SetWidth(width);
    end

    if self.mouseDown then
        self.dragTime = self.dragTime + elapsed;
        if self.dragTime >= 0.016 then
            self.dragTime = 0;
            local _, y = GetCursorPosition();
            y = y / bar:GetEffectiveScale();
            local deltaY = y - self.cursorY;
            self.cursorY = y;
            if deltaY ~= 0 then
                bar:SetScrollOffsetByCursorDelta(deltaY);
            end
        end
    elseif not self.isOver and width <= RAIL_WIDTH then
        self:SetScript("OnUpdate", nil);
    end
end

local function CreateThumb(bar)
    local thumb = CreateFrame("Frame", nil, bar);
    thumb.bar = bar;
    thumb:SetFrameLevel(bar.Rail:GetFrameLevel() + 5);
    thumb:SetPoint("TOP", bar.Rail, "TOP", 0, 0);
    thumb:SetWidth(BUTTON_SIZE);
    thumb:SetHeight(BUTTON_SIZE);
    thumb:EnableMouse(true);
    thumb.width = RAIL_WIDTH;

    -- The visible part is narrow (rail width) and grows on hover; the frame keeps the full width for the mouse.
    thumb.art = CreateFrame("Frame", nil, thumb);
    thumb.art:SetPoint("TOP", thumb, "TOP", 0, 0);
    thumb.art:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0);
    thumb.art:SetWidth(RAIL_WIDTH);
    thumb.pieces = NineSlice:Create(thumb.art, ThemeUtil:GetTextureFile(THUMB_FILE), {32, 32}, 4, 2, "OVERLAY");
    ThemeUtil:BindSlice(thumb.pieces, THUMB_FILE);

    function thumb:StopDrag()
        if self.mouseDown then
            self.mouseDown = nil;
            bar:UpdateColors();
        end
    end

    thumb:SetScript("OnEnter", function(self)
        self.isOver = true;
        self:SetScript("OnUpdate", Thumb_OnUpdate);
        bar:UpdateColors();
    end);
    thumb:SetScript("OnLeave", function(self)
        self.isOver = nil;
        bar:UpdateColors();
    end);
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.mouseDown = true;
        local _, y = GetCursorPosition();
        self.cursorY = y / bar:GetEffectiveScale();
        self.dragTime = 0;
        self:SetScript("OnUpdate", Thumb_OnUpdate);
        bar:UpdateColors();
    end);
    thumb:SetScript("OnMouseUp", function(self)
        self:StopDrag();
    end);
    thumb:SetScript("OnHide", function(self)
        self:StopDrag();
        self.isOver = nil;
    end);

    return thumb
end


local function CreateScrollBar(parent)
    local f = CreateFrame("Frame", nil, parent);
    f:SetWidth(BUTTON_SIZE);
    f:SetHeight(224);
    f:EnableMouse(true);

    f.UpArrow = CreateArrowButton(f, 1, {0, 0.5, 0, 0.5});
    f.UpArrow:SetPoint("TOP", f, "TOP", 0, 0);
    f.DownArrow = CreateArrowButton(f, -1, {0.5, 1, 0, 0.5});
    f.DownArrow:SetPoint("BOTTOM", f, "BOTTOM", 0, 0);

    local rail = CreateFrame("Frame", nil, f);
    f.Rail = rail;
    rail:SetWidth(RAIL_WIDTH);
    rail:SetPoint("TOP", f.UpArrow, "BOTTOM", 0, -RAIL_GAP);
    rail:SetPoint("BOTTOM", f.DownArrow, "TOP", 0, RAIL_GAP);
    f.railPieces = NineSlice:Create(rail, ThemeUtil:GetTextureFile(RAIL_FILE), {8, 64}, 2, 2, "BORDER");
    ThemeUtil:BindSlice(f.railPieces, RAIL_FILE);

    f.Thumb = CreateThumb(f);

    API.Mixin(f, ScrollBarMixin);
    f:SetScript("OnHide", f.OnHide);
    f.railSize = 1;
    f.thumbRange = 0;
    f.cursorScrollSize = 0;

    f.UpArrow:Disable();
    f.DownArrow:Disable();
    f:UpdateColors();
    CallbackRegistry:Register("ThemeChanged", function()
        f:UpdateColors();
    end);

    return f
end
addon.CreateScrollBar = CreateScrollBar;
