local _, addon = ...;

-- Quest Item Display. Port of retail's Widget_QuestItemDisplay.lua for 3.3.5a.
-- When you loot a quest item with lore text, a book, or an item that starts a quest, a small parchment popup shows
-- the icon, name and lore text, plus a button that reads the item or opens the quest it starts.
-- Differences from retail:
--   * no C_TooltipInfo / GetItemInfoInstant: the item is detected from its tooltip text (TooltipScan);
--   * no mask textures: the auto close countdown is a thin bar along the bottom edge instead of a circular swipe;
--   * no settings window yet: options are saved in DialogueUI_335_DB;
--   * no widget chain (this is the only popup), no edit mode (use /duiqid test, then drag).
local L = addon.L;
local API = addon.API;
local GetDBValue = addon.GetDBValue;
local SetDBValue = addon.SetDBValue;
local After = API.After;
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;
local TooltipScan = addon.TooltipScan;

local CreateFrame = CreateFrame;
local GetItemInfo = GetItemInfo;
local InCombatLockdown = InCombatLockdown;
local GetCursorPosition = GetCursorPosition;
local UIParent = UIParent;
local max, min, floor = math.max, math.min, math.floor;
local match, find, gsub = string.match, string.find, string.gsub;

-- Layout (px), same values as retail.
local BASE_TEXT_WIDTH = 224;
local ICON_SIZE = 36;
local PADDING_OUTER = 12;
local PADDING_BUTTON_V = 4;
local PADDING_BUTTON_H = 8;
local GAP_TEXT_ICON = 8;
local GAP_TITLE_DESC = 4;
local CLOSE_BUTTON_SIZE = 34;
local QUEUE_MARKER_SIZE = 17;
local BUTTON_ICON_SIZE = 12;
local BORDER_SCALE = 0.6;        -- drawn size of one texel of the icon border (retail look is thinner than 1:1)
local BORDER_OFFSET = 6;        -- 10 px of frame in the art * BORDER_SCALE

-- Countdown ring around the close button (retail: circular swipe made with mask textures, not possible here).
local RING_SEGMENTS = 120;
local RING_RADIUS = 8.5;
local RING_DOT_SIZE = 1.2;
local RING_COLOR = {0.88, 0.76, 0.55};

-- Timing.
local READING_SPEED_LETTER = 180 * 5;   -- words per minute * average word length
local AUTOHIDE_DELAY_MIN = 5;
local REQUERY_DELAY = 1.0;              -- retail uses 1.0 on Classic
local SLIDE_TIME = 0.35;
local SLIDE_DISTANCE = 32;
local FADE_IN_TIME = 0.25;
local FADE_OUT_SPEED = 2;               -- alpha per second
local FADE_OUT_EXTRA = 0.5;             -- seconds kept hidden after the fade, before the next item
local DEFER_CHECK_INTERVAL = 0.25;

-- Art: Textures/Theme_Brown/QuestItemDisplay-UI.blp is a 512x512 sheet.
local SHEET_FILE = "QuestItemDisplay-UI.blp";
local SHEET_SIZE = 512;
local CLOSE_FILE = "Interface\\AddOns\\DialogueUI_335\\Textures\\Shared\\WidgetCloseButton.blp";
local QUEST_MARK_FILE = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\QuestItem-NotOnQuest.blp";
local SOLID_FILE = "Interface\\Buttons\\WHITE8X8";

-- Regions of the sheet in px: {x, y, width, height}.
local RECT_BACKGROUND = {128, 128, 128, 128};
local RECT_SHADOW = {264, 128, 128, 128};
local RECT_ICON_BORDER = {0, 0, 80, 80};
local RECT_BUTTON_NORMAL = {0, 264, 256, 32};
local RECT_BUTTON_HIGHLIGHT = {0, 304, 256, 32};
local RECT_BUTTON_DISABLED = {0, 344, 256, 32};
local COORD_TITLE_STRIP = {96 / 512, 1, 0, 64 / 512};
local COORD_QUEUE_MARKER = {0, 32 / 512, 96 / 512, 128 / 512};

-- {Brown, Dark} color keys of ThemeUtil
local COLOR_TITLE = {"DarkBrown", "DarkModeGrey90"};
local COLOR_DESC = {"DarkBrown", "DarkModeGrey70"};
local COLOR_BUTTON = {"Ivory", "DarkModeGold"};
local COLOR_PROGRESS = {0.36, 0.25, 0.2};

-- Tooltip lines that mark the item type. These are FrameXML strings, not in wow-docs (UNVERIFIED): the English
-- text is the fallback.
local READABLE_LINES = {};
local function AddLine(set, text)
    if text then set[text] = true end;
end
AddLine(READABLE_LINES, _G.ITEM_CAN_BE_READ);
AddLine(READABLE_LINES, _G.ITEM_READABLE);
AddLine(READABLE_LINES, "<Right Click to Read>");
local START_QUEST_TEXT = _G.ITEM_STARTS_QUEST or "This Item Begins a Quest";
local QUEST_ITEM_TEXT = _G.ITEM_BIND_QUEST or "Quest Item";
local CLICK_TO_READ = L["Click To Read"];
local BEGINS_QUEST = L["Begins A Quest"];

-- Items that drop again and again: shown once even when "ignore seen items" is off.
local ONE_TIME_ITEM = {
    [29433] = true,     -- Grisly Trophy
};

