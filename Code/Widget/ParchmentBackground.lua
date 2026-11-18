local _, addon = ...;

local CallbackRegistry = addon.CallbackRegistry;
local GetDBValue = addon.GetDBValue;
local SetDBValue = addon.SetDBValue;
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;

local min = math.min;

local ATLAS_WIDTH = 1024;
local ATLAS_HEIGHT = 2048;
local BASE_WIDTH = 546.13;      -- frame width at multiplier 1 (retail: 0.85 x height, see docs/SettingsMenu.md)

local DEFAULT_DURATION = 0.35; -- seconds for both height and fade
local START_MID_RATIO = 0.1;  -- middle piece starts at this fraction of its full height

local TOP_ROWS = { 0, 256 };
local MID_ROWS = { 256, 896 };
local BOTTOM_ROWS = { 896, 1152 };

local DIVIDER_COLS = { 0, 672 };
local DIVIDER_ROWS = { 1160, 1256 };

local FOOTER_COLS = { 0, 736 };
local FOOTER_ROWS = { 1408, 1472 };
local FOOTER_OFFSET_Y = 96; -- first value only; the footer buttons set the real one (button height + padding)

-- Divider shown instead of the Header on the first-contact page (retail HeaderDivider).
local GOSSIP_DIVIDER_COLS = { 0, 736 };
local GOSSIP_DIVIDER_ROWS = { 1480, 1544 };
local TOPLIGHT_COLS = { 0, 672 };
local TOPLIGHT_ROWS = { 1336, 1400 };
local TOPLIGHT_ALPHA = 0.06;

