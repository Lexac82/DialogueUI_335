local _, addon = ...;

-- Menu that opens under a dropdown button of the Settings (port of retail's Settings_DropdownMenu.lua).
-- Retail builds it from DUIDropdownMenuTemplate (XML with texture slicing); here it is Lua + NineSlice:CreateTiled.
-- A long list is shown in pages of MAX_BUTTON_PER_PAGE entries: arrows at the bottom and the mouse wheel turn the page.
--
-- DropdownMenu:Open(owner, parent, data)
--   owner:  the dropdown button. Uses owner:OnMenuClosed() (optional) and owner:IsInRange() (optional, false closes the menu).
--   parent: frame the menu is drawn in (the Settings window).
--   data:   choices     array of {name = shown text, dbValue = value}
--           getFontFile optional function(choice) returning the font file the name is drawn in
--           getSelected function returning the dbValue that is chosen now
--           onSelect    function(dbValue) called on a click; the menu stays open
--           menuWidth   width of the menu (at least as wide as the button)
local API = addon.API;
local ThemeUtil = addon.ThemeUtil;
local FontUtil = addon.FontUtil;
local NineSlice = addon.NineSlice;
local CallbackRegistry = addon.CallbackRegistry;

local CreateFrame = CreateFrame;
local IsMouseButtonDown = IsMouseButtonDown;
local PlaySound = PlaySound;
local ceil = math.ceil;
local max = math.max;
local min = math.min;

-- Retail values.
local BG_MAX_SIZE = 340;
local MAX_BUTTON_PER_PAGE = 8;
local BUTTON_TEXT_OFFSET_X = 12;
local BUTTON_PUSH_OFFSET = 1;
local BUTTON_HEIGHT = 24;
local MENU_BUTTON_PADDING = 8;              -- top and bottom
local TEXT_HEIGHT = 12;
local MIN_TEXT_HEIGHT = 9;                  -- a name wider than the menu is made smaller, down to this
local DEFAULT_MENU_WIDTH = 260;              -- retail fits the menu to the longest name, which needs every font loaded first

-- Same texel size as the Settings window (0.75 units per screen pixel).
local TEXEL = 0.75;
local BACKGROUND_INSET = 7 * TEXEL;

local COMPONENT_FILE = "DropdownMenu-Component.blp";      -- 1024 x 512 sheet
local BACKGROUND_FILE = "DropdownMenu-Background.blp";
local HIGHLIGHT_FILE = "Settings-ButtonHighlight.blp";
local ARROW_FILE = "Settings-ArrowOption.blp";

local DropdownMenu = {};
addon.DropdownMenu = DropdownMenu;

local menu;                                 -- the one menu, made on first use

local function GetMenuTextColor()
    -- Retail's DUIFont_MenuButton_Normal colors.
    return ThemeUtil:GetColor(ThemeUtil:IsDarkMode() and "DarkModeGrey90" or "DarkBrown")
end

---------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------

local function Button_OnClick(self, mouseButton)
    if mouseButton == "LeftButton" then
        local data = menu.data;
        if data and self.choice then
            PlaySound("igMainMenuOptionCheckBoxOn");
            data.onSelect(self.choice.dbValue);
            menu:UpdateSelected();
        end
    else
        menu:Hide();
    end
end

local function CreateMenuButton()
    local button = CreateFrame("Button", nil, menu);
    button:SetFrameLevel(menu.baseLevel + 3);
    button:SetHeight(BUTTON_HEIGHT);
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp");

    local text = button:CreateFontString(nil, "OVERLAY");
    text:SetFontObject(FontUtil:GetQuestFont("DUI335_MenuButton", TEXT_HEIGHT));
    text:SetJustifyH("LEFT");
    text:SetJustifyV("MIDDLE");
    text:SetPoint("LEFT", button, "LEFT", BUTTON_TEXT_OFFSET_X, 0);
    button.text = text;

    button:SetScript("OnEnter", function(self)
        menu:HighlightButton(self);
    end);
    button:SetScript("OnLeave", function()
        menu:HighlightButton(nil);
    end);
    button:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            self.text:SetPoint("LEFT", self, "LEFT", BUTTON_TEXT_OFFSET_X + BUTTON_PUSH_OFFSET, 0);
        end
    end);
    button:SetScript("OnMouseUp", function(self)
        self.text:SetPoint("LEFT", self, "LEFT", BUTTON_TEXT_OFFSET_X, 0);
    end);
    button:SetScript("OnClick", Button_OnClick);
    return button