-- Saved options: QuestItemDisplay, QuestItemDisplayHideSeen, QuestItemDisplayAwaitWorldMap, QuestItemDisplayFontSize,
-- QuestItemDisplayPosition and QuestItems (defaults in Initialization.lua).
local function GetSeenItems()
    local seen = GetDBValue("QuestItems");
    if type(seen) ~= "table" then
        seen = {};
        SetDBValue("QuestItems", seen);
    end
    return seen
end

local SEEN_SESSION = {};

local function CountLetters(text)
    if not text then return 0 end;
    local _, count = gsub(text, "[^\128-\191]", "");
    return count
end

-- Whether the cursor is over the frame (used to pause the countdown). Takes the frame's scale into account.
local function IsCursorOver(frame)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom();
    if not (left and right and top and bottom) then return false end;
    local scale = frame:GetEffectiveScale();
    local x, y = GetCursorPosition();
    x, y = x / scale, y / scale;
    return x >= left and x <= right and y >= bottom and y <= top
end

local QuestItemDisplay = CreateFrame("Frame", nil, UIParent);
addon.QuestItemDisplay = QuestItemDisplay;
QuestItemDisplay:Hide();
QuestItemDisplay.queue = {};

local TitleFont, DescFont, ButtonFont;
local GetBagPosition;       -- defined below, used by the button click

local function UpdateFonts()
    local size = GetDBValue("QuestItemDisplayFontSize");
    TitleFont = FontUtil:GetColoredFont("DUI335_QID_Title" .. size, size, COLOR_TITLE);
    DescFont = FontUtil:GetColoredFont("DUI335_QID_Desc" .. size, max(size - 2, 8), COLOR_DESC);
    ButtonFont = FontUtil:GetColoredFont("DUI335_QID_Button" .. size, max(size - 2, 8), COLOR_BUTTON);
end

local function GetMaxTextWidth()
    local size = GetDBValue("QuestItemDisplayFontSize");
    if size > 16 then
        return math.floor(BASE_TEXT_WIDTH * size / 16 + 0.5)
    end
    return BASE_TEXT_WIDTH
end

---------------------------------------------------------------------------------------------------------------
-- Frame

local function SheetFile()
    return ThemeUtil:GetTextureFile(SHEET_FILE)
end

local function CreateSheetSlice(frame, rect, margin, layer, scale)
    local slice = NineSlice:CreateTiled(frame, SheetFile(), {rect[3], rect[4]}, margin, scale or 1, layer, {rect[1], rect[2], SHEET_SIZE, SHEET_SIZE});
    ThemeUtil:BindSlice(slice, SHEET_FILE);
    return slice
end

function QuestItemDisplay:Init()
    self.Init = nil;

    self:SetWidth(8);
    self:SetHeight(8);
    self:SetFrameStrata("FULLSCREEN_DIALOG");
    self:SetFrameLevel(10);
    self:SetClampedToScreen(true);
    self:SetMovable(true);
    self:EnableMouse(true);
    self:RegisterForDrag("LeftButton");
    UpdateFonts();

    -- Shadow: its own frame one level below, so it is drawn under the parchment (child frames draw above parent regions).
    local shadowFrame = CreateFrame("Frame", nil, self);
    shadowFrame:SetFrameLevel(self:GetFrameLevel() - 1);
    shadowFrame:SetPoint("TOPLEFT", self, "TOPLEFT", -16, 16);
    shadowFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 16, -16);
    self.shadowFrame = shadowFrame;
    self.shadow = CreateSheetSlice(shadowFrame, RECT_SHADOW, 24, "BACKGROUND");

    self.background = CreateSheetSlice(self, RECT_BACKGROUND, 24, "BORDER");

    local titleStrip = self:CreateTexture(nil, "ARTWORK");
    self.titleStrip = titleStrip;
    ThemeUtil:BindTexture(titleStrip, SHEET_FILE);
    titleStrip:SetTexCoord(COORD_TITLE_STRIP[1], COORD_TITLE_STRIP[2], COORD_TITLE_STRIP[3], COORD_TITLE_STRIP[4]);
    titleStrip:SetBlendMode("ADD");
    titleStrip:SetAlpha(0.15);
    titleStrip:SetHeight(CLOSE_BUTTON_SIZE);

    local icon = self:CreateTexture(nil, "ARTWORK");
    self.icon = icon;
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("TOPLEFT", self, "TOPLEFT", PADDING_OUTER, -PADDING_OUTER);
    icon:SetTexCoord(0.0625, 0.9375, 0.0625, 0.9375);

    titleStrip:SetPoint("LEFT", icon, "RIGHT", -24, 8);     -- width is set in Layout

    local borderFrame = CreateFrame("Frame", nil, self);
    borderFrame:SetFrameLevel(self:GetFrameLevel() + 1);
    borderFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -BORDER_OFFSET, BORDER_OFFSET);
    borderFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", BORDER_OFFSET, -BORDER_OFFSET);
    self.iconBorder = CreateSheetSlice(borderFrame, RECT_ICON_BORDER, 18, "OVERLAY", BORDER_SCALE);
    self.iconBorder:Update(ICON_SIZE + 2 * BORDER_OFFSET, ICON_SIZE + 2 * BORDER_OFFSET);

    local textLayer = CreateFrame("Frame", nil, self);
    textLayer:SetAllPoints(self);
    textLayer:SetFrameLevel(self:GetFrameLevel() + 2);

    local title = textLayer:CreateFontString(nil, "OVERLAY");
    self.title = title;
    title:SetFontObject(TitleFont);
    title:SetJustifyH("LEFT");
    title:SetJustifyV("TOP");
    title:SetSpacing(2);

    local desc = textLayer:CreateFontString(nil, "OVERLAY");
    self.desc = desc;
    desc:SetFontObject(DescFont);
    desc:SetJustifyH("LEFT");
    desc:SetJustifyV("TOP");
    desc:SetSpacing(2);
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -GAP_TITLE_DESC);

    self:CreateTextButton();
    self:CreateCloseButton();
    self.queueMarkers = {};

    self:SetScript("OnDragStart", self.OnDragStart);
    self:SetScript("OnDragStop", self.OnDragStop);
    self:SetScript("OnMouseUp", self.OnMouseUp);
    self:SetScript("OnHide", self.OnHide);

    self:LoadPosition();

    -- Button text color depends on the state and the theme.
    addon.CallbackRegistry:Register("ThemeChanged", function()
        if self.buttonState then
            self:SetButtonState(self.buttonState);
        end
    end);
