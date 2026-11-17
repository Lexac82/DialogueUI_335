local _, addon = ...;

-- Three-piece parchment background (top / middle / bottom) from the Brown theme atlas.
-- Atlas is 1024x2048; pieces are rows 0-256, 256-896, 896-1152 (see retail Code/Dialogue/DialogueUI.lua:350-358).
-- Play() grows the middle piece from a fraction of its height to full height and fades the frame in.

local ThemeUtil = addon.ThemeUtil;

local min = math.min;

local ATLAS_WIDTH = 1024;
local ATLAS_HEIGHT = 2048;
local FRAME_WIDTH = 546.13; -- same scale as the retail frame
local SCALE = FRAME_WIDTH / ATLAS_WIDTH;

local DEFAULT_DURATION = 0.5; -- seconds for both height and fade
local START_MID_RATIO = 0.1;  -- middle piece starts at this fraction of its full height

local TOP_ROWS = { 0, 256 };
local MID_ROWS = { 256, 896 };
local BOTTOM_ROWS = { 896, 1152 };

local function RowsToHeight(rows)
    return (rows[2] - rows[1]) * SCALE;
end

local function RowsToTexCoord(rows)
    return 0, 1, rows[1] / ATLAS_HEIGHT, rows[2] / ATLAS_HEIGHT;
end

local TOP_H = RowsToHeight(TOP_ROWS);
local MID_H = RowsToHeight(MID_ROWS);
local BOTTOM_H = RowsToHeight(BOTTOM_ROWS);
local FULL_H = TOP_H + MID_H + BOTTOM_H;
local START_H = TOP_H + BOTTOM_H + MID_H * START_MID_RATIO;

local ParchmentBackground = {};
ParchmentBackground.__index = ParchmentBackground;

function ParchmentBackground:OnPlayUpdate(elapsed)
    self.elapsed = self.elapsed + elapsed;

    local duration = self.duration;
    local progress = (duration > 0) and min(self.elapsed / duration, 1) or 1;

    local frame = self.frame;
    frame:SetHeight(START_H + (FULL_H - START_H) * progress);
    frame:SetAlpha(progress);

    if progress >= 1 then
        frame:SetScript("OnUpdate", nil);
    end
end

function ParchmentBackground:Play(duration)
    local frame = self.frame;
    self.duration = duration or DEFAULT_DURATION;
    self.elapsed = 0;

    frame:SetHeight(START_H);
    frame:SetAlpha(0);
    frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnPlayUpdate(elapsed);
    end);
    frame:Show();
end

-- Plays the animation only if it is not already visible, so repeated dialogue events don't restart it.
function ParchmentBackground:Show(duration)
    if self.frame:IsShown() then
        return;
    end
    self:Play(duration);
end

function ParchmentBackground:Hide()
    self.frame:SetScript("OnUpdate", nil);
    self.frame:Hide();
end

local function CreateParchmentBackground(parent)
    local self = setmetatable({}, ParchmentBackground);
    self.elapsed = 0;
    self.duration = DEFAULT_DURATION;

    local file = ThemeUtil:GetTextureFile("Parchment.blp");

    local frame = CreateFrame("Frame", nil, parent or UIParent);
    frame:SetWidth(FRAME_WIDTH);
    frame:SetHeight(START_H);
    frame:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0);
    frame:SetAlpha(0);
    frame:Hide(); -- frames are shown by default in CreateFrame
    self.frame = frame;

    -- Top and bottom keep a fixed height. The middle stretches between them,
    -- so changing the frame height only changes the middle piece.
    local top = frame:CreateTexture(nil, "BACKGROUND");
    top:SetTexture(file);
    top:SetTexCoord(RowsToTexCoord(TOP_ROWS));
    top:SetWidth(FRAME_WIDTH);
    top:SetHeight(TOP_H);
    top:SetPoint("TOP", frame, "TOP", 0, 0);

    local bottom = frame:CreateTexture(nil, "BACKGROUND");
    bottom:SetTexture(file);
    bottom:SetTexCoord(RowsToTexCoord(BOTTOM_ROWS));
    bottom:SetWidth(FRAME_WIDTH);
    bottom:SetHeight(BOTTOM_H);
    bottom:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0);

    local middle = frame:CreateTexture(nil, "BACKGROUND");
    middle:SetTexture(file);
    middle:SetTexCoord(RowsToTexCoord(MID_ROWS));
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0);
    middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0);

    return self;
end

addon.CreateParchmentBackground = CreateParchmentBackground;
