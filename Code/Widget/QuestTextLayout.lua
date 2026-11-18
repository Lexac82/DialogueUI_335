local _, addon = ...;

-- Quest description (body + objectives) inside the parchment.
-- Port of retail's FormatParagraph, AcquireAndSetSubHeader and UseQuestLayout.
-- Scrolling: ScrollArea is a ScrollFrame (SmoothScrollFrame.lua), ContentFrame is its scroll child.

local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local MathUtil = addon.MathUtil;
local TextUtil = addon.TextUtil;

local Round = MathUtil.Round;
local SplitParagraph = TextUtil.SplitParagraph;

local CreateFrame = CreateFrame;

-- Header divider width before scaling (ParchmentBackground.lua DIVIDER_COLS).
local DIVIDER_BASE_WIDTH = 358;

-- Unscaled values, same as retail's DialogueUI.lua:41-44.
local FONT_SIZE = 12;                               -- DUIFontFamily_Serif_12
local TEXT_SPACING = FONT_SIZE * 0.35;              -- line spacing
local PARAGRAPH_SPACING = 4 * TEXT_SPACING;

local SUBHEADER_PADDING_H = 8;
local SUBHEADER_PADDING_V = 4;
local SUBHEADER_HEIGHT = 12 + 2 * SUBHEADER_PADDING_V;
local SUBHEADER_SIZE = SUBHEADER_HEIGHT + SUBHEADER_PADDING_V + TEXT_SPACING;
local SUBHEADER_TEX_WIDTH = 128;                    -- SubHeaderBackground.blp
local SUBHEADER_CAP = 8;                            -- left/right cap width in the texture
local SUBHEADER_TEX_NAME = "SubHeaderBackground.blp";

local PARAGRAPH_FONT_NAME = "DUI335_Quest_Paragraph";
local SUBHEADER_FONT_NAME = "DUI335_Quest_SubHeader";
local SUBHEADER_LABEL = "Objectives";               -- retail uses OBJECTIVES_LABEL, not in wow-docs

-- Smooth reveal, like Blizzard's quest frame. Skipped when "Instant Quest Text" is on.
local INSTANT_TEXT_CVAR = "questFadingDisable";        -- UNVERIFIED name: not in wow-docs
local REVEAL_CPS = 40;                                  -- characters per second
local REVEAL_GRADIENT = 30;                             -- soft edge width in pixels
local REVEAL_TAIL = 5;                                  -- extra characters so the last ones fully fade in (~30 px)

local pcall = pcall;
local GetCVarBool = GetCVarBool;
local strlen = string.len;

local function IsInstantText()
    -- GetCVarBool raises an error for an unknown CVar, so a wrong name falls back to the fade.
    local ok, value = pcall(GetCVarBool, INSTANT_TEXT_CVAR);
    return ok and value and true or false
end

local QuestTextLayout = {};
QuestTextLayout.__index = QuestTextLayout;

function QuestTextLayout:StopReveal()
    self.revealFrame:SetScript("OnUpdate", nil);
    local items = self.revealItems;
    for i = 1, #items do
        local item = items[i];
        if item.fs then
            item.fs:SetAlphaGradient(0, 0);     -- length 0 restores full opacity
        end
        item.region:Show();
    end
end

-- Reveals paragraphs and sub-headers one after another, in layout order.
function QuestTextLayout:StartReveal()
    local items = self.revealItems;
    if #items == 0 or IsInstantText() then
        self:StopReveal();
        return
    end

    for i = 1, #items do
        items[i].region:Hide();
    end

    local index, progress = 0, 0;

    -- Moves to the next item. Returns false when none are left.
    local function Advance()
        index = index + 1;
        progress = 0;
        local item = items[index];
        if not item then
            return false
        end
        -- Gradient first, then show, so the text never appears fully opaque for a frame.
        if item.fs then
            item.fs:SetAlphaGradient(0, REVEAL_GRADIENT);
        end
        item.region:Show();
        return true
    end

    Advance();

    -- Own frame: the scroll area's OnUpdate belongs to the scroll easing.
    self.revealFrame:SetScript("OnUpdate", function(frame, elapsed)
        progress = progress + elapsed * REVEAL_CPS;
        local item = items[index];
        while item do
            if item.fs and progress < item.length + REVEAL_TAIL then
                item.fs:SetAlphaGradient(progress, REVEAL_GRADIENT);
                return
            end
            -- Finished (or a sub-header, which has no text to sweep): restore and move on.
            if item.fs then
                item.fs:SetAlphaGradient(0, 0);
            end
            if not Advance() then
                frame:SetScript("OnUpdate", nil);
                return
            end
            item = items[index];
        end
    end);