end

-- The secure button under the text: reads the item, or (when the quest is already in the log) opens the log.
-- It holds its own background so the text and background sit in the same frame, above the popup.
function QuestItemDisplay:CreateTextButton()
    local btn = CreateFrame("Button", nil, self);
    self.textButton = btn;
    btn:SetFrameLevel(self:GetFrameLevel() + 5);
    btn:EnableMouse(true);
    btn:RegisterForClicks("LeftButtonUp");
    btn:Hide();

    -- Everything that is drawn lives on a plain frame below the secure button, which is only the click layer.
    local visual = CreateFrame("Frame", nil, self);
    btn.visual = visual;
    visual:SetFrameLevel(self:GetFrameLevel() + 4);
    visual:Hide();

    btn.normal = CreateSheetSlice(visual, RECT_BUTTON_NORMAL, 8, "BACKGROUND");
    btn.highlight = CreateSheetSlice(visual, RECT_BUTTON_HIGHLIGHT, 8, "BACKGROUND");
    btn.disabled = CreateSheetSlice(visual, RECT_BUTTON_DISABLED, 8, "BACKGROUND");

    local markIcon = visual:CreateTexture(nil, "OVERLAY");
    btn.markIcon = markIcon;
    markIcon:SetWidth(BUTTON_ICON_SIZE);
    markIcon:SetHeight(BUTTON_ICON_SIZE);
    markIcon:SetPoint("LEFT", visual, "LEFT", PADDING_BUTTON_V, 0);
    markIcon:SetTexture(QUEST_MARK_FILE);
    markIcon:Hide();

    local text = visual:CreateFontString(nil, "OVERLAY");
    btn.text = text;
    text:SetFontObject(ButtonFont);
    text:SetJustifyH("LEFT");
    text:SetJustifyV("MIDDLE");

    btn:SetScript("OnEnter", function()
        if not self.buttonDisabled then
            self:SetButtonState("highlight");
        end
    end);
    btn:SetScript("OnLeave", function()
        if not self.buttonDisabled then
            self:SetButtonState("normal");
        end
    end);
    btn:SetScript("OnClick", function()
        -- Books and quest-starting items have no Use effect, so UseContainerItem is not protected for them
        -- and a plain button can read them. (Retail's secure button was not needed here and did not receive the click.)
        if self.buttonDisabled or not self.current then return end;
        local current = self.current;
        if current.mode == "questLog" then
            self:OpenQuestLog(current.logIndex);
        else
            local bag, slot = current.bag, current.slot;
            if not (bag and slot) or not self:IsItemAt(current.itemID, bag, slot) then
                bag, slot = GetBagPosition(current.itemID);
            end
            if bag and slot then
                UseContainerItem(bag, slot);
            end
        end
        self:Clear();
    end);

end

function QuestItemDisplay:IsItemAt(itemID, bag, slot)
    local link = GetContainerItemLink(bag, slot);
    return link and tonumber(match(link, "item:(%d+)")) == itemID
end

function QuestItemDisplay:CreateCloseButton()
    local close = CreateFrame("Button", nil, self);
    self.closeButton = close;
    close:SetFrameLevel(self:GetFrameLevel() + 6);
    close:SetWidth(CLOSE_BUTTON_SIZE);
    close:SetHeight(CLOSE_BUTTON_SIZE);
    close:SetPoint("CENTER", self, "TOPRIGHT", -8, -8);

    close:SetNormalTexture(CLOSE_FILE);
    close:GetNormalTexture():SetTexCoord(0, 0.25, 0, 0.25);

    close:SetHighlightTexture(CLOSE_FILE, "ADD");
    local highlight = close:GetHighlightTexture();
    highlight:SetTexCoord(0.5, 0.75, 0, 0.25);
    highlight:SetVertexColor(0.5, 0.5, 0.5);

    close:SetScript("OnClick", function()
        self:Clear();
    end);

    -- Ring of dots that fills clockwise from the top as the reading time runs out.
    local ring = {};
    for i = 1, RING_SEGMENTS do
        local angle = (i - 1) / RING_SEGMENTS * 2 * math.pi;
        local dot = close:CreateTexture(nil, "OVERLAY");
        dot:SetTexture(SOLID_FILE);
        dot:SetVertexColor(RING_COLOR[1], RING_COLOR[2], RING_COLOR[3]);
        dot:SetWidth(RING_DOT_SIZE);
        dot:SetHeight(RING_DOT_SIZE);
        dot:SetPoint("CENTER", close, "CENTER", math.sin(angle) * RING_RADIUS, math.cos(angle) * RING_RADIUS);
        ring[i] = dot;
    end
    self.ring = ring;
end

-- progress: 0 = empty ring, 1 = full ring. Segments are numbered clockwise from the top.
function QuestItemDisplay:SetRingProgress(progress)
    local ring = self.ring;
    local exact = max(min(progress, 1), 0) * RING_SEGMENTS;
    local visible = floor(exact);
    local partial = exact - visible;

    if visible ~= self.ringVisible then
        self.ringVisible = visible;
        for i = 1, RING_SEGMENTS do
            if i <= visible then
                ring[i]:SetAlpha(1);
                ring[i]:Show();
            else
                ring[i]:Hide();
            end
        end
    end

    -- The segment being drawn fades in, so the fill moves smoothly instead of in steps.
    local leading = ring[visible + 1];
    if leading then
        leading:SetAlpha(partial);
        leading:Show();
    end
end

function QuestItemDisplay:SetButtonState(state)
    local btn = self.textButton;
    btn.normal:SetShown(state == "normal");
    btn.highlight:SetShown(state == "highlight");
    btn.disabled:SetShown(state == "disabled");
    self.buttonState = state;
    if state == "disabled" then
        btn.text:SetTextColor(ThemeUtil:GetColor(ThemeUtil:IsDarkMode() and "DarkModeGrey70" or "DarkBrown"));
    else
        btn.text:SetTextColor(ThemeUtil:GetColor(ThemeUtil:IsDarkMode() and "DarkModeGold" or "Ivory"));
    end
end

-- Disabled while in combat (retail does the same): using the item may be blocked.
function QuestItemDisplay:SetButtonEnabled(enabled)
    if not self.textButton then return end;
    self.buttonDisabled = not enabled;
    self:SetButtonState(enabled and "normal" or "disabled");
end

---------------------------------------------------------------------------------------------------------------
-- Position

function QuestItemDisplay:LoadPosition()
    local pos = GetDBValue("QuestItemDisplayPosition");
    if pos and pos[1] and pos[2] then
        self.base = { "LEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2] };
    else
        -- Default: left edge of the screen, a little above the middle (retail MainAnchor).
        self.base = { "LEFT", UIParent, "LEFT", 24, 32 };
    end
    self:ApplyPosition(0);
end

-- offsetY: extra vertical offset while the popup slides in.
function QuestItemDisplay:ApplyPosition(offsetY)
    local base = self.base;
    self:ClearAllPoints();
    self:SetPoint(base[1], base[2], base[3], base[4], base[5] + (offsetY or 0));
end

function QuestItemDisplay:SavePosition()
    local left = self:GetLeft();
    local _, centerY = self:GetCenter();
    if not (left and centerY) then return end;
    SetDBValue("QuestItemDisplayPosition", { floor(left + 0.5), floor(centerY + 0.5) });
end

function QuestItemDisplay:IsUsingCustomPosition()
    return GetDBValue("QuestItemDisplayPosition") ~= nil
end

function QuestItemDisplay:ResetPosition()
    SetDBValue("QuestItemDisplayPosition", nil);
    self:LoadPosition();
end

function QuestItemDisplay:OnDragStart()
    self.isMoving = true;
    self:StartMoving();
end

function QuestItemDisplay:OnDragStop()
    self:StopMovingOrSizing();
    self.isMoving = nil;
    self:SavePosition();
    self:LoadPosition();
end

function QuestItemDisplay:OnMouseUp(button)
    if button == "RightButton" then
        self:Clear();
    elseif button == "MiddleButton" then
        self:ResetPosition();
    end
end

---------------------------------------------------------------------------------------------------------------
-- Layout

-- Width of the text on one line, measured on a spare FontString that never has a fixed width
-- (GetStringWidth on the real one depends on its current width and wrapping).
local measurer;
local function MeasureWidth(fontObject, text)
    if not measurer then
        measurer = UIParent:CreateFontString(nil, "OVERLAY");
        measurer:SetAlpha(0);
        measurer:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 0, 0);   -- off screen
    end
    measurer:SetFontObject(fontObject);
    measurer:SetText(text or "");
    return measurer:GetStringWidth()
end

-- Gives a FontString the width of its text (at most maxWidth, then it wraps). Returns the width used.
local function FitWidth(fontString, fontObject, text, maxWidth)
    local width = MeasureWidth(fontObject, text);
    if width > maxWidth then
        fontString:SetWidth(maxWidth);
        return maxWidth
    end
    width = math.ceil(width) + 2;      -- spare pixels so rounding never wraps the last word
    fontString:SetWidth(width);
    return width
end

function QuestItemDisplay:Layout(hasDescription, hasButton)
    local maxWidth = GetMaxTextWidth();
    local title, desc, btn = self.title, self.desc, self.textButton;

    local titleWidth = FitWidth(title, TitleFont, title:GetText(), maxWidth);
    local titleHeight = title:GetHeight();
    local descWidth, descHeight = 0, 0;
    if hasDescription then
        descWidth = FitWidth(desc, DescFont, desc:GetText(), maxWidth);
        descHeight = desc:GetHeight();
    end
    if hasDescription then desc:Show() else desc:Hide() end;

    local buttonWidth, buttonHeight = 0, 0;
    if hasButton then
        local iconWidth = btn.markIcon:IsShown() and (BUTTON_ICON_SIZE + PADDING_BUTTON_V) or 0;
        local textWidth = FitWidth(btn.text, ButtonFont, btn.text:GetText(), maxWidth - 2 * PADDING_BUTTON_H - iconWidth);
        buttonWidth = textWidth + iconWidth + 2 * PADDING_BUTTON_H;
        buttonHeight = math.floor(btn.text:GetHeight() + 2 * PADDING_BUTTON_V + 0.5);
    end

    local textWidthMax = math.floor(max(titleWidth + CLOSE_BUTTON_SIZE, descWidth, buttonWidth) + 0.5);
    local textHeight = titleHeight;
    if hasDescription then
        textHeight = textHeight + GAP_TITLE_DESC + descHeight;
    end
    if hasButton then
        textHeight = textHeight + GAP_TITLE_DESC + buttonHeight;
    end
    textHeight = math.floor(textHeight + 0.5);

    -- Short text is centred against the icon.
    title:ClearAllPoints();
    if textHeight < ICON_SIZE then
        title:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", GAP_TEXT_ICON, 0.5 * (textHeight - ICON_SIZE));
        textHeight = ICON_SIZE;
    else
        title:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", GAP_TEXT_ICON, 0);
    end

    if hasButton then
        local visual = btn.visual;
        visual:ClearAllPoints();
        visual:SetPoint("TOPLEFT", hasDescription and desc or title, "BOTTOMLEFT", 0, -GAP_TITLE_DESC);
        visual:SetWidth(textWidthMax);
        visual:SetHeight(buttonHeight);
        btn:ClearAllPoints();
        btn:SetAllPoints(visual);
        btn.normal:Update(textWidthMax, buttonHeight);
        btn.highlight:Update(textWidthMax, buttonHeight);
        btn.disabled:Update(textWidthMax, buttonHeight);
        btn.text:ClearAllPoints();
        if btn.markIcon:IsShown() then
            btn.text:SetPoint("LEFT", btn.markIcon, "RIGHT", PADDING_BUTTON_V, 0);
        else
            btn.text:SetPoint("LEFT", visual, "LEFT", PADDING_BUTTON_H, 0);
        end
    end

    local width = textWidthMax + ICON_SIZE + 2 * PADDING_OUTER + GAP_TEXT_ICON;
    local height = textHeight + 2 * PADDING_OUTER;
    self:SetWidth(width);
    self:SetHeight(height);
    self.background:Update(width, height);
    self.shadow:Update(width + 32, height + 32);
    self.titleStrip:SetWidth(width - (PADDING_OUTER + ICON_SIZE - 24));
end

---------------------------------------------------------------------------------------------------------------
-- Item data

GetBagPosition = function(itemID)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot);
            if link and tonumber(match(link, "item:(%d+)")) == itemID then
                return bag, slot
            end
        end
    end
