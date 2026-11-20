local _, addon = ...;

-- Experience bar along the bottom edge of the screen. Port of retail's StatusBar.lua (the "xp" data provider) and its
-- use in DialogueUI.lua. It shows while the parchment is open (Settings > UI > Quest > Experience Bar) and, with
-- "Always Show", all the time, so it can stand in for the game's own experience bar.
--
-- Same behaviour as retail: the fill eases to its new length in 2 s (inOutSine), a "+N XP" block fades in over the
-- gained piece, a level up fills the bar to the end and continues from zero in the new level, notches mark every 5%,
-- the tooltip follows the cursor.
--
-- Textures (Textures\Shared\, converted from retail's Art\Theme_Shared PNGs): StatusBar-Background 256x16,
-- StatusBar-Border 256x16, StatusBar-FillShort-Purple 32x16, StatusBar-ValueBlock-Purple 128x64, StatusBar-Notch 8x16.
-- Retail draws them with texture slice mode, 3.3.5a has none, so NineSlice builds the same from 9 textures.
-- Not ported: nothing is anchored to the bar (retail anchors its chat frame to it).

local L = addon.L;
local API = addon.API;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;
local CallbackRegistry = addon.CallbackRegistry;
local Clamp = API.Clamp;

local CreateFrame = CreateFrame;
local UnitLevel = UnitLevel;
local UnitXP = UnitXP;
local UnitXPMax = UnitXPMax;
local GetCursorPosition = GetCursorPosition;
local cos = math.cos;
local floor = math.floor;
local max = math.max;
local min = math.min;
local pi = math.pi;

local FILE_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Shared\\";
local BACKGROUND_FILE = FILE_PATH .. "StatusBar-Background.blp";
local BORDER_FILE = FILE_PATH .. "StatusBar-Border.blp";
local FILL_FILE = FILE_PATH .. "StatusBar-FillShort-Purple.blp";
local NOTCH_FILE = FILE_PATH .. "StatusBar-Notch.blp";
local VALUE_BLOCK_FILE = FILE_PATH .. "StatusBar-ValueBlock-Purple.blp";

local BAR_HEIGHT = 8;
local BAR_OFFSET_Y = -2;                -- the border's lower edge is cut off by the screen edge
local NUM_COMPARTMENTS = 20;            -- 19 notches
local SLICE_MARGIN = 6;                 -- texels of the 256x16 / 32x16 textures
local SLICE_CORNER = 3;                 -- drawn corner: the 16 texel high art is squeezed into 8 units, as retail does
local FILL_DURATION = 2.0;
local FADE_OUT_DURATION = 0.15;
local BLOCK_OFFSET_Y = -2;              -- the "+N XP" block sits 2 units lower than retail's
local BLOCK_MIN_WIDTH = 24;             -- a smaller gain shows no "+N XP" block

-- Retail's EasingFunctions.inOutSine.
local function inOutSine(t, b, e, d)
    return -(e - b) / 2 * (cos(pi * t / d) - 1) + b
end

-- 3.3.5a has no BreakUpLargeNumbers.
local function BreakUpLargeNumbers(value)
    local text = tostring(floor(value));
    local count;
    repeat
        text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2");
    until count == 0;
    return text
end

-- One screen pixel in the units of `frame` (retail API.GetPixelForWidget; same resolution lookup as Settings.lua).
local function GetPixelSize(frame)
    local _, physHeight = string.match(GetCVar("gxResolution") or "", "(%d+)x(%d+)");
    physHeight = tonumber(physHeight);
    local scale = frame:GetEffectiveScale();
    if physHeight and physHeight > 0 and scale and scale > 0 then
        return 768 / physHeight / scale
    end
    return 0.71
end

-- GetMaxPlayerLevel is not in wow-docs (retail's code probes for it the same way), so it is looked up at run time.
-- Without it the bar only hides when the server reports no experience to gain.
local function IsCapped()
    local maxXP = UnitXPMax("player");
    if not maxXP or maxXP <= 0 then
        return true
    end
    local cap = GetMaxPlayerLevel and GetMaxPlayerLevel();
    return cap ~= nil and UnitLevel("player") >= cap
end


---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------

-- On UIRoot, so the bar stays when Hide UI hides UIParent.
local frame = CreateFrame("Frame", nil, addon.UIRoot);
frame:SetFrameStrata("BACKGROUND");     -- set before the children exist, they copy it
frame:SetHeight(BAR_HEIGHT);
frame:SetPoint("BOTTOMLEFT", addon.UIRoot, "BOTTOMLEFT", 0, BAR_OFFSET_Y);
frame:SetPoint("BOTTOMRIGHT", addon.UIRoot, "BOTTOMRIGHT", 0, BAR_OFFSET_Y);
frame:EnableMouse(true);
frame:SetAlpha(0);
frame:Hide();

local baseLevel = frame:GetFrameLevel();

local background = NineSlice:Create(frame, BACKGROUND_FILE, {256, 16}, SLICE_MARGIN, SLICE_CORNER, "BACKGROUND");
for i = 1, #background do
    background[i]:SetAlpha(0.5);
end

-- The fill is a frame of its own: its width changes and its 9 textures follow.
local fill = CreateFrame("Frame", nil, frame);
fill:SetFrameLevel(baseLevel + 1);
fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
fill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);
fill:SetWidth(1);
NineSlice:Create(fill, FILL_FILE, {32, 16}, SLICE_MARGIN, SLICE_CORNER, "ARTWORK");

-- Glowing edge at the end of the fill.
local surface = fill:CreateTexture(nil, "OVERLAY");
surface:SetHeight(6);
surface:SetWidth(48);
surface:SetTexture(1, 1, 1, 1);
surface:SetGradientAlpha("HORIZONTAL", 1, 0.5, 1, 0, 1, 0.5, 1, 0.5);
surface:SetBlendMode("ADD");
surface:SetPoint("RIGHT", fill, "RIGHT", 0, 0);

-- Border and notches above the fill.
local overlay = CreateFrame("Frame", nil, frame);
overlay:SetFrameLevel(baseLevel + 2);
overlay:SetAllPoints(frame);
local border = NineSlice:Create(overlay, BORDER_FILE, {256, 16}, SLICE_MARGIN, SLICE_CORNER, "OVERLAY");
NineSlice:SetVertexColor(border, 0.25, 0.25, 0.25);

local notches = {};
for i = 1, NUM_COMPARTMENTS - 1 do
    local notch = overlay:CreateTexture(nil, "OVERLAY");
    notch:SetTexture(NOTCH_FILE);
    notch:SetVertexColor(0.25, 0.25, 0.25);
    notches[i] = notch;
end

-- "+N XP" over the piece that was just gained.
local valueBlock = CreateFrame("Frame", nil, frame);
valueBlock:SetFrameLevel(baseLevel + 3);
valueBlock:SetHeight(32);
valueBlock:Hide();
NineSlice:Create(valueBlock, VALUE_BLOCK_FILE, {128, 64}, 8, 8, "OVERLAY");
valueBlock.Text = valueBlock:CreateFontString(nil, "OVERLAY");
valueBlock.Text:SetFontObject(FontUtil:GetOutlinedFont("DUI335_ExpBarValue", 12, {0.8, 0.8, 0.8}));
valueBlock.Text:SetJustifyH("CENTER");
valueBlock.Text:SetPoint("CENTER", valueBlock, "CENTER", 0, 2);

local tooltip;      -- created on first hover


---------------------------------------------------------------------------
-- Bar state
---------------------------------------------------------------------------

local bar = {
    minVal = 0,
    maxVal = 100,
    range = 100,
    value = 0,
    width = 0,
    level = nil,
};

local function UpdateNotches()
    local width = bar.width;
    if width <= 0 then
        return
    end
    local lineWidth = 4 * GetPixelSize(frame);
    local height = BAR_HEIGHT - 2;
    local offset = width / NUM_COMPARTMENTS;
    for i = 1, #notches do
        local notch = notches[i];
        notch:SetWidth(lineWidth);
        notch:SetHeight(height);
        notch:ClearAllPoints();
        notch:SetPoint("CENTER", frame, "LEFT", i * offset, 0);
    end
end

local function SetBarWidthByPercentage(a)
    if a <= 0 then
        a = 0;
        fill:Hide();
    else
        if a > 1 then
            a = 1;
        end
        fill:Show();
        fill:SetWidth(max(bar.width * a, 0.1));
    end
    bar.progress = a;
end

local function CalculateValueRatio(value)
    return (value - bar.minVal) / bar.range
end

local function SetValue(value)
    value = Clamp(value, bar.minVal, bar.maxVal);
    bar.value = value;
    SetBarWidthByPercentage(CalculateValueRatio(value));
end

local function SetMinMaxValue(minVal, maxVal)
    bar.minVal = minVal;
    bar.maxVal = maxVal;
    bar.range = (maxVal > minVal) and (maxVal - minVal) or 1;
    SetValue(bar.value);
end

local function StopAnimation()
    bar.animating = false;
    frame:SetScript("OnUpdate", nil);
    valueBlock:Hide();
    valueBlock:SetScript("OnUpdate", nil);
end

-- Range of the level the player is in now.
local function GetRange()
    local maxXP = UnitXPMax("player");
    bar.level = UnitLevel("player");
    return 0, (maxXP and maxXP > 0) and maxXP or 1
end

local AnimFill_OnUpdate;

local function AnimateBetweenValues(fromValue, toValue)
    if toValue < fromValue then
        toValue = bar.maxVal;
    end
    bar.fromRatio = CalculateValueRatio(fromValue);
    bar.toRatio = CalculateValueRatio(toValue);
    bar.t = 0;
    bar.animating = true;
    frame:SetScript("OnUpdate", AnimFill_OnUpdate);
end

-- The animation went past the end of the bar: the new level starts empty and fills to what is left over.
local function OnOverflow()
    local newValue = bar.value - bar.maxVal;
    local minVal, maxVal = GetRange();
    SetMinMaxValue(minVal, maxVal);
    SetValue(newValue);
    AnimateBetweenValues(0, newValue);
end

AnimFill_OnUpdate = function(_, elapsed)
    bar.t = bar.t + elapsed;
    local ratio = inOutSine(bar.t, bar.fromRatio, bar.toRatio, FILL_DURATION);

    if bar.t >= FILL_DURATION then
        bar.t = 0;
        bar.animating = false;
        frame:SetScript("OnUpdate", nil);
        ratio = bar.toRatio;
    end

    if ratio > 1 then
        ratio = ratio - 1;
        OnOverflow();       -- starts the next animation
    end

    SetBarWidthByPercentage(ratio);
end

local function CrossFade_OnUpdate(self, elapsed)
    if self.t <= 1.0 then
        self.alpha = self.alpha + 10 * elapsed;
        if self.alpha > 1 then
            self.alpha = 1;
            self.t = self.t + elapsed;
        end
    else
        self.alpha = self.alpha - 1 * elapsed;
        if self.alpha <= 0 then
            self.alpha = 0;
            self:SetScript("OnUpdate", nil);
            self:Hide();
        end
    end
    self:SetAlpha(self.alpha);
end

local function AddValue(deltaValue)
    local blockWidth = bar.width * deltaValue / bar.range;

    if blockWidth > BLOCK_MIN_WIDTH then
        valueBlock:SetWidth(blockWidth);
        valueBlock:ClearAllPoints();
        valueBlock:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CalculateValueRatio(bar.value) * bar.width, BLOCK_OFFSET_Y);
        valueBlock.Text:SetText(L["Format Gained XP"]:format(deltaValue));
        valueBlock.t = 0;
        valueBlock.alpha = 0;
        valueBlock:SetAlpha(0);
        valueBlock:SetScript("OnUpdate", CrossFade_OnUpdate);
        valueBlock:Show();
    else
        valueBlock:Hide();
        valueBlock:SetScript("OnUpdate", nil);
    end

    local currentValue = bar.value;
    local newValue = currentValue + deltaValue;
    bar.value = newValue;
    AnimateBetweenValues(currentValue, newValue);
