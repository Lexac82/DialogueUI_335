local _, addon = ...;

-- Settings window. Port of retail's Settings.xml / Settings.lua layout (frame, header with tabs and close button,
-- header divider, option list on the left, description on the right). The tabs are empty for now.
-- Retail builds this in XML with texture slicing; 3.3.5a has neither, so it is Lua + NineSlice:CreateTiled.
local L = addon.L;
local API = addon.API;
local NineSlice = addon.NineSlice;
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local CallbackRegistry = addon.CallbackRegistry;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local SetOverrideBindingClick = SetOverrideBindingClick;
local ClearOverrideBindings = ClearOverrideBindings;
local PlaySound = PlaySound;
local Round = API.Round;
local upper = string.upper;
local max = math.max;

-- Retail values (Settings.lua) at the default font height 12.
local FRAME_PADDING = 14;
local BUTTON_PADDING_LARGE = 12;
local FONT_HEIGHT = 12;
local TAB_BUTTON_GAP = 4;
local OPTIONBUTTON_HEIGHT = FONT_HEIGHT + 2 * BUTTON_PADDING_LARGE;         -- 36
local OPTIONBUTTON_WIDTH = OPTIONBUTTON_HEIGHT * 12;                        -- 432
local NUM_VISIBLE_OPTIONS = 10.5;
local GAP_TO_HEADER = 12;
local TAB_HEIGHT = FONT_HEIGHT + 2 * BUTTON_PADDING_LARGE;                  -- 36
local TAB_MIN_WIDTH = 2 * TAB_HEIGHT;                                       -- 72
local DIVIDER_THICKNESS = 9;

-- Frame background: GenericFrame-Tiled-Large, 80 px corners, with a 16 px transparent drop shadow around it.
local BACKGROUND_SCALE = 0.75;                  -- drawn size of one texel (retail: pixel-perfect, ~0.71 at 1080p)
local BACKGROUND_SHADOW = 16 * BACKGROUND_SCALE;
local SELECTION_SCALE = 0.75;

local TAB_ENTRIES = {
    { name = L["UI"] },
    { name = L["Control"] },
    { name = L["Gameplay"] },
};

local TOGGLE_NAME = "DialogueUI335SettingsToggle";      -- global names so key bindings can click them
local CLOSE_NAME = "DialogueUI335SettingsClose";

local SettingsUI = {};
addon.SettingsUI = SettingsUI;

local frame;


---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

-- Three-piece divider: two end caps keep their shape, the middle stretches. Retail slices these with margins
-- (H: left/right 32, V: top/bottom 32) and draws them 9 px thick.
local function CreateDivider(parent, file, isVertical)
    local f = CreateFrame("Frame", nil, parent);
    local cap = 32 / 256;
    local capSize = 32 * DIVIDER_THICKNESS / 16;

    local first = f:CreateTexture(nil, "ARTWORK");
    local middle = f:CreateTexture(nil, "ARTWORK");
    local last = f:CreateTexture(nil, "ARTWORK");
    f.pieces = { first, middle, last };

    if isVertical then
        first:SetTexCoord(0, 1, 0, cap);
        middle:SetTexCoord(0, 1, cap, 1 - cap);
        last:SetTexCoord(0, 1, 1 - cap, 1);
        first:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
        first:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0);
        first:SetHeight(capSize);
        last:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
        last:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
        last:SetHeight(capSize);
        middle:SetPoint("TOPLEFT", first, "BOTTOMLEFT", 0, 0);
        middle:SetPoint("BOTTOMRIGHT", last, "TOPRIGHT", 0, 0);
        f:SetWidth(DIVIDER_THICKNESS);
    else
        first:SetTexCoord(0, cap, 0, 1);
        middle:SetTexCoord(cap, 1 - cap, 0, 1);
        last:SetTexCoord(1 - cap, 1, 0, 1);
        first:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0);
        first:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
        first:SetWidth(capSize);
        last:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0);
        last:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
        last:SetWidth(capSize);
        middle:SetPoint("TOPLEFT", first, "TOPRIGHT", 0, 0);
        middle:SetPoint("BOTTOMRIGHT", last, "BOTTOMLEFT", 0, 0);
        f:SetHeight(DIVIDER_THICKNESS);
    end

    for i = 1, 3 do
        f.pieces[i]:SetTexture(file);
    end
    return f
