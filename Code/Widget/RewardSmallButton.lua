local _, addon = ...;

-- Small reward row (money, XP, honor, talent and arena points, required money).
-- Port of retail's DUIDialogSmallItemButtonMixin (UITemplates.lua 1981-2131, DialogueUI.xml 289-326).
local L = addon.L;
local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local MoneyUtil = addon.MoneyUtil;
local FrameSize = addon.FrameSize;

local CreateFrame = CreateFrame;
local UnitXPMax = UnitXPMax;
local GetMoney = GetMoney;
local GetCoinText = GetCoinText;
local floor = math.floor;
local ceil = math.ceil;
local max = math.max;

-- Sizes are for frame size multiplier 1 and are scaled when applied.
local ROW_HEIGHT = 15;
local ICON_SIZE = 15;
local TEXT_LEFT = 18;
local TEXT_RIGHT = 6;
local BACKGROUND_FILE = "ItemButtonBackground.blp";
local XP_FILE = "XP-Purple.blp";
local TEXT_COLOR = {"DarkBrown", "DarkModeGrey90"};     -- DUIFont_Item

local ICON_HONOR = "Interface\\AddOns\\DialogueUI\\Textures\\Icons\\Honor-Small.blp";
local ICON_ARENA = "Interface\\AddOns\\DialogueUI\\Textures\\Icons\\Conquest-Small.blp";
local ICON_TALENTS = "Interface\\Icons\\INV_Misc_Book_11";

local RewardSmallButton = {};
RewardSmallButton.__index = RewardSmallButton;

local function ClientFile(file)
    return ThemeUtil:GetTextureFile(file)
end

-- Sizes the row for the current frame size. Never lower than its text: the font size is a setting of its own.
function RewardSmallButton:ApplySize()
    local _, fontHeight = self.font:GetFont();
    local frame = self.frame;
    frame:SetHeight(max(FrameSize:Scale(ROW_HEIGHT), ceil(fontHeight + 4)));
    local iconSize = FrameSize:Scale(ICON_SIZE);
    self.icon:SetWidth(iconSize);
    self.icon:SetHeight(iconSize);
    self.text:SetPoint("LEFT", frame, "LEFT", FrameSize:Scale(TEXT_LEFT), 0);
end

-- Fills the row from a QuestData entry. Returns the text width so the layout can size the row.
function RewardSmallButton:SetEntry(entry)
    self.entry = entry;
    self:ApplySize();
    local kind = entry.kind;
    local icon, text, red;

    if kind == "money" then
        icon = ClientFile(MoneyUtil:GetCoinFile(entry.amount));
        text = MoneyUtil:GetShortText(entry.amount);
    elseif kind == "requiredMoney" then
        -- Costs on the progress page: full words, red when the player cannot pay (retail shows an overflow icon).
        icon = ClientFile(MoneyUtil:GetCoinFile(entry.amount));
        text = GetCoinText(entry.amount, " ");
        red = GetMoney() < entry.amount;
    elseif kind == "xp" then
        icon = ClientFile(XP_FILE);
        local maxXP = UnitXPMax("player");
        text = MoneyUtil.Thousands(entry.amount);
        if maxXP and maxXP > 0 then
            text = text .. " (" .. floor(entry.amount / maxXP * 100 + 0.5) .. "%)";
        end
    elseif kind == "honor" then
        icon = ICON_HONOR;
        text = MoneyUtil.Thousands(entry.amount) .. " " .. L["Honor Points"];
    elseif kind == "arena" then
        icon = ICON_ARENA;
        text = MoneyUtil.Thousands(entry.amount) .. " " .. L["Arena Points"];
    elseif kind == "talents" then
        icon = ICON_TALENTS;
        text = L[entry.amount == 1 and "Format Talent Point Row" or "Format Talent Points Row"]:format(entry.amount);
    else
        icon, text = "", "";
    end

    self.icon:SetTexture(icon);
    self.text:SetText(text);
    if red then
        self.text:SetTextColor(ThemeUtil:GetWarningColor());
    else
        self.text:SetTextColor(self.font:GetTextColor());
    end
    self.frame:SetAlpha(1);
end

-- Width that fits the text, at least minWidth.
function RewardSmallButton:FitWidth(minWidth)
    local padding = FrameSize:Scale(TEXT_LEFT) + FrameSize:Scale(TEXT_RIGHT);
    local width = max(minWidth, padding + self.text:GetStringWidth());
    self.frame:SetWidth(width);
    return width
end

function RewardSmallButton:Release()
    self.entry = nil;
    self.frame:ClearAllPoints();
    self.frame:Hide();
end

local function CreateRewardSmallButton(parent, host)
    local self = setmetatable({}, RewardSmallButton);
    self.host = host;

    local frame = CreateFrame("Button", nil, parent);
    frame:Hide();
    self.frame = frame;

    -- Drawn corner 7 px: the row is only 15 px high, so the 16 px slice margin would overlap.
    local background = NineSlice:Create(frame, ThemeUtil:GetTextureFile(BACKGROUND_FILE), {64, 64}, 16, 7, "BACKGROUND");
    ThemeUtil:BindSlice(background, BACKGROUND_FILE);

    local icon = frame:CreateTexture(nil, "ARTWORK");
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0);
    self.icon = icon;

    local text = frame:CreateFontString(nil, "ARTWORK");
    self.font = FontUtil:GetColoredFont("DUI335_Item", 10, TEXT_COLOR);
    text:SetFontObject(self.font);
    text:SetJustifyH("LEFT");
    text:SetJustifyV("MIDDLE");
    text:SetWordWrap(false);
    self.text = text;
    self:ApplySize();

    -- Tooltips for these rows: XP, honor, talents and arena only (money has none, as retail).
    frame:SetScript("OnEnter", function()
        host:OnButtonEnter(self);
    end);
    frame:SetScript("OnLeave", function()
        host:OnButtonLeave(self);
    end);

    -- Icon file, money colors and the warning color depend on the theme: fill the row again.
    addon.CallbackRegistry:Register("ThemeChanged", function()
        if self.entry then
            self:SetEntry(self.entry);
        end
    end);

    return self
end

addon.CreateRewardSmallButton = CreateRewardSmallButton;