-- Completed-quest checkmark (retail's WarbandCompleteAlert icon), top right of the header.
local CHECK_COLS = { 736, 832 };
local CHECK_ROWS = { 1160, 1256 };

local function RowsToTexCoord(rows)
    return 0, 1, rows[1] / ATLAS_HEIGHT, rows[2] / ATLAS_HEIGHT;
end

local function RectToTexCoord(cols, rows)
    return cols[1] / ATLAS_WIDTH, cols[2] / ATLAS_WIDTH, rows[1] / ATLAS_HEIGHT, rows[2] / ATLAS_HEIGHT;
end

-- Every size and offset of the parchment for one frame size multiplier m. Atlas pieces are scaled by width / 1024,
-- retail's own sizes (paddings, offsets) by m. Medium (1.1) is the look the layout was made for.
local function ComputeMetrics(m)
    local width = BASE_WIDTH * m;
    local scale = width / ATLAS_WIDTH;
    local M = { multiplier = m, width = width };

    M.topH = (TOP_ROWS[2] - TOP_ROWS[1]) * scale;
    M.midH = (MID_ROWS[2] - MID_ROWS[1]) * scale;
    M.bottomH = (BOTTOM_ROWS[2] - BOTTOM_ROWS[1]) * scale;
    M.capOverhang = (M.topH + M.bottomH) / 2;
    M.fullH = M.midH + M.capOverhang;
    M.startH = M.capOverhang + M.midH * START_MID_RATIO;

    M.dividerW = (DIVIDER_COLS[2] - DIVIDER_COLS[1]) * scale;
    M.dividerH = (DIVIDER_ROWS[2] - DIVIDER_ROWS[1]) * scale;
    M.headerOffsetY = -28 * m;
    M.paddingH = 26 * m;
    M.paddingBottom = 36 * m;           -- retail PADDING_BOTTOM: buttons sit this far above the frame bottom

    M.portraitSize = 34 * m;
    M.portraitX = 23 * m;
    M.portraitY = -23 * m;

    M.footerW = (FOOTER_COLS[2] - FOOTER_COLS[1]) * scale;
    M.footerH = (FOOTER_ROWS[2] - FOOTER_ROWS[1]) * scale;

    M.gossipDividerW = (GOSSIP_DIVIDER_COLS[2] - GOSSIP_DIVIDER_COLS[1]) * scale;
    M.gossipDividerH = (GOSSIP_DIVIDER_ROWS[2] - GOSSIP_DIVIDER_ROWS[1]) * scale;
    M.gossipDividerY = -42 * m;
    M.topLightW = (TOPLIGHT_COLS[2] - TOPLIGHT_COLS[1]) * scale;
    M.topLightH = (TOPLIGHT_ROWS[2] - TOPLIGHT_ROWS[1]) * scale;
    M.topLightY = -2 * m;

    M.titleFontHeight = 18 * m;
    M.titleLeftX = 53 * m;
    M.titleRightX = -8 * m;
    M.titleY = 2 * m;
    M.titleRightXWithIcon = -56 * m;

    M.checkSize = 44 * m;
    M.checkX = -25 * m;
    M.checkY = -20 * m;

    -- The atlas has transparent margins, so the visible paper is narrower than the frame. The text box and the
    -- footer buttons line up with the header divider instead of retail's 26 x multiplier inset.
    M.footerInset = (width - M.dividerW) / 2;
    return M
end

local ParchmentBackground = {};
ParchmentBackground.__index = ParchmentBackground;

function ParchmentBackground:OnPlayUpdate(elapsed)
    self.elapsed = self.elapsed + elapsed;

    local duration = self.duration;
    local progress = (duration > 0) and min(self.elapsed / duration, 1) or 1;

    local frame = self.frame;
    local M = self.metrics;
    frame:SetHeight(M.startH + (M.fullH - M.startH) * progress);
    frame:SetAlpha(progress);

    if progress >= 1 then
        self.playing = false;
        frame:SetScript("OnUpdate", nil);
    end
end

function ParchmentBackground:Play(duration)
    local frame = self.frame;
    self.duration = duration or DEFAULT_DURATION;
    self.elapsed = 0;
    self.playing = true;

    frame:SetHeight(self.metrics.startH);
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

-- Checkmark in the header for a quest that is being turned in (QUEST_COMPLETE). Moves the title clear of it.
function ParchmentBackground:SetCompleteIcon(shown)
    local header = self.FrontFrame.Header;
    local title = header.Title;
    self.completeIconShown = shown and true or false;
    local M = self.metrics;
    local rightX = shown and M.titleRightXWithIcon or M.titleRightX;
    title:ClearAllPoints();
    title:SetPoint("LEFT", header, "LEFT", M.titleLeftX, M.titleY);
    title:SetPoint("RIGHT", header, "RIGHT", rightX, M.titleY);
    if shown then
        header.CompleteIcon:Show();
    else
        header.CompleteIcon:Hide();
    end
end

-- Header (title, portrait, pills) on quest pages, divider only on the first-contact page.
function ParchmentBackground:SetListMode(isList)
    local frontFrame = self.FrontFrame;
    if isList then
        frontFrame.Header:Hide();
        frontFrame.HeaderDivider:Show();
    else
        frontFrame.Header:Show();
        frontFrame.HeaderDivider:Hide();
    end
end

-- First-contact page: greeting text and the quest / option rows (GossipDataProvider:Read). Replaces SetTitle,
-- SetTags, SetQuestText and SetPage for GOSSIP_SHOW and QUEST_GREETING.
function ParchmentBackground:SetListPage(event, page)
    self:SetCompleteIcon(false);
    self:SetTags(nil);
    self:SetListMode(true);
    self.QuestText:SetListPage(page);
    self.Footer:SetPage(event, page);
    self.Footer:SetRowKeys(self.QuestText.rowNames);
end
function ParchmentBackground:Hide()
    self:SetCompleteIcon(false);
    self.playing = false;
    self.frame:SetScript("OnUpdate", nil);
    self.frame:Hide();
end

-- fn() is called when the player closes the conversation (Goodbye, Cancel, Esc, right click). It should close
-- the game side (CloseQuest / CloseGossip). The parchment hides itself afterwards.
function ParchmentBackground:SetCloseHandler(fn)
    self.onClose = fn;
end

function ParchmentBackground:RequestClose()
    if self.onClose then
        self.onClose();
    end
    self:Hide();
end

-- Sets the buttons for the page: event is the opening event (QUEST_DETAIL, ...), page is QuestData:GetPage(event).
-- Call after SetQuestText, because the Complete button looks at the reward choice.
function ParchmentBackground:SetPage(event, page)
    self.Footer:SetPage(event, page);
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

-- tags: page.tags from QuestData (nil or empty clears the pills, e.g. on gossip pages).
function ParchmentBackground:SetTags(tags)
    self.HeaderTags:SetTags(tags);
end

function ParchmentBackground:SetFooterOffset(y)
    local divider = self.FrontFrame.FooterDivider;
    divider:ClearAllPoints();
    divider:SetPoint("CENTER", self.FrontFrame, "BOTTOM", 0, y);
    self.QuestText:SetFooterOffset(y);
end

-- Quest body and objectives. Objectives get a sub-header when present.
function ParchmentBackground:SetQuestText(body, objective, page)
    self:SetListMode(false);
    self.QuestText:SetQuestText(body, objective, page);
end

-- Reward choice (see RewardLayout.lua). GetRewardChoice: choice index for GetQuestReward, 0 when there is
-- nothing to choose, nil while the player has not chosen yet. The future Complete button disables itself on nil.
function ParchmentBackground:GetRewardChoice()
    return self.QuestText.rewards:GetChoiceIndex()
end

-- fn(choiceIndex) is called when the player picks a reward.
function ParchmentBackground:SetRewardChoiceHandler(fn)
    self.userChoiceHandler = fn;
end

-- For the Complete button: clicked while no reward is chosen -> flash the choices.
function ParchmentBackground:FlashRewardChoices()
    self.QuestText.rewards:FlashChoices();
end

-- Puts the frame back where the player left it (UIParent offsets), else the default CENTER.
local function RestorePosition(frame)
    local pos = GetDBValue("ParchmentPosition");
    if pos and pos.point and pos.x and pos.y then
        frame:ClearAllPoints();
        frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y);
    end
