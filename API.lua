local _, addon = ...;
local API = addon.API;

-- Custom helpers shared by all modules. Names follow retail's API.lua.

local floor = math.floor;
local min = math.min;
local gmatch = string.gmatch;
local tremove = table.remove;


-- Math ---------------------------------------------------------------------------------------------------------

-- Nearest whole pixel.
local function Round(value)
    return floor(value + 0.5);
end
API.Round = Round;

local function Clamp(value, lo, hi)
    if value < lo then
        return lo
    elseif value > hi then
        return hi
    end
    return value
end
API.Clamp = Clamp;

-- Frame-rate independent ease toward b, like Blizzard's DeltaLerp.
-- amount is the fraction covered per 1/60 s. The exact retail formula is not in wow-docs: tune in game.
local function DeltaLerp(a, b, amount, elapsed)
    return a + (b - a) * min(1, amount * elapsed * 60)
end
API.DeltaLerp = DeltaLerp;


-- Text ---------------------------------------------------------------------------------------------------------

-- Splits text into paragraphs at control characters (newlines) and drops lone spaces.
local function SplitParagraph(text)
    local paragraphs = {};

    if text then
        local n = 0;
        for paragraph in gmatch(text, "[%C]+") do
            if paragraph ~= " " then
                n = n + 1;
                paragraphs[n] = paragraph;
            end
        end
    end

    return paragraphs
end
API.SplitParagraph = SplitParagraph;

local function PrintMessage(text)
    print("|cffb8a37eDialogue UI:|r "..text);
end
API.PrintMessage = PrintMessage;


-- Mixin --------------------------------------------------------------------------------------------------------

-- 3.3.5a has no Mixin / CreateFromMixins. Copies the methods of each mixin table onto object (later mixins win).
local function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...);
        for key, value in pairs(mixin) do
            object[key] = value;
        end
    end
    return object
end
API.Mixin = Mixin;

local function CreateFromMixins(...)
    return Mixin({}, ...)
end
API.CreateFromMixins = CreateFromMixins;


-- Timer --------------------------------------------------------------------------------------------------------

-- 3.3.5a has no C_Timer.After. One shared frame runs every pending timer and stops when none is left.
do
    local timers = {};
    local timerFrame = CreateFrame("Frame");

    local function OnUpdate(frame, elapsed)
        for i = #timers, 1, -1 do
            local timer = timers[i];
            timer.delay = timer.delay - elapsed;
            if timer.delay <= 0 then
                tremove(timers, i);
                timer.func();
            end
        end
        if #timers == 0 then
            frame:SetScript("OnUpdate", nil);
        end
    end

    local function After(delay, func)
        timers[#timers + 1] = { delay = delay, func = func };
        timerFrame:SetScript("OnUpdate", OnUpdate);
    end
    API.After = After;
end
