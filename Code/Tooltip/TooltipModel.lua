local _, addon = ...;

-- Static 2D preview of the item in the tooltip: a large icon in the top right corner.
-- Retail shows a 3D model here (Tooltip_Private.lua 276-426). For weapons it shows the item alone, which
-- needs a model file path that 3.3.5a cannot look up from an item ID, so the icon is used instead.
-- Shown for equippable items that can be dressed (IsDressableItem), same condition as the old model.
local ThemeUtil = addon.ThemeUtil;

local TooltipModel = {};
addon.TooltipModel = TooltipModel;

local CreateFrame = CreateFrame;
local GetItemInfo = GetItemInfo;
local IsDressableItem = IsDressableItem;

local BORDER_FILE = "ItemBorder.blp";
local ICON_INSET = 4;                      -- icon is this much smaller than the border on each side
local ICON_TEXCOORD = {0.0625, 0.9275, 0.0625, 0.9275};

local function CreatePreview(tooltip)
    local metrics = addon.TOOLTIP_METRICS;
    local frame = CreateFrame("Frame", nil, tooltip.frame);
    frame:SetWidth(metrics.MODEL_WIDTH);
    frame:SetHeight(metrics.MODEL_HEIGHT);
    frame:SetPoint("TOPRIGHT", tooltip.frame, "TOPRIGHT", -metrics.PADDING, metrics.MODEL_OVERHANG);
    frame:Hide();

    local icon = frame:CreateTexture(nil, "ARTWORK");
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", ICON_INSET, -ICON_INSET);
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET);
    icon:SetTexCoord(ICON_TEXCOORD[1], ICON_TEXCOORD[2], ICON_TEXCOORD[3], ICON_TEXCOORD[4]);

    local border = frame:CreateTexture(nil, "OVERLAY");
    border:SetTexture(ThemeUtil:GetTextureFile(BORDER_FILE));
    border:SetAllPoints(frame);

    frame.icon = icon;
    return frame
end

function TooltipModel:CanPreview(link)
    return link ~= nil and IsDressableItem(link) and true or false
end

-- Called by TooltipFrame:SetPreviewItem. link nil hides the preview.
function TooltipModel:Update(tooltip, link)
    local preview = tooltip.model;
    local texture = link and select(10, GetItemInfo(link));
    if not link or not texture or not self:CanPreview(link) then
        tooltip.previewLink = nil;
        if preview then
            preview:Hide();
        end
        return
    end

    if not preview then
        preview = CreatePreview(tooltip);
        tooltip.model = preview;
    end
    preview.icon:SetTexture(texture);
    preview:Show();
end
