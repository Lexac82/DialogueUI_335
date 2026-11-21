local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local L = addon.L;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local max = math.max;

-- Header buttons of the manual loot window: Take All (with its hotkey) and Close.
-- Same sheet as the Settings close button: two 128x64 cells (normal, hover) of Settings-CloseButton, 16 px corners.
local SHEET_FILE = "Settings-CloseButton.blp";
local SHEET_NORMAL = { 0, 0, 256, 128 };
local SHEET_HOVER = { 128, 0, 256, 128 };
local HOTKEY_FILE = "HotkeyBackground.blp";             -- 32x32, margin 8
local BUTTON_HEIGHT = 28;
local HOTKEY_PADDING = 4;
local TEXT_PADDING = 10;
local CLICK_GLOW_DURATION = 0.9;

local FONT_COLOR = {"Ivory", "DarkModeGold"};
local HOTKEY_FONT_COLOR = {"DarkModeGrey70", "DarkModeGrey70"};


local function CreateButtonBase(parent, name)
    local button = CreateFrame("Button", name, parent);
    button:SetHeight(BUTTON_HEIGHT);
    button:RegisterForClicks("LeftButtonUp");
    local level = button:GetFrameLevel();

    local back = CreateFrame("Frame", nil, button);
    back:SetAllPoints(button);
    back:SetFrameLevel(level);
    button.background = NineSlice:CreateTiled(back, ThemeUtil:GetTextureFile(SHEET_FILE), { 128, 64 }, 16, 1, "BACKGROUND", SHEET_NORMAL);
    ThemeUtil:BindSlice(button.background, SHEET_FILE);

    local hover = CreateFrame("Frame", nil, button);
    hover:SetAllPoints(button);
    hover:SetFrameLevel(level + 1);
    button.hover = NineSlice:CreateTiled(hover, ThemeUtil:GetTextureFile(SHEET_FILE), { 128, 64 }, 16, 1, "ARTWORK", SHEET_HOVER);
    button.hover:SetShown(false);
    ThemeUtil:BindSlice(button.hover, SHEET_FILE);

    local content = CreateFrame("Frame", nil, button);
    content:SetAllPoints(button);
    content:SetFrameLevel(level + 2);
    button.content = content;

    button:SetScript("OnEnter", function(self)
        self.hover:SetShown(true);
        self.lootFrame:SetFocused(true);
    end);
    button:SetScript("OnLeave", function(self)
        self.hover:SetShown(false);
        self.lootFrame:SetFocused(false);
    end);
    return button
end

local function ResizeBackground(button)
    local w, h = button:GetWidth(), button:GetHeight();
    button.background:Update(w, h);
    button.hover:Update(w, h);
end


---------------------------------------------------------------------------
-- Close button
---------------------------------------------------------------------------

function LootUI.CreateCloseButton(parent, lootFrame)
    local button = CreateButtonBase(parent, "DialogueUI335LootClose");
    button.lootFrame = lootFrame;
    button:SetWidth(BUTTON_HEIGHT);
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp");

    local icon = button.content:CreateTexture(nil, "OVERLAY");
    ThemeUtil:BindTexture(icon, SHEET_FILE);
    icon:SetTexCoord(0.0625, 0.1875, 0.625, 0.875);
    icon:SetWidth(14);
    icon:SetHeight(14);
    icon:SetPoint("CENTER", button, "CENTER", 0, 0);

    ResizeBackground(button);
    button:SetScript("OnClick", function()
        lootFrame:CloseFromClick();
    end);
    return button
end


---------------------------------------------------------------------------
-- Take All
---------------------------------------------------------------------------

local TakeAll = {};

function TakeAll:SetHotkeyVisual(key)
    local hotkey = self.hotkey;
    if key then
        self.hotkeyName = key;
        hotkey.text:SetText(key);
        local bgSize = max(BUTTON_HEIGHT - 2 * HOTKEY_PADDING, hotkey.text:GetStringWidth() + 2 * HOTKEY_PADDING);
        hotkey:SetWidth(bgSize);
        hotkey:SetHeight(BUTTON_HEIGHT - 2 * HOTKEY_PADDING);
        hotkey:Show();
    else
        self.hotkeyName = nil;
        hotkey:Hide();
    end
    self:Layout();
end

