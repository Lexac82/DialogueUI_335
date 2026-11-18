local _, addon = ...;

-- Custom tooltip frame. Port of retail's Tooltip_Base.lua (CreateTooltipBase), without C_TooltipInfo.
-- Lines are added with AddLine / AddDoubleLine / SetTitle / AddBlankLine, then Layout() sizes the frame.
-- Background: 9 textures (NineSlice), because 3.3.5a has no texture slice mode.

local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local API = addon.API;

local CreateFrame = CreateFrame;
local max = math.max;
local min = math.min;

-- Values from retail Tooltip_Base.lua.
local PADDING = 12;
local MAX_TEXT_WIDTH = 256 - 2 * PADDING;     -- 232
local SPACING_LINE = 2;                       -- SPACING_INTERNAL
local SPACING_BLANK = 4;                      -- SPACING_NEW_LINE
local COLUMN_GAP = 24;                        -- FONTSTRING_MIN_GAP
local SHOW_DELAY = 0.25;
local DEFAULT_COLOR = { 0.9, 0.9, 0.9 };

local BACKGROUND_FILE = "TooltipBackground-Temp.blp";
local BACKGROUND_SIZE = { 128, 128 };
local BACKGROUND_MARGIN = 32;                 -- retail slice margin
local BACKGROUND_SCALE = 0.75;                -- drawn size of one texel; retail uses its pixel-perfect scale (~0.71 at 1080p)

local HOTKEY_FILE = "HotkeyBackground.blp";
local HOTKEY_SIZE = { 32, 32 };
local HOTKEY_MARGIN = 8;
local HOTKEY_HEIGHT = 20;

local MODEL_WIDTH = 48;                     -- static item icon preview (TooltipModel.lua)
local MODEL_HEIGHT = 48;
local MODEL_OVERHANG = -PADDING;              -- y offset from the top edge: inside the padding

local TooltipFrame = {};
TooltipFrame.__index = TooltipFrame;

local function GetFonts()
    return {
        title = FontUtil:GetColoredFont("DUI335_Tooltip_Large", 12, DEFAULT_COLOR),
        body = FontUtil:GetColoredFont("DUI335_Tooltip_Medium", 10, DEFAULT_COLOR),
    }
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

function TooltipFrame:AcquireRow()
    local count = self.rowCount + 1;
    self.rowCount = count;

    local row = self.rows[count];
    if not row then
        row = {
            left = self.frame:CreateFontString(nil, "ARTWORK"),
            right = self.frame:CreateFontString(nil, "ARTWORK"),
        };
        -- A FontString needs a font before any SetText, even SetText("") in Clear().
        row.left:SetFontObject(self.fonts.body);
        row.right:SetFontObject(self.fonts.body);
        row.left:SetJustifyH("LEFT");
        row.left:SetJustifyV("TOP");
        row.right:SetJustifyH("RIGHT");
        row.right:SetJustifyV("TOP");
        self.rows[count] = row;
    end

    row.blank = nil;
    row.hasRight = nil;
    row.isTitle = nil;
    row.left:Show();
    row.right:Hide();
    return row
end

function TooltipFrame:Clear()
    for i = 1, self.rowCount do
        local row = self.rows[i];
        row.left:SetText("");
        row.left:ClearAllPoints();
        row.left:Hide();
        row.right:SetText("");
        row.right:ClearAllPoints();
        row.right:Hide();
    end
    self.rowCount = 0;
    self.hotkey = nil;
    self.hotkeyFrame:Hide();
    self:SetPreviewItem(nil);
end

local function SetColor(fs, color, r, g, b)
    if r then
        fs:SetTextColor(r, g, b);
    else
        fs:SetTextColor(color[1], color[2], color[3]);
    end
end

function TooltipFrame:SetTitle(text, r, g, b)
    local row = self:AcquireRow();
    row.isTitle = true;
    row.left:SetFontObject(self.fonts.title);
    row.left:SetText(text or "");
    SetColor(row.left, DEFAULT_COLOR, r, g, b);
end

function TooltipFrame:AddLine(text, r, g, b)
    local row = self:AcquireRow();
    row.left:SetFontObject(self.fonts.body);
    row.left:SetText(text or "");
    SetColor(row.left, DEFAULT_COLOR, r, g, b);
end

function TooltipFrame:AddDoubleLine(leftText, rightText, lr, lg, lb, rr, rg, rb)
    local row = self:AcquireRow();
    row.hasRight = true;
    row.left:SetFontObject(self.fonts.body);
    row.left:SetText(leftText or "");
    SetColor(row.left, DEFAULT_COLOR, lr, lg, lb);
    row.right:SetFontObject(self.fonts.body);
    row.right:SetText(rightText or "");
    SetColor(row.right, DEFAULT_COLOR, rr, rg, rb);
    row.right:Show();