end

local function FindQuestInLog(questID)
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i);
        if not isHeader and id == questID then
            return i, title
        end
    end
end

-- Reads the item's tooltip. Returns nil while the client is still fetching the item.
-- Returns: name, description, isReadable, isStartQuest, isQuestItem
local function ReadItemTooltip(itemID)
    local lines = TooltipScan:ScanHyperlink("item:" .. itemID);
    if TooltipScan:IsRetrieving(lines) then
        return nil
    end

    local name, description, isReadable, isStartQuest, isQuestItem;
    for i, line in ipairs(lines) do
        local text = line.left;
        if text and text ~= "" then
            if i == 1 then
                name = text;
            elseif match(text, "^[\"“]") then
                description = text;
            elseif READABLE_LINES[text] or find(text, "to Read>", 1, true) then
                isReadable = true;
            elseif text == START_QUEST_TEXT then
                isStartQuest = true;
            elseif text == QUEST_ITEM_TEXT then
                isQuestItem = true;
            end
        end
    end
    return name, description, isReadable, isStartQuest, isQuestItem
end

-- Readable and quest-starting flags from the bag slot. The hidden tooltip of an item link does not show
-- "<Right Click to Read>", so the bag data is the only place the readable flag exists in 3.3.5a.
-- Returns: bag, slot, isReadable, questID (bag is nil while the item is not in the bags yet).
local function GetBagItemFlags(itemID)
    local bag, slot = GetBagPosition(itemID);
    if not bag then return end;
    local _, _, _, _, readable = GetContainerItemInfo(bag, slot);
    -- GetContainerItemQuestInfo: 3.3.3+. Returns isQuestItem, questID, isActive.
    local _, questID = GetContainerItemQuestInfo(bag, slot);
    if questID == 0 then questID = nil end;
    return bag, slot, readable and true or false, questID
