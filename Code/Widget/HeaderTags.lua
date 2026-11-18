local _, addon = ...;

-- Quest type pills above the header title (port of retail's QuestHeaderWidget, non-clickable pills:
-- an optional icon and a small label, no background). Left to right, starting at the title's top left.
local FontUtil = addon.FontUtil;

local ICON_SIZE = 14;
local ICON_TEXT_GAP = 2;
local SPACING = 8;
local FONT_HEIGHT = 11;
local TEXT_COLOR = {0.45, 0.36, 0.24};      -- muted brown, readable on the parchment

local HeaderTags = {};
HeaderTags.__index = HeaderTags;

function HeaderTags:SetTags(tags)
    for _, pill in ipairs(self.pills) do
        pill:Hide();
    end

    local previous;
    for i, tag in ipairs(tags or {}) do
        local pill = self.pills[i] or self:CreatePill(i);
        pill.Text:SetText(tag.text);

        local width = pill.Text:GetStringWidth();
        pill.Text:ClearAllPoints();
        if tag.icon then
            pill.Icon:SetTexture(tag.icon);
            pill.Icon:Show();
            pill.Text:SetPoint("LEFT", pill, "LEFT", ICON_SIZE + ICON_TEXT_GAP, 0);
            width = width + ICON_SIZE + ICON_TEXT_GAP;
        else
            pill.Icon:Hide();
            pill.Text:SetPoint("LEFT", pill, "LEFT", 0, 0);
        end
        pill:SetWidth(math.max(1, width));

        pill:ClearAllPoints();
        if previous then
            pill:SetPoint("LEFT", previous, "RIGHT", SPACING, 0);
        else
            pill:SetPoint("BOTTOMLEFT", self.anchorTo, "TOPLEFT", 0, 0);
        end
        pill:Show();
        previous = pill;
    end
end

function HeaderTags:CreatePill(index)
    local pill = CreateFrame("Frame", nil, self.parent);
    pill:SetHeight(ICON_SIZE);

    local icon = pill:CreateTexture(nil, "ARTWORK");
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("LEFT", pill, "LEFT", 0, 0);
    pill.Icon = icon;

    local text = pill:CreateFontString(nil, "OVERLAY");
    text:SetFontObject(FontUtil:GetColoredFont("DUI335HeaderTag", FONT_HEIGHT, TEXT_COLOR));
    text:SetJustifyH("LEFT");
    pill.Text = text;

    self.pills[index] = pill;
    return pill
end

-- parent: header frame. anchorTo: the title font string.
function addon.CreateHeaderTags(parent, anchorTo)
    local self = setmetatable({}, HeaderTags);
    self.parent = parent;
    self.anchorTo = anchorTo;
    self.pills = {};
    return self
end