end

-- Loading a font file is slow (a big font can take tens of milliseconds), so a page does not load its 8 fonts in one
-- frame. The names appear at once in the default font, and one name per frame gets its own font (Menu_OnUpdate).
local function SetPlainText(button, name)
    button.text:SetFont(FontUtil:GetFontFile("default"), TEXT_HEIGHT, "");
    button.text:SetTextColor(GetMenuTextColor());
    button.text:SetText(name);
end

-- The name in its own font, made smaller until it fits the entry. A font that cannot be loaded keeps the default.
local function SetPreviewFont(button, fontFile, buttonWidth)
    local text = button.text;
    if not (fontFile and text:SetFont(fontFile, TEXT_HEIGHT, "")) then
        return
    end
    local available = buttonWidth - 2 * BUTTON_TEXT_OFFSET_X;
    local height = TEXT_HEIGHT;
    while text:GetStringWidth() > available and height > MIN_TEXT_HEIGHT do
        height = height - 1;
        text:SetFont(fontFile, height, "");
    end
end

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

-- Background crop, border and shadow follow the size (retail OnSizeChanged).
local function Layout(self, width, height)
    local size = max(width, height);
    local scale = size / BG_MAX_SIZE;
    local w, h = width, height;
    if scale > 1 then
        w = width / scale;
        h = height / scale;
    end
    self.background:SetTexCoord(0, w / BG_MAX_SIZE, 0, h / BG_MAX_SIZE);
    self.border:Update(width, height);

    local shadowWidth = (294 / 256) * w;
    local shadowHeight = 128 / 336 * w;
    local edgeWidth = 32 / 336 * shadowWidth;
    local offsetY = -26 / 336 * shadowWidth;
    local shadow = self.shadow;
    shadow.left:ClearAllPoints();
    shadow.left:SetPoint("BOTTOMLEFT", self, "BOTTOM", -0.5 * shadowWidth, offsetY);
    shadow.left:SetWidth(edgeWidth);
    shadow.left:SetHeight(shadowHeight);
    shadow.right:ClearAllPoints();
    shadow.right:SetPoint("BOTTOMRIGHT", self, "BOTTOM", 0.5 * shadowWidth, offsetY);
    shadow.right:SetWidth(edgeWidth);
    shadow.right:SetHeight(shadowHeight);
end

function DropdownMenu:HighlightButton(button)
    local highlight = self.highlightFrame;
    highlight:Hide();
    highlight:ClearAllPoints();
    if button and button:IsEnabled() then
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, 0);
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 0);
        self.highlight:Update(button:GetWidth() - 4, button:GetHeight());
        highlight:Show();
    end
end

-- Puts the check mark on the entry that is chosen now (if it is on this page).
function DropdownMenu:UpdateSelected()
    local icon = self.selectedFrame;
    icon:Hide();
    icon:ClearAllPoints();
    local selected = self.data and self.data.getSelected();
    for i = 1, MAX_BUTTON_PER_PAGE do
        local button = self.buttons[i];
        if button and button:IsShown() and button.choice and button.choice.dbValue == selected then
            icon:SetPoint("CENTER", button, "LEFT", 0, 0);
            icon:Show();
            return
        end
    end
end

local function EnableArrow(arrow, enabled)
    if enabled then
        arrow:Enable();
        arrow.texture:SetAlpha(1);
    else
        arrow:Disable();
        arrow.texture:SetAlpha(0);
    end
end