end

-- Top of the text box: below the header on quest pages, below the divider on the first-contact page.
function QuestTextLayout:SetScrollTop(y)
    if self.scrollTop ~= y then
        self.scrollTop = y;
        self:SetFooterOffset(self.footerOffset);
    end
end

-- Re-anchors the scroll area between the header and the footer.
-- The scroll area is the text box: inset paddingH on the left and right, like CSS padding.
function QuestTextLayout:SetFooterOffset(y)
    self.footerOffset = y;
    local scrollArea = self.ScrollArea;
    scrollArea:ClearAllPoints();
    scrollArea:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.paddingLeft, -self.scrollTop);
    scrollArea:SetPoint("BOTTOMRIGHT", self.parent, "BOTTOMRIGHT", -self.paddingRight, y);
    if self.contentHeight > 0 then
        self:UpdateScrollRange();
    end
end

-- The divider whose alpha follows the scroll position (see SmoothScrollFrame.lua).
function QuestTextLayout:SetFooterDivider(texture)
    self.ScrollArea.footerDivider = texture;
    self.ScrollArea:UpdateDivider(self.ScrollArea.value);
end

-- Port of retail's SetScrollRange (DialogueUI.lua:955).
-- The view height comes from the final parchment height: the real frame height is animated.
function QuestTextLayout:UpdateScrollRange()
    local viewHeight = self.fullHeight - self.scrollTop - self.footerOffset;
    local range = self.contentHeight - viewHeight + PARAGRAPH_SPACING;

    if range > 0 then
        if range < 12 then
            range = 12;
        end
        range = Round(range + 36);
    else
        range = 0;
    end

    -- Scroll child is a view taller than the range, so the client's own scroll range is never smaller than ours.
    self.ContentFrame:SetHeight(viewHeight + range);
    self.ScrollArea:SetScrollRange(range);
end

function QuestTextLayout:ReleaseAll()
    self:StopReveal();
    self.revealItems = {};
    if self.rewards then
        self.rewards:ReleaseAll();
    end

    for i = 1, self.fontStringCount do
        local fs = self.fontStrings[i];
        fs:SetText("");
        fs:ClearAllPoints();
        fs:Hide();
    end
    self.fontStringCount = 0;

    for i = 1, self.subHeaderCount do
        local subHeader = self.subHeaders[i];
        subHeader.text:SetText("");
        subHeader.frame:ClearAllPoints();
        subHeader.frame:Hide();
    end
    self.subHeaderCount = 0;

    for i = 1, self.rowCount do
        local row = self.rowButtons[i];
        row:ResetVisual();
        row:ClearAllPoints();
        row:Hide();
    end
    self.rowCount = 0;
    self.rowNames = {};
end

function QuestTextLayout:AcquireFontString()
    local count = self.fontStringCount + 1;
    self.fontStringCount = count;

    local fs = self.fontStrings[count];
    if not fs then
        fs = self.ContentFrame:CreateFontString(nil, "ARTWORK");
        self.fontStrings[count] = fs;
    end

    fs:SetFontObject(self.paragraphFont);
    fs:SetWordWrap(true);   -- without it, in game, the text ignored the box width
    fs:SetSpacing(TEXT_SPACING);
    fs:SetJustifyH("LEFT");
    fs:SetJustifyV("TOP");
    fs:Show();
    return fs
end

function QuestTextLayout:AcquireSubHeader()
    local count = self.subHeaderCount + 1;
    self.subHeaderCount = count;

    local subHeader = self.subHeaders[count];
    if not subHeader then
        local file = ThemeUtil:GetTextureFile(SUBHEADER_TEX_NAME);
        local frame = CreateFrame("Frame", nil, self.ContentFrame);
        frame:SetHeight(SUBHEADER_HEIGHT);

        -- Three horizontal pieces: left cap, stretched middle, right cap.
        local left = frame:CreateTexture(nil, "BORDER");
        left:SetTexture(file);
        left:SetTexCoord(0, SUBHEADER_CAP / SUBHEADER_TEX_WIDTH, 0, 1);
        left:SetWidth(SUBHEADER_CAP);
        left:SetHeight(SUBHEADER_HEIGHT);

        local middle = frame:CreateTexture(nil, "BORDER");
        middle:SetTexture(file);
        middle:SetTexCoord(SUBHEADER_CAP / SUBHEADER_TEX_WIDTH, 1 - SUBHEADER_CAP / SUBHEADER_TEX_WIDTH, 0, 1);
        middle:SetHeight(SUBHEADER_HEIGHT);

        local right = frame:CreateTexture(nil, "BORDER");
        right:SetTexture(file);
        right:SetTexCoord(1 - SUBHEADER_CAP / SUBHEADER_TEX_WIDTH, 1, 0, 1);
        right:SetWidth(SUBHEADER_CAP);
        right:SetHeight(SUBHEADER_HEIGHT);

        local text = frame:CreateFontString(nil, "ARTWORK");

        subHeader = {frame = frame, left = left, middle = middle, right = right, text = text};
        self.subHeaders[count] = subHeader;
    end

    subHeader.text:SetFontObject(self.subHeaderFont);
    subHeader.text:SetJustifyH("LEFT");
    subHeader.text:SetJustifyV("TOP");
    subHeader.frame:Show();
    return subHeader
