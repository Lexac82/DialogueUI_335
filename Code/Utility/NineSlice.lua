local _, addon = ...;

-- 3.3.5a has no texture slice mode (retail's TextureSliceMode / TextureSliceMargins).
-- This builds the same thing from 9 textures: fixed corners, stretched edges and centre.
local NineSlice = {};
addon.NineSlice = NineSlice;

local min = math.min;

-- Returns a table of 9 textures anchored to `frame`.
-- file: texture path. texSize: {width, height} of the texture in px.
-- margin: slice margin in texture px (same value on all sides). corner: drawn corner size in px (default = margin).
-- layer: texture draw layer (3.3.5a has no sublevel argument; creation order decides within a layer).
function NineSlice:Create(frame, file, texSize, margin, corner, layer)
    corner = corner or margin;
    local tw, th = texSize[1], texSize[2];
    local u1, u2 = margin / tw, 1 - margin / tw;
    local v1, v2 = margin / th, 1 - margin / th;

    -- Column / row coordinate ranges: left, centre, right.
    local us = { {0, u1}, {u1, u2}, {u2, 1} };
    local vs = { {0, v1}, {v1, v2}, {v2, 1} };

    local pieces = {};
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = frame:CreateTexture(nil, layer or "BACKGROUND");
            tex:SetTexture(file);
            tex:SetTexCoord(us[col][1], us[col][2], vs[row][1], vs[row][2]);
            pieces[#pieces + 1] = tex;
        end
    end

    -- Positions: 1 2 3 / 4 5 6 / 7 8 9.
    pieces[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
    pieces[1]:SetWidth(corner); pieces[1]:SetHeight(corner);
    pieces[3]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0);
    pieces[3]:SetWidth(corner); pieces[3]:SetHeight(corner);
    pieces[7]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);
    pieces[7]:SetWidth(corner); pieces[7]:SetHeight(corner);
    pieces[9]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0);
    pieces[9]:SetWidth(corner); pieces[9]:SetHeight(corner);

    pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT", 0, 0);
    pieces[2]:SetPoint("BOTTOMRIGHT", pieces[3], "BOTTOMLEFT", 0, 0);
    pieces[8]:SetPoint("TOPLEFT", pieces[7], "TOPRIGHT", 0, 0);
    pieces[8]:SetPoint("BOTTOMRIGHT", pieces[9], "BOTTOMLEFT", 0, 0);
    pieces[4]:SetPoint("TOPLEFT", pieces[1], "BOTTOMLEFT", 0, 0);
    pieces[4]:SetPoint("BOTTOMRIGHT", pieces[7], "TOPRIGHT", 0, 0);
    pieces[6]:SetPoint("TOPLEFT", pieces[3], "BOTTOMLEFT", 0, 0);
    pieces[6]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPRIGHT", 0, 0);
    pieces[5]:SetPoint("TOPLEFT", pieces[1], "BOTTOMRIGHT", 0, 0);
    pieces[5]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPLEFT", 0, 0);

    return pieces
end

-- Tiled 9-slice, retail's TextureSliceMode(1) (Tiled). The corners keep their texel size and the edges and
-- the centre repeat the texture instead of stretching it. 3.3.5a can only repeat a whole texture, not a
-- sub-rectangle, so the repeats are separate textures cropped with SetTexCoord (pooled, re-laid by Update).
-- margin: slice margin in texture px. scale: drawn size of one texel (0.75 = a 32 px corner is 24 units).
local TiledSlice = {};
TiledSlice.__index = TiledSlice;

