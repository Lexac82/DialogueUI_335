local _, addon = ...;

-- Book frame for readable items and objects (books, letters, plaques, tombstones).
-- Port of retail's Code/Book/BookUI.lua and BookUI_Component.lua, built in Lua only (no XML).
-- Textures: Textures\Book\TextureKit-Parchment.blp and TextureKit-Metal.blp (same atlas layout, 1024x2048),
-- Textures\Book\ScreenDarken.blp. See docs/Book.md.
--
-- This file: the frame, skins, header with page buttons, scrolling, content layout.
-- BookEvents.lua feeds it from the ITEM_TEXT_* events.

local FontUtil = addon.FontUtil;
local API = addon.API;
local GetDBValue = addon.GetDBValue;
local GetDBBool = addon.GetDBBool;
local SetDBValue = addon.SetDBValue;
local BookFormatter = addon.BookFormatter;
local BookItem = addon.BookItem;

local Round = API.Round;
local Clamp = API.Clamp;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local SetOverrideBindingClick = SetOverrideBindingClick;
local ClearOverrideBindings = ClearOverrideBindings;
local IsShiftKeyDown = IsShiftKeyDown;
local UIParent = UIParent;
local ipairs, pairs, unpack = ipairs, pairs, unpack;
local max, min = math.max, math.min;

local Book = {};
addon.Book = Book;

local frame;        -- main frame, created on first use (Book:Init)


-- Settings ------------------------------------------------------------------------------------------------
-- Defaults are in Initialization.lua. They apply the next time a book opens.
--   BookUISize              frame size 0..4 = 0.9, 1.0, 1.1, 1.25, 1.4
--   BookFontSize            paragraph font size (8..24); headings follow
--   BookDarkenScreen        dark vignette at the left of the screen
--   BookShowLocation        zone and coordinates for books standing in the world
--   BookUIItemDescription   item icon and flavor text above the book
--   BookKeepUIOpen          keep the book open when the game closes the readable (walking away)
--   BookPosition            saved frame position (left-drag)

local SIZE_SCALES = { [0] = 0.9, [1] = 1.0, [2] = 1.1, [3] = 1.25, [4] = 1.4 };


-- Sizes ---------------------------------------------------------------------------------------------------
-- Raw sizes are in atlas pixels. They are multiplied by PIXEL_SCALE and the frame size setting.

local PIXEL_SCALE = 0.53333;
local EDGE_DISTANCE = 48;               -- default distance from the left screen edge
local OTHER_ALPHA_FADE = 24;            -- px of scrolling over which the top overlap fades in
local FOOTER_SHIFT = 20;             -- the bottom cap sits this much lower than retail's default (in-game check)
local SOURCE_PANEL_PAD = 8;          -- paper left and right of the item strip
local SOURCE_PANEL_PAD_V = 13;      -- paper above and below it
local SOURCE_PANEL_SCALE = 0.35;        -- drawn size of one texel of the paper art (its corners are 80 texels)
local SOURCE_PANEL_SHADOW = 16 * SOURCE_PANEL_SCALE;   -- transparent shadow margin of the paper art
local ANIM_DURATION = 0.5;
local ANIM_OFFSET = 48;

local RawSize = {
    FRAME_WIDTH = 768,
    FRAME_HEIGHT_MAX = 896,
    FRAME_HEIGHT_MIN = 192,
    FRAME_TOP_HEIGHT = 64,
    FRAME_BOTTOM_HEIGHT = 88,

    PIECE_WIDTH = 1024,
    PIECE_HEIGHT_FULL = 1152,
    PIECE_BOTTOM_HEIGHT = 256,
    PIECE_TOP_OFFSET = 128,
    PIECE_BOTTOM_OFFSET = -128,
    PIECE_BOTTOM_OVERLAP = -40,

    PADDING_H = 60,
    PADDING_V = 90,

    CLOSE_BUTTON_OFFSET = 26,
    CLOSE_BUTTON_SIZE = 64,

    HEADER_DIVIDER_HEIGHT = 32,
    FOOTER_DIVIDER_HEIGHT = 32,
    HEADER_OVERLAP_HEIGHT = 80,
    HEADER_DIVIDER_BELOW_TITLE = -46,

    PAGE_BUTTON_SIZE = 40,
    PAGE_BUTTON_GAP = 2,

    ITEM_BORDER_SIZE = 96,
    ITEM_BORDER_EFFECTIVE_SIZE = 80,
    ITEM_ICON_SIZE = 64,
};

local cs = {};          -- converted sizes (frame units)
local Metrics = {};     -- font dependent spacing

local function CalculateSizeData()
    local base = GetDBValue("BookFontSize");
    base = Clamp(tonumber(base) or 12, 8, 24);

    local a = PIXEL_SCALE * (SIZE_SCALES[GetDBValue("BookUISize")] or 1.0);
    for k, v in pairs(RawSize) do
        cs[k] = a * v;
    end
    cs.PIXEL = a;       -- frame units per atlas pixel
    cs.CONTENT_WIDTH = a * (RawSize.FRAME_WIDTH - 2 * RawSize.PADDING_H);

    Metrics.FONT_SIZE = base;
    Metrics.TEXT_SPACING = 0.35 * base;                 -- recommended line height 1.2 to 1.5
    Metrics.PARAGRAPH_SPACING = 4 * Metrics.TEXT_SPACING;
    Metrics.PAGE_SPACING = 4 * Metrics.PARAGRAPH_SPACING;
    Metrics.OFFSET_PER_SCROLL = Round(4 * (base + Metrics.TEXT_SPACING));
end


-- Texture kits --------------------------------------------------------------------------------------------

local TEXTURE_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Book\\";

local TextureKit = {
    [1] = {file = "TextureKit-Parchment.blp", text = {0.19, 0.17, 0.13}, selected = {0.87, 0.86, 0.75}, normal = {0.50, 0.36, 0.24}, shadow = false},
    [2] = {file = "TextureKit-Metal.blp", text = {0.8, 0.8, 0.8}, selected = {0.9, 0.9, 0.9}, normal = {0.7, 0.7, 0.7}, shadow = true},
};

-- ItemTextGetMaterial: nil means Parchment.
local MaterialKit = {
    Parchment = 1,
    Stone = 2,
    Marble = 2,
    Silver = 2,
    Bronze = 2,
};

local ATLAS_W, ATLAS_H = 1024, 2048;

