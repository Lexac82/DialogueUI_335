local _, addon = ...;

-- Big reward button (item, spell, title). Port of retail's DUIDialogItemButtonMixin
-- (UITemplates.lua 1396-1979, DialogueUI.xml 210-287) for 3.3.5a.
local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local Clamp = addon.API.Clamp;

local CreateFrame = CreateFrame;
local GetItemCount = GetItemCount;
local GetItemInfo = GetItemInfo;
local ceil = math.ceil;
local min = math.min;

local BUTTON_HEIGHT = 36;
local BORDER_SIZE = 36;
local ICON_SIZE = 28;                     -- retail: 32 with a 6 px inset on the 36 px border; tune in game
local ICON_TEXCOORD = {0.0625, 0.9275, 0.0625, 0.9275};
local NAME_LEFT = 40;
local NAME_RIGHT = 8;
local TWO_LINE_MAX_HEIGHT = 32;           -- 10 pt font: two lines ~ 27, three ~ 39 (3.2 x the font height, see below)

-- The item font follows the font size (HEIGHT_2 in FontUtil: base - 2): the limit scales with it.
addon.CallbackRegistry:Register("FontSizeChanged", function(baseFontSize)
    TWO_LINE_MAX_HEIGHT = 3.2 * (baseFontSize - 2);
end);

local BACKGROUND_NORMAL = "ItemButtonBackground.blp";    -- 64x64, slice margin 16
local BACKGROUND_CHOOSE = "RewardChoice-Pending.blp";    -- 256x64, slice margin 16
local BORDER_NORMAL = "ItemBorder.blp";
local BORDER_CHOOSE = "RewardChoice-ItemBorder.blp";
local OVERLAY_FILE = "ItemOverlays.blp";                 -- 8x8 grid of 64 px cells
local SHEEN_FILE = "RewardChoice-Sheen.blp";
local COIN_FILE = "Coin-Gold.blp";
local UPGRADE_FILE = "Interface\\AddOns\\DialogueUI_335\\Textures\\Shared\\ItemIsUpgrade.blp";    -- 64x64, same for both themes
local UPGRADE_SIZE = 32;
-- Retail IconAnimation_FlyUp: starts 0.5 s late, rises 12 px over 0.5 s (outSine), fades in at 4 per second.
local UPGRADE_DELAY = 0.5;
local UPGRADE_DURATION = 0.5;
local UPGRADE_RISE = 12;

local OVERLAY_ALERT_INDEX = 10;           -- red "!" used for unusable items

local COLOR_NORMAL = {"DarkBrown", "DarkModeGrey90"};     -- DUIFont_Item
local COLOR_CHOOSE = {"Ivory", "DarkModeGold"};           -- DUIFont_ItemSelect

local FADE_SPEED = 1 / 0.15;              -- retail FadeFrame duration 0.15 s

-- Sheen: retail AnimSheen (0.25 s delay, 0.6 s travel of 140 px, fade in 0.2, fade out 0.45 after 0.1).
local SHEEN_DELAY = 0.25;
local SHEEN_TRAVEL = 140;
local SHEEN_TRAVEL_TIME = 0.6;
local SHEEN_END = SHEEN_DELAY + 0.1 + 0.45 + 0.2;

local ICON_TITLE = "Interface\\Icons\\INV_Misc_Note_02";
local ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark";

local RewardItemButton = {};
RewardItemButton.__index = RewardItemButton;

local function SetOverlay(texture, index)
    if not index then
        texture:Hide();
        return
    end
    -- 1-based cell index, row-major in an 8 column grid.
    local column = (index - 1) % 8;
    local row = (index - 1 - column) / 8;
    texture:SetTexCoord(column / 8, (column + 1) / 8, row / 8, (row + 1) / 8);
    texture:Show();
end

function RewardItemButton:SetStyle(style)
    self.style = style;
    local choose = (style == 2);
    NineSlice:SetShown(self.backgroundNormal, not choose);
    NineSlice:SetShown(self.backgroundChoose, choose);
    self.border:SetTexture(ThemeUtil:GetTextureFile(choose and BORDER_CHOOSE or BORDER_NORMAL));
    self:UpdateNameColor();
end

