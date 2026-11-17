local _, addon = ...;

local MathUtil = {};
addon.MathUtil = MathUtil;

local floor = math.floor;

-- Nearest whole pixel, as retail's API.Round.
function MathUtil.Round(value)
    return floor(value + 0.5);
end