end

-- Drags the whole window from any of its mouse-enabled parts.
local function ForwardDrag(object)
    object:RegisterForDrag("LeftButton");
    object:SetScript("OnDragStart", function()
        frame:StartMoving();
    end);
    object:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing();
    end);
end


---------------------------------------------------------------------------
-- Close button (retail Header.CloseButton)
---------------------------------------------------------------------------

local CLOSE_SHEET = { 0, 0, 256, 128 };
local CLOSE_HIGHLIGHT_SHEET = { 128, 0, 256, 128 };

local function CreateCloseButton(parent)
    local button = CreateFrame("Button", nil, parent);
    button:SetWidth(TAB_MIN_WIDTH);
    button:SetHeight(TAB_HEIGHT);
    button:RegisterForClicks("LeftButtonUp");

    local file = ThemeUtil:GetTextureFile("Settings-CloseButton.blp");
    local level = button:GetFrameLevel();

    -- Background and hover glow are 128x64 cells of the 256x128 sheet, sliced with 16 px corners.
    local backFrame = CreateFrame("Frame", nil, button);
    backFrame:SetAllPoints(button);
    backFrame:SetFrameLevel(level);
    button.background = NineSlice:CreateTiled(backFrame, file, { 128, 64 }, 16, 1, "BACKGROUND", CLOSE_SHEET);
    button.background:Update(TAB_MIN_WIDTH, TAB_HEIGHT);

    local highlightFrame = CreateFrame("Frame", nil, button);
    highlightFrame:SetAllPoints(button);
    highlightFrame:SetFrameLevel(level + 1);
    button.highlight = NineSlice:CreateTiled(highlightFrame, file, { 128, 64 }, 16, 1, "ARTWORK", CLOSE_HIGHLIGHT_SHEET);
    button.highlight:Update(TAB_MIN_WIDTH, TAB_HEIGHT);
    button.highlight:SetShown(false);

    local iconFrame = CreateFrame("Frame", nil, button);
    iconFrame:SetAllPoints(button);
    iconFrame:SetFrameLevel(level + 2);
    local icon = iconFrame:CreateTexture(nil, "OVERLAY");
    icon:SetTexture(file);
    icon:SetTexCoord(0.0625, 0.1875, 0.625, 0.875);
    icon:SetWidth(FONT_HEIGHT);
    icon:SetHeight(FONT_HEIGHT);
    icon:SetPoint("CENTER", button, "CENTER", 0, 0);
    button.icon = icon;

    button:SetScript("OnEnter", function(self)
        self.highlight:SetShown(true);
    end);
    button:SetScript("OnLeave", function(self)
        self.highlight:SetShown(false);
    end);
    button:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("CENTER", self, "CENTER", 0, -1);
    end);
    button:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0);
    end);
    button:SetScript("OnClick", function()
        SettingsUI:Hide();
        PlaySound("igMainMenuOptionCheckBoxOn");
    end);
    button:SetScript("OnHide", function(self)
        self.highlight:SetShown(false);
        self.icon:SetPoint("CENTER", self, "CENTER", 0, 0);
    end);
    ForwardDrag(button);

    return button
end


---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local NormalTabFont, SelectedTabFont;

local function Tab_SetSelected(button, selected)
    button.isSelected = selected;
    button.Name:SetFontObject(selected and SelectedTabFont or NormalTabFont);
end