-- Name color: the font color (Ivory when chosen). In Dark the name takes its item quality color (retail).
function RewardItemButton:UpdateNameColor()
    local font = (self.style == 2) and self.fontChoose or self.fontNormal;
    self.name:SetFontObject(font);
    local entry = self.entry;
    if self.style ~= 2 and entry and entry.kind == "item" and entry.quality and ThemeUtil:IsDarkMode() then
        self.name:SetTextColor(ThemeUtil:GetQualityColor(entry.quality));
    else
        self.name:SetTextColor(font:GetTextColor());     -- explicit, so a quality color from before is gone
    end
end

function RewardItemButton:SetCount(text)
    self.count:SetText(text or "");
end

-- Name width: widen by one grid cell at a time while the name needs a third line (retail FitToName).
-- baseWidth: width in px for the default size. cellStep: px added per extra cell. maxExtra: how many cells at most.
function RewardItemButton:Fit(baseWidth, cellStep, maxExtra)
    local width = baseWidth;
    local name = self.name;
    for extra = 0, maxExtra or 0 do
        width = baseWidth + extra * cellStep;
        name:SetWidth(width - NAME_LEFT - NAME_RIGHT);
        if name:GetStringHeight() <= TWO_LINE_MAX_HEIGHT then
            break
        end
    end
    self.frame:SetWidth(width);
    name:SetWidth(width - NAME_LEFT - NAME_RIGHT);
    return width
end

function RewardItemButton:SetWidth(width)
    self.frame:SetWidth(width);
    self.name:SetWidth(width - NAME_LEFT - NAME_RIGHT);
end

-- Fills the button from a QuestData entry.
function RewardItemButton:SetEntry(entry)
    self.entry = entry;
    local overlay, count;
    local texture, name = ICON_UNKNOWN, "";

    if entry.kind == "item" then
        texture = entry.texture or ICON_UNKNOWN;
        name = entry.name or "";

        if entry.itemType == "required" then
            -- Owned / needed, as retail: owned count in grey.
            local owned = entry.link and GetItemCount(entry.link) or 0;
            local ownedText = owned > 999 and "*" or owned;
            count = "|cffaaaaaa" .. ownedText .. "/|r" .. entry.count;
        elseif entry.count and entry.count > 1 then
            count = entry.count;
        end

        if entry.itemType ~= "required" and not entry.isUsable then
            overlay = OVERLAY_ALERT_INDEX;           -- can't use it
        elseif entry.quality and entry.quality >= 2 then
            overlay = entry.quality;                 -- uncommon .. legendary corner triangle
        end
    elseif entry.kind == "spell" then
        texture = entry.texture or ICON_UNKNOWN;
        name = entry.name or "";
    elseif entry.kind == "title" then
        texture = ICON_TITLE;
        name = "Title: " .. (entry.name or "");
    end

    self.icon:SetTexture(texture);
    self.name:SetText(name);
    self:UpdateNameColor();
    self:SetCount(count);
    SetOverlay(self.overlay, overlay);
    self:SetSellMarker(false);
    self:SetUpgradeMarker(false);
    self.frame:SetAlpha(1);
    self.targetAlpha = 1;
end

-- Gold coin on the icon marks the most valuable choice (retail SetHighestSellPrice).
function RewardItemButton:SetSellMarker(shown)
    if shown then
        if not self.coin then
            local coin = self.topFrame:CreateTexture(nil, "OVERLAY");
            ThemeUtil:BindTexture(coin, COIN_FILE);
            coin:SetWidth(15);
            coin:SetHeight(15);
            coin:SetPoint("CENTER", self.icon, "TOPLEFT", 3, -3);
            self.coin = coin;
        end
        self.coin:Show();
    elseif self.coin then
        self.coin:Hide();
    end
end

