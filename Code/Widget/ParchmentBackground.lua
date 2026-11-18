local _, addon = ...;

local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;

local min = math.min;

local ATLAS_WIDTH = 1024;
local ATLAS_HEIGHT = 2048;
local FRAME_SIZE_MULTIPLIER = 1.1; -- retail default
local FRAME_WIDTH = 546.13 * FRAME_SIZE_MULTIPLIER;
local SCALE = FRAME_WIDTH / ATLAS_WIDTH;

local DEFAULT_DURATION = 0.5; -- seconds for both height and fade
local START_MID_RATIO = 0.1;  -- middle piece starts at this fraction of its full height

local TOP_ROWS = { 0, 256 };
local MID_ROWS = { 256, 896 };
local BOTTOM_ROWS = { 896, 1152 };

local DIVIDER_COLS = { 0, 672 };
local DIVIDER_ROWS = { 1160, 1256 };

local function RowsToHeight(rows)
    return (rows[2] - rows[1]) * SCALE;
end

local function RowsToTexCoord(rows)
    return 0, 1, rows[1] / ATLAS_HEIGHT, rows[2] / ATLAS_HEIGHT;
end

local function RectToTexCoord(cols, rows)
    return cols[1] / ATLAS_WIDTH, cols[2] / ATLAS_WIDTH, rows[1] / ATLAS_HEIGHT, rows[2] / ATLAS_HEIGHT;
end

local TOP_H = RowsToHeight(TOP_ROWS);
local MID_H = RowsToHeight(MID_ROWS);
local BOTTOM_H = RowsToHeight(BOTTOM_ROWS);

local CAP_OVERHANG = (TOP_H + BOTTOM_H) / 2;
local FULL_H = MID_H + CAP_OVERHANG;
local START_H = CAP_OVERHANG + MID_H * START_MID_RATIO;

local DIVIDER_W = (DIVIDER_COLS[2] - DIVIDER_COLS[1]) * SCALE;
local DIVIDER_H = RowsToHeight(DIVIDER_ROWS);
local HEADER_OFFSET_Y = -28 * FRAME_SIZE_MULTIPLIER;
local PADDING_H = 26 * FRAME_SIZE_MULTIPLIER;

local HEADER_PORTRAIT_SIZE = 34 * FRAME_SIZE_MULTIPLIER;
local HEADER_PORTRAIT_X = 23 * FRAME_SIZE_MULTIPLIER;
local HEADER_PORTRAIT_Y = -23 * FRAME_SIZE_MULTIPLIER;

local FOOTER_COLS = { 0, 736 };
local FOOTER_ROWS = { 1408, 1472 };
local FOOTER_W = (FOOTER_COLS[2] - FOOTER_COLS[1]) * SCALE;
local FOOTER_H = RowsToHeight(FOOTER_ROWS);
local FOOTER_OFFSET_Y = 96; -- retail default; depends on button height once buttons exist

local TOPLIGHT_COLS = { 0, 672 };
local TOPLIGHT_ROWS = { 1336, 1400 };
local TOPLIGHT_W = (TOPLIGHT_COLS[2] - TOPLIGHT_COLS[1]) * SCALE;
local TOPLIGHT_H = (TOPLIGHT_ROWS[2] - TOPLIGHT_ROWS[1]) * SCALE;
local TOPLIGHT_ALPHA = 0.06;
local TOPLIGHT_OFFSET_Y = -2 * FRAME_SIZE_MULTIPLIER;

local TITLE_FONT_HEIGHT = 18 * FRAME_SIZE_MULTIPLIER;
local TITLE_LEFT_X = 53 * FRAME_SIZE_MULTIPLIER;
local TITLE_RIGHT_X = -8 * FRAME_SIZE_MULTIPLIER;
local TITLE_Y = 2 * FRAME_SIZE_MULTIPLIER;

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

-- Header portrait: the NPC in the conversation, or the player as a fallback (same as retail).
-- An explicit unit can be passed (e.g. "target" for testing).
function ParchmentBackground:UpdatePortrait(unit)
    unit = unit or (UnitExists("npc") and "npc" or "player");
    SetPortraitTexture(self.FrontFrame.Header.Portrait, unit);
end

function ParchmentBackground:SetTitle(text)
    self.FrontFrame.Header.Title:SetText(text or "");
end

function ParchmentBackground:SetFooterOffset(y)
    local divider = self.FrontFrame.FooterDivider;
    divider:ClearAllPoints();
    divider:SetPoint("CENTER", self.FrontFrame, "BOTTOM", 0, y);
    self.QuestText:SetFooterOffset(y);
end

-- Quest body and objectives. Objectives get a sub-header when present.
function ParchmentBackground:SetQuestText(body, objective, page)
    self.QuestText:SetQuestText(body, objective, page);
end