local function UV(x1, x2, y1, y2)
    return x1 / ATLAS_W, x2 / ATLAS_W, y1 / ATLAS_H, y2 / ATLAS_H
end

-- Textures cut from the kit atlas. coords are kept so SetTexture can be followed by SetTexCoord.
local kitTextures = {};

local function RegisterKitTexture(tex)
    kitTextures[#kitTextures + 1] = tex;
    -- Page buttons are created after the first skin was applied.
    if Book.kit then
        tex:SetTexture(TEXTURE_PATH .. Book.kit.file);
    end
    return tex
end

local function SetKitCoord(tex, u1, u2, v1, v2)
    tex.kitCoord = {u1, u2, v1, v2};
    tex:SetTexCoord(u1, u2, v1, v2);
end

local function Size(obj, width, height)
    obj:SetWidth(width);
    obj:SetHeight(height);
end


-- Fonts ---------------------------------------------------------------------------------------------------
-- Same fonts as retail (DUIFont_Book_*), Friz Quadrata instead of Trajan for the title.

local FontNames = {
    p = "DUI335_Book_Paragraph",
    h1 = "DUI335_Book_H1",
    h2 = "DUI335_Book_H2",
    h3 = "DUI335_Book_H3",
    title = "DUI335_Book_Title",
    smallprint = "DUI335_Book_10",
};

local Fonts = {};
local SourceFont;      -- item strip text: same size as the paragraphs, always dark brown on the tan paper

local function InitFonts()
    for tag, name in pairs(FontNames) do
        Fonts[tag] = FontUtil:GetQuestFont(name, 12, false);        -- the book sets its own colors (kit), no theme
    end
    SourceFont = FontUtil:GetQuestFont("DUI335_Book_Source", 12, false);
end

local function ApplyFontSizes()
    local base = Metrics.FONT_SIZE;
    local sizes = {
        p = base, h1 = base + 4, h2 = base + 4, h3 = base + 6, title = 18, smallprint = max(8, base - 2),
    };
    for tag, fontObject in pairs(Fonts) do
        local file = fontObject:GetFont();
        fontObject:SetFont(file, sizes[tag], "");
    end
    SourceFont:SetFont(SourceFont:GetFont(), base, "");
end


-- Simple object pool -------------------------------------------------------------------------------------

local function CreatePool(create, reset)
    local pool = { free = {}, used = {} };

    function pool:Acquire()
        local obj = table.remove(self.free);
        if not obj then
            obj = create();
        end
        self.used[#self.used + 1] = obj;
        return obj
    end

    function pool:ReleaseAll()
        for i = #self.used, 1, -1 do
            local obj = self.used[i];
            reset(obj);
            self.free[#self.free + 1] = obj;
            self.used[i] = nil;
        end
    end

    return pool
end


-- Cache: the book that is open -----------------------------------------------------------------------------

local Cache = { positions = {} };       -- positions[id] = scroll offset, kept for the session
Book.Cache = Cache;

function Cache:Reset(title, itemInfo)
    self.title = title;
    self.itemInfo = itemInfo;
    self.pageTexts = {};
    self.maxPage = 1;
    self.content = {};          -- [index] = {text | image, align, fontTag, spacing..., offsetY}
    self.pageStartOffset = {};
    self.spacingPending = nil;
    self.nextContentIsPageStart = nil;
    self.id = nil;
end

function Cache:NewBlock(block)
    local content = self.content;
    block.spacingAbove = self.spacingPending or 0;
    self.spacingPending = nil;
    if self.nextContentIsPageStart then
        self.nextContentIsPageStart = nil;
        block.isPageStart = true;
    end
    content[#content + 1] = block;
end

-- Sink interface used by BookFormatter.
function Cache:StoreText(fontTag, text, align, spacingBelow)
    if align == "RIGHT" then
        align = "CENTER";       -- retail treats right-aligned text as centred
    end
    self:NewBlock({ text = text, fontTag = fontTag, align = align or "LEFT", spacingBelow = spacingBelow or 0 });
end

function Cache:StoreImage(file, align, width, height)
    self:NewBlock({ image = file, align = align, width = width, height = height, spacingBelow = 0 });
end

function Cache:AddSpacerToNextContent(height)
    self.spacingPending = (self.spacingPending or 0) + height;
end

function Cache:RemoveLastTextSpacingBelow()
    local last = self.content[#self.content];
    if last then
        last.spacingBelow = 0;
    end
end

function Cache:AddSpacerToLastContent(height)
    local last = self.content[#self.content];
    if last then
        last.spacingBelow = last.spacingBelow + height;
    end
end

function Cache:FlagNextContentIsPageStart()
    self.nextContentIsPageStart = true;
end

function Cache:GetPageStartOffset(page)
    return self.pageStartOffset[page]
end

-- Stacks the blocks from fromOffsetY. Records where each page starts. Returns the total height.
function Cache:CalculateFullContentHeight(fromOffsetY)
    local offsetY = fromOffsetY;
    local page = 0;
    for _, block in ipairs(self.content) do
        offsetY = offsetY + block.spacingAbove;
        if block.isPageStart then
            page = page + 1;
            self.pageStartOffset[page] = offsetY;
        end
        block.offsetY = offsetY;
        if block.text then
            offsetY = Round(offsetY + block.textHeight + block.spacingBelow);
        else
            offsetY = Round(offsetY + block.height);
        end
        block.endingOffsetY = offsetY;
    end
    return offsetY
end


-- Frame construction ---------------------------------------------------------------------------------------

local fontStringPool, texturePool, pagePool;

-- Anchor kept for the fly-in animation (the frame is moved by the animation and by the player).
local anchor = { point = "LEFT", relPoint = "LEFT", x = EDGE_DISTANCE, y = 0 };

local function ApplyAnchor(offsetY)
    frame:ClearAllPoints();
    frame:SetPoint(anchor.point, UIParent, anchor.relPoint, anchor.x, anchor.y + (offsetY or 0));
end

local function RestorePosition()
    local pos = GetDBValue("BookPosition");
    if pos and pos.point and pos.x and pos.y then
        anchor.point, anchor.relPoint, anchor.x, anchor.y = pos.point, pos.relativePoint or pos.point, pos.x, pos.y;
    else
        anchor.point, anchor.relPoint, anchor.x, anchor.y = "LEFT", "LEFT", EDGE_DISTANCE, 0;
    end
    ApplyAnchor(0);
end

-- Left-drag moves the whole book. The scroll frame forwards the drag.
local function MakeMovable(...)
    frame:SetMovable(true);
    frame:SetClampedToScreen(true);
    frame:SetUserPlaced(false);     -- we save the position ourselves
    local function OnDragStart()
        frame:StartMoving();
    end
    local function OnDragStop()
        frame:StopMovingOrSizing();
        local point, _, relativePoint, x, y = frame:GetPoint(1);
        if point then
            anchor.point, anchor.relPoint, anchor.x, anchor.y = point, relativePoint, x, y;
            SetDBValue("BookPosition", { point = point, relativePoint = relativePoint, x = x, y = y });
        end
    end
    local function Enable(target)
        target:EnableMouse(true);
        target:RegisterForDrag("LeftButton");
        target:SetScript("OnDragStart", OnDragStart);
        target:SetScript("OnDragStop", OnDragStop);
        target:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                Book:Hide();
            end
        end);
    end
    Enable(frame);
    for i = 1, select("#", ...) do
        Enable((select(i, ...)));
    end
end

local function CreatePageButton()
    local button = CreateFrame("Button", nil, Book.header);
    button.Background = RegisterKitTexture(button:CreateTexture(nil, "BORDER"));
    button.Background:SetAllPoints(button);
    button.Highlight = RegisterKitTexture(button:CreateTexture(nil, "BORDER"));
    button.Highlight:SetAllPoints(button);
    SetKitCoord(button.Highlight, UV(908, 948, 1564, 1604));
    button.Highlight:Hide();
    button.Text = button:CreateFontString(nil, "OVERLAY");
    button.Text:SetFontObject(Fonts.smallprint);
    button.Text:SetPoint("CENTER", button, "CENTER", 0, 0);

    -- The hover tile is light, so a selected number switches to the normal text colour while hovered.
    button:SetScript("OnEnter", function(self)
        self.hovered = true;
        self.Highlight:Show();
        Book:StylePageButton(self);
    end);
    button:SetScript("OnLeave", function(self)
        self.hovered = nil;
        self.Highlight:Hide();
        Book:StylePageButton(self);
    end);
    button:SetScript("OnClick", function(self)
        if self.page == 1 then
            Book:ScrollTo(0);
        else
            Book:ScrollToPage(self.page);
        end
        Book:SetCurrentPage(self.page);     -- update the buttons at once
    end);
    return button
end

local function ResetPageButton(button)
    button:Hide();
    button:ClearAllPoints();
    button.selected = nil;
    button.hovered = nil;
    button.Highlight:Hide();
end

function Book:Init()
    if frame then
        return
    end

    CalculateSizeData();
    InitFonts();
    ApplyFontSizes();

    frame = CreateFrame("Frame", "DUI335BookFrame", addon.UIRoot);
    self.frame = frame;
    frame:SetFrameStrata("DIALOG");
    frame:SetToplevel(true);
    frame:SetWidth(cs.FRAME_WIDTH);
    frame:SetHeight(cs.FRAME_HEIGHT_MAX);
    frame:Hide();

    -- Screen darkening, drawn first so the pages cover it.
    self.vignette = frame:CreateTexture(nil, "BACKGROUND");
    self.vignette:SetTexture(TEXTURE_PATH .. "ScreenDarken.blp");

    -- Background: one piece when the text fits, otherwise top piece plus bottom cap.
    self.bgTop = RegisterKitTexture(frame:CreateTexture(nil, "BORDER"));
    self.bgBottom = nil;        -- created on the footer below

    -- Scroll area
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame);
    self.scrollFrame = scrollFrame;
    local scrollChild = CreateFrame("Frame", nil, scrollFrame);
    scrollChild:SetWidth(cs.FRAME_WIDTH);
    scrollChild:SetHeight(1);
    scrollFrame:SetScrollChild(scrollChild);
    self.scrollChild = scrollChild;

    -- Header: title, location, divider, page buttons. Above the scroll frame so text slides under it.
    local header = CreateFrame("Frame", nil, frame);
    self.header = header;
    header:SetFrameLevel(frame:GetFrameLevel() + 10);
    header:SetPoint("TOP", frame, "TOP", 0, 0);
    header:SetWidth(cs.CONTENT_WIDTH);
    header:SetHeight(1);

    self.headerOverlap = RegisterKitTexture(header:CreateTexture(nil, "ARTWORK"));
    SetKitCoord(self.headerOverlap, UV(128, 896, 1408, 1488));
    self.headerOverlap:SetPoint("CENTER", scrollFrame, "TOP", 0, 0);

    -- The header divider is two halves with a gap for the page buttons (retail cuts it with a MaskTexture).
    self.dividerAnchor = CreateFrame("Frame", nil, header);
    self.dividerLeft = RegisterKitTexture(header:CreateTexture(nil, "ARTWORK"));
    self.dividerLeft:SetPoint("LEFT", self.dividerAnchor, "LEFT", 0, 0);
    self.dividerRight = RegisterKitTexture(header:CreateTexture(nil, "ARTWORK"));
    self.dividerRight:SetPoint("RIGHT", self.dividerAnchor, "RIGHT", 0, 0);

    self.title = header:CreateFontString(nil, "OVERLAY");
    self.title:SetFontObject(Fonts.title);
    self.title:SetJustifyH("CENTER");
    self.title:SetJustifyV("TOP");
    self.title:SetSpacing(4);

    self.location = header:CreateFontString(nil, "OVERLAY");
    self.location:SetFontObject(Fonts.smallprint);
    self.location:SetJustifyH("CENTER");
    self.location:SetJustifyV("TOP");
    self.location:SetPoint("BOTTOM", self.title, "TOP", 0, 9);
    self.location:Hide();

    -- Footer: bottom cap and divider, above the scroll frame so text slides under it.
    local footer = CreateFrame("Frame", nil, frame);
    self.footer = footer;
    footer:SetFrameLevel(frame:GetFrameLevel() + 10);
    footer:SetAllPoints(frame);
    -- Cap below the divider: 3.3.5a has no sublevels, so the cap takes ARTWORK and the divider OVERLAY.
    self.bgBottom = RegisterKitTexture(footer:CreateTexture(nil, "ARTWORK"));
    self.footerDivider = RegisterKitTexture(footer:CreateTexture(nil, "OVERLAY"));
    SetKitCoord(self.footerDivider, UV(0, 768, 1488, 1520));
    self.footerDivider:SetPoint("CENTER", scrollFrame, "BOTTOM", 0, 0);

    -- Close button (also the target of the Esc override binding)
    local close = CreateFrame("Button", "DUI335BookCloseButton", frame);
    close:SetFrameLevel(frame:GetFrameLevel() + 20);
    close:RegisterForClicks("LeftButtonUp");
    close.Texture = RegisterKitTexture(close:CreateTexture(nil, "ARTWORK"));
    close.Texture:SetAllPoints(close);
    SetKitCoord(close.Texture, UV(768, 832, 1488, 1552));
    close.Highlight = RegisterKitTexture(close:CreateTexture(nil, "HIGHLIGHT"));
    close.Highlight:SetAllPoints(close);
    SetKitCoord(close.Highlight, UV(832, 896, 1488, 1552));
    close:SetScript("OnClick", function() Book:Hide(); end);
    self.closeButton = close;

    -- Hidden FontString that measures the height of wrapped text.
    self.measure = frame:CreateFontString(nil, "ARTWORK");
    self.measure:SetFontObject(Fonts.p);
    self.measure:SetJustifyH("LEFT");
    self.measure:SetJustifyV("TOP");
    self.measure:SetAlpha(0);
    self.measure:SetPoint("TOP", frame, "BOTTOM", 0, -64);

    -- Pools
    fontStringPool = CreatePool(function()
        local fs = scrollChild:CreateFontString(nil, "ARTWORK");
        fs:SetJustifyV("TOP");
        return fs
    end, function(fs)
        fs:SetText("");
        fs:Hide();
        fs:ClearAllPoints();
    end);
    texturePool = CreatePool(function()
        return scrollChild:CreateTexture(nil, "ARTWORK")
    end, function(tex)
        tex:SetTexture(nil);
        tex:Hide();
        tex:ClearAllPoints();
    end);
    pagePool = CreatePool(CreatePageButton, ResetPageButton);

    -- Scrolling (shared smooth scroll frame). The footer divider fades with the distance to the bottom,
    -- the header overlap fades in when the text has moved under the title.
    addon.InitSmoothScrollFrame(scrollFrame, self.footerDivider);
    local baseSetOffset = scrollFrame.SetOffset;
    function scrollFrame:SetOffset(value)
        baseSetOffset(self, value);
        Book:OnScrolled();
    end
    local baseUpdateDivider = scrollFrame.UpdateDivider;
    function scrollFrame:UpdateDivider(value)
        baseUpdateDivider(self, value);
        if self.range > 0 then
            Book.headerOverlap:SetAlpha(Clamp(value / OTHER_ALPHA_FADE, 0, 1));
        else
            Book.headerOverlap:SetAlpha(0);
        end
    end
    local function OnMouseWheel(_, delta)
        Book:OnMouseWheel(delta);
    end
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel);
    frame:EnableMouseWheel(true);
    frame:SetScript("OnMouseWheel", OnMouseWheel);

    MakeMovable(scrollFrame);
    RestorePosition();

    -- Vignette anchors depend on the screen, not on the frame position.
    self.vignette:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 1);
    self.vignette:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, -1);

    frame:SetScript("OnShow", function() Book:OnShow(); end);
    frame:SetScript("OnHide", function() Book:OnHide(); end);

    -- Key bindings cannot change in combat: apply them when it ends.
    local combatFrame = CreateFrame("Frame");
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
    combatFrame:SetScript("OnEvent", function()
        if Book.keysDirty then
            Book:UpdateKeys();
        end
    end);

    self:CreateSourceButton();
end


-- Skin -------------------------------------------------------------------------------------------------------

function Book:SetTextureKit(kitID)
    local kit = TextureKit[kitID];
    if not kit then
        return
    end
    self.kitID = kitID;
    self.kit = kit;
    local file = TEXTURE_PATH .. kit.file;

    for _, tex in ipairs(kitTextures) do
        tex:SetTexture(file);
        if tex.kitCoord then
            tex:SetTexCoord(unpack(tex.kitCoord));
        end
    end

    for tag, fontObject in pairs(Fonts) do
        local color = (tag == "smallprint") and kit.normal or kit.text;
        fontObject:SetTextColor(color[1], color[2], color[3]);
        if kit.shadow then
            fontObject:SetShadowOffset(1, -1);
            fontObject:SetShadowColor(0, 0, 0);
        else
            fontObject:SetShadowOffset(0, 0);
        end
    end

    -- Strings that use SetFont keep their own colour.
    self.title:SetTextColor(kit.text[1], kit.text[2], kit.text[3]);
    self.location:SetTextColor(kit.normal[1], kit.normal[2], kit.normal[3]);
    if kit.shadow then
        self.title:SetShadowOffset(1, -1);
        self.title:SetShadowColor(0, 0, 0);
    else
        self.title:SetShadowOffset(0, 0);
    end

    for _, button in ipairs(pagePool.used) do
        self:StylePageButton(button);
    end
    for _, button in ipairs(pagePool.free) do
        button.selected = nil;
    end
end

function Book:StylePageButton(button)
    local kit = self.kit;
    if button.selected then
        SetKitCoord(button.Background, UV(780, 820, 1564, 1604));
        local color = button.hovered and kit.normal or kit.selected;
        button.Text:SetTextColor(color[1], color[2], color[3]);
    else
        SetKitCoord(button.Background, UV(844, 884, 1564, 1604));
        button.Text:SetTextColor(kit.normal[1], kit.normal[2], kit.normal[3]);
    end
end


-- Layout -----------------------------------------------------------------------------------------------------

-- Frame height and background pieces. Returns the final frame height.
function Book:SetFrameHeight(height, scrollable)
    if height < cs.FRAME_HEIGHT_MIN then
        height = cs.FRAME_HEIGHT_MIN;
    end

    local isDynamicHeight = (not scrollable) and (height + 8) < cs.FRAME_HEIGHT_MAX;
    local useTwoPieceBG = scrollable or isDynamicHeight;
    if not isDynamicHeight then
        height = cs.FRAME_HEIGHT_MAX;
    end

    local top, bottom = self.bgTop, self.bgBottom;
    top:ClearAllPoints();
    bottom:ClearAllPoints();

    if useTwoPieceBG then
        -- The top piece runs from above the frame top to just under the top of the bottom cap. Its height is
        -- known from the anchors, so the rows cropped from the atlas are taken from it: one atlas px always
        -- stays one texel on screen, wherever the cap sits (retail's (192 + 744 * ratio) is the same thing
        -- for the default cap position).
        local bottomOffset = cs.PIECE_BOTTOM_OFFSET - FOOTER_SHIFT;
        local capTop = bottomOffset + cs.PIECE_BOTTOM_HEIGHT;
        local topHeight = height + cs.PIECE_TOP_OFFSET - (capTop + cs.PIECE_BOTTOM_OVERLAP);
        local rows = Clamp(topHeight / cs.PIXEL, 0, 1152);

        SetKitCoord(top, 0, 1, 0, rows / ATLAS_H);
        top:SetWidth(cs.PIECE_WIDTH);
        top:SetPoint("TOP", frame, "TOP", 0, cs.PIECE_TOP_OFFSET);
        top:SetPoint("BOTTOM", bottom, "TOP", 0, cs.PIECE_BOTTOM_OVERLAP);

        SetKitCoord(bottom, 0, 1, 1152 / ATLAS_H, 1408 / ATLAS_H);
        Size(bottom, cs.PIECE_WIDTH, cs.PIECE_BOTTOM_HEIGHT);
        bottom:SetPoint("BOTTOM", frame, "BOTTOM", 0, bottomOffset);
        bottom:Show();
    else
        height = cs.FRAME_HEIGHT_MAX;
        SetKitCoord(top, 0, 1, 0, 1152 / ATLAS_H);
        Size(top, cs.PIECE_WIDTH, cs.PIECE_HEIGHT_FULL);
        top:SetPoint("CENTER", frame, "CENTER", 0, 0);
        bottom:Hide();
    end

    Size(frame, cs.FRAME_WIDTH, height);
    return height
end

-- Sizes that depend on the frame size setting.
function Book:Resize()
    Size(self.closeButton, cs.CLOSE_BUTTON_SIZE, cs.CLOSE_BUTTON_SIZE);
    self.closeButton:ClearAllPoints();
    self.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -cs.CLOSE_BUTTON_OFFSET, -cs.CLOSE_BUTTON_OFFSET);

    self.header:SetWidth(cs.CONTENT_WIDTH);
    self.title:ClearAllPoints();
    self.title:SetPoint("TOP", frame, "TOP", 0, -cs.PADDING_V);

    Size(self.headerOverlap, cs.FRAME_WIDTH, cs.HEADER_OVERLAP_HEIGHT);
    Size(self.footerDivider, cs.FRAME_WIDTH, cs.FOOTER_DIVIDER_HEIGHT);
    self.scrollChild:SetWidth(cs.FRAME_WIDTH);
    self.measure:SetWidth(cs.CONTENT_WIDTH);
