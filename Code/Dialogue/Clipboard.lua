local _, addon = ...;

-- Copy Text: a window with the page's text in a read-only-ish edit box (select with the mouse or Ctrl+A, copy with
-- Ctrl+C), and the small button that opens it. Port of retail's Clipboard.lua.
-- Differences: 3.3.5a has no GLOBAL_MOUSE_DOWN / GLOBAL_MOUSE_UP, so a click outside the window and the mouse
-- release are detected with IsMouseButtonDown in an OnUpdate. No retail scroll bar (ScrollBar.lua is not ported):
-- a small rail + thumb is built here from the same textures.
-- Textures (not theme folders, used by both themes): Textures\Shared\ClipboardBackground.blp (128x128),
-- Textures\Shared\CopyTextButton.blp (256x32, one 32x32 icon per theme: Brown, Dark).
local L = addon.L;
local API = addon.API;
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;

local Clamp = API.Clamp;
local Round = API.Round;
local GetCursorPosition = GetCursorPosition;
local IsMouseButtonDown = IsMouseButtonDown;
local max = math.max;

local SHARED_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Shared\\";
local BACKGROUND_FILE = SHARED_PATH .. "ClipboardBackground.blp";
local BUTTON_FILE = SHARED_PATH .. "CopyTextButton.blp";

local FRAME_WIDTH = 480;
local FRAME_HEIGHT = 480;
local FRAME_INSET = 12;
local EDITBOX_TEXT_INSET = 4;
local SCROLLBAR_WIDTH = 12;
local RAIL_WIDTH = 4;
local THUMB_MIN_HEIGHT = 12;
local THUMB_HOVER_WIDTH = 8;
local OFFSET_PER_SCROLL = 24;               -- two lines
local VIEW_HEIGHT = FRAME_HEIGHT - 2 * FRAME_INSET;       -- changes with the window size (ShowContent)

local Clipboard = {};
addon.Clipboard = Clipboard;

local frame, scrollFrame, editBox;          -- created on first use
local copyTextButtons = {};