function NineSlice:CreateTiled(frame, file, texSize, margin, scale, layer)
    local self = setmetatable({}, TiledSlice);
    self.frame, self.file, self.layer = frame, file, layer or "BACKGROUND";
    self.tw, self.th, self.margin, self.scale = texSize[1], texSize[2], margin, scale;
    self.tiles, self.used = {}, 0;

    local u1, u2 = margin / self.tw, 1 - margin / self.tw;
    local v1, v2 = margin / self.th, 1 - margin / self.th;
    self.u1, self.u2, self.v1, self.v2 = u1, u2, v1, v2;

    -- Corners: TL, TR, BL, BR.
    local function Corner(point, l, r, t, b)
        local tex = frame:CreateTexture(nil, self.layer);
        tex:SetTexture(file);
        tex:SetTexCoord(l, r, t, b);
        tex:SetPoint(point, frame, point, 0, 0);
        return tex
    end
    self.corners = {
        Corner("TOPLEFT", 0, u1, 0, v1),
        Corner("TOPRIGHT", u2, 1, 0, v1),
        Corner("BOTTOMLEFT", 0, u1, v2, 1),
        Corner("BOTTOMRIGHT", u2, 1, v2, 1),
    };
    return self
end

function TiledSlice:AcquireTile()
    local count = self.used + 1;
    self.used = count;
    local tex = self.tiles[count];
    if not tex then
        tex = self.frame:CreateTexture(nil, self.layer);
        tex:SetTexture(self.file);
        self.tiles[count] = tex;
    end
    tex:ClearAllPoints();
    tex:Show();
    return tex
end

-- Places one tile of size (w, h) at (x, y) from the frame's top left, showing texture rectangle l..r, t..b.
function TiledSlice:PlaceTile(x, y, w, h, l, r, t, b)
    local tex = self:AcquireTile();
    tex:SetTexCoord(l, r, t, b);
    tex:SetPoint("TOPLEFT", self.frame, "TOPLEFT", x, -y);
    tex:SetWidth(w);
    tex:SetHeight(h);
end

-- Re-lays the pieces for a frame of the given size. Call after the frame is resized.
function TiledSlice:Update(width, height)
    if self.width == width and self.height == height then
        return
    end
    self.width, self.height = width, height;

    for i = 1, self.used do
        self.tiles[i]:Hide();
    end
    self.used = 0;

    -- Frames smaller than two corners shrink the texel size so the corners still fit.
    local scale = min(self.scale, width / (2 * self.margin), height / (2 * self.margin));
    local cm = self.margin * scale;
    for i = 1, 4 do
        self.corners[i]:SetWidth(cm);
        self.corners[i]:SetHeight(cm);
    end

    local innerW, innerH = width - 2 * cm, height - 2 * cm;
    local tileW = (self.tw - 2 * self.margin) * scale;
    local tileH = (self.th - 2 * self.margin) * scale;
    local u1, u2, v1, v2 = self.u1, self.u2, self.v1, self.v2;

    -- Horizontal strips (top and bottom edges) and vertical strips (left and right edges).
    local x = 0;
    while x < innerW - 0.01 do
        local segW = min(tileW, innerW - x);
        local ur = u1 + (u2 - u1) * (segW / tileW);
        self:PlaceTile(cm + x, 0, segW, cm, u1, ur, 0, v1);
        self:PlaceTile(cm + x, height - cm, segW, cm, u1, ur, v2, 1);
        x = x + tileW;
    end
    local y = 0;
    while y < innerH - 0.01 do
        local segH = min(tileH, innerH - y);
        local vb = v1 + (v2 - v1) * (segH / tileH);
        self:PlaceTile(0, cm + y, cm, segH, 0, u1, v1, vb);
        self:PlaceTile(width - cm, cm + y, cm, segH, u2, 1, v1, vb);
        y = y + tileH;
    end

    -- Centre.
    y = 0;
    while y < innerH - 0.01 do
        local segH = min(tileH, innerH - y);
        local vb = v1 + (v2 - v1) * (segH / tileH);
        x = 0;
        while x < innerW - 0.01 do
            local segW = min(tileW, innerW - x);
            local ur = u1 + (u2 - u1) * (segW / tileW);
            self:PlaceTile(cm + x, cm + y, segW, segH, u1, ur, v1, vb);
            x = x + tileW;
        end
        y = y + tileH;
    end
    if self.hidden then
        self:SetShown(false);
    end
