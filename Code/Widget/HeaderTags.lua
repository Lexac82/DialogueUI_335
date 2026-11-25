local _, addon = ...;

-- Quest type pills above the header title (port of retail's QuestHeaderWidget, non-clickable pills:
-- an optional icon and a small label, no background). Left to right, starting at the title's top left.
local FontUtil = addon.FontUtil;
local FrameSize = addon.FrameSize;

-- Sizes are for frame size multiplier 1 and are scaled when applied.
local ICON_SIZE = 14;
local ICON_TEXT_GAP = 0;
local SPACING = 8;
local FONT_HEIGHT = 11;
local TEXT_COLOR = {"MutedBrown", "DarkModeGrey70"};      -- muted brown on the parchment, grey on Dark (retail DUIFont_QuestType_Right)

local HeaderTags = {};
HeaderTags.__index = HeaderTags;

local function GetPillFont()
    return FontUtil:GetColoredFont("DUI335HeaderTag", FrameSize:Scale(FONT_HEIGHT), TEXT_COLOR)
end

function HeaderTags:SetTags(tags)
    self.tags = tags;       -- kept for a frame size change
    local iconSize = FrameSize:Scale(ICON_SIZE);
    local iconSpace = iconSize + FrameSize:Scale(ICON_TEXT_GAP);
    local spacing = FrameSize:Scale(SPACING);
    -- Before the text, so the widths below are measured at this height.
    FontUtil:SetFontHeight(GetPillFont(), FrameSize:Scale(FONT_HEIGHT));

    for _, pill in ipairs(self.pills) do
        pill:Hide();
    end

    local previous;
    for i, tag in ipairs(tags or {}) do
        local pill = self.pills[i] or self:CreatePill(i);
        pill:SetHeight(iconSize);
        pill.Icon:SetWidth(iconSize);
        pill.Icon:SetHeight(iconSize);
        pill.Text:SetText(tag.text);

        local width = pill.Text:GetStringWidth();
        pill.Text:ClearAllPoints();
        if tag.icon then
            pill.Icon:SetTexture(tag.icon);
            pill.Icon:Show();
            pill.Text:SetPoint("LEFT", pill, "LEFT", iconSpace, 0);
            width = width + iconSpace;
        else
            pill.Icon:Hide();
            pill.Text:SetPoint("LEFT", pill, "LEFT", 0, 0);
        end
        pill:SetWidth(math.max(1, width));

        pill:ClearAllPoints();
        if previous then
            pill:SetPoint("LEFT", previous, "RIGHT", spacing, 0);
        else
            pill:SetPoint("BOTTOMLEFT", self.anchorTo, "TOPLEFT", 0, 0);
        end
        pill:Show();
        previous = pill;
    end
end

function HeaderTags:CreatePill(index)
    local pill = CreateFrame("Frame", nil, self.parent);

    local icon = pill:CreateTexture(nil, "ARTWORK");
    icon:SetPoint("LEFT", pill, "LEFT", 0, 0);
    pill.Icon = icon;

    local text = pill:CreateFontString(nil, "OVERLAY");
    text:SetFontObject(GetPillFont());
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
    addon.CallbackRegistry:Register("FrameSizeChanged", function()
        self:SetTags(self.tags);
    end);
    return self
end