end

-- animating false: jump to the current experience. true: animate from the shown value to it.
local function Update(animating, newLevel)
    local level, currentXP, maxXP = UnitLevel("player"), UnitXP("player"), UnitXPMax("player");
    if newLevel and type(newLevel) == "number" then
        level = newLevel;
    end
    if not (currentXP and maxXP) then
        return
    end

    if animating then
        local deltaValue;
        if bar.level and level > bar.level then
            deltaValue = currentXP + bar.maxVal - bar.value;
        else
            deltaValue = currentXP - bar.value;
        end
        -- Nothing to show for no gain. A drop means the level up has not reached us yet: its event follows.
        if deltaValue > 0 then
            AddValue(deltaValue);
        end
    else
        bar.level = level;
        StopAnimation();
        SetMinMaxValue(0, maxXP > 0 and maxXP or 1);
        SetValue(currentXP);
    end
end

frame:SetScript("OnSizeChanged", function(_, width)
    bar.width = width;
    if bar.value then
        SetBarWidthByPercentage(bar.progress or CalculateValueRatio(bar.value));
    end
    UpdateNotches();
end);

-- Defined below.
local HideTooltip;

-- Ours replaces the other experience bars: only one shows. They are made invisible and click-through rather than
-- hidden, because their own code shows them again on every XP or level change. The old alpha and mouse state is
-- kept and put back, since DragonUI makes the game's bar invisible itself.
-- {global frame name, name of the child that takes the mouse (nil: the frame itself)}
local REPLACED_BARS = {
    {"MainMenuExpBar"},                 -- the game's
    {"DragonUI_XPBar", "Bar"},          -- DragonUI's
};
local savedBars = {};