end

-- Shows or hides the whole slice (corners and every tile). Update keeps the state.
function TiledSlice:SetShown(shown)
    self.hidden = not shown;
    for i = 1, 4 do
        if shown then self.corners[i]:Show() else self.corners[i]:Hide() end
    end
    for i = 1, self.used do
        if shown then self.tiles[i]:Show() else self.tiles[i]:Hide() end
    end
end

-- Swaps the texture file (the crop coordinates stay the same).
function TiledSlice:SetTexture(file)
    self.file = file;
    for i = 1, 4 do
        self.corners[i]:SetTexture(file);
    end
    for i = 1, #self.tiles do
        self.tiles[i]:SetTexture(file);
    end
end

-- Stretched 9-slice with a different margin on each side (retail TextureSliceMargins left/right/top/bottom).
-- The margins are in texture px and are drawn 1:1. Returns the 9 textures, same order as Create.
function NineSlice:CreateEdges(frame, file, texSize, left, right, top, bottom, layer)
    local tw, th = texSize[1], texSize[2];
    local us = { {0, left / tw}, {left / tw, 1 - right / tw}, {1 - right / tw, 1} };
    local vs = { {0, top / th}, {top / th, 1 - bottom / th}, {1 - bottom / th, 1} };

    local pieces = {};
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = frame:CreateTexture(nil, layer or "BACKGROUND");
            tex:SetTexture(file);
            tex:SetTexCoord(us[col][1], us[col][2], vs[row][1], vs[row][2]);
            pieces[#pieces + 1] = tex;
        end
    end

    pieces[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0);
    pieces[1]:SetWidth(left); pieces[1]:SetHeight(top);
    pieces[3]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0);
    pieces[3]:SetWidth(right); pieces[3]:SetHeight(top);
    pieces[7]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0);
    pieces[7]:SetWidth(left); pieces[7]:SetHeight(bottom);
    pieces[9]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0);
    pieces[9]:SetWidth(right); pieces[9]:SetHeight(bottom);

    pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT", 0, 0);
    pieces[2]:SetPoint("BOTTOMRIGHT", pieces[3], "BOTTOMLEFT", 0, 0);
    pieces[8]:SetPoint("TOPLEFT", pieces[7], "TOPRIGHT", 0, 0);
    pieces[8]:SetPoint("BOTTOMRIGHT", pieces[9], "BOTTOMLEFT", 0, 0);
    pieces[4]:SetPoint("TOPLEFT", pieces[1], "BOTTOMLEFT", 0, 0);
    pieces[4]:SetPoint("BOTTOMRIGHT", pieces[7], "TOPRIGHT", 0, 0);
    pieces[6]:SetPoint("TOPLEFT", pieces[3], "BOTTOMLEFT", 0, 0);
    pieces[6]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPRIGHT", 0, 0);
    pieces[5]:SetPoint("TOPLEFT", pieces[1], "BOTTOMRIGHT", 0, 0);
    pieces[5]:SetPoint("BOTTOMRIGHT", pieces[9], "TOPLEFT", 0, 0);

    return pieces
end

-- Shared helpers for a table returned by Create.
function NineSlice:SetVertexColor(pieces, r, g, b, a)
    for i = 1, #pieces do
        pieces[i]:SetVertexColor(r, g, b, a);
    end
end

function NineSlice:SetBlendMode(pieces, mode)
    for i = 1, #pieces do
        pieces[i]:SetBlendMode(mode);
    end
end

function NineSlice:SetShown(pieces, shown)
    for i = 1, #pieces do
        if shown then
            pieces[i]:Show();
        else
            pieces[i]:Hide();
        end
    end
end

function NineSlice:SetTexture(pieces, file)
    for i = 1, #pieces do
        pieces[i]:SetTexture(file);
    end
end