end

-- Title: biggest font (18, 16, 14) that keeps it on one line, else 14 on two lines.
function Book:SetTitle(title)
    local t = self.title;
    title = title or "";
    local file = Fonts.title:GetFont();
    local width = cs.CONTENT_WIDTH;
    local chosen;

    t:SetText(title);
    for _, size in ipairs({18, 16, 14}) do
        t:SetFont(file, size, "");
        t:SetWidth(0);
        t:SetHeight(0);
        if t:GetStringWidth() <= width then
            chosen = size;
            break
        end
    end

    if chosen then
        self.titleHeight = Round(t:GetStringHeight());
        self.titleLineHeight = chosen;
    else
        chosen = 14;
        t:SetFont(file, chosen, "");
        self.titleHeight = Round(2 * chosen + 4);       -- two lines plus the line spacing
        self.titleLineHeight = chosen;
    end
    t:SetWidth(width);
    t:SetHeight(self.titleHeight);
end

function Book:SetLocation(text)
    if text and text ~= "" then
        self.location:SetText(text);
        self.location:Show();
    else
        self.location:SetText("");
        self.location:Hide();
    end
end

-- Sets the number on a page button. The digit 1 is drawn about 1 px right of centre, so it is shifted back.
local function SetPageButtonNumber(button, page)
    button.page = page;
    button.Text:SetText(page);
    button.Text:ClearAllPoints();
    button.Text:SetPoint("CENTER", button, "CENTER", (page == 1) and -1 or 0, 0);