function DropdownMenu:ShowPage(page)
    local data = self.data;
    local choices = data.choices;
    local total = #choices;
    local maxPage = max(1, ceil(total / MAX_BUTTON_PER_PAGE));
    page = API.Clamp(page, 1, maxPage);
    self.page = page;
    self.maxPage = maxPage;

    local scrollable = maxPage > 1;
    if scrollable then
        self.nav:Show();
    else
        self.nav:Hide();
    end
    self.pageText:SetText(page .. " / " .. maxPage);
    EnableArrow(self.leftArrow, page > 1);
    EnableArrow(self.rightArrow, page < maxPage);

    local buttonWidth = max(data.menuWidth or DEFAULT_MENU_WIDTH, self.owner:GetWidth() + 4);
    local firstIndex = (page - 1) * MAX_BUTTON_PER_PAGE;
    local shown = 0;

    self.pending = nil;
    for i = 1, MAX_BUTTON_PER_PAGE do
        local button = self.buttons[i];
        local choice = choices[firstIndex + i];
        if choice then
            shown = i;
            if not button then
                button = CreateMenuButton();
                self.buttons[i] = button;
            end
            button.choice = choice;
            button:ClearAllPoints();
            button:SetPoint("TOP", self, "TOP", 0, -MENU_BUTTON_PADDING - (i - 1) * BUTTON_HEIGHT);
            button:SetWidth(buttonWidth);
            SetPlainText(button, choice.name);
            button:Show();
        elseif button then
            button.choice = nil;
            button:Hide();
        end
    end

    -- Entries that have a font of their own: loaded one per frame, then once more (retail: some fonts show only
    -- after the second load).
    if data.getFontFile then
        self.pending = { next = 1, pass = 1, count = shown, width = buttonWidth };
    end

    local numButtons = scrollable and MAX_BUTTON_PER_PAGE or shown;
    local footer = scrollable and BUTTON_HEIGHT or MENU_BUTTON_PADDING;
    local width = buttonWidth;
    local height = numButtons * BUTTON_HEIGHT + footer + MENU_BUTTON_PADDING;
    self:SetWidth(width);
    self:SetHeight(height);
    Layout(self, width, height);

    self:HighlightButton(nil);
    self:UpdateSelected();
end

local function Menu_OnMouseWheel(self, delta)
    if not self.data then
        return
    end
    if delta > 0 then
        if self.page > 1 then
            self:ShowPage(self.page - 1);
        end
    elseif self.page < self.maxPage then
        self:ShowPage(self.page + 1);
    end
end

-- Closes on a click away from the menu and its button (3.3.5a has no GLOBAL_MOUSE_DOWN), and when the button has
-- been scrolled out of the list. Also gives one entry per frame its own font.
local function Menu_OnUpdate(self, elapsed)
    local owner = self.owner;
    if not owner or not owner:IsVisible() then
        self:Hide();
        return
    end
    if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
        and not self:IsMouseOver() and not owner:IsMouseOver() then
        self:Hide();
        return
    end
    if owner.IsInRange and not owner:IsInRange() then
        self:Hide();
        return
    end
    local pending = self.pending;
    if pending and self.data then
        local button = self.buttons[pending.next];
        if button and button.choice then
            SetPreviewFont(button, self.data.getFontFile(button.choice), pending.width);
        end
        pending.next = pending.next + 1;
        if pending.next > pending.count then
            if pending.pass == 1 then
                pending.pass = 2;
                pending.next = 1;
            else
                self.pending = nil;
            end
        end
    end
end

local function Menu_OnHide(self)
    self:SetScript("OnUpdate", nil);
    self:ClearAllPoints();
    self:HighlightButton(nil);
    self.selectedFrame:Hide();
    local owner = self.owner;
    self.owner = nil;
    self.data = nil;
    if owner and owner.OnMenuClosed then
        owner:OnMenuClosed();
    end
end