end

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1);
    if point then
        SetDBValue("ParchmentPosition", { point = point, relativePoint = relativePoint, x = x, y = y });
    end
end

-- Left-drag on the paper moves the whole parchment. Other mouse frames on it (scroll area) forward the drag.
local function MakeMovable(frame, ...)
    frame:SetMovable(true);
    frame:SetClampedToScreen(true);
    frame:SetUserPlaced(false); -- we save the position ourselves
    local function OnDragStart()
        frame:StartMoving();
    end
    local function OnDragStop()
        frame:StopMovingOrSizing();
        SavePosition(frame);
    end
    local function EnableDrag(target)
        target:EnableMouse(true);
        target:RegisterForDrag("LeftButton");
        target:SetScript("OnDragStart", OnDragStart);
        target:SetScript("OnDragStop", OnDragStop);
    end
    EnableDrag(frame);
    for i = 1, select("#", ...) do
        EnableDrag((select(i, ...)));
    end
end
-- Resizes and re-anchors every part for the current frame size. The open page is not laid out again here
-- (DialogueUI.lua does that after this). Called at creation and from "FrameSizeChanged".
function ParchmentBackground:ApplySize()
    local M = ComputeMetrics(addon.FrameSize:GetMultiplier());
    self.metrics = M;

    local frame = self.frame;
    frame:SetWidth(M.width);
    if not self.playing then
        frame:SetHeight(M.fullH);       -- while the intro runs, OnPlayUpdate follows the new heights
    end

    local top, bottom = self.top, self.bottom;
    top:SetWidth(M.width);
    top:SetHeight(M.topH);
    bottom:SetWidth(M.width);
    bottom:SetHeight(M.bottomH);

    local frontFrame = self.FrontFrame;
    frontFrame:ClearAllPoints();
    frontFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", M.paddingH, 0);
    frontFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -M.paddingH, 0);

    local header = frontFrame.Header;
    header:SetWidth(M.dividerW);
    header:SetHeight(M.dividerH);
    header:ClearAllPoints();
    header:SetPoint("TOP", frontFrame, "TOP", 0, M.headerOffsetY);

    local divider = header.Divider;
    divider:SetWidth(M.dividerW);
    divider:SetHeight(M.dividerH);

    local topLight = header.TopLight;
    topLight:SetWidth(M.topLightW);
    topLight:SetHeight(M.topLightH);
    topLight:ClearAllPoints();
    topLight:SetPoint("CENTER", divider, "CENTER", 0, M.topLightY);

    FontUtil:SetQuestTitleFontHeight(M.titleFontHeight);
    self:SetCompleteIcon(self.completeIconShown);       -- title anchors

    local checkIcon = header.CompleteIcon;
    checkIcon:SetWidth(M.checkSize);
    checkIcon:SetHeight(M.checkSize);
    checkIcon:ClearAllPoints();
    checkIcon:SetPoint("CENTER", header, "TOPRIGHT", M.checkX, M.checkY);

    local portrait = header.Portrait;
    portrait:SetWidth(M.portraitSize);
    portrait:SetHeight(M.portraitSize);
    portrait:ClearAllPoints();
    portrait:SetPoint("CENTER", header, "TOPLEFT", M.portraitX, M.portraitY);

    local gossipDivider = frontFrame.HeaderDivider;
    gossipDivider:SetWidth(M.gossipDividerW);
    gossipDivider:SetHeight(M.gossipDividerH);
    gossipDivider:ClearAllPoints();
    gossipDivider:SetPoint("CENTER", frontFrame, "TOP", 0, M.gossipDividerY);

    local footerDivider = frontFrame.FooterDivider;
    footerDivider:SetWidth(M.footerW);
    footerDivider:SetHeight(M.footerH);

    -- Footer first: its button height and padding decide the footer offset the text box needs.
    self.Footer:SetSize(M.width, M.footerInset, M.paddingBottom);
    self.QuestText:SetSize(M.width, M.multiplier, M.fullH, M.footerInset);
    self:SetFooterOffset(self.Footer:GetFooterOffset());