end

local MAX_PAGE_BUTTONS = 9;

-- Creates the page buttons. Returns how many there are (0 for a single page).
function Book:SetMaxPage(maxPage)
    pagePool:ReleaseAll();
    self.maxPage = maxPage;
    self.currentPage = 0;

    if maxPage <= 1 then
        self.dynamicPagination = false;
        return 0
    end

    local numButtons = min(maxPage, MAX_PAGE_BUTTONS);
    self.dynamicPagination = maxPage > MAX_PAGE_BUTTONS;

    local size, gap = cs.PAGE_BUTTON_SIZE, cs.PAGE_BUTTON_GAP;
    local fromX = -0.5 * ((size + gap) * numButtons - gap);
    for i = 1, numButtons do
        local button = pagePool:Acquire();
        button:Show();
        button.index = i;
        SetPageButtonNumber(button, i);
        Size(button, size, size);
        button:SetPoint("LEFT", self.dividerAnchor, "CENTER", fromX + (i - 1) * (size + gap), 0);
        button.selected = (i == 1);
        self:StylePageButton(button);
    end
    self:SetCurrentPage(1);
    return numButtons
end

function Book:UpdatePageButtons()
    local page = self.currentPage;
    local maxPage = self.maxPage;
    local buttons = pagePool.used;

    if self.dynamicPagination then
        -- More pages than buttons: first and last stay, the current page sits in the middle.
        local last = MAX_PAGE_BUTTONS;
        local leftMost = max(1, page - 4);
        for index, button in ipairs(buttons) do
            local value;
            if leftMost == 1 then
                value = (index == last) and maxPage or index;
            elseif page + 4 >= maxPage then
                value = (index == 1) and 1 or (maxPage + index - last);
            elseif index == 1 then
                value = 1;
            elseif index == last then
                value = maxPage;
            else
                value = page + index - 5;
            end
            SetPageButtonNumber(button, value);
        end
    end

    for _, button in ipairs(buttons) do
        local selected = (button.page == page);
        if button.selected ~= selected then
            button.selected = selected;
            self:StylePageButton(button);
        end
    end