-- Green arrow at the bottom left of the icon: the item is an upgrade (retail ShowUpgradeIcon).
-- animate: fly up (retail does it while the player is choosing a reward).
function RewardItemButton:SetUpgradeMarker(shown, animate)
    local marker = self.upgradeFrame;
    if not shown then
        if marker then
            marker:SetScript("OnUpdate", nil);
            marker:Hide();
        end
        return
    end

    if not marker then
        marker = CreateFrame("Frame", nil, self.frame);
        marker:SetFrameLevel(self.frame:GetFrameLevel() + 4);
        marker:SetWidth(UPGRADE_SIZE);
        marker:SetHeight(UPGRADE_SIZE);
        marker:SetPoint("CENTER", self.icon, "BOTTOMLEFT", 1, 5);
        marker.texture = marker:CreateTexture(nil, "OVERLAY");
        marker.texture:SetWidth(UPGRADE_SIZE);
        marker.texture:SetHeight(UPGRADE_SIZE);
        marker.texture:SetTexture(UPGRADE_FILE);
        marker.texture:SetPoint("CENTER", marker, "CENTER", 0, 0);
        self.upgradeFrame = marker;
    end
    if marker:IsShown() then
        return                  -- already up (a refresh must not replay the animation)
    end
    marker:Show();
    marker.texture:ClearAllPoints();
    marker.texture:SetPoint("CENTER", marker, "CENTER", 0, 0);
    marker:SetAlpha(1);
    marker:SetScript("OnUpdate", nil);

    if animate then
        local t, alpha = -UPGRADE_DELAY, 0;
        marker:SetAlpha(0);
        marker:SetScript("OnUpdate", function(f, elapsed)
            t = t + elapsed;
            if t <= 0 then
                return
            end
            alpha = min(1, alpha + 4 * elapsed);
            f:SetAlpha(alpha);
            local progress = min(1, t / UPGRADE_DURATION);
            f.texture:ClearAllPoints();
            f.texture:SetPoint("CENTER", f, "CENTER", 0, -UPGRADE_RISE * (1 - math.sin(progress * math.pi / 2)));
            if progress >= 1 and alpha >= 1 then
                f:SetScript("OnUpdate", nil);
            end
        end);
    end
end

-- Smooth fade (retail FadeFrame): used to dim the choices that were not picked.
function RewardItemButton:FadeTo(alpha)
    self.targetAlpha = alpha;
    local frame = self.frame;
    if not frame:IsShown() then
        frame:SetAlpha(alpha);
        return
    end
    frame:SetScript("OnUpdate", function(f, elapsed)
        local current = f:GetAlpha();
        local target = self.targetAlpha;
        local step = elapsed * FADE_SPEED;
        if current < target then
            current = min(target, current + step);
        else
            current = math.max(target, current - step);
        end
        f:SetAlpha(current);
        if current == target then
            f:SetScript("OnUpdate", nil);
        end
    end);
end

function RewardItemButton:StopFade()
    self.frame:SetScript("OnUpdate", nil);
end

-- Sheen sweep across the button, used to flash the choices (retail AnimSheen).
function RewardItemButton:PlaySheen()
    local sheen = self.sheen;
    local host = self.sheenFrame;
    local elapsed = 0;
    sheen:Show();
    sheen:SetAlpha(0);
    host:SetScript("OnUpdate", function(f, dt)
        elapsed = elapsed + dt;
        if elapsed >= SHEEN_END then
            sheen:Hide();
            f:SetScript("OnUpdate", nil);
            return
        end
        local t = elapsed - SHEEN_DELAY;
        if t < 0 then
            return
        end
        local rise = min(1, t / 0.2);
        local fall = 1 - Clamp((t - 0.1) / 0.45, 0, 1);
        sheen:SetAlpha(min(rise, fall));
        local progress = Clamp(t / SHEEN_TRAVEL_TIME, 0, 1);
        local eased = 1 - (1 - progress) * (1 - progress);      -- smoothing "OUT"
        sheen:ClearAllPoints();
        sheen:SetPoint("LEFT", self.frame, "LEFT", SHEEN_TRAVEL * eased, 0);
    end);
end

function RewardItemButton:Release()
    self:StopFade();
    self.sheenFrame:SetScript("OnUpdate", nil);
    self.sheen:Hide();
    self.entry = nil;
    self:SetUpgradeMarker(false);
    self.frame:ClearAllPoints();
    self.frame:Hide();
end