local function CreateTabButton(parent, tabID, name)
    local button = CreateFrame("Button", nil, parent);
    button:RegisterForClicks("LeftButtonUp");
    button.tabID = tabID;

    button.Name = button:CreateFontString(nil, "OVERLAY");
    button.Name:SetFontObject(NormalTabFont);
    button.Name:SetPoint("CENTER", button, "CENTER", 0, 0);
    button.Name:SetText(upper(name));

    local width = max(TAB_MIN_WIDTH, Round(button.Name:GetStringWidth() + 2 * FONT_HEIGHT));
    button:SetWidth(width);
    button:SetHeight(TAB_HEIGHT);

    button:SetScript("OnEnter", function(self)
        SettingsUI:HighlightButton(self);
    end);
    button:SetScript("OnLeave", function()
        SettingsUI:HighlightButton(nil);
    end);
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" and not self.isSelected then
            self.Name:SetPoint("CENTER", self, "CENTER", 0, -1);
        end
    end);
    button:SetScript("OnMouseUp", function(self)
        self.Name:SetPoint("CENTER", self, "CENTER", 0, 0);
    end);
    button:SetScript("OnClick", function(self)
        SettingsUI:SelectTab(self.tabID);
    end);
    ForwardDrag(button);

    return button
end


---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local function CreateSettingsFrame()
    NormalTabFont = FontUtil:GetQuestFont("DUI335_SettingsTab", FONT_HEIGHT);               -- dark brown, on paper
    SelectedTabFont = FontUtil:GetColoredFont("DUI335_SettingsTabSelected", FONT_HEIGHT, { 0.87, 0.86, 0.75 });   -- cream, on the dark selection

    local f = CreateFrame("Frame", "DialogueUI335Settings", UIParent);
    frame = f;
    f:SetFrameStrata("DIALOG");
    f:SetToplevel(true);
    f:EnableMouse(true);
    f:SetMovable(true);
    f:SetClampedToScreen(true);
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
    f:Hide();
    ForwardDrag(f);

    -- Retail geometry: the option list is OPTIONBUTTON_WIDTH wide and 10.5 rows tall, the frame width puts the
    -- list and the description area in the golden ratio.
    local listWidth = OPTIONBUTTON_WIDTH;
    local listHeight = NUM_VISIBLE_OPTIONS * OPTIONBUTTON_HEIGHT;
    local frameWidth = Round((listWidth + 1.5 * FRAME_PADDING) / 0.618);
    local frameHeight = FRAME_PADDING + TAB_HEIGHT + GAP_TO_HEADER + listHeight + FRAME_PADDING;
    local rightAreaWidth = Round(frameWidth - listWidth - 2 * FRAME_PADDING);
    local descriptionWidth = Round(frameWidth - listWidth - 3 * FRAME_PADDING - BUTTON_PADDING_LARGE);
    f:SetWidth(frameWidth);
    f:SetHeight(frameHeight);

    local baseLevel = f:GetFrameLevel();

    -- Background with the drop shadow outside the frame edge.
    local background = CreateFrame("Frame", nil, f);
    background:SetFrameLevel(baseLevel);
    background:SetPoint("TOPLEFT", f, "TOPLEFT", -BACKGROUND_SHADOW, BACKGROUND_SHADOW);
    background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", BACKGROUND_SHADOW, -BACKGROUND_SHADOW);
    f.backgroundSlice = NineSlice:CreateTiled(background, ThemeUtil:GetTextureFile("GenericFrame-Tiled-Large.blp"),
        { 512, 512 }, 80, BACKGROUND_SCALE, "BACKGROUND");
    f.backgroundSlice:Update(frameWidth + 2 * BACKGROUND_SHADOW, frameHeight + 2 * BACKGROUND_SHADOW);

    -- Dividers and description sit on one frame above the background.
    local content = CreateFrame("Frame", nil, f);
    content:SetFrameLevel(baseLevel + 1);
    content:SetAllPoints(f);
    f.content = content;

    -- Header: tab buttons on the left, close button on the right.
    local header = CreateFrame("Frame", nil, f);
    header:SetFrameLevel(baseLevel + 2);
    header:SetPoint("TOPLEFT", f, "TOPLEFT", FRAME_PADDING, -FRAME_PADDING);
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -FRAME_PADDING, -FRAME_PADDING);
    header:SetHeight(TAB_HEIGHT);
    f.header = header;

    -- Dark plate behind the selected tab. Its own frame so it stays under the tab text.
    local selectionFrame = CreateFrame("Frame", nil, header);
    selectionFrame:SetFrameLevel(baseLevel + 2);
    selectionFrame:Hide();
    f.selectionFrame = selectionFrame;
    f.selection = NineSlice:CreateTiled(selectionFrame, ThemeUtil:GetTextureFile("Settings-TabButton-Selection.blp"),
        { 128, 64 }, 16, SELECTION_SCALE, "BACKGROUND");

    -- Hover glow shared by the tab buttons.
    local highlightFrame = CreateFrame("Frame", nil, header);
    highlightFrame:Hide();
    f.highlightFrame = highlightFrame;
    f.highlight = NineSlice:CreateTiled(highlightFrame, ThemeUtil:GetTextureFile("Settings-ButtonHighlight.blp"),
        { 128, 64 }, 24, 1, "BACKGROUND");

    f.closeButton = CreateCloseButton(header);
    f.closeButton:SetFrameLevel(baseLevel + 4);
    f.closeButton:SetPoint("RIGHT", header, "RIGHT", 0, 0);

    f.tabButtons = {};
    for i, entry in ipairs(TAB_ENTRIES) do
        local button = CreateTabButton(header, i, entry.name);
        button:SetFrameLevel(baseLevel + 4);
        if i == 1 then
            button:SetPoint("LEFT", header, "LEFT", 0, 0);
        else
            button:SetPoint("LEFT", f.tabButtons[i - 1], "RIGHT", TAB_BUTTON_GAP, 0);
        end
        f.tabButtons[i] = button;
    end

    -- Line under the header.
    f.headerDivider = CreateDivider(content, ThemeUtil:GetTextureFile("Settings-Divider-H.blp"), false);
    f.headerDivider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -TAB_BUTTON_GAP);
    f.headerDivider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -TAB_BUTTON_GAP);

    -- Option list (left). One page per tab; the options will be placed on the pages.
    local list = CreateFrame("Frame", nil, f);
    list:SetFrameLevel(baseLevel + 2);
    list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -GAP_TO_HEADER);
    list:SetWidth(listWidth);
    list:SetHeight(listHeight);
    f.list = list;

    f.pages = {};
    for i = 1, #TAB_ENTRIES do
        local page = CreateFrame("Frame", nil, list);
        page:SetAllPoints(list);
        page:Hide();
        f.pages[i] = page;
    end

    -- Line between the list and the description. Retail anchors it to the scroll bar (list right + 4).
    f.verticalDivider = CreateDivider(content, ThemeUtil:GetTextureFile("Settings-Divider-V.blp"), true);
    f.verticalDivider:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0);
    f.verticalDivider:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 8, 0);

    -- Description (right). Preview picture slot first, text below it, as retail.
    local previewShrink = 1;
    local previewWidth = descriptionWidth - 2 * previewShrink;
    local preview = CreateFrame("Frame", nil, f);
    preview:SetFrameLevel(baseLevel + 2);
    preview:SetWidth(previewWidth);
    preview:SetHeight(0.5 * previewWidth);
    preview:SetPoint("TOP", f, "TOPRIGHT", -rightAreaWidth * 0.5 - previewShrink, -(TAB_HEIGHT + 2.5 * FRAME_PADDING));
    preview:Hide();                 -- no preview pictures yet
    f.preview = preview;

    local description = content:CreateFontString(nil, "OVERLAY");
    description:SetFontObject(FontUtil:GetQuestFont("DUI335_SettingsDescription", FONT_HEIGHT));
    description:SetJustifyH("LEFT");
    description:SetJustifyV("TOP");
    description:SetSpacing(4);
    description:SetWidth(descriptionWidth);
    description:SetPoint("TOP", preview, "TOP", 0, -8);
    f.description = description;

    -- Keys while the window is open: Esc and F1 close it.
    f:SetScript("OnShow", function()
        SettingsUI:UpdateKeys();
        CallbackRegistry:Trigger("SettingsUI.Show");
    end);
    f:SetScript("OnHide", function()
        SettingsUI:UpdateKeys();
        CallbackRegistry:Trigger("SettingsUI.Hide");
    end);

    f.keysEvents = CreateFrame("Frame");
    f.keysEvents:RegisterEvent("PLAYER_REGEN_ENABLED");
    f.keysEvents:SetScript("OnEvent", function()
        if f.keysDirty then
            SettingsUI:UpdateKeys();
        end
    end);

    return f