end

-- Whether a looted item should get a popup. Retail filters by item class (Quest, or Consumable/Misc "Other");
-- 3.3.5a GetItemInfo only gives localized class names, so this uses the tooltip text and the bag data instead.
-- Returns: isLore (nil while the item data is not ready), isInBag
local function IsLoreItem(itemID)
    local name, description, isReadable, isStartQuest, isQuestItem = ReadItemTooltip(itemID);
    if not name then
        return nil
    end
    local bag, _, readable, questID = GetBagItemFlags(itemID);
    local isLore = isReadable or readable or isStartQuest or questID ~= nil or (isQuestItem and description ~= nil);
    return isLore and true or false, bag ~= nil
end

---------------------------------------------------------------------------------------------------------------
-- Display

function QuestItemDisplay:ShowLogMark(state)
    if state then
        self.textButton.markIcon:Show();
    else
        self.textButton.markIcon:Hide();
    end
end

function QuestItemDisplay:OpenQuestLog(logIndex)
    -- UNVERIFIED: only SelectQuestLogEntry is in wow-docs. ToggleQuestLog is the FrameXML function behind the L key.
    if logIndex then
        SelectQuestLogEntry(logIndex);
    end
    if QuestLogFrame and not QuestLogFrame:IsShown() and ToggleQuestLog then
        ToggleQuestLog();
    end