local function SetOtherBarsShown(shown)
    for _, info in ipairs(REPLACED_BARS) do
        local name = info[1];
        local other = _G[name];
        if other then
            local mouseFrame = info[2] and other[info[2]] or other;
            local saved = savedBars[name];
            if shown then
                if saved then
                    other:SetAlpha(saved.alpha);
                    mouseFrame:EnableMouse(saved.mouse);
                    savedBars[name] = nil;
                end
            elseif not saved then
                savedBars[name] = {alpha = other:GetAlpha(), mouse = mouseFrame:IsMouseEnabled()};
                other:SetAlpha(0);
                mouseFrame:EnableMouse(false);
            end
        end
    end
end

frame:SetScript("OnShow", function()
    SetOtherBarsShown(false);
end);

frame:SetScript("OnHide", function()
    StopAnimation();
    HideTooltip();
    SetOtherBarsShown(true);
end);


---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function FollowCursor()
    local x, y = GetCursorPosition();
    local scale = addon.UIRoot:GetEffectiveScale();
    tooltip.frame:ClearAllPoints();
    tooltip.frame:SetPoint("BOTTOMLEFT", addon.UIRoot, "BOTTOMLEFT", x / scale + 12, y / scale + 12);
end

-- Retail anchors the tooltip to the cursor. A separate frame moves it: the bar's own OnUpdate runs the fill animation.
local cursorDriver = CreateFrame("Frame", nil, addon.UIRoot);
local function CursorDriver_OnUpdate()
    FollowCursor();