end

-- Sizes the background to the label, as retail's AcquireAndSetSubHeader.
function QuestTextLayout:SetSubHeaderText(subHeader, text)
    local frame = subHeader.frame;
    local label = subHeader.text;

    label:SetText(text);
    label:SetPoint("LEFT", frame, "LEFT", SUBHEADER_PADDING_H, 0);

    local width = Round(label:GetStringWidth() + 2 * SUBHEADER_PADDING_H);
    frame:SetWidth(width);

    subHeader.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
    subHeader.middle:SetPoint("TOPLEFT", frame, "TOPLEFT", SUBHEADER_CAP, 0);
    subHeader.middle:SetWidth(width - 2 * SUBHEADER_CAP);
    subHeader.right:SetPoint("TOPLEFT", frame, "TOPLEFT", width - SUBHEADER_CAP, 0);
end

-- Returns the offset below the sub-header.
function QuestTextLayout:InsertSubHeader(offsetY, text)
    local subHeader = self:AcquireSubHeader();
    self:SetSubHeaderText(subHeader, text);
    subHeader.frame:SetPoint("TOPLEFT", self.ContentFrame, "TOPLEFT", 0, -offsetY);
    local items = self.revealItems;
    items[#items + 1] = {region = subHeader.frame, length = 0};
    return Round(offsetY + SUBHEADER_SIZE)
end

-- Lays out each paragraph as its own FontString. Returns the offset below the last one.
function QuestTextLayout:FormatParagraph(offsetY, text)
    local paragraphs = SplitParagraph(text);
    if #paragraphs == 0 then
        return offsetY
    end

    for _, paragraph in ipairs(paragraphs) do
        local fs = self:AcquireFontString();
        -- Explicit width sets the wrap width. Word wrap is on (see AcquireFontString).
        fs:SetWidth(self.textWidth);
        fs:SetPoint("TOPLEFT", self.ContentFrame, "TOPLEFT", 0, -offsetY);
        fs:SetText(paragraph);
        local items = self.revealItems;
        items[#items + 1] = {region = fs, fs = fs, length = strlen(paragraph)};
        offsetY = Round(offsetY + fs:GetStringHeight() + PARAGRAPH_SPACING);
    end

    return offsetY - PARAGRAPH_SPACING
end

function QuestTextLayout:AcquireRow()
    local count = self.rowCount + 1;
    self.rowCount = count;
    local row = self.rowButtons[count];
    if not row then
        row = addon.CreateOptionButton(self.ContentFrame, "DialogueUI335Row" .. count, self.owner);
        row:SetButtonWidth(self.textWidth);
        self.rowButtons[count] = row;
    end
    row:Show();
    return row
end

local function OnClick_Row(button)
    local row = button.row;
    if row and row.select then
        row.select(row.index);
    end
end

-- First-contact page (GOSSIP_SHOW, QUEST_GREETING): greeting text, then one button per quest or option.
-- page: GossipData:Read(event). Rows 1-9 get a key (the badge on quests, "N. " in front of option text).
function QuestTextLayout:SetListPage(page)
    self:ReleaseAll();
    self.ScrollArea:ResetScroll();
    self:SetScrollTop(self.listScrollTop);

    local gaps = addon.GossipData.GAPS;
    local offsetY = PARAGRAPH_SPACING;
    local body = page.body;
    if body and body ~= "" then
        offsetY = self:FormatParagraph(offsetY, body);
    end

    for _, data in ipairs(page.rows) do
        local row = self:AcquireRow();
        row.row = data;
        local text, key = data.text, nil;
        if data.kind == "option" then
            if data.key then
                text = data.key .. ". " .. text;
            end
        else
            key = data.key;
        end
        row:Configure({
            type = data.kind, text = text, art = data.art, key = key, icon = data.icon, iconSize = data.iconSize, note = data.note,
            padding = data.kind == "option" and addon.OPTION_BUTTON_PADDING_SMALL or nil,
            onClick = OnClick_Row,
        });
        offsetY = offsetY + gaps[data.gap or "none"];
        row:SetPoint("TOPLEFT", self.ContentFrame, "TOPLEFT", 0, -offsetY);
        offsetY = Round(offsetY + row:GetHeight());
        if data.key then
            self.rowNames[#self.rowNames + 1] = "DialogueUI335Row" .. self.rowCount;
        end
    end

    self.contentHeight = offsetY;
    self:UpdateScrollRange();
    self:StartReveal();
end

-- Shows the quest body, then the objectives under a sub-header when there are any.
-- page (optional): QuestData page with suggested group size, rewards, costs and requirements.
function QuestTextLayout:SetQuestText(body, objective, page)
    self:ReleaseAll();
    self.ScrollArea:ResetScroll();
    self:SetScrollTop(self.questScrollTop);

    local offsetY = self.topOffset;

    if body and body ~= "" then
        offsetY = offsetY + PARAGRAPH_SPACING;
        offsetY = self:FormatParagraph(offsetY, body);
    end

    if objective and objective ~= "" then
        offsetY = offsetY + PARAGRAPH_SPACING;
        offsetY = self:InsertSubHeader(offsetY, SUBHEADER_LABEL);
        offsetY = self:FormatParagraph(offsetY, objective);
    end

    if page then
        if page.suggested then
            -- QUEST_SUGGESTED_GROUP_NUM is a FrameXML string ("Suggested Players [%d]"), not in wow-docs.
            local format = _G.QUEST_SUGGESTED_GROUP_NUM or "Suggested Players [%d]";
            offsetY = offsetY + PARAGRAPH_SPACING;
            offsetY = self:FormatParagraph(offsetY, format:format(page.suggested));
        end
        offsetY = self.rewards:Layout(offsetY, page);
    end

    self.contentHeight = offsetY;
    self:UpdateScrollRange();

    self:StartReveal();
end

-- parent: parchment frame. width: parchment width. scale: FRAME_SIZE_MULTIPLIER.
-- footerOffset: distance from the parchment bottom to the scroll area bottom.
-- fullHeight: parchment height once its intro animation is done.
local function CreateQuestTextLayout(parent, width, scale, footerOffset, fullHeight)
    local self = setmetatable({}, QuestTextLayout);

    self.parent = parent;
    self.fullHeight = fullHeight;
    self.contentHeight = 0;
    self.questScrollTop = (28 + 40) * scale;        -- retail UseQuestLayout topOffset
    self.listScrollTop = 42 * scale;                -- retail UseQuestLayout(false): the Header is hidden
    self.scrollTop = self.questScrollTop;
    self.rowButtons = {};
    self.rowCount = 0;
    self.rowNames = {};
    -- Text box edges line up with the header divider (358 px, centred on the frame).
    local inset = (width - DIVIDER_BASE_WIDTH * scale) / 2;
    self.paddingLeft = inset;
    self.paddingRight = inset;
    self.textWidth = width - self.paddingLeft - self.paddingRight;
    self.topOffset = 6 * scale;                     -- retail UpdateQuestTitle, header allowance

    self.ScrollArea = CreateFrame("ScrollFrame", nil, parent);
    addon.InitSmoothScrollFrame(self.ScrollArea);
    self:SetFooterOffset(footerOffset);

    -- Content has no inset of its own: its width is the padded text box.
    -- Height is set by UpdateScrollRange. The scroll frame clips it to the box.
    local contentFrame = CreateFrame("Frame", nil, self.ScrollArea);
    contentFrame:SetWidth(self.textWidth);
    contentFrame:SetHeight(self.fullHeight - self.scrollTop - footerOffset);
    self.ScrollArea:SetScrollChild(contentFrame);
    self.ContentFrame = contentFrame;

    -- Separate frame for the reveal OnUpdate.
    self.revealFrame = CreateFrame("Frame", nil, self.ScrollArea);

    self.paragraphFont = FontUtil:GetQuestFont(PARAGRAPH_FONT_NAME, FONT_SIZE);
    self.subHeaderFont = FontUtil:GetQuestFont(SUBHEADER_FONT_NAME, FONT_SIZE);

    self.fontStrings = {};
    self.fontStringCount = 0;
    self.subHeaders = {};
    self.subHeaderCount = 0;
    self.revealItems = {};

    self.paragraphSpacing = PARAGRAPH_SPACING;
    self.rewards = addon.CreateRewardLayout(self);

    return self
end

addon.CreateQuestTextLayout = CreateQuestTextLayout;