local function CreateArrow(nav, delta, offsetX)
    local button = CreateFrame("Button", nil, nav);
    button:SetWidth(18);
    button:SetHeight(18);
    button:SetPoint("CENTER", nav, "CENTER", offsetX, 0);
    button:RegisterForClicks("LeftButtonUp");

    local texture = button:CreateTexture(nil, "BACKGROUND");
    texture:SetWidth(14);
    texture:SetHeight(14);
    texture:SetPoint("CENTER", button, "CENTER", 0, 0);
    ThemeUtil:BindTexture(texture, ARROW_FILE);
    button.texture = texture;

    local glow = button:CreateTexture(nil, "HIGHLIGHT");
    glow:SetAllPoints(texture);
    ThemeUtil:BindTexture(glow, ARROW_FILE);

    if delta > 0 then       -- previous page: the arrow points left
        texture:SetTexCoord(0.5, 0, 0, 0.5);
        glow:SetTexCoord(1, 0.5, 0, 0.5);
    else
        texture:SetTexCoord(0, 0.5, 0, 0.5);
        glow:SetTexCoord(0.5, 1, 0, 0.5);
    end

    button:SetScript("OnClick", function()
        Menu_OnMouseWheel(menu, delta);
    end);
    return button
end

local function CreateMenu(parent)
    local f = CreateFrame("Frame", nil, parent);
    f:Hide();
    f:EnableMouse(true);
    f:EnableMouseWheel(true);
    f.buttons = {};
    -- The frame is the menu: it needs the methods (the DropdownMenu table only is the public entry).
    f.HighlightButton = DropdownMenu.HighlightButton;
    f.UpdateSelected = DropdownMenu.UpdateSelected;
    f.ShowPage = DropdownMenu.ShowPage;

    -- Drop shadow under the bottom edge: three pieces of the component sheet (136..265 of 512 rows).
    local shadow = {};
    shadow.left = f:CreateTexture(nil, "BACKGROUND");
    shadow.center = f:CreateTexture(nil, "BACKGROUND");
    shadow.right = f:CreateTexture(nil, "BACKGROUND");
    shadow.left:SetTexCoord(0, 32 / 1024, 136 / 512, 265 / 512);
    shadow.center:SetTexCoord(32 / 1024, 304 / 1024, 136 / 512, 265 / 512);
    shadow.right:SetTexCoord(304 / 1024, 336 / 1024, 136 / 512, 265 / 512);
    shadow.center:SetPoint("TOPLEFT", shadow.left, "TOPRIGHT", 0, 0);
    shadow.center:SetPoint("BOTTOMRIGHT", shadow.right, "BOTTOMLEFT", 0, 0);
    for _, piece in pairs(shadow) do
        ThemeUtil:BindTexture(piece, COMPONENT_FILE);
    end
    f.shadow = shadow;

    local background = f:CreateTexture(nil, "BACKGROUND");
    background:SetPoint("TOPLEFT", f, "TOPLEFT", BACKGROUND_INSET, -BACKGROUND_INSET);
    background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -BACKGROUND_INSET, BACKGROUND_INSET);
    ThemeUtil:BindTexture(background, BACKGROUND_FILE);
    f.background = background;

    -- Frame levels are set in SetOwner, relative to the menu.
    local borderFrame = CreateFrame("Frame", nil, f);
    borderFrame:SetAllPoints(f);
    f.borderFrame = borderFrame;
    f.border = NineSlice:CreateTiled(borderFrame, ThemeUtil:GetTextureFile(COMPONENT_FILE), { 256, 128 }, 16, TEXEL,
        "BACKGROUND", { 0, 0, 1024, 512 });
    ThemeUtil:BindSlice(f.border, COMPONENT_FILE);

    local highlightFrame = CreateFrame("Frame", nil, f);
    highlightFrame:Hide();
    f.highlightFrame = highlightFrame;
    f.highlight = NineSlice:CreateTiled(highlightFrame, ThemeUtil:GetTextureFile(HIGHLIGHT_FILE), { 128, 64 }, 24, 1,
        "BACKGROUND");
    ThemeUtil:BindSlice(f.highlight, HIGHLIGHT_FILE);

    local selectedFrame = CreateFrame("Frame", nil, f);
    selectedFrame:SetWidth(32);
    selectedFrame:SetHeight(32);
    selectedFrame:Hide();
    local selectedTexture = selectedFrame:CreateTexture(nil, "OVERLAY");
    selectedTexture:SetAllPoints(selectedFrame);
    selectedTexture:SetTexCoord(0, 64 / 1024, 272 / 512, 336 / 512);
    ThemeUtil:BindTexture(selectedTexture, COMPONENT_FILE);
    f.selectedFrame = selectedFrame;

    -- Page navigation along the bottom edge.
    local nav = CreateFrame("Frame", nil, f);
    nav:SetHeight(BUTTON_HEIGHT);
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0);
    nav:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0);
    nav:Hide();
    f.nav = nav;
    local navBackground = nav:CreateTexture(nil, "ARTWORK");
    navBackground:SetWidth(4 * BUTTON_HEIGHT);
    navBackground:SetHeight(BUTTON_HEIGHT);
    navBackground:SetPoint("CENTER", nav, "CENTER", 0, 0);
    navBackground:SetTexCoord(0, 192 / 1024, 336 / 512, 384 / 512);
    ThemeUtil:BindTexture(navBackground, COMPONENT_FILE);
    local pageText = nav:CreateFontString(nil, "OVERLAY");
    pageText:SetFontObject(FontUtil:GetColoredFont("DUI335_MenuPage", 10, { "DarkBrown", "DarkModeGrey90" }));
    pageText:SetPoint("CENTER", nav, "CENTER", 0, 0);
    f.pageText = pageText;
    f.leftArrow = CreateArrow(nav, 1, -32);
    f.rightArrow = CreateArrow(nav, -1, 32);

    f:SetScript("OnMouseWheel", Menu_OnMouseWheel);
    f:SetScript("OnHide", Menu_OnHide);
    return f