end

frame:SetScript("OnEnter", function()
    if not UnitXP("player") then
        return
    end
    tooltip = tooltip or addon.CreateTooltipFrame();
    tooltip:Hide();
    tooltip:Clear();

    local level, currentXP, maxXP = UnitLevel("player"), UnitXP("player"), UnitXPMax("player");
    local percentage = (maxXP > 0) and floor(currentXP / maxXP * 100 + 0.5) or 0;
    tooltip:AddLine(L["Format Unit Level"]:format(level), 1, 1, 1);
    tooltip:AddLine(L["Format Player XP"]:format(currentXP, maxXP, percentage), 1, 1, 1);
    local diff = maxXP - currentXP;
    if diff > 0 then
        tooltip:AddLine(L["To Next Level Label"] .. ": |cffffffff" .. BreakUpLargeNumbers(diff) .. "|r", 1, 0.82, 0);
    end
    tooltip:Show();
    FollowCursor();
    cursorDriver:SetScript("OnUpdate", CursorDriver_OnUpdate);
end);

HideTooltip = function()
    cursorDriver:SetScript("OnUpdate", nil);
    if tooltip then
        tooltip:Hide();
    end
end
frame:SetScript("OnLeave", HideTooltip);


---------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------

local ExperienceBar = {};
addon.ExperienceBar = ExperienceBar;

local controller = CreateFrame("Frame", nil, addon.UIRoot);     -- always shown: events and the fade run here
local parchmentShown = false;
local ready = false;            -- the player's experience is known (not at file load)
local fadeTarget = 0;
local fadeSpeed = 4;