end

function Book:SetCurrentPage(page)
    if page ~= self.currentPage then
        self.currentPage = page;
        self:UpdatePageButtons();
    end
end

-- The divider under the title, split around the page buttons.
function Book:LayoutHeaderDivider(usePagination, numButtons, titleSpacing)
    local anchorFrame = self.dividerAnchor;
    local width, height = cs.FRAME_WIDTH, cs.HEADER_DIVIDER_HEIGHT;
    local gap = 0;
    local y;

    if usePagination then
        gap = numButtons * (cs.PAGE_BUTTON_SIZE + cs.PAGE_BUTTON_GAP) + 3 * cs.PAGE_BUTTON_GAP;
        y = -(cs.PADDING_V + self.titleHeight) + cs.HEADER_DIVIDER_BELOW_TITLE;
    else
        y = -Round(cs.PADDING_V + self.titleHeight + titleSpacing);
    end

    anchorFrame:ClearAllPoints();
    anchorFrame:SetPoint("CENTER", frame, "TOP", 0, y);
    Size(anchorFrame, width, height);

    local half = max(0, (width - gap) / 2);
    local fraction = half / width;
    local u1, u2, v1, v2 = UV(0, 768, 1520, 1552);
    Size(self.dividerLeft, half, height);
    Size(self.dividerRight, half, height);
    SetKitCoord(self.dividerLeft, u1, u2 * fraction, v1, v2);
    SetKitCoord(self.dividerRight, u2 * (1 - fraction), u2, v1, v2);