end

function TooltipFrame:AddBlankLine()
    local row = self:AcquireRow();
    row.blank = true;
    row.left:SetFontObject(self.fonts.body);
    row.left:SetText("");
    row.left:Hide();
end

-- "Shift  Show Comparison" hint, drawn under the last row.
function TooltipFrame:AddHotkey(key, description)
    self.hotkey = { key = key, description = description };
end

---------------------------------------------------------------------------
-- Model preview (see TooltipModel.lua)
---------------------------------------------------------------------------

function TooltipFrame:SetPreviewItem(link)
    self.previewLink = link;
    if addon.TooltipModel then
        addon.TooltipModel:Update(self, link);
    end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

-- Natural width first, then wrapped to `limit` when too wide. Returns width, height.
local function MeasureWrapped(fs, limit)
    fs:SetWidth(0);
    local width = fs:GetStringWidth();
    if width > limit then
        fs:SetWidth(limit);
        width = limit;
    end
    return width, fs:GetStringHeight()
end

function TooltipFrame:Layout()
    local frame = self.frame;
    local rows = self.rows;
    local reserve = self.previewLink and (MODEL_WIDTH + 8) or 0;

    -- Pass 1: widths and heights.
    local contentWidth = 0;
    local rowY = PADDING;                       -- where the row starts, to know which rows sit beside the preview
    for i = 1, self.rowCount do
        local row = rows[i];
        if row.blank then
            row.height = SPACING_BLANK;
            row.width = 0;
            row.reserve = 0;
        else
            local limit = MAX_TEXT_WIDTH;
            local extra = 0;
            -- Every row that starts next to the preview keeps clear of it (text wraps, right columns shift left).
            if reserve > 0 and rowY < PADDING + MODEL_HEIGHT then
                limit = limit - reserve;
                extra = reserve;
            end
            row.reserve = extra;
            if row.hasRight then
                row.left:SetWidth(0);
                row.right:SetWidth(0);
                local lw, rw = row.left:GetStringWidth(), row.right:GetStringWidth();
                row.width = lw + COLUMN_GAP + rw;
                row.height = max(row.left:GetStringHeight(), row.right:GetStringHeight());
                row.limit = nil;
            else
                local width, height = MeasureWrapped(row.left, limit);
                row.width = width;
                row.height = height;
                row.limit = limit;
            end
            contentWidth = max(contentWidth, row.width + extra);
        end
        rowY = rowY + row.height + (row.blank and 0 or SPACING_LINE);
    end

    local hotkeyHeight = 0;
    local hotkeyFrame = self.hotkeyFrame;
    if self.hotkey then
        hotkeyFrame.keyText:SetText(self.hotkey.key);
        hotkeyFrame.description:SetText(self.hotkey.description);
        local keyWidth = max(24, API.Round(hotkeyFrame.keyText:GetStringWidth() + 16));
        hotkeyFrame:SetWidth(keyWidth);
        hotkeyFrame.keyWidth = keyWidth;
        local hotkeyRowWidth = keyWidth + 6 + hotkeyFrame.description:GetStringWidth();
        contentWidth = max(contentWidth, hotkeyRowWidth);
        hotkeyHeight = HOTKEY_HEIGHT;
    end

    -- Pass 2: positions.
    local y = PADDING;
    for i = 1, self.rowCount do
        local row = rows[i];
        if not row.blank then
            row.left:ClearAllPoints();
            row.left:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y);
            if row.hasRight then
                row.right:ClearAllPoints();
                row.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING - (row.reserve or 0), -y);
            else
                -- Wrapped rows keep their wrap width; short rows stay at natural width.
                row.left:SetWidth(row.limit and min(row.limit, contentWidth) or 0);
            end
        end
        y = y + row.height + (row.blank and 0 or SPACING_LINE);
    end

    if self.hotkey then
        y = y + SPACING_BLANK;
        hotkeyFrame:ClearAllPoints();
        hotkeyFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -y);
        hotkeyFrame:Show();
        y = y + hotkeyHeight;
    else
        hotkeyFrame:Hide();
    end

    local height = y - (self.rowCount > 0 and SPACING_LINE or 0) + PADDING;
    if self.previewLink then
        -- The preview reaches (MODEL_HEIGHT - MODEL_OVERHANG) below the top edge.
        height = max(height, MODEL_HEIGHT - MODEL_OVERHANG + PADDING);
    end

    local width = contentWidth + 2 * PADDING;
    frame:SetWidth(width);
    frame:SetHeight(height);
    self.background:Update(width, height);