end

-- addon.DialogueUI is the dialogue frame object, the frame itself is DialogueUI.frame.
local function IsDialogueShown()
    local dialogue = addon.DialogueUI;
    return dialogue ~= nil and dialogue.frame ~= nil and dialogue.frame:IsShown()
end

function QuestItemDisplay:GetDeferReason(isReadable)
    if InCombatLockdown() then
        return "combat"
    end
    if MerchantFrame and MerchantFrame:IsShown() then
        return "merchant"
    end
    -- Using a readable item ends the NPC interaction, so it waits until the conversation is over.
    if isReadable and IsDialogueShown() then
        return "dialogue"
    end
end

function QuestItemDisplay:IsDeferred()
    return InCombatLockdown() or (MerchantFrame and MerchantFrame:IsShown()) or (IsDialogueShown());
end

-- While anything is deferred, check a few times per second whether it is clear to show the next item.
function QuestItemDisplay:StartDeferWatch()
    if self.deferWatcher then return end;
    local watcher = CreateFrame("Frame");
    self.deferWatcher = watcher;
    local t = 0;
    watcher:SetScript("OnUpdate", function(frame, elapsed)
        t = t + elapsed;
        if t < DEFER_CHECK_INTERVAL then return end;
        t = 0;
        if self:IsShown() then
            return
        end
        if not self:IsDeferred() then
            frame:SetScript("OnUpdate", nil);
            self.deferWatcher = nil;
            self:ProcessQueue();
        end
    end);
end

function QuestItemDisplay:QueueItem(itemID)
    if self.current and self.current.itemID == itemID then return end;
    for _, id in ipairs(self.queue) do
        if id == itemID then return end;
    end
    table.insert(self.queue, itemID);
    if self:IsShown() and self.phase == "hold" then
        self:UpdateQueueMarkers();
    end
end

function QuestItemDisplay:ProcessQueue()
    if #self.queue > 0 then
        local itemID = table.remove(self.queue, 1);
        self:UpdateQueueMarkers();
        self:TryDisplayItem(itemID);
    else
        self:Clear();
    end
end

function QuestItemDisplay:TryDisplayItem(itemID, isRequery)
    if self.inCutscene then
        self:Clear();
        return
    end
    if self.Init then
        self:Init();
    end

    if self:IsShown() then
        self:QueueItem(itemID);
        return
    end

    local name, description, isReadable, isStartQuest = ReadItemTooltip(itemID);
    if not name then
        -- Not cached yet. The tooltip request above asks the server, so look again shortly.
        if not isRequery then
            After(REQUERY_DELAY, function()
                self:TryDisplayItem(itemID, true);
            end);
        else
            self:ProcessQueue();
        end
        return
    end

    local bag, slot, readable, questID = GetBagItemFlags(itemID);
    if readable then
        isReadable = true;
    end
    if not bag and (isReadable or isStartQuest) and not isRequery then
        -- The item may not have reached the bag yet: look again so the button has a slot to use.
        After(REQUERY_DELAY, function()
            self:TryDisplayItem(itemID, true);
        end);
        return
    end

    -- Known only now, so a readable item waits for the end of an NPC conversation (using it ends the conversation).
    local reason = self:GetDeferReason(isReadable);
    if reason then
        self:QueueItem(itemID);
        self:StartDeferWatch();
        return
    end

    local logIndex, questName;

    if not (description or isReadable or isStartQuest or questID) then
        self:ProcessQueue();
        return
    end

    local itemName, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID);
    self.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark");
    self.title:SetText(itemName or name);
    self.desc:SetText(description);

    local current = { itemID = itemID, bag = bag, slot = slot };
    self.current = current;

    -- Button: read the item, or start/open the quest.
    local button = self.textButton;
    local buttonText;
    self:ShowLogMark(false);
    if questID then
        current.mode = "quest";
        logIndex, questName = FindQuestInLog(questID);
        self:ShowLogMark(true);
        if logIndex then
            current.mode = "questLog";
            current.logIndex = logIndex;
            buttonText = questName;
        else
            buttonText = BEGINS_QUEST;
        end
    elseif isReadable then
        current.mode = "book";
        buttonText = CLICK_TO_READ;
    end

    if buttonText then
        button.text:SetText(buttonText);
        button:Show();
        button.visual:Show();
        self:SetButtonEnabled(true);
    else
        button:Hide();
        button.visual:Hide();
    end

    self:Layout(description ~= nil, buttonText ~= nil);

    local letters = CountLetters(itemName or name) + CountLetters(description) + CountLetters(buttonText);
    self.readTime = max(AUTOHIDE_DELAY_MIN, 1 + letters / READING_SPEED_LETTER * 60);
    self.remaining = self.readTime;
    self.ringVisible = nil;
    self:SetRingProgress(0);

    self:UpdateQueueMarkers();
    self:StartSlideIn();
end

function QuestItemDisplay:StartSlideIn()
    self.phase = "in";
    self.t = 0;
    self:SetAlpha(0);
    self:ApplyPosition(-SLIDE_DISTANCE);
    self:SetScript("OnUpdate", self.OnUpdate);
    self:Show();
    self:ApplyWorldMapState();
end

function QuestItemDisplay:IsPaused()
    return self.isMoving or self.isEditMode or self.worldMapOpen or IsCursorOver(self) or IsCursorOver(self.closeButton);
end

