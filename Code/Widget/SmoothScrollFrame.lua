local _, addon = ...;

-- Eased vertical scrolling for a ScrollFrame.
-- Port of retail's Scroll_EasySmooth.lua, without recycling, pagination and joystick scrolling.

local MathUtil = addon.MathUtil;
local DeltaLerp = MathUtil.DeltaLerp;
local Clamp = MathUtil.Clamp;

local pairs = pairs;

local SCROLL_BLEND_SPEED = 0.15;
local SCROLL_PER_WHEEL = 96;        -- retail offsetPerScroll
local DIVIDER_FADE_DISTANCE = 24;   -- px over which the divider fades

local ScrollMixin = {};

function ScrollMixin:UpdateDivider(value)
    local divider = self.footerDivider;
    if not divider then
        return
    end
    if self.range <= 0 then
        divider:SetAlpha(0);
    else
        divider:SetAlpha(Clamp((self.range - value) / DIVIDER_FADE_DISTANCE, 0, 1));
    end
end

function ScrollMixin:SetOffset(value)
    self.value = value;
    self:SetVerticalScroll(value);
    self:UpdateDivider(value);
end

function ScrollMixin:OnUpdate_Easing(elapsed)
    self.value = DeltaLerp(self.value, self.scrollTarget, self.blendSpeed, elapsed);

    local diff = self.value - self.scrollTarget;
    if diff > -0.4 and diff < 0.4 then
        self.value = self.scrollTarget;
        self:SetScript("OnUpdate", nil);
    end

    self:SetOffset(self.value);
end

-- Jumps without easing. ignoreRange lets a reset work before the range is known.
function ScrollMixin:SnapTo(value, ignoreRange)
    if not ignoreRange then
        value = Clamp(value, 0, self.range);
    end
    self:SetScript("OnUpdate", nil);
    self.scrollTarget = value;
    self:SetOffset(value);
end

function ScrollMixin:ResetScroll()
    self:SnapTo(0, true);
end

function ScrollMixin:ScrollTo(value)
    value = Clamp(value, 0, self.range);
    if value ~= self.scrollTarget then
        self.scrollTarget = value;
        self:SetScript("OnUpdate", self.OnUpdate_Easing);
    end
end

function ScrollMixin:ScrollBy(delta)
    -- Relative to the target, so quick wheel turns add up.
    self:ScrollTo((self.scrollTarget or self.value) + delta);
end

function ScrollMixin:ScrollToBottom()
    self:ScrollTo(self.range);
end

function ScrollMixin:SetScrollRange(range)
    self.range = range;
    if self.scrollTarget > range then
        self:SnapTo(range);
    else
        self:UpdateDivider(self.value);
    end
end

function ScrollMixin:IsScrollable()
    return self.range > 0
end

function ScrollMixin:IsAtPageBottom()
    return self.scrollTarget + 0.5 >= self.range
end

function ScrollMixin:OnMouseWheel(delta)
    if self.range <= 0 then
        return
    end
    -- delta is 1 when scrolling up.
    if delta > 0 then
        self:ScrollBy(-SCROLL_PER_WHEEL);
    else
        self:ScrollBy(SCROLL_PER_WHEEL);
    end
end

function ScrollMixin:OnHide()
    self:SetScript("OnUpdate", nil);
    if self.scrollTarget ~= self.value then
        self:SnapTo(self.scrollTarget);
    end
end

-- footerDivider: texture whose alpha follows the distance to the bottom (may be set later).
local function InitSmoothScrollFrame(scrollFrame, footerDivider)
    for key, func in pairs(ScrollMixin) do
        scrollFrame[key] = func;
    end

    scrollFrame.value = 0;
    scrollFrame.scrollTarget = 0;
    scrollFrame.range = 0;
    scrollFrame.blendSpeed = SCROLL_BLEND_SPEED;
    scrollFrame.footerDivider = footerDivider;

    scrollFrame:EnableMouseWheel(true);
    scrollFrame:SetScript("OnMouseWheel", scrollFrame.OnMouseWheel);
    scrollFrame:SetScript("OnHide", scrollFrame.OnHide);
    return scrollFrame
end

addon.InitSmoothScrollFrame = InitSmoothScrollFrame;
