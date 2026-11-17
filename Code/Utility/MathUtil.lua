local _, addon = ...;

local MathUtil = {};
addon.MathUtil = MathUtil;

local floor = math.floor;
local min = math.min;

-- Nearest whole pixel, as retail's API.Round.
function MathUtil.Round(value)
    return floor(value + 0.5);
end

function MathUtil.Clamp(value, lo, hi)
    if value < lo then
        return lo
    elseif value > hi then
        return hi
    end
    return value
end

-- Frame-rate independent ease toward b, like Blizzard's DeltaLerp (retail API.DeltaLerp).
-- amount is the fraction covered per 1/60 s. The exact retail formula is not in wow-docs: tune in game.
function MathUtil.DeltaLerp(a, b, amount, elapsed)
    return a + (b - a) * min(1, amount * elapsed * 60)
end