-- host: RewardLayout. It handles hover, click and selection.
local function CreateRewardItemButton(parent, host)
    local self = setmetatable({}, RewardItemButton);
    self.host = host;

    self.fontNormal = FontUtil:GetColoredFont("DUI335_Item", 10, COLOR_NORMAL);
    self.fontChoose = FontUtil:GetColoredFont("DUI335_ItemSelect", 10, COLOR_CHOOSE);

    local frame = CreateFrame("Button", nil, parent);
    frame:SetHeight(BUTTON_HEIGHT);
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp");
    frame:Hide();
    self.frame = frame;

    self.backgroundNormal = NineSlice:Create(frame, ThemeUtil:GetTextureFile(BACKGROUND_NORMAL), {64, 64}, 16, 16, "BACKGROUND");
    self.backgroundChoose = NineSlice:Create(frame, ThemeUtil:GetTextureFile(BACKGROUND_CHOOSE), {256, 64}, 16, 16, "BACKGROUND");
    ThemeUtil:BindSlice(self.backgroundNormal, BACKGROUND_NORMAL);
    ThemeUtil:BindSlice(self.backgroundChoose, BACKGROUND_CHOOSE);

    local icon = frame:CreateTexture(nil, "ARTWORK");
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("CENTER", frame, "LEFT", BORDER_SIZE / 2, 0);
    icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4]);
    self.icon = icon;

    local border = frame:CreateTexture(nil, "OVERLAY");
    border:SetWidth(BORDER_SIZE);
    border:SetHeight(BORDER_SIZE);
    border:SetPoint("CENTER", icon, "CENTER", 0, 0);
    self.border = border;

    -- Quality / alert overlay, count and sell marker live on a child frame one level above the button.
    -- Inside one frame, 3.3.5a draws textures of the same layer in no guaranteed order, and the border
    -- (also OVERLAY) was drawn over them. A higher frame level always draws on top.
    local topFrame = CreateFrame("Frame", nil, frame);
    topFrame:SetAllPoints(frame);
    topFrame:SetFrameLevel(frame:GetFrameLevel() + 2);
    self.topFrame = topFrame;

    local overlay = topFrame:CreateTexture(nil, "OVERLAY");
    ThemeUtil:BindTexture(overlay, OVERLAY_FILE);
    overlay:SetWidth(BORDER_SIZE);
    overlay:SetHeight(BORDER_SIZE);
    overlay:SetPoint("CENTER", icon, "CENTER", 0, 0);
    overlay:Hide();
    self.overlay = overlay;

    local name = frame:CreateFontString(nil, "ARTWORK");
    name:SetJustifyH("LEFT");
    name:SetJustifyV("MIDDLE");
    name:SetWordWrap(true);
    name:SetSpacing(2);
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", NAME_LEFT, 0);
    name:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", NAME_LEFT, 0);
    self.name = name;

    local count = topFrame:CreateFontString(nil, "OVERLAY");
    count:SetFontObject(FontUtil:GetCountFont());
    count:SetJustifyH("RIGHT");
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1);
    self.count = count;

    -- Sheen lives on its own frame so its OnUpdate never collides with the fade's.
    local sheenFrame = CreateFrame("Frame", nil, frame);
    sheenFrame:SetAllPoints(frame);
    local sheen = sheenFrame:CreateTexture(nil, "OVERLAY");
    ThemeUtil:BindTexture(sheen, SHEEN_FILE);
    sheen:SetBlendMode("ADD");
    sheen:SetWidth(BORDER_SIZE);
    sheen:SetHeight(BORDER_SIZE);
    sheen:SetPoint("LEFT", frame, "LEFT", 0, 0);
    sheen:Hide();
    self.sheen = sheen;
    self.sheenFrame = sheenFrame;

    frame:SetScript("OnEnter", function()
        host:OnButtonEnter(self);
    end);
    frame:SetScript("OnLeave", function()
        host:OnButtonLeave(self);
    end);
    frame:SetScript("OnClick", function(_, mouseButton)
        host:OnButtonClick(self, mouseButton);
    end);

    self:SetStyle(1);

    -- The border file and the name color depend on the style.
    addon.CallbackRegistry:Register("ThemeChanged", function()
        self:SetStyle(self.style);
    end);
    return self
end

addon.CreateRewardItemButton = CreateRewardItemButton;
addon.REWARD_BUTTON_HEIGHT = BUTTON_HEIGHT;