local function Fade_OnUpdate(_, elapsed)
    local alpha = frame:GetAlpha();
    if fadeTarget > alpha then
        alpha = min(alpha + fadeSpeed * elapsed, 1);
    else
        alpha = max(alpha - fadeSpeed * elapsed, 0);
    end
    frame:SetAlpha(alpha);
    if alpha == fadeTarget then
        controller:SetScript("OnUpdate", nil);
        if alpha == 0 then
            frame:Hide();
        end
    end
end

-- The parchment closes at once, but the experience of the quest arrives a moment later and its animation takes
-- seconds. The bar stays for LINGER_TIME after the close, and while an animation runs, so it can play to the end.
local LINGER_TIME = 3;
local lingerLeft = 0;
local lingerDriver = CreateFrame("Frame", nil, addon.UIRoot);

local function Linger_OnUpdate(self, elapsed)
    if parchmentShown then
        return      -- the countdown starts when it closes
    end
    if bar.animating or valueBlock:IsShown() then
        lingerLeft = max(lingerLeft, 1);        -- one more second after the animation ends
    else
        lingerLeft = lingerLeft - elapsed;
    end
    if lingerLeft <= 0 then
        lingerLeft = 0;
        self:SetScript("OnUpdate", nil);
        ExperienceBar:Refresh();
    end
end

local function ShouldShow()
    return ready
        and addon.GetDBBool("ShowEXPBar")
        and (parchmentShown or lingerLeft > 0 or addon.GetDBBool("ShowEXPBarAlways"))
        and not IsCapped()
end

function ExperienceBar:Refresh()
    if ShouldShow() then
        if not frame:IsShown() then
            local width = frame:GetWidth();
            if width and width > 0 then
                bar.width = width;      -- OnSizeChanged may not have run yet
            end
            Update(false);
            frame:SetAlpha(0);
            frame:Show();
            UpdateNotches();
        end
        SetOtherBarsShown(false);       -- also catches a bar that was created after ours showed
        if fadeTarget ~= 1 then
            fadeTarget = 1;
            -- Fades in as fast as the parchment opens.
            local duration = addon.GetDBValue("OpenAnimationDuration") or 0.25;
            fadeSpeed = (duration > 0) and (1 / duration) or 1000;
            controller:SetScript("OnUpdate", Fade_OnUpdate);
        end
    elseif frame:IsShown() and fadeTarget == 1 then
        fadeTarget = 0;
        fadeSpeed = 1 / FADE_OUT_DURATION;
        controller:SetScript("OnUpdate", Fade_OnUpdate);
    end
end

function ExperienceBar:IsShown()
    return frame:IsShown()
end

controller:RegisterEvent("PLAYER_XP_UPDATE");
controller:RegisterEvent("PLAYER_LEVEL_UP");
controller:SetScript("OnEvent", function(_, event, arg1)
    if not (ready and frame:IsShown() and fadeTarget == 1) then
        return      -- the values are read again when the bar shows
    end
    if event == "PLAYER_XP_UPDATE" then
        if arg1 == nil or arg1 == "player" then
            Update(true);
        end
    elseif event == "PLAYER_LEVEL_UP" then
        Update(true, arg1);
    end
end);

CallbackRegistry:Register("PLAYER_ENTERING_WORLD", function()
    ready = true;
    ExperienceBar:Refresh();
end);

CallbackRegistry:Register("ParchmentShown", function()
    parchmentShown = true;
    lingerLeft = 0;
    lingerDriver:SetScript("OnUpdate", nil);
    ExperienceBar:Refresh();
end);

CallbackRegistry:Register("ParchmentHidden", function()
    parchmentShown = false;
    if frame:IsShown() then
        lingerLeft = LINGER_TIME;
        lingerDriver:SetScript("OnUpdate", Linger_OnUpdate);
    end
    ExperienceBar:Refresh();
end);

CallbackRegistry:Register("SettingChanged.ShowEXPBar", function()
    ExperienceBar:Refresh();
end);

CallbackRegistry:Register("SettingChanged.ShowEXPBarAlways", function()
    ExperienceBar:Refresh();
end);