end


---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function SettingsUI:HighlightButton(button)
    local f = frame;
    f.highlightFrame:Hide();
    f.highlightFrame:ClearAllPoints();
    -- The selected tab already has the dark plate.
    if button and not button.isSelected then
        f.highlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
        f.highlightFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0);
        f.highlightFrame:SetFrameLevel(button:GetFrameLevel() - 1);
        f.highlight:Update(button:GetWidth(), button:GetHeight());
        f.highlightFrame:Show();
    end
end

function SettingsUI:SelectTab(tabID, silent)
    local f = frame;
    if tabID == f.tabID then
        return
    end
    f.tabID = tabID;

    for i, button in ipairs(f.tabButtons) do
        local selected = (i == tabID);
        Tab_SetSelected(button, selected);
        -- Frame:SetShown does not exist in 3.3.5a.
        if selected then
            f.pages[i]:Show();
        else
            f.pages[i]:Hide();
        end
        if selected then
            f.selectionFrame:ClearAllPoints();
            f.selectionFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);
            f.selectionFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0);
            f.selectionFrame:SetFrameLevel(button:GetFrameLevel() - 1);
            f.selection:Update(button:GetWidth(), button:GetHeight());
            f.selectionFrame:Show();
        end
    end
    self:HighlightButton(nil);
    self:SetDescription(nil);

    if not silent and f:IsVisible() then
        PlaySound("igMainMenuOptionCheckBoxOn");
    end
