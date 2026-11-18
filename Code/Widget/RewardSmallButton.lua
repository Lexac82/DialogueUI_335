local _, addon = ...;

-- Small reward row (money, XP, honor, talent and arena points, required money).
-- Port of retail's DUIDialogSmallItemButtonMixin (UITemplates.lua 1981-2131, DialogueUI.xml 289-326).
local L = addon.L;
local FontUtil = addon.FontUtil;
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local MoneyUtil = addon.MoneyUtil;

local CreateFrame = CreateFrame;
local UnitXPMax = UnitXPMax;
local UnitFactionGroup = UnitFactionGroup;
local GetMoney = GetMoney;
local GetCoinText = GetCoinText;
local floor = math.floor;
local max = math.max;

local ROW_HEIGHT = 15;
local ICON_SIZE = 15;
local TEXT_LEFT = 18;
local TEXT_RIGHT = 6;
local BACKGROUND_FILE = "ItemButtonBackground.blp";
local XP_FILE = "XP-Purple.blp";
local TEXT_COLOR = {0.19, 0.17, 0.13};
local RED_COLOR = {0.61, 0.125, 0.125};       -- ThemeUtil:AdjustTextColor turns pure red into |cff9B2020 on Brown

local ICON_HONOR = {
    Alliance = "Interface\\PVPFrame\\PVP-Currency-Alliance",
    Horde = "Interface\\PVPFrame\\PVP-Currency-Horde",
};
local ICON_ARENA = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon";
local ICON_TALENTS = "Interface\\Icons\\INV_Misc_Book_11";

local RewardSmallButton = {};
RewardSmallButton.__index = RewardSmallButton;

local function ClientFile(file)
    return ThemeUtil:GetTextureFile(file)
end

-- Fills the row from a QuestData entry. Returns the text width so the layout can size the row.
function RewardSmallButton:SetEntry(entry)
    self.entry = entry;
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
        icon = ICON_HONOR[UnitFactionGroup("player")] or ICON_HONOR.Horde;
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
    local color = red and RED_COLOR or TEXT_COLOR;
    self.text:SetTextColor(color[1], color[2], color[3]);
    self.frame:SetAlpha(1);
end

-- Width that fits the text, at least minWidth.
function RewardSmallButton:FitWidth(minWidth)
    local width = max(minWidth, TEXT_LEFT + self.text:GetStringWidth() + TEXT_RIGHT);
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
    frame:SetHeight(ROW_HEIGHT);
    frame:Hide();
    self.frame = frame;

    -- Drawn corner 7 px: the row is only 15 px high, so the 16 px slice margin would overlap.
    NineSlice:Create(frame, ThemeUtil:GetTextureFile(BACKGROUND_FILE), {64, 64}, 16, 7, "BACKGROUND");

    local icon = frame:CreateTexture(nil, "ARTWORK");
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0);
    self.icon = icon;

    local text = frame:CreateFontString(nil, "ARTWORK");
    text:SetFontObject(FontUtil:GetColoredFont("DUI335_Item", 10, TEXT_COLOR));
    text:SetJustifyH("LEFT");
    text:SetJustifyV("MIDDLE");
    text:SetWordWrap(false);
    text:SetPoint("LEFT", frame, "LEFT", TEXT_LEFT, 0);
    self.text = text;

    -- Tooltips for these rows: XP, honor, talents and arena only (money has none, as retail).
    frame:SetScript("OnEnter", function()
        host:OnButtonEnter(self);
    end);
    frame:SetScript("OnLeave", function()
        host:OnButtonLeave(self);
    end);

    return self
end

addon.CreateRewardSmallButton = CreateRewardSmallButton;
addon.REWARD_SMALL_HEIGHT = ROW_HEIGHT;