end

---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------

-- Anchors above the owner's icon like retail: BOTTOMLEFT on the icon's TOPRIGHT, 2 px up.
function TooltipFrame:SetOwnerAnchor(owner, anchorFrame)
    self.owner = owner;
    local frame = self.frame;
    frame:ClearAllPoints();
    frame:SetPoint("BOTTOMLEFT", anchorFrame or owner, "TOPRIGHT", 0, 2);
end

function TooltipFrame:Show()
    self:Layout();
    -- Laid out now, shown after SHOW_DELAY by the driver frame (see CreateTooltipFrame).
    self.frame:Hide();
    self.showTime = 0;
    self.waiting = true;
end

function TooltipFrame:Hide()
    self.waiting = false;
    self.frame:Hide();
    self.owner = nil;
    self.retry = nil;
    self.onModifier = nil;
    self.frame:UnregisterEvent("MODIFIER_STATE_CHANGED");
end

function TooltipFrame:IsShown()
    return self.frame:IsShown()
end

function TooltipFrame:GetOwner()
    return self.owner
end

local function CreateTooltipFrame()
    local self = setmetatable({}, TooltipFrame);
    self.rows = {};
    self.rowCount = 0;
    self.fonts = GetFonts();

    local frame = CreateFrame("Frame", nil, UIParent);
    frame:SetFrameStrata("TOOLTIP");
    frame:SetClampedToScreen(true);
    frame:SetClampRectInsets(-4, 4, 4, -4);
    frame:EnableMouse(false);
    frame:Hide();
    self.frame = frame;

    local file = ThemeUtil:GetTextureFile(BACKGROUND_FILE);
    -- Tiled like retail's TextureSliceMode(1): corners keep their texel size, edges and centre repeat.
    self.background = NineSlice:CreateTiled(frame, file, BACKGROUND_SIZE, BACKGROUND_MARGIN, BACKGROUND_SCALE, "BACKGROUND");

    -- Hotkey hint: key cap (9-slice) + description.
    local hotkeyFrame = CreateFrame("Frame", nil, frame);
    hotkeyFrame:SetHeight(HOTKEY_HEIGHT);
    hotkeyFrame:SetWidth(30);
    NineSlice:Create(hotkeyFrame, ThemeUtil:GetTextureFile(HOTKEY_FILE), HOTKEY_SIZE, HOTKEY_MARGIN, HOTKEY_MARGIN, "BACKGROUND");
    local keyText = hotkeyFrame:CreateFontString(nil, "ARTWORK");
    keyText:SetFontObject(self.fonts.body);
    keyText:SetPoint("CENTER", hotkeyFrame, "CENTER", 0, 0);
    keyText:SetTextColor(1, 1, 1);
    local description = hotkeyFrame:CreateFontString(nil, "ARTWORK");
    description:SetFontObject(self.fonts.body);
    description:SetPoint("LEFT", hotkeyFrame, "RIGHT", 6, 0);
    description:SetTextColor(0.5, 0.5, 0.5);
    hotkeyFrame.keyText = keyText;
    hotkeyFrame.description = description;
    hotkeyFrame:Hide();
    self.hotkeyFrame = hotkeyFrame;

    -- Show delay (retail SetShowDelay(0.25)). The frame stays hidden during the delay and appears at full
    -- alpha: inline coin icons in the text ignore the frame's alpha, so a fade or alpha 0 would show the coins
    -- before the text and background. The driver is a separate frame, because a hidden frame gets no OnUpdate.
    local driver = CreateFrame("Frame", nil, UIParent);
    driver:SetScript("OnUpdate", function(_, elapsed)
        if not self.waiting then
            return
        end
        self.showTime = self.showTime + elapsed;
        if self.showTime >= SHOW_DELAY then
            self.waiting = false;
            frame:SetAlpha(1);
            frame:Show();
        end
    end);
    self.driver = driver;

    -- Runs the retry hook (re-reads an item still loading) while the tooltip is visible.
    frame:SetScript("OnUpdate", function(_, elapsed)
        if self.retry then
            self.retry(elapsed);
        end
    end);
    frame:SetScript("OnEvent", function(f, event, key, state)
        if self.onModifier then
            self.onModifier(key, state);
        end
    end);

    return self
end

addon.CreateTooltipFrame = CreateTooltipFrame;
addon.TOOLTIP_METRICS = {MODEL_WIDTH = MODEL_WIDTH, MODEL_HEIGHT = MODEL_HEIGHT, MODEL_OVERHANG = MODEL_OVERHANG, PADDING = PADDING};