end

function Book:GetContentFromOffsetY(multiPage)
    local fromOffsetY;
    if multiPage then
        fromOffsetY = Round(cs.PADDING_H - Metrics.PARAGRAPH_SPACING);
    else
        fromOffsetY = Round(Metrics.PARAGRAPH_SPACING);
    end
    self.scrollFromOffsetY = fromOffsetY;
    return fromOffsetY
end

-- Port of retail's SetScrollContentHeight. Decides if the text scrolls, whether pagination is shown, the
-- frame height and the scroll range. Returns the content height actually used.
function Book:LayoutFrame(contentHeight, maxPage)
    local usePagination = maxPage > 1;
    local titleHeight = self.titleHeight;
    local titleSpacing = 0.35 * self.titleLineHeight;
    local heightBelowTitleNoPagi = titleSpacing + 2;
    local heightBelowTitle = usePagination and (Metrics.PARAGRAPH_SPACING + cs.PAGE_BUTTON_SIZE) or heightBelowTitleNoPagi;

    local maxContentHeight = cs.FRAME_HEIGHT_MAX - 2 * cs.PADDING_V - titleHeight - heightBelowTitle;
    local scrollable = contentHeight > maxContentHeight;
    if not scrollable then
        usePagination = false;
    end

    if maxPage > 1 and not usePagination then
        -- Several pages that fit in one view: no page buttons, so restack with the single-view start offset.
        contentHeight = Cache:CalculateFullContentHeight(self:GetContentFromOffsetY(false));
    end

    if not usePagination then
        heightBelowTitle = heightBelowTitleNoPagi;
        maxPage = 1;
    end

    local numButtons = self:SetMaxPage(maxPage);
    self:LayoutHeaderDivider(usePagination, numButtons, titleSpacing);

    local headerHeight = Round(titleHeight + heightBelowTitle);
    local frameHeight = self:SetFrameHeight(headerHeight + contentHeight + 2 * cs.PADDING_V, scrollable);
    -- GetHeight of an anchored frame is not reliable on the frame it changed, so it is computed.
    local viewHeight = frameHeight - 2 * cs.PADDING_V - headerHeight;

    local scrollFrame = self.scrollFrame;
    scrollFrame:ClearAllPoints();
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -cs.PADDING_V - headerHeight);
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, cs.PADDING_V);
    self.header:SetHeight(headerHeight);

    local scrollRange = 0;
    if scrollable then
        scrollRange = max(0, Round(contentHeight + Metrics.PAGE_SPACING - viewHeight));
    end

    self.scrollable = scrollable;
    self.viewHeight = viewHeight;
    self.scrollChild:SetHeight(viewHeight + scrollRange);
    scrollFrame:SetScrollRange(scrollRange);
    return contentHeight
end


-- Content ----------------------------------------------------------------------------------------------------

function Book:MeasureText(fontTag, text)
    local m = self.measure;
    m:SetFontObject(Fonts[fontTag] or Fonts.p);
    m:SetSpacing(Metrics.TEXT_SPACING);
    m:SetWidth(cs.CONTENT_WIDTH);
    m:SetHeight(0);
    m:SetText(text);
    local height = m:GetStringHeight();
    m:SetText("");
    return height
end

function Book:ReleaseContent()
    if fontStringPool then
        fontStringPool:ReleaseAll();
        texturePool:ReleaseAll();
    end
end

-- Puts every block on the scroll child. Retail recycles blocks outside the view; the book texts are short
-- enough that showing them all is fine.
function Book:RenderContent()
    self:ReleaseContent();
    local child = self.scrollChild;

    for _, block in ipairs(Cache.content) do
        if block.text then
            local fs = fontStringPool:Acquire();
            fs:SetFontObject(Fonts[block.fontTag] or Fonts.p);
            fs:SetSpacing(Metrics.TEXT_SPACING);
            fs:SetWidth(cs.CONTENT_WIDTH);
            fs:SetHeight(0);
            fs:SetJustifyH(block.align);
            fs:SetText(block.text);
            fs:SetPoint("TOP", child, "TOP", 0, -block.offsetY);
            fs:Show();
        elseif block.image then
            local tex = texturePool:Acquire();
            Size(tex, block.width, block.height);
            tex:SetTexture(block.image);
            tex:SetTexCoord(0, 1, 0, 1);
            tex:SetPoint("TOP", child, "TOP", 0, -block.offsetY);
            tex:Show();
        end
    end
end

-- Called when every page is cached (BookEvents.lua).
function Book:Build()
    CalculateSizeData();
    ApplyFontSizes();
    self:SetTextureKit(self.kitID or 1);        -- recolour after a size change
    self:Resize();
    self:SetTitle(Cache.title);

    -- Format all pages into blocks.
    Cache.content = {};
    Cache.pageStartOffset = {};
    Cache.spacingPending = nil;
    local maxPage = Cache.maxPage;
    local ctx = {
        sink = Cache,
        titleText = Cache.title,
        paragraphSpacing = Metrics.PARAGRAPH_SPACING,
        contentWidth = cs.CONTENT_WIDTH,
    };
    for page, text in ipairs(Cache.pageTexts) do
        Cache:FlagNextContentIsPageStart();
        BookFormatter.Format(text, ctx);
        if maxPage > 1 and page ~= maxPage then
            Cache:AddSpacerToLastContent(Metrics.PAGE_SPACING);
        end
    end

    for _, block in ipairs(Cache.content) do
        if block.text then
            block.textHeight = self:MeasureText(block.fontTag, block.text);
        end
    end

    local contentHeight = Cache:CalculateFullContentHeight(self:GetContentFromOffsetY(maxPage > 1));
    self:LayoutFrame(contentHeight, maxPage);
    self:RenderContent();

    -- Same book as last time: go back to where the player stopped.
    local first = Cache.pageTexts[1] or "";
    Cache.id = (Cache.title or "") .. ":" .. #first .. ":" .. first:sub(1, 24);
    local lastOffset = Cache.positions[Cache.id];
    if lastOffset then
        self.scrollFrame:SnapTo(lastOffset);
    else
        self.scrollFrame:ResetScroll();
    end
    self:OnScrolled();

    self:UpdateSourceButton();