end

function SettingsUI:SetDescription(text)
    frame.description:SetText(text or "");
end

function SettingsUI:Show()
    frame:Show();
end

function SettingsUI:Hide()
    frame:Hide();
end

function SettingsUI:Toggle()
    if frame:IsShown() then
        frame:Hide();
    else
        frame:Show();
    end
end

function SettingsUI:IsShown()
    return frame:IsShown()
end

-- Override bindings cannot change in combat: apply them when it ends. Esc and F1 click the hidden buttons below.
function SettingsUI:UpdateKeys()
    local f = frame;
    if InCombatLockdown() then
        f.keysDirty = true;
        return
    end
    f.keysDirty = false;
    ClearOverrideBindings(f);
    if f:IsShown() then
        SetOverrideBindingClick(f, true, "ESCAPE", CLOSE_NAME, "LeftButton");
        SetOverrideBindingClick(f, true, "F1", TOGGLE_NAME, "LeftButton");
    end
end

-- Buttons the key bindings click. Shown but empty, so they are invisible.
local function CreateKeyTarget(name, onClick)
    local button = CreateFrame("Button", name, UIParent);
    button:SetWidth(1);
    button:SetHeight(1);
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0);
    button:SetScript("OnClick", onClick);
end

CreateKeyTarget(TOGGLE_NAME, function()
    SettingsUI:Toggle();
end);
CreateKeyTarget(CLOSE_NAME, function()
    SettingsUI:Hide();
end);

CreateSettingsFrame();
SettingsUI:SelectTab(1, true);

SLASH_DIALOGUEUI3351 = "/dui";
SLASH_DIALOGUEUI3352 = "/dialogui";
SlashCmdList["DIALOGUEUI335"] = function()
    SettingsUI:Toggle();
end;