function TakeAll:Layout()
    local text = self.text;
    text:ClearAllPoints();
    local width;
    if self.hotkeyName then
        self.hotkey:ClearAllPoints();
        self.hotkey:SetPoint("LEFT", self, "LEFT", TEXT_PADDING, 0);
        text:SetPoint("LEFT", self.hotkey, "RIGHT", HOTKEY_PADDING + 2, 0);
        width = TEXT_PADDING + self.hotkey:GetWidth() + HOTKEY_PADDING + 2 + text:GetStringWidth() + TEXT_PADDING;
    else
        text:SetPoint("LEFT", self, "LEFT", TEXT_PADDING, 0);
        width = text:GetStringWidth() + 2 * TEXT_PADDING;
    end
    self:SetWidth(max(width, 2 * BUTTON_HEIGHT));
    ResizeBackground(self);
end

-- Hotkey: an override binding that clicks this button, set while the window is open and the player is out of
-- combat (3.3.5a has no SetPropagateKeyboardInput, so a key handler would swallow the key).
function TakeAll:UpdateHotkey()
    ClearOverrideBindings(self);
    if Def.USE_HOTKEY and Def.TAKE_ALL_KEY and not InCombatLockdown() then
        self:SetHotkeyVisual(Def.TAKE_ALL_KEY);
        SetOverrideBindingClick(self, true, Def.TAKE_ALL_KEY, self:GetName(), "LeftButton");
    else
        self:SetHotkeyVisual(nil);
    end
end

function TakeAll:PlayClick()
    local glow = self.glow;
    local t = 0;
    glow:Show();
    glow:SetAlpha(1);
    self.glowDriver:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed;
        if t >= CLICK_GLOW_DURATION then
            glow:Hide();
            self.glowDriver:SetScript("OnUpdate", nil);
            return
        end
        glow:SetAlpha(t < 0.1 and (t / 0.1) or (1 - (t - 0.1) / (CLICK_GLOW_DURATION - 0.1)));
    end);
end

function LootUI.CreateTakeAllButton(parent, lootFrame)
    local button = CreateButtonBase(parent, "DialogueUI335LootTakeAll");
    addon.API.Mixin(button, TakeAll);
    button.lootFrame = lootFrame;

    button.font = LootUI.GetSizedFont("DUI335_LootButton", 10, FONT_COLOR);
    button.hotkeyFont = LootUI.GetSizedFont("DUI335_LootHotkey", 10, HOTKEY_FONT_COLOR);

    button.text = button.content:CreateFontString(nil, "OVERLAY");
    button.text:SetFontObject(button.font);
    button.text:SetText(L["Take All"]);

    local hotkey = CreateFrame("Frame", nil, button.content);
    hotkey:SetFrameLevel(button.content:GetFrameLevel() + 1);
    hotkey.slice = NineSlice:Create(hotkey, ThemeUtil:GetTextureFile(HOTKEY_FILE), {32, 32}, 8, 8, "ARTWORK");
    ThemeUtil:BindSlice(hotkey.slice, HOTKEY_FILE);
    hotkey.text = hotkey:CreateFontString(nil, "OVERLAY");
    hotkey.text:SetFontObject(button.hotkeyFont);
    hotkey.text:SetPoint("CENTER", hotkey, "CENTER", 0, 0);
    hotkey:Hide();
    button.hotkey = hotkey;

    -- Click feedback: the hover plate flashes.
    local glowFrame = CreateFrame("Frame", nil, button);
    glowFrame:SetAllPoints(button);
    glowFrame:SetFrameLevel(button:GetFrameLevel() + 1);
    glowFrame:Hide();
    glowFrame.slice = NineSlice:CreateTiled(glowFrame, ThemeUtil:GetTextureFile(SHEET_FILE), { 128, 64 }, 16, 1, "ARTWORK", SHEET_HOVER);
    ThemeUtil:BindSlice(glowFrame.slice, SHEET_FILE);
    button.glow = glowFrame;
    button.glowDriver = CreateFrame("Frame", nil, button);

    button:Layout();

    function button:OnClickTakeAll()
        lootFrame:LootAllItemsSorted();
        self:PlayClick();
    end
    button:SetScript("OnClick", button.OnClickTakeAll);

    button:SetScript("OnShow", function(self)
        self:UpdateHotkey();
        self.glowFrameSize = nil;
        self.glow.slice:Update(self:GetWidth(), self:GetHeight());
    end);
    button:SetScript("OnHide", function(self)
        ClearOverrideBindings(self);
        self.glowDriver:SetScript("OnUpdate", nil);
        self.glow:Hide();
    end);
    button:RegisterEvent("PLAYER_REGEN_DISABLED");
    button:RegisterEvent("PLAYER_REGEN_ENABLED");
    button:SetScript("OnEvent", function(self)
        if self:IsShown() then
            self:UpdateHotkey();
        end
    end);

    return button