---------------------------------------------------------------------------
-- Scroll bar (rail + thumb, dark colors as retail's clipboard uses theme 2)
---------------------------------------------------------------------------

local RAIL_COLOR = {0.16, 0.16, 0.16, 1};
local THUMB_COLOR = {0.33, 0.33, 0.33, 1};
local THUMB_HOVER_COLOR = {0.6, 0.6, 0.6, 1};
local THUMB_PUSHED_COLOR = {0.72, 0.72, 0.72, 1};

local scrollRange = 0;
local thumb, thumbArt, thumbPieces, thumbHeight, thumbTravel, scrollBar;
local dragging, dragCursorY;

local function PaintThumb(color)
    NineSlice:SetVertexColor(thumbPieces, color[1], color[2], color[3], color[4]);
end

local function UpdateThumbSize()
    if scrollRange <= 0 then
        scrollBar:Hide();
        return
    end
    scrollBar:Show();
    thumbHeight = max(THUMB_MIN_HEIGHT, Round(VIEW_HEIGHT * VIEW_HEIGHT / (scrollRange + VIEW_HEIGHT)));
    thumbTravel = VIEW_HEIGHT - thumbHeight;
    thumb:SetHeight(thumbHeight);
end

local function UpdateThumbPosition()
    if scrollRange <= 0 or not thumbTravel then
        return
    end
    local progress = scrollFrame:GetVerticalScroll() / scrollRange;
    thumb:ClearAllPoints();
    thumb:SetPoint("TOP", scrollBar, "TOP", 0, -thumbTravel * Clamp(progress, 0, 1));
end

local function SetScrollOffset(offset)
    offset = Clamp(offset, 0, scrollRange);
    scrollFrame:SetVerticalScroll(offset);
    UpdateThumbPosition();
end

local function ScrollBy(delta)
    SetScrollOffset(scrollFrame:GetVerticalScroll() + delta);
end

-- The edit box grows with its text a frame after SetText, so the range is read again every frame.
local function UpdateScrollRange()
    local range = scrollFrame:GetVerticalScrollRange();
    if range < 0 then
        range = 0;
    end
    if range == scrollRange then
        return
    end
    local diff = scrollRange - range;
    scrollRange = range;
    UpdateThumbSize();
    if diff < -1 or diff > 1 then
        SetScrollOffset(0);
    else
        SetScrollOffset(scrollFrame:GetVerticalScroll());
    end
end

local function CreateScrollBar(parent)
    scrollBar = CreateFrame("Frame", nil, parent);
    scrollBar:SetWidth(SCROLLBAR_WIDTH);
    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -FRAME_INSET, -FRAME_INSET);
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -FRAME_INSET, FRAME_INSET);
    scrollBar:EnableMouse(true);

    local rail = CreateFrame("Frame", nil, scrollBar);
    rail:SetWidth(RAIL_WIDTH);
    rail:SetPoint("TOP", scrollBar, "TOP", 0, 0);
    rail:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 0);
    local railPieces = NineSlice:Create(rail, ThemeUtil:GetTextureFile("ScrollBar-Vertical-Rail.blp"), {8, 64}, 2, 2, "BORDER");
    NineSlice:SetVertexColor(railPieces, RAIL_COLOR[1], RAIL_COLOR[2], RAIL_COLOR[3], RAIL_COLOR[4]);

    thumb = CreateFrame("Frame", nil, scrollBar);
    thumb:SetFrameLevel(rail:GetFrameLevel() + 5);
    thumb:SetWidth(SCROLLBAR_WIDTH);
    thumb:SetHeight(THUMB_MIN_HEIGHT);
    thumb:SetPoint("TOP", scrollBar, "TOP", 0, 0);
    thumb:EnableMouse(true);

    thumbArt = CreateFrame("Frame", nil, thumb);
    thumbArt:SetPoint("TOP", thumb, "TOP", 0, 0);
    thumbArt:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0);
    thumbArt:SetWidth(RAIL_WIDTH);
    thumbPieces = NineSlice:Create(thumbArt, ThemeUtil:GetTextureFile("ScrollBar-Vertical-Thumb.blp"), {32, 32}, 4, 2, "OVERLAY");
    PaintThumb(THUMB_COLOR);

    thumb:SetScript("OnEnter", function()
        thumbArt:SetWidth(THUMB_HOVER_WIDTH);
        if not dragging then
            PaintThumb(THUMB_HOVER_COLOR);
        end
    end);
    thumb:SetScript("OnLeave", function()
        if not dragging then
            thumbArt:SetWidth(RAIL_WIDTH);
            PaintThumb(THUMB_COLOR);
        end
    end);
    thumb:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then
            return
        end
        dragging = true;
        local _, y = GetCursorPosition();
        dragCursorY = y / frame:GetEffectiveScale();
        PaintThumb(THUMB_PUSHED_COLOR);
    end);
    thumb:SetScript("OnMouseUp", function()
        Clipboard:StopThumbDrag();
    end);

    scrollBar:Hide();
end

function Clipboard:StopThumbDrag()
    if not dragging then
        return
    end
    dragging = false;
    if thumb:IsMouseOver() then
        PaintThumb(THUMB_HOVER_COLOR);
    else
        thumbArt:SetWidth(RAIL_WIDTH);
        PaintThumb(THUMB_COLOR);
    end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local cursorScrolling, cursorTop, cursorBottom;
local wasMouseDown = false;

local function IsOverCopyButton()
    for _, button in ipairs(copyTextButtons) do
        if button:IsShown() and button:IsMouseOver() then
            return true
        end
    end
    return false
end