function QuestItemDisplay:OnUpdate(elapsed)
    local phase = self.phase;
    if phase == "in" then
        self.t = self.t + elapsed;
        local p = min(self.t / SLIDE_TIME, 1);
        local eased = 1 - (1 - p) * (1 - p);
        if not self.worldMapOpen then
            self:SetAlpha(min(self.t / FADE_IN_TIME, 1));
        end
        if not self.isMoving then
            self:ApplyPosition(-SLIDE_DISTANCE * (1 - eased));
        end
        if p >= 1 then
            self.phase = "hold";
            self:UpdateQueueMarkers();
        end
    elseif phase == "hold" then
        if not self:IsPaused() then
            self.remaining = max(self.remaining - elapsed, 0);
            self:SetRingProgress(1 - self.remaining / self.readTime);
            if self.remaining <= 0 then
                self.phase = "out";
                self.fadeAlpha = self:GetAlpha();
            end
        end
    elseif phase == "out" then
        self.fadeAlpha = self.fadeAlpha - FADE_OUT_SPEED * elapsed;
        if self.fadeAlpha <= 0 then
            self:SetAlpha(0);
            if self.fadeAlpha <= -FADE_OUT_SPEED * FADE_OUT_EXTRA then
                self:SetScript("OnUpdate", nil);
                self.phase = nil;
                self:Hide();
                self:ProcessQueue();
            end
        else
            self:SetAlpha(self.fadeAlpha);
        end
    end
end

function QuestItemDisplay:Clear()
    local wasEditMode = self.isEditMode;
    self.isEditMode = nil;
    self:SetScript("OnUpdate", nil);
    self.phase = nil;
    self.current = nil;
    self.queue = {};
    if self.Init == nil then
        self:UpdateQueueMarkers();
    end
    self:SetAlpha(1);
    self:Hide();
    if wasEditMode and addon.SettingsUI then
        addon.SettingsUI:RefreshToggles();      -- the Move row is no longer on
    end
end

-- Settings > Gameplay > Quest Item Display > Move: a sample popup (no countdown) that can be dragged without
-- having to loot a quest item. Left-click drag moves it, the close button or a right click ends it.
function QuestItemDisplay:IsEditMode()
    return self.isEditMode and self:IsShown() and true or false
end

function QuestItemDisplay:ToggleEditMode()
    if self:IsEditMode() then
        self:Clear();
        return
    end
    if InCombatLockdown() then
        return      -- the popup holds a secure button: it cannot be shown in combat
    end
    if self.Init then
        self:Init();
    end

    self:Clear();
    self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark");
    self.title:SetText(L["Quest Item Display"]);
    self.desc:SetText(L["Drag To Move"]);
    self:ShowLogMark(false);
    self.textButton:Hide();
    self.textButton.visual:Hide();
    self:Layout(true, false);
    self:SetRingProgress(0);
    self.isEditMode = true;
    self:StartSlideIn();
    addon.SettingsUI:RefreshToggles();
end

-- Turning the popup off removes whatever is showing or waiting.
addon.CallbackRegistry:Register("SettingChanged.QuestItemDisplay", function(state)
    if not state then
        QuestItemDisplay:Clear();
    end
end);

-- The sample goes away with the Settings window or when the Gameplay tab is left.
addon.CallbackRegistry:Register("SettingsUI.Hide", function()
    if QuestItemDisplay.isEditMode then
        QuestItemDisplay:Clear();
    end
end);
addon.CallbackRegistry:Register("SettingsUI.TabChanged", function(tabID)
    if tabID ~= 3 and QuestItemDisplay.isEditMode then
        QuestItemDisplay:Clear();
    end
end);

-- Await World Map: takes effect at once (the popup on screen hides behind an open map, or comes back).
addon.CallbackRegistry:Register("SettingChanged.QuestItemDisplayAwaitWorldMap", function()
    if QuestItemDisplay.Init == nil then
        QuestItemDisplay:ApplyWorldMapState();
    end
end);

function QuestItemDisplay:OnHide()
    if self.isMoving then
        self:StopMovingOrSizing();
        self.isMoving = nil;
        self:SavePosition();
        self:LoadPosition();
    end
end

---------------------------------------------------------------------------------------------------------------
-- Queue markers

function QuestItemDisplay:UpdateQueueMarkers()
    if not self.queueMarkers then return end;
    local count = #self.queue;
    local markers = self.queueMarkers;
    for i = 1, max(count, #markers) do
        local marker = markers[i];
        if i <= count then
            if not marker then
                marker = self:CreateTexture(nil, "OVERLAY");
                ThemeUtil:BindTexture(marker, SHEET_FILE);
                marker:SetTexCoord(COORD_QUEUE_MARKER[1], COORD_QUEUE_MARKER[2], COORD_QUEUE_MARKER[3], COORD_QUEUE_MARKER[4]);
                marker:SetWidth(QUEUE_MARKER_SIZE);
                marker:SetHeight(QUEUE_MARKER_SIZE);
                markers[i] = marker;
            end
            marker:ClearAllPoints();
            marker:SetPoint("TOPLEFT", self, "BOTTOM", -count * QUEUE_MARKER_SIZE * 0.5 + (i - 1) * QUEUE_MARKER_SIZE, 0);
            marker:Show();
        elseif marker then
            marker:Hide();
        end
    end
end

---------------------------------------------------------------------------------------------------------------
-- World map (optional): hide behind the map and pause the countdown while it is open.

function QuestItemDisplay:ApplyWorldMapState()
    local open = GetDBValue("QuestItemDisplayAwaitWorldMap") and WorldMapFrame and WorldMapFrame:IsShown();
    if open then
        self.worldMapOpen = true;
        self:SetAlpha(0);
        -- Behind the map, so the invisible popup cannot be clicked. Strata of a frame with a secure child cannot change in combat.
        if not InCombatLockdown() then
            self:SetFrameStrata("LOW");
        end
    elseif self.worldMapOpen then
        self.worldMapOpen = nil;
        if not InCombatLockdown() then
            self:SetFrameStrata("FULLSCREEN_DIALOG");
        end
        if self:IsShown() and self.phase ~= "in" then
            self:SetAlpha(1);
        end
    end
end

if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", function()
        if QuestItemDisplay.Init == nil then
            QuestItemDisplay:ApplyWorldMapState();
        end
    end);
    WorldMapFrame:HookScript("OnHide", function()
        if QuestItemDisplay.Init == nil then
            QuestItemDisplay:ApplyWorldMapState();
        end
    end);
