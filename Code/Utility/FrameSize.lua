local _, addon = ...;

-- Size of the dialogue frame: the one place that knows the multiplier for the "FrameSize" setting.
-- Same multipliers as retail's FrameSizeIndexScale; [4] = 1.4 (retail: Mobile Device Mode only) is the Extra Large choice. Parts that scale read GetMultiplier() when built and listen to "FrameSizeChanged".
--   "FrameSizeChanged"   (multiplier)   after the setting changed (and once at load with the saved value)

local CallbackRegistry = addon.CallbackRegistry;

local DEFAULT_MULTIPLIER = 1.1;     -- Medium, retail default

local FrameSize = {};
addon.FrameSize = FrameSize;

local MULTIPLIERS = {
    [0] = 0.9,      -- Extra Small
    [1] = 1.0,      -- Small
    [2] = DEFAULT_MULTIPLIER,
    [3] = 1.25,     -- Large
    [4] = 1.4,      -- Extra Large (retail only uses it for Mobile Device Mode)
};

local multiplier = DEFAULT_MULTIPLIER;

function FrameSize:GetMultiplier()
    return multiplier
end

-- Registered here, before the parts that listen to "FrameSizeChanged", so the value is already updated for them.
CallbackRegistry:Register("SettingChanged.FrameSize", function(dbValue)
    local new = MULTIPLIERS[dbValue] or DEFAULT_MULTIPLIER;
    if new ~= multiplier then
        multiplier = new;
        CallbackRegistry:Trigger("FrameSizeChanged", multiplier);
    end
end);