-- Reward choice (see RewardLayout.lua). GetRewardChoice: choice index for GetQuestReward, 0 when there is
-- nothing to choose, nil while the player has not chosen yet. The future Complete button disables itself on nil.
function ParchmentBackground:GetRewardChoice()
    return self.QuestText.rewards:GetChoiceIndex()
end

-- fn(choiceIndex) is called when the player picks a reward.
function ParchmentBackground:SetRewardChoiceHandler(fn)
    self.QuestText.rewards.onChoiceChanged = fn;
end

-- For the Complete button: clicked while no reward is chosen -> flash the choices.
function ParchmentBackground:FlashRewardChoices()
    self.QuestText.rewards:FlashChoices();
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

    local top = frame:CreateTexture(nil, "BACKGROUND");
    top:SetTexture(file);
    top:SetTexCoord(RowsToTexCoord(TOP_ROWS));
    top:SetWidth(FRAME_WIDTH);
    top:SetHeight(TOP_H);
    top:SetPoint("CENTER", frame, "TOP", 0, 0);

    local bottom = frame:CreateTexture(nil, "BACKGROUND");
    bottom:SetTexture(file);
    bottom:SetTexCoord(RowsToTexCoord(BOTTOM_ROWS));
    bottom:SetWidth(FRAME_WIDTH);
    bottom:SetHeight(BOTTOM_H);
    bottom:SetPoint("CENTER", frame, "BOTTOM", 0, 0);

    local middle = frame:CreateTexture(nil, "BACKGROUND");
    middle:SetTexture(file);
    middle:SetTexCoord(RowsToTexCoord(MID_ROWS));
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0);
    middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0);

    local frontFrame = CreateFrame("Frame", nil, frame);
    frontFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING_H, 0);
    frontFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PADDING_H, 0);
    self.FrontFrame = frontFrame;

    -- Created before the footer so SetFooterOffset can reach it.
    self.QuestText = addon.CreateQuestTextLayout(frame, FRAME_WIDTH, FRAME_SIZE_MULTIPLIER, FOOTER_OFFSET_Y, FULL_H);

    local header = CreateFrame("Frame", nil, frontFrame);
    header:SetWidth(DIVIDER_W);
    header:SetHeight(DIVIDER_H);
    header:SetPoint("TOP", frontFrame, "TOP", 0, HEADER_OFFSET_Y);
    frontFrame.Header = header;

    local divider = header:CreateTexture(nil, "ARTWORK");
    divider:SetTexture(file);
    divider:SetTexCoord(RectToTexCoord(DIVIDER_COLS, DIVIDER_ROWS));
    divider:SetWidth(DIVIDER_W);
    divider:SetHeight(DIVIDER_H);
    divider:SetPoint("TOP", header, "TOP", 0, 0);
    header.Divider = divider;

    local topLight = header:CreateTexture(nil, "ARTWORK");
    topLight:SetTexture(file);
    topLight:SetTexCoord(RectToTexCoord(TOPLIGHT_COLS, TOPLIGHT_ROWS));
    topLight:SetBlendMode("ADD");
    topLight:SetAlpha(TOPLIGHT_ALPHA);
    topLight:SetWidth(TOPLIGHT_W);
    topLight:SetHeight(TOPLIGHT_H);
    topLight:SetPoint("CENTER", divider, "CENTER", 0, TOPLIGHT_OFFSET_Y);
    header.TopLight = topLight;

    local title = header:CreateFontString(nil, "OVERLAY");
    title:SetFontObject(FontUtil:GetQuestTitleFont(TITLE_FONT_HEIGHT));
    title:SetJustifyH("LEFT");
    title:SetJustifyV("BOTTOM");
    title:SetPoint("LEFT", header, "LEFT", TITLE_LEFT_X, TITLE_Y);
    title:SetPoint("RIGHT", header, "RIGHT", TITLE_RIGHT_X, TITLE_Y);
    header.Title = title;

    local footerDivider = frontFrame:CreateTexture(nil, "ARTWORK");
    footerDivider:SetTexture(file);
    footerDivider:SetTexCoord(RectToTexCoord(FOOTER_COLS, FOOTER_ROWS));
    footerDivider:SetWidth(FOOTER_W);
    footerDivider:SetHeight(FOOTER_H);
    frontFrame.FooterDivider = footerDivider;
    self:SetFooterOffset(FOOTER_OFFSET_Y);
    -- Fades with the scroll position; hidden while the text does not scroll.
    self.QuestText:SetFooterDivider(footerDivider);

    local portrait = header:CreateTexture(nil, "ARTWORK");
    portrait:SetWidth(HEADER_PORTRAIT_SIZE);
    portrait:SetHeight(HEADER_PORTRAIT_SIZE);
    portrait:SetPoint("CENTER", header, "TOPLEFT", HEADER_PORTRAIT_X, HEADER_PORTRAIT_Y);
    portrait:SetVertexColor(1, 0.9, 0.78); -- light theme tint, as retail
    header.Portrait = portrait;

    return self;
end

addon.CreateParchmentBackground = CreateParchmentBackground;