end

-- Frame levels above the owner: border, highlight, the entries, the check mark, the page arrows.
local function SetLevels(self, ownerLevel)
    local base = ownerLevel + 10;
    self.baseLevel = base;
    self:SetFrameLevel(base);
    self.borderFrame:SetFrameLevel(base + 1);
    self.highlightFrame:SetFrameLevel(base + 2);
    self.nav:SetFrameLevel(base + 3);
    self.leftArrow:SetFrameLevel(base + 4);
    self.rightArrow:SetFrameLevel(base + 4);
    self.selectedFrame:SetFrameLevel(base + 4);
    for _, button in pairs(self.buttons) do
        button:SetFrameLevel(base + 3);
    end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

function DropdownMenu:Open(owner, parent, data)
    if not menu then
        menu = CreateMenu(parent);
    end
    if menu:IsShown() then
        menu:Hide();            -- the previous owner hears that its menu closed
    end

    menu.owner = owner;
    menu.data = data;
    menu:ClearAllPoints();
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", -2, 0);
    SetLevels(menu, owner:GetFrameLevel());
    menu:Show();
    menu:SetScript("OnUpdate", Menu_OnUpdate);

    -- Start on the page of the chosen entry.
    local page = 1;
    local selected = data.getSelected();
    for i, choice in ipairs(data.choices) do
        if choice.dbValue == selected then
            page = ceil(i / MAX_BUTTON_PER_PAGE);
            break
        end
    end
    menu:ShowPage(page);
end

function DropdownMenu:Close()
    if menu and menu:IsShown() then
        menu:Hide();
    end
end

function DropdownMenu:IsOpenFor(owner)
    return menu and menu:IsShown() and menu.owner == owner
end

-- The menu draws the theme's art when it is made, so it is closed on a theme change instead of being redrawn.
CallbackRegistry:Register("SettingsUI.Hide", function() DropdownMenu:Close(); end);
CallbackRegistry:Register("SettingsUI.TabChanged", function() DropdownMenu:Close(); end);
CallbackRegistry:Register("ThemeChanged", function() DropdownMenu:Close(); end);