end

local function CreateParchmentBackground(parent)
    local self = setmetatable({}, ParchmentBackground);
    self.elapsed = 0;
    self.duration = DEFAULT_DURATION;
    self.playing = false;
    self.completeIconShown = false;

    local M = ComputeMetrics(addon.FrameSize:GetMultiplier());
    self.metrics = M;

    local frame = CreateFrame("Frame", nil, parent or UIParent);
    frame:SetWidth(M.width);
    frame:SetHeight(M.startH);
    frame:SetPoint("CENTER", parent or UIParent, "CENTER", 0, 0);
    frame:SetAlpha(0);
    frame:Hide(); -- frames are shown by default in CreateFrame
    self.frame = frame;

    local top = frame:CreateTexture(nil, "BACKGROUND");
    ThemeUtil:BindTexture(top, "Parchment.blp");
    top:SetTexCoord(RowsToTexCoord(TOP_ROWS));
    top:SetPoint("CENTER", frame, "TOP", 0, 0);
    self.top = top;

    local bottom = frame:CreateTexture(nil, "BACKGROUND");
    ThemeUtil:BindTexture(bottom, "Parchment.blp");
    bottom:SetTexCoord(RowsToTexCoord(BOTTOM_ROWS));
    bottom:SetPoint("CENTER", frame, "BOTTOM", 0, 0);
    self.bottom = bottom;

    local middle = frame:CreateTexture(nil, "BACKGROUND");
    ThemeUtil:BindTexture(middle, "Parchment.blp");
    middle:SetTexCoord(RowsToTexCoord(MID_ROWS));
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0);
    middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0);

    local frontFrame = CreateFrame("Frame", nil, frame);
    self.FrontFrame = frontFrame;

    -- Created before the footer so SetFooterOffset can reach it.
    self.QuestText = addon.CreateQuestTextLayout(frame, M.width, M.multiplier, FOOTER_OFFSET_Y, M.fullH, M.footerInset);
    self.QuestText.owner = self;

    -- Saved variables are loaded after this file runs, so the saved position is only readable once the DB is ready.
    CallbackRegistry:Register("ADDON_LOADED", function()
        RestorePosition(frame);
    end);
    MakeMovable(frame, self.QuestText.ScrollArea);

    local header = CreateFrame("Frame", nil, frontFrame);
    frontFrame.Header = header;

    local divider = header:CreateTexture(nil, "ARTWORK");
    ThemeUtil:BindTexture(divider, "Parchment.blp");
    divider:SetTexCoord(RectToTexCoord(DIVIDER_COLS, DIVIDER_ROWS));
    divider:SetPoint("TOP", header, "TOP", 0, 0);
    header.Divider = divider;

    local topLight = header:CreateTexture(nil, "ARTWORK");
    ThemeUtil:BindTexture(topLight, "Parchment.blp");
    topLight:SetTexCoord(RectToTexCoord(TOPLIGHT_COLS, TOPLIGHT_ROWS));
    topLight:SetBlendMode("ADD");
    topLight:SetAlpha(TOPLIGHT_ALPHA);
    header.TopLight = topLight;

    local title = header:CreateFontString(nil, "OVERLAY");
    title:SetFontObject(FontUtil:GetQuestTitleFont(M.titleFontHeight));
    title:SetJustifyH("LEFT");
    title:SetJustifyV("BOTTOM");
    header.Title = title;

    -- Quest type pills (Quest / Daily / Weekly, Dungeon / Raid ...) above the title.
    self.HeaderTags = addon.CreateHeaderTags(header, title);

    local checkIcon = header:CreateTexture(nil, "ARTWORK");
    ThemeUtil:BindTexture(checkIcon, "Parchment.blp");
    checkIcon:SetTexCoord(RectToTexCoord(CHECK_COLS, CHECK_ROWS));
    checkIcon:Hide();
    header.CompleteIcon = checkIcon;

    local gossipDivider = frontFrame:CreateTexture(nil, "ARTWORK");
    ThemeUtil:BindTexture(gossipDivider, "Parchment.blp");
    gossipDivider:SetTexCoord(RectToTexCoord(GOSSIP_DIVIDER_COLS, GOSSIP_DIVIDER_ROWS));
    gossipDivider:Hide();
    frontFrame.HeaderDivider = gossipDivider;
    local footerDivider = frontFrame:CreateTexture(nil, "ARTWORK");
    ThemeUtil:BindTexture(footerDivider, "Parchment.blp");
    footerDivider:SetTexCoord(RectToTexCoord(FOOTER_COLS, FOOTER_ROWS));
    frontFrame.FooterDivider = footerDivider;
    self:SetFooterOffset(FOOTER_OFFSET_Y);
    -- Fades with the scroll position; hidden while the text does not scroll.
    self.QuestText:SetFooterDivider(footerDivider);

    -- Footer buttons. Their height decides the footer offset (retail: button height + padding + 2 gaps).
    self.Footer = addon.CreateFooterButtons(frame, self, M.width, M.footerInset, M.paddingBottom);
    self:SetFooterOffset(self.Footer:GetFooterOffset());
    self.QuestText.rewards.onChoiceChanged = function(index)
        self.Footer:OnRewardChoiceChanged();
        if self.userChoiceHandler then
            self.userChoiceHandler(index);
        end
    end;
    frame:SetScript("OnHide", function()
        self.Footer:ClearKeys();
    end);

    local portrait = header:CreateTexture(nil, "ARTWORK");
    header.Portrait = portrait;
    -- Warm tint on the Brown theme, none on Dark (as retail).
    local function TintPortrait()
        if ThemeUtil:IsDarkMode() then
            portrait:SetVertexColor(1, 1, 1);
        else
            portrait:SetVertexColor(1, 0.9, 0.78);
        end
    end
    TintPortrait();
    CallbackRegistry:Register("ThemeChanged", TintPortrait);

    self:ApplySize();
    CallbackRegistry:Register("FrameSizeChanged", function()
        self:ApplySize();
    end);

    return self;
end

addon.CreateParchmentBackground = CreateParchmentBackground;