end


---------------------------------------------------------------------------
-- Pagination dot (notifications that did not fit on one page)
---------------------------------------------------------------------------

function LootUI.CreateDot(parent)
    local dot = parent:CreateTexture(nil, "OVERLAY");
    dot:SetTexture("Interface\\AddOns\\DialogueUI\\Textures\\Shared\\LootPageDot.tga");     -- 32x32, from Plumber's LootUI.png
    dot:SetWidth(Def.DOT_SIZE);
    dot:SetHeight(Def.DOT_SIZE);
    return dot
end


---------------------------------------------------------------------------
-- Master looter menu. The game's own list (GroupLootDropDown) is FrameXML, not in wow-docs, so the candidates are
-- listed here with GetMasterLootCandidate and handed out with GiveMasterLoot.
---------------------------------------------------------------------------

do
    local MAX_CANDIDATES = 40;
    local BUTTON_W, BUTTON_H, MENU_PAD = 150, 22, 12;
    local menu;
    local buttons = {};

    local function CreateMenu()
        local f = CreateFrame("Frame", "DialogueUI335LootMasterMenu", addon.UIRoot);
        f:SetFrameStrata("FULLSCREEN_DIALOG");
        f:SetClampedToScreen(true);
        f:EnableMouse(true);
        f:Hide();
        f.background = LootUI.CreateBackground(f);
        f.title = f:CreateFontString(nil, "OVERLAY");
        f.title:SetFontObject(LootUI.GetSizedFont("DUI335_LootButton", 10, FONT_COLOR));
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", MENU_PAD, -MENU_PAD);
        f.title:SetText(L["Give To"]);
        f:SetScript("OnHide", function()
            f.slot = nil;
        end);
        return f
    end

    local function GetButton(i)
        local b = buttons[i];
        if not b then
            b = CreateFrame("Button", nil, menu);
            b:SetWidth(BUTTON_W);
            b:SetHeight(BUTTON_H);
            b:SetFrameLevel(menu:GetFrameLevel() + 3);
            b.text = b:CreateFontString(nil, "OVERLAY");
            b.text:SetFontObject(LootUI.GetSizedFont("DUI335_LootButton", 10, FONT_COLOR));
            b.text:SetPoint("LEFT", b, "LEFT", 6, 0);
            b.highlight = b:CreateTexture(nil, "HIGHLIGHT");
            b.highlight:SetTexture(ThemeUtil:GetTextureFile("ButtonHighlight-Add.blp"));
            b.highlight:SetBlendMode("ADD");
            b.highlight:SetAllPoints(b);
            b:SetScript("OnClick", function(self)
                if menu.slot and self.candidate then
                    GiveMasterLoot(menu.slot, self.candidate);
                end
                menu:Hide();
            end);
            buttons[i] = b;
        end
        return b
    end

    function LootUI.HideMasterLootMenu()
        if menu then
            menu:Hide();
        end
    end

    function LootUI.ShowMasterLootMenu(slotIndex, anchor)
        if not slotIndex then
            return
        end
        menu = menu or CreateMenu();
        for _, b in ipairs(buttons) do
            b:Hide();
        end

        local n = 0;
        for i = 1, MAX_CANDIDATES do
            local name = GetMasterLootCandidate(i);
            if name then
                n = n + 1;
                local b = GetButton(n);
                b.candidate = i;
                b.text:SetText(name);
                b:ClearAllPoints();
                b:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, -MENU_PAD - 18 - (n - 1) * BUTTON_H);
                b:Show();
            end
        end
        if n == 0 then
            menu:Hide();
            return
        end

        menu.slot = slotIndex;
        local width = BUTTON_W + 2 * MENU_PAD;
        local height = 2 * MENU_PAD + 18 + n * BUTTON_H;
        menu:SetWidth(width);
        menu:SetHeight(height);
        menu.background:UpdatePixel();
        menu.background:SetBackgroundSize(width, height);
        menu:ClearAllPoints();
        menu:SetPoint("TOPLEFT", anchor or UIParent, anchor and "TOPRIGHT" or "CENTER", 12, 0);
        menu:Show();
    end
end