end

---------------------------------------------------------------------------------------------------------------
-- Loot detection

-- Patterns that match the player's own loot messages. The strings are FrameXML globals (UNVERIFIED, not in wow-docs).
local SELF_PATTERNS = {};
do
    local names = {
        "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE",
        "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
        "LOOT_ITEM_CREATED_SELF", "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    };
    for _, globalName in ipairs(names) do
        local format = _G[globalName];
        if format then
            local pattern = gsub(format, "([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1");   -- escape
            pattern = gsub(pattern, "%%%%s", ".+");
            pattern = gsub(pattern, "%%%%d", "%%d+");
            SELF_PATTERNS[#SELF_PATTERNS + 1] = "^" .. pattern;
        end
    end
end

local function IsOwnLoot(text, playerName)
    if #SELF_PATTERNS == 0 then
        return playerName == nil or playerName == "" or playerName == UnitName("player")
    end
    for _, pattern in ipairs(SELF_PATTERNS) do
        if find(text, pattern) then
            return true
        end
    end
    return false
end

local pendingLoot = {};

function QuestItemDisplay:OnItemLooted(itemID, isRetry)
    if SEEN_SESSION[itemID] then return end;

    local isLore, isInBag = IsLoreItem(itemID);
    if isLore == nil then
        -- Item data is not ready: let the next loot message try again.
        return
    end

    if not isLore and not isInBag then
        -- The loot message can arrive before the item reaches the bag, and the readable flag is only in the bag.
        if not isRetry and not pendingLoot[itemID] then
            pendingLoot[itemID] = true;
            After(REQUERY_DELAY, function()
                pendingLoot[itemID] = nil;
                self:OnItemLooted(itemID, true);
            end);
        end
        return
    end

    SEEN_SESSION[itemID] = true;
    if not isLore then return end;

    local seen = GetSeenItems();
    if (GetDBValue("QuestItemDisplayHideSeen") or ONE_TIME_ITEM[itemID]) and seen[itemID] then
        return
    end
    seen[itemID] = true;
    self:TryDisplayItem(itemID);
end

local events = CreateFrame("Frame");
local function OnEvent(_, event, ...)
    if event == "CHAT_MSG_LOOT" then
        local text, playerName = ...;
        if not GetDBValue("QuestItemDisplay") then return end;
        if not text or not IsOwnLoot(text, playerName) then return end;
        local itemID = match(text, "item:(%d+)");
        itemID = itemID and tonumber(itemID);
        if itemID then
            QuestItemDisplay:OnItemLooted(itemID);
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        QuestItemDisplay:SetButtonEnabled(false);
    elseif event == "PLAYER_REGEN_ENABLED" then
        if QuestItemDisplay.current and QuestItemDisplay.phase ~= "out" then
            QuestItemDisplay:SetButtonEnabled(true);
        end
        if #QuestItemDisplay.queue > 0 then
            QuestItemDisplay:StartDeferWatch();
        end
    elseif event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
        QuestItemDisplay.inCutscene = true;
        QuestItemDisplay:Clear();
    elseif event == "CINEMATIC_STOP" or event == "PLAYER_ENTERING_WORLD" then
        QuestItemDisplay.inCutscene = nil;
    end
end
events:SetScript("OnEvent", OnEvent);
events:RegisterEvent("CHAT_MSG_LOOT");
events:RegisterEvent("PLAYER_REGEN_DISABLED");
events:RegisterEvent("PLAYER_REGEN_ENABLED");
events:RegisterEvent("CINEMATIC_START");
events:RegisterEvent("CINEMATIC_STOP");
events:RegisterEvent("PLAY_MOVIE");
events:RegisterEvent("PLAYER_ENTERING_WORLD");

---------------------------------------------------------------------------------------------------------------
-- Test slash command. Options are the QuestItemDisplay* settings and have no UI for now.
--   /duiqid test <itemID>   show the popup for an item
--   /duiqid reset           reset the popup position

SLASH_DUIQID1 = "/duiqid";
SlashCmdList["DUIQID"] = function(message)
    local command, rest = match(message or "", "^%s*(%S*)%s*(.-)%s*$");
    command = command and command:lower() or "";
    local itemID = tonumber(rest);
    if command == "test" and itemID then
        SEEN_SESSION[itemID] = nil;
        QuestItemDisplay:Clear();
        QuestItemDisplay:TryDisplayItem(itemID);
    elseif command == "reset" then
        if QuestItemDisplay.Init == nil then
            QuestItemDisplay:ResetPosition();
        else
            SetDBValue("QuestItemDisplayPosition", nil);
        end
    end
end