-- Left or right button went down: a press on the text starts selecting (the window scrolls when the cursor leaves
-- it), a press anywhere else but on a Copy Text button closes the window.
local function OnMouseDown()
    if frame:IsMouseOver() then
        if scrollFrame:IsMouseOver() then
            cursorScrolling = true;
            cursorTop = scrollFrame:GetTop();
            cursorBottom = scrollFrame:GetBottom();
        end
    elseif not IsOverCopyButton() then
        Clipboard:Hide();
    end
end

local function OnMouseUp()
    cursorScrolling = false;
    Clipboard:StopThumbDrag();
end

local function OnUpdate(_, elapsed)
    local down = (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and true or false;
    if down and not wasMouseDown then
        OnMouseDown();
    elseif wasMouseDown and not down then
        OnMouseUp();
    end
    wasMouseDown = down;
    if not frame:IsShown() then
        return
    end

    UpdateScrollRange();

    local _, cursorY = GetCursorPosition();
    cursorY = cursorY / frame:GetEffectiveScale();

    if dragging then
        local delta = cursorY - dragCursorY;
        dragCursorY = cursorY;
        if delta ~= 0 and thumbTravel and thumbTravel > 0 then
            ScrollBy(-delta * scrollRange / thumbTravel);
        end
    elseif cursorScrolling and scrollRange > 0 then
        -- Dragging a selection past the top or bottom edge scrolls, faster the further out the cursor is.
        if cursorY > cursorTop then
            ScrollBy((cursorTop - cursorY) * elapsed * 10);
        elseif cursorY < cursorBottom then
            ScrollBy((cursorBottom - cursorY) * elapsed * 10);
        end
    end
end

local function Init()
    frame = CreateFrame("Frame", nil, addon.UIRoot);
    frame:SetWidth(FRAME_WIDTH);
    frame:SetHeight(FRAME_HEIGHT);
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    frame:SetFrameStrata("DIALOG");
    frame:SetToplevel(true);
    frame:EnableMouse(true);
    frame:Hide();
    Clipboard.frame = frame;

    NineSlice:Create(frame, BACKGROUND_FILE, {128, 128}, 16, 16, "BACKGROUND");

    CreateScrollBar(frame);

    scrollFrame = CreateFrame("ScrollFrame", nil, frame);
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_INSET, -FRAME_INSET);
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(FRAME_INSET + SCROLLBAR_WIDTH + FRAME_INSET), FRAME_INSET);
    scrollFrame:EnableMouseWheel(true);
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(delta > 0 and -OFFSET_PER_SCROLL or OFFSET_PER_SCROLL);
    end);

    editBox = CreateFrame("EditBox", nil, scrollFrame);
    editBox:SetFontObject(FontUtil:GetColoredFont("DUI335_Clipboard", 12, {0.9, 0.9, 0.9}));
    editBox:SetAutoFocus(false);
    editBox:SetMultiLine(true);
    editBox:SetMaxLetters(0);
    editBox:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0);
    editBox:SetWidth(FRAME_WIDTH - 3 * FRAME_INSET - SCROLLBAR_WIDTH);
    editBox:SetHeight(1);
    editBox:SetTextInsets(EDITBOX_TEXT_INSET, EDITBOX_TEXT_INSET, EDITBOX_TEXT_INSET, EDITBOX_TEXT_INSET);
    scrollFrame:SetScrollChild(editBox);

    -- The text is for copying: typing into it closes the window.
    editBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then
            Clipboard:Hide();
            return
        end
        scrollFrame:UpdateScrollChildRect();
    end);
    editBox:SetScript("OnEscapePressed", function()
        Clipboard:Hide();
    end);

    frame:SetScript("OnShow", function()
        wasMouseDown = false;
        cursorScrolling = false;
        frame:SetScript("OnUpdate", OnUpdate);
    end);
    frame:SetScript("OnHide", function()
        frame:SetScript("OnUpdate", nil);
        Clipboard.sender = nil;
        cursorScrolling = false;
        Clipboard:StopThumbDrag();
        editBox:SetText("");
        editBox:ClearFocus();
    end);

    Init = nil;