end


-- Scrolling --------------------------------------------------------------------------------------------------

function Book:GetCurrentPage()
    local scrollFrame = self.scrollFrame;
    local maxPage = Cache.maxPage;
    if scrollFrame.range <= 0 or maxPage <= 1 then
        return 1
    end
    if scrollFrame.scrollTarget <= 0.5 then
        return 1
    end
    if scrollFrame:IsAtPageBottom() then
        return maxPage
    end
    -- A page counts as current once it reaches 40% of the view.
    local offset = scrollFrame.scrollTarget + self.scrollFromOffsetY + 0.4 * self.viewHeight;
    for page = maxPage, 1, -1 do
        local start = Cache:GetPageStartOffset(page);
        if start and offset > start then
            return page
        end
    end
    return 1
end

function Book:OnScrolled()
    if self.maxPage and self.maxPage > 1 then
        self:SetCurrentPage(self:GetCurrentPage());
    end
end

function Book:ScrollTo(value)
    self.scrollFrame:ScrollTo(value);
end

function Book:ScrollToPage(page)
    page = min(page, Cache.maxPage);
    if page <= 1 then
        self:ScrollTo(0);
        return
    end
    local start = Cache:GetPageStartOffset(page);
    if start then
        self:ScrollTo(start - self.scrollFromOffsetY);
    end
end

function Book:ScrollToNearNextPage()
    local offset = self.scrollFrame.scrollTarget + self.scrollFromOffsetY + 0.1;
    local maxPage = Cache.maxPage;
    for page = 1, maxPage do
        local start = Cache:GetPageStartOffset(page);
        if start and offset < start then
            if page == 1 and page < maxPage then
                page = 2;
                start = Cache:GetPageStartOffset(page);
            end
            self:ScrollTo(start - self.scrollFromOffsetY);
            break
        end
    end
end

function Book:ScrollToNearPrevPage()
    local offset = self.scrollFrame.scrollTarget + self.scrollFromOffsetY - 0.1;
    for page = Cache.maxPage, 1, -1 do
        local start = Cache:GetPageStartOffset(page);
        if start and offset > start then
            self:ScrollTo(page == 1 and 0 or (start - self.scrollFromOffsetY));
            break
        end
    end
end

-- Wheel moves by 4 lines. Shift + wheel jumps to the previous / next page.
function Book:OnMouseWheel(delta)
    local scrollFrame = self.scrollFrame;
    if scrollFrame.range <= 0 then
        return
    end
    if IsShiftKeyDown() then
        if delta > 0 then
            self:ScrollToNearPrevPage();
        else
            self:ScrollToNearNextPage();
        end
    elseif delta > 0 then
        scrollFrame:ScrollBy(-Metrics.OFFSET_PER_SCROLL);
    else
        scrollFrame:ScrollBy(Metrics.OFFSET_PER_SCROLL);
    end
end


-- Source item (icon and flavor text above the book) -----------------------------------------------------------

function Book:CreateSourceButton()
    -- Levels: the book frame draws the screen shadow, so the paper (+2) and the strip with the icon and text
    -- (+3) must be above it. A child frame at the same level as its parent can draw below the parent's textures.
    local f = CreateFrame("Frame", nil, frame);
    f:SetFrameLevel(frame:GetFrameLevel() + 3);
    f:SetPoint("BOTTOM", frame, "TOP", 0, 21);     -- paper bottom stays 8 above the book
    f:Hide();

    -- Tan paper behind the icon and text (tiled 9-slice, like the tooltip). A sibling of f, one level under it,
    -- so it sits behind f's ring, icon and text. It is larger than f by SOURCE_PANEL_PAD on every side and
    -- follows f when it shows or hides.
    local panel = CreateFrame("Frame", nil, frame);
    panel:SetFrameLevel(frame:GetFrameLevel() + 2);
    panel:Hide();
    f:SetScript("OnShow", function() panel:Show(); end);
    f:SetScript("OnHide", function() panel:Hide(); end);
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", -SOURCE_PANEL_PAD, SOURCE_PANEL_PAD_V);
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", SOURCE_PANEL_PAD, -SOURCE_PANEL_PAD_V);
    f.panel = panel;
    f.panelSlice = addon.NineSlice:CreateTiled(panel, addon.ThemeUtil:GetFixedTextureFile("GenericFrame-Tiled-Large.blp"),
        {512, 512}, 80, SOURCE_PANEL_SCALE, "BACKGROUND");

    f.icon = f:CreateTexture(nil, "ARTWORK");
    f.border = RegisterKitTexture(f:CreateTexture(nil, "OVERLAY"));
    SetKitCoord(f.border, UV(768, 864, 1616, 1712));

    f.text = f:CreateFontString(nil, "OVERLAY");
    f.text:SetFontObject(SourceFont);
    f.text:SetJustifyH("LEFT");
    f.text:SetJustifyV("MIDDLE");
    f.text:SetTextColor(0.19, 0.17, 0.13);     -- dark brown on the tan paper

    self.source = f;
end

