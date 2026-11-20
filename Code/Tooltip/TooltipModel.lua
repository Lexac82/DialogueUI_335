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
local OVERLAY_TRANSMOG_INDEX = 8;         -- same cell as RewardItemButton
local ICON_INSET = 4;                     -- icon is this much smaller than the border on each side
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
    ThemeUtil:BindTexture(border, BORDER_FILE);
    border:SetAllPoints(frame);

    -- Quality and transmog corners on a child frame so they draw over the border.
    local top = CreateFrame("Frame", nil, frame);
    top:SetAllPoints(frame);
    top:SetFrameLevel(frame:GetFrameLevel() + 2);

    local quality = top:CreateTexture(nil, "OVERLAY");
    quality:SetAllPoints(frame);
    quality:Hide();
    local transmog = top:CreateTexture(nil, "OVERLAY");
    transmog:SetAllPoints(frame);
    transmog:Hide();

    frame.icon = icon;
    frame.quality = quality;
    frame.transmog = transmog;
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

    local itemQuality = select(3, GetItemInfo(link));
    local TransmogStatus = addon.TransmogStatus;
    local uncollected = TransmogStatus and TransmogStatus:IsUncollected(TransmogStatus:GetItemID(link));
    -- Quality corner moves to the top left (mirrored) while the transmog marker shows.
    ThemeUtil:SetItemOverlay(preview.quality, itemQuality and itemQuality >= 2 and itemQuality or nil, uncollected and true or false);
    ThemeUtil:SetItemOverlay(preview.transmog, uncollected and OVERLAY_TRANSMOG_INDEX or nil);
    preview:Show();
end