end

-- sender: the Copy Text button that asked, so a second click on it closes the window again.
-- selectAll: focus the box and select everything, ready for Ctrl+C.
-- width, height (optional): window size, the default 480 x 480 when omitted (the link window is small).
function Clipboard:ShowContent(text, sender, selectAll, width, height)
    if Init then
        Init();
    end
    width, height = width or FRAME_WIDTH, height or FRAME_HEIGHT;
    frame:SetWidth(width);
    frame:SetHeight(height);
    editBox:SetWidth(width - 3 * FRAME_INSET - SCROLLBAR_WIDTH);
    VIEW_HEIGHT = height - 2 * FRAME_INSET;
    editBox:SetText(text);
    scrollRange = -1;           -- measured again by the next update
    scrollFrame:SetVerticalScroll(0);
    frame:Show();
    self.sender = sender;
    if selectAll then
        editBox:SetFocus();
        editBox:HighlightText();
    end
end

function Clipboard:IsFromSameSender(sender)
    return self.sender ~= nil and self.sender == sender
end

function Clipboard:CloseIfFromSameSender(sender)
    if self:IsFromSameSender(sender) then
        self:Hide();
        return true
    end
    return false
end

function Clipboard:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Clipboard:Hide()
    if frame then
        frame:Hide();
    end
end

function Clipboard:CloseIfShown()
    if self:IsShown() then
        frame:Hide();
        return true
    end
    return false
end


---------------------------------------------------------------------------
-- Copy Text button
---------------------------------------------------------------------------

local BUTTON_SIZE = 24;
local ICON_SIZE = 16;
local ALPHA_UNFOCUSED = 0.6;
local THEME_SLOT_WIDTH = 0.125;             -- the sheet is 256 wide, one 32 px icon per theme

local tooltip;

local function ShowButtonTooltip(button)
    tooltip = tooltip or addon.CreateTooltipFrame();
    tooltip:Hide();
    tooltip:Clear();
    tooltip:SetTitle(button.tooltipText or L["Copy Text"]);
    tooltip:SetOwnerAnchor(button);
    tooltip.frame:ClearAllPoints();
    tooltip.frame:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2);      -- the button sits in the top right corner
    tooltip:Show();
end

local function HideButtonTooltip()
    if tooltip then
        tooltip:Hide();
    end
end

local function SetButtonTheme(button, themeID)
    local x = THEME_SLOT_WIDTH * ((themeID or 1) - 1);
    button.icon:SetTexCoord(x, x + THEME_SLOT_WIDTH, 0, 1);
end

-- tooltipText (optional): hover text, "Copy Text" when omitted.
function addon.CreateCopyTextButton(parent, onClickFunc, themeID, tooltipText)
    local button = CreateFrame("Button", nil, parent);
    button.tooltipText = tooltipText;
    button:SetWidth(BUTTON_SIZE);
    button:SetHeight(BUTTON_SIZE);
    button:RegisterForClicks("LeftButtonUp");

    local icon = button:CreateTexture(nil, "OVERLAY");
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("CENTER", button, "CENTER", 0, 0);
    icon:SetTexture(BUTTON_FILE);
    icon:SetAlpha(ALPHA_UNFOCUSED);
    button.icon = icon;

    function button:SetTheme(id)
        SetButtonTheme(self, id);
    end

    button:SetScript("OnClick", onClickFunc);
    button:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(1);
        ShowButtonTooltip(self);
    end);
    button:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(ALPHA_UNFOCUSED);
        HideButtonTooltip();
    end);
    button:SetScript("OnHide", function(self)
        self.icon:SetAlpha(ALPHA_UNFOCUSED);
        HideButtonTooltip();
    end);

    SetButtonTheme(button, themeID);
    copyTextButtons[#copyTextButtons + 1] = button;
    return button
end