function Book:ShowSource(icon, text)
    local f = self.source;
    local border, effective, iconSize = cs.ITEM_BORDER_SIZE, cs.ITEM_BORDER_EFFECTIVE_SIZE, cs.ITEM_ICON_SIZE;
    local gap = Metrics.FONT_SIZE;
    -- The paper is as wide as the book. Its art has a transparent shadow margin, so the visible edge is inside.
    local stripWidth = Round(cs.FRAME_WIDTH + 2 * SOURCE_PANEL_SHADOW - 2 * SOURCE_PANEL_PAD);
    -- Left padding equal to the book's text padding, so the ring lines up with the text edge below.
    -- The strip is a little narrower than the book (shadow margin and padding), which is taken off.
    local leftPad = cs.PADDING_H - (cs.FRAME_WIDTH - stripWidth) / 2;
    local textLeft = leftPad + 0.5 * effective + 0.5 * border + gap;     -- strip left to the text
    local maxTextWidth = stripWidth - textLeft - leftPad;               -- same padding on the right

    -- Round icon: SetPortraitToTexture crops the icon with the portrait mask. Plain square icon if it fails.
    Size(f.icon, iconSize, iconSize);
    local ok = pcall(SetPortraitToTexture, f.icon, icon);
    if not ok then
        f.icon:SetTexture(icon);
        f.icon:SetTexCoord(0.0625, 0.9275, 0.0625, 0.9275);
    end

    Size(f.border, border, border);
    f.border:ClearAllPoints();
    f.border:SetPoint("CENTER", f, "LEFT", leftPad + 0.5 * effective, 0);
    f.icon:ClearAllPoints();
    f.icon:SetPoint("CENTER", f.border, "CENTER", 0, 0);

    -- Width of the text on one line, to size the strip. FontStrings have no GetWrappedWidth in 3.3.5a.
    f.text:SetSpacing(Metrics.TEXT_SPACING);
    f.text:SetText(text);
    f.text:SetWidth(0);
    f.text:SetHeight(0);
    local width = min(f.text:GetStringWidth(), maxTextWidth);
    f.text:SetWidth(width);
    local height = f.text:GetStringHeight();
    f.text:ClearAllPoints();
    f.text:SetPoint("LEFT", f.border, "RIGHT", gap, 0);

    local stripHeight = Round(max(height, effective));
    Size(f, stripWidth, stripHeight);
    f.panelSlice:Update(stripWidth + 2 * SOURCE_PANEL_PAD, stripHeight + 2 * SOURCE_PANEL_PAD_V);
    f:Show();
end

function Book:UpdateSourceButton()
    local f = self.source;
    f:Hide();
    self:SetLocation(nil);

    local info = Cache.itemInfo;
    if info then
        -- An item from the bags: flavor text above the book, sender line for the Plain Letter.
        if GetDBBool("BookUIItemDescription") then
            local icon, text = BookItem:GetDescription(info);
            if icon and text then
                self:ShowSource(icon, text);
            end
        end
        self:SetLocation(BookItem:GetLetterSender(info));
    elseif GetDBBool("BookShowLocation") then
        -- A readable standing in the world.
        self:SetLocation(BookItem:GetLocation());
    end
end


-- Show / hide ------------------------------------------------------------------------------------------------

-- Size and font settings are read again every time a book is built. With a book open, build it again from the
-- cached pages (keeping the reading position) so the change shows at once.
local function RebuildOpenBook()
    if Book:IsShown() and Cache.maxPage and Cache.pageTexts and Cache.pageTexts[1] then
        Book:SavePosition();
        Book:Build();
    end
end
addon.CallbackRegistry:Register("SettingChanged.BookUISize", RebuildOpenBook);
addon.CallbackRegistry:Register("SettingChanged.BookFontSize", RebuildOpenBook);

-- The vignette needs its own live update.
addon.CallbackRegistry:Register("SettingChanged.BookDarkenScreen", function(state)
    if Book.vignette and Book:IsShown() then
        if state then
            Book.vignette:Show();
        else
            Book.vignette:Hide();
        end
    end
end);

-- Distance still to go (1 at the start, 0 at the end), out-quart easing.
local function OutQuart(t, duration)
    local x = t / duration - 1;
    return x * x * x * x
end

local animElapsed = 0;

local function AnimOnUpdate(self, elapsed)
    animElapsed = animElapsed + elapsed;
    local ease = animElapsed >= ANIM_DURATION and 0 or OutQuart(animElapsed, ANIM_DURATION);
    self:SetAlpha(min(1, 4 * animElapsed));
    if animElapsed >= ANIM_DURATION then
        self:SetScript("OnUpdate", nil);
        self:SetAlpha(1);
    end
    ApplyAnchor(-ANIM_OFFSET * ease);
end

-- Shows the frame. The fly-in plays only when the book was not open yet.
function Book:ShowUI()
    if GetDBBool("BookDarkenScreen") then
        self.vignette:Show();
    else
        self.vignette:Hide();
    end
    if not frame:IsShown() then
        animElapsed = 0;
        frame:SetAlpha(0);
        ApplyAnchor(-ANIM_OFFSET);
        frame:Show();
        frame:SetScript("OnUpdate", AnimOnUpdate);
    end
end

function Book:IsShown()
    return frame and frame:IsShown()
end

function Book:Hide()
    if frame then
        frame:Hide();
    end
end

-- Esc closes the book. 3.3.5a has no SetPropagateKeyboardInput, so a keyboard frame would swallow every key.
-- An override binding replaces only Esc while the book is open (as FooterButtons.lua does for its buttons).
function Book:UpdateKeys()
    if InCombatLockdown() then
        self.keysDirty = true;
        return
    end
    self.keysDirty = false;
    ClearOverrideBindings(frame);
    if frame:IsShown() then
        SetOverrideBindingClick(frame, true, "ESCAPE", "DUI335BookCloseButton", "LeftButton");
    end
end

function Book:OnShow()
    self:UpdateKeys();
end

function Book:OnHide()
    self:SavePosition();
    frame:SetScript("OnUpdate", nil);
    frame:SetAlpha(1);
    self:UpdateKeys();
    if self.onHide then
        self.onHide();      -- BookEvents.lua: CloseItemText, stop page turning
    end
    self:ReleaseContent();
    pagePool:ReleaseAll();
    self.source:Hide();
    self.scrollFrame:ResetScroll();
end

-- Remembers where the player stopped reading.
function Book:SavePosition()
    if Cache.id and self.scrollFrame then
        Cache.positions[Cache.id] = self.scrollFrame.scrollTarget;
    end
end

-- Entry points for BookEvents.lua ---------------------------------------------------------------------------

-- A readable was opened. material: ItemTextGetMaterial(). itemInfo: BookItem:Resolve() result or nil.
function Book:BeginReading(material, title, itemInfo)
    self:Init();
    self.kitID = MaterialKit[material or "Parchment"] or 1;
    Cache:Reset(title, itemInfo);
end

function Book:AddPage(page, text)
    Cache.pageTexts[page] = text;
end

-- Every page is cached: lay out and show.
function Book:FinishReading(maxPage)
    Cache.maxPage = maxPage;
    self:Build();
    self:ShowUI();
end
