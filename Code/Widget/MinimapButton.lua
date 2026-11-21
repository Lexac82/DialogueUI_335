local addonName, addon = ...;
local L = addon.L;

-- Minimap button that opens the Settings window. Same idea as DragonUI's settings button (a round button that orbits
-- the minimap rim at a saved angle, dragged with the left mouse button), simplified: no collector, no skinning.
-- The Minimap section of the Gameplay tab shows / hides it (ShowMinimapButton).

local cos, sin, atan2, rad, deg = math.cos, math.sin, math.atan2, math.rad, math.deg;

local LOGO_FILE = "Interface\\AddOns\\DialogueUI\\Textures\\Logo.blp";
local BUTTON_SIZE = 31;
local DEFAULT_ANGLE = 215;

local MinimapButton = {};
addon.MinimapButton = MinimapButton;

local button;

local function NormalizeAngle(angle)
    return (tonumber(angle) or DEFAULT_ANGLE) % 360
end

-- Places the button on the rim. Square minimaps (GetMinimapShape, set by minimap addons) get a square orbit.
local function PositionByAngle(angle)
    local r = rad(angle);
    local radius = Minimap:GetWidth() / 2 + 5;
    local x, y = cos(r), sin(r);
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y));
        if m > 0 then
            x, y = x / m, y / m;
        end
    end
    button:ClearAllPoints();
    button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius);
end

local function GetCursorAngle()
    local cx, cy = Minimap:GetCenter();
    if not cx then return end
    local scale = Minimap:GetEffectiveScale();
    local mx, my = GetCursorPosition();
    local dx, dy = mx / scale - cx, my / scale - cy;
    if dx == 0 and dy == 0 then return end
    return NormalizeAngle(deg(atan2(dy, dx)))
end

local function OnUpdate_Drag(self)
    local angle = GetCursorAngle();
    if angle then
        addon.SetDBValue("MinimapButtonAngle", angle);
        PositionByAngle(angle);
        self.dragMoved = true;
    end
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT");
    GameTooltip:SetText("Dialogue UI");
    GameTooltip:AddLine(L["Minimap Button Tooltip"], 1, 0.82, 0, true);
    GameTooltip:AddLine(L["Minimap Button Drag"], 0.7, 0.7, 0.7, true);
    GameTooltip:Show();
end

local function OnLeave(self)
    GameTooltip:Hide();
end

local function OnClick(self)
    if self.suppressClickUntil and GetTime() < self.suppressClickUntil then
        return
    end
    addon.SettingsUI:Toggle();
end

local ICON_SIZE = 15;               -- inside the ring's hole (ring is 53 px of art on a 31 px button)
local ICON_X, ICON_Y = 17, -15;     -- centre of the ring's hole, from the button's top left

local function CreateButton()
    -- A Button, so DragonUI's minimap module picks it up like any addon launcher (collector box, skin).
    button = CreateFrame("Button", "DialogueUI335MinimapButton", Minimap);
    button:SetFrameStrata("MEDIUM");
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8);
    button:SetWidth(BUTTON_SIZE);
    button:SetHeight(BUTTON_SIZE);
    button:RegisterForClicks("LeftButtonUp");
    button:RegisterForDrag("LeftButton");
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

    -- Standard minimap button parts: dark disc, icon, gold ring on top.
    local background = button:CreateTexture(nil, "BACKGROUND");
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
    background:SetWidth(20);
    background:SetHeight(20);
    background:SetPoint("CENTER", button, "TOPLEFT", ICON_X, ICON_Y);

    -- Plain texture: SetPortraitToTexture drew nothing for this file. Square corners sit under the ring.
    local icon = button:CreateTexture(nil, "ARTWORK");
    icon:SetWidth(ICON_SIZE);
    icon:SetHeight(ICON_SIZE);
    icon:SetPoint("CENTER", button, "TOPLEFT", ICON_X, ICON_Y);
    icon:SetTexture(LOGO_FILE);
    icon:SetTexCoord(0.06, 0.94, 0.06, 0.94);
    button.icon = icon;

    local border = button:CreateTexture(nil, "OVERLAY");
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
    border:SetWidth(53);
    border:SetHeight(53);
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);

    button:SetScript("OnEnter", OnEnter);
    button:SetScript("OnLeave", OnLeave);
    button:SetScript("OnClick", OnClick);
    button:SetScript("OnDragStart", function(self)
        self.dragMoved = false;
        GameTooltip:Hide();
        self:SetScript("OnUpdate", OnUpdate_Drag);
    end);
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil);
        -- Ignore a click delivered right after the drag ends (DragonUI does the same).
        if self.dragMoved then
            self.suppressClickUntil = GetTime() + 0.2;
        end
    end);
    button:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("CENTER", self, "TOPLEFT", ICON_X + 1, ICON_Y - 1);
    end);
    button:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("CENTER", self, "TOPLEFT", ICON_X, ICON_Y);
    end);
end

function MinimapButton:Update()
    local show = addon.GetDBBool("ShowMinimapButton");
    if show and not button then
        CreateButton();
    end
    if not button then return end
    if show then
        PositionByAngle(NormalizeAngle(addon.GetDBValue("MinimapButtonAngle")));
        button:Show();
    else
        button:Hide();
    end
end

-- Fires once at load with the saved value, and again when the Minimap checkbox changes.
addon.CallbackRegistry:Register("SettingChanged.ShowMinimapButton", function()
    MinimapButton:Update();
end);
