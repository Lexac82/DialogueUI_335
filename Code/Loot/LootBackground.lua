local _, addon = ...;
local LootUI = addon.LootUI;
local ThemeUtil = addon.LootThemeUtil;
local NineSlice = addon.NineSlice;

local abs = math.abs;
local min = math.min;

-- Window background: GenericFrame-Tiled-Large drawn exactly as the Settings window does it (80 px corners,
-- tiled edges and centre, a 16 px transparent drop shadow around the frame, pixel perfect texel size).
-- The size animates: Plumber's background eases toward the new size (4 x the distance per second).
local FILE = "GenericFrame-Tiled-Large.blp";
local CORNER = 80;
local SHADOW = 16;
local DEFAULT_TEXEL = 0.75;
local EASE_SPEED = 8;
local SNAP = 0.5;

local BackgroundMixin = {};

-- 1 texel = 1 screen pixel (see Settings.lua UpdateBackgroundScale).
local function GetTexel(frame)
    local _, physHeight = string.match(GetCVar("gxResolution") or "", "(%d+)x(%d+)");
    physHeight = tonumber(physHeight);
    local effScale = frame:GetEffectiveScale();
    if physHeight and physHeight > 0 and effScale and effScale > 0 then
        return 768 / physHeight / effScale
    end
    return DEFAULT_TEXEL
end

-- Lays the slice for the current size. width / height: the window, without the shadow.
function BackgroundMixin:Layout()
    local shadow = self.shadow * self.texel;
    local owner = self.owner;
    self:ClearAllPoints();
    self:SetPoint("TOPLEFT", owner, "TOPLEFT", -shadow, shadow);
    self:SetWidth(self.width + 2 * shadow);
    self:SetHeight(self.height + 2 * shadow);
    self.slice.scale = self.texel * self.sliceScale;
    self.slice.width = nil;                 -- force a re-layout
    self.slice:Update(self.width + 2 * shadow, self.height + 2 * shadow);
end

function BackgroundMixin:UpdatePixel()
    self.texel = GetTexel(self.owner);
    self:Layout();
end

local function OnUpdate(self, elapsed)
    local done = true;
    local k = min(1, EASE_SPEED * elapsed);

    local dw = self.toWidth - self.width;
    if abs(dw) > SNAP then
        self.width = self.width + dw * k;
        done = false;
    else
        self.width = self.toWidth;
    end

    local dh = self.toHeight - self.height;
    if abs(dh) > SNAP then
        self.height = self.height + dh * k;
        done = false;
    else
        self.height = self.toHeight;
    end

    self:Layout();
    if done then
        self:SetScript("OnUpdate", nil);
    end
end

function BackgroundMixin:SetBackgroundSize(width, height)
    self:SetScript("OnUpdate", nil);
    self.width, self.height = width, height;
    self.toWidth, self.toHeight = width, height;
    self:Layout();
end

function BackgroundMixin:AnimateSize(width, height)
    self.toWidth, self.toHeight = width, height;
    if abs(width - self.width) > SNAP or abs(height - self.height) > SNAP then
        self:SetScript("OnUpdate", OnUpdate);
    end
end

function BackgroundMixin:SetBackgroundAlpha(alpha)
    self:SetAlpha(alpha);
end

-- owner: the loot window the background hangs from (the window has no art of its own).
function LootUI.CreateBackground(owner)
    local f = CreateFrame("Frame", nil, owner);
    f:SetFrameLevel(owner:GetFrameLevel());
    addon.API.Mixin(f, BackgroundMixin);
    f.owner = owner;
    f.width, f.height = 128, 128;
    f.toWidth, f.toHeight = 128, 128;
    f.texel = DEFAULT_TEXEL;

    f.shadow, f.sliceScale = SHADOW, 1;
    f.slice = NineSlice:CreateTiled(f, ThemeUtil:GetTextureFile(FILE), { 512, 512 }, CORNER, DEFAULT_TEXEL, "BACKGROUND");
    ThemeUtil:BindSlice(f.slice, FILE);
    return f
end
