local _, addon = ...;

-- A stand-in for a GameTooltip that only records the lines added to it. Item providers of other addons
-- (Auctionator, Pawn, ...) write to it with the calls they already use on GameTooltip, and the recorded
-- lines are drawn in our own tooltip. Same idea as retail's Tooltip_Capture.lua.
-- Lines have the shape of TooltipScan lines: {left, right, lr, lg, lb, rr, rg, rb}.
local TooltipCapture = {};
addon.TooltipCapture = TooltipCapture;

local Capture = {};
Capture.__index = Capture;

function TooltipCapture:New()
    local capture = setmetatable({}, Capture);
    capture.lines = {};
    return capture
end

-- Calls that only make sense on a real frame do nothing.
local function Noop() end
Capture.SetOwner = function(self) self:ClearLines(); end;
Capture.SetPoint = Noop;
Capture.ClearAllPoints = Noop;
Capture.AddTexture = Noop;
Capture.Show = Noop;
Capture.Hide = Noop;
Capture.SetMinimumWidth = Noop;
Capture.GetOwner = Noop;

function Capture:ClearLines()
    self.lines = {};
end

function Capture:IsShown()
    return true
end

function Capture:NumLines()
    return #self.lines
end

-- Empty text is ignored, as GameTooltip does for a nil text.
function Capture:AddLine(text, r, g, b)
    if text == nil or text == "" then
        return
    end
    self.lines[#self.lines + 1] = {left = text, lr = r, lg = g, lb = b};
end

function Capture:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
    local hasLeft = left ~= nil and left ~= "";
    local hasRight = right ~= nil and right ~= "";
    if not hasLeft and not hasRight then
        return
    end
    if not hasRight then
        return self:AddLine(left, lr, lg, lb)
    end
    self.lines[#self.lines + 1] = {left = hasLeft and left or " ", right = right, lr = lr, lg = lg, lb = lb, rr = rr, rg = rg, rb = rb};
end

-- GameTooltip:GetItem() returns the item name and link. Providers that look the item up this way get it.
function Capture:SetHyperlink(link)
    self.link = link;
end

function Capture:GetItem()
    if not self.link then
        return nil
    end
    return (GetItemInfo(self.link)), self.link
end
