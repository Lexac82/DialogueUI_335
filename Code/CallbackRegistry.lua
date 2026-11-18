local _, addon = ...;

-- Internal events between modules. Same interface as retail's CallbackRegistry.
-- Events used so far:
--   "SettingChanged.<dbKey>"    (value, userInput) every setting, once at load and on every change
--   "ADDON_LOADED"              (DB) saved variables are ready
--   "PLAYER_ENTERING_WORLD"     once, at login or reload

local CallbackRegistry = {};
CallbackRegistry.events = {};
addon.CallbackRegistry = CallbackRegistry;

local tinsert = table.insert;
local tremove = table.remove;
local type = type;
local ipairs = ipairs;
local pairs = pairs;

--[[
    callbackType:
        1. Function func(owner)
        2. Method owner:func()
--]]

function CallbackRegistry:Register(event, func, owner, prioritized)
    if not self.events[event] then
        self.events[event] = {};
    end

    local callbackType;

    if type(func) == "string" then
        callbackType = 2;
    else
        callbackType = 1;
    end

    if prioritized then
        tinsert(self.events[event], 1, {callbackType, func, owner});
    else
        tinsert(self.events[event], {callbackType, func, owner});
    end
end

function CallbackRegistry:Trigger(event, ...)
    if self.events[event] then
        for _, cb in ipairs(self.events[event]) do
            if cb[1] == 1 then
                if cb[3] then
                    cb[2](cb[3], ...);
                else
                    cb[2](...);
                end
            else
                cb[3][cb[2]](cb[3], ...);
            end
        end
    end
end

function CallbackRegistry:UnregisterCallback(event, callback, owner)
    if self.events[event] then
        local callbacks = self.events[event];
        local i = 1;
        local cb = callbacks[i];

        if type(callback) == "string" then
            if owner then
                while cb do
                    if cb[1] == 2 and cb[2] == callback and cb[3] == owner then
                        tremove(callbacks, i);
                    else
                        i = i + 1;
                    end
                    cb = callbacks[i];
                end
            else
                while cb do
                    if cb[1] == 2 and cb[2] == callback then
                        tremove(callbacks, i);
                    else
                        i = i + 1;
                    end
                    cb = callbacks[i];
                end
            end
        else
            while cb do
                if cb[1] == 1 and cb[2] == callback then
                    tremove(callbacks, i);
                else
                    i = i + 1;
                end
                cb = callbacks[i];
            end
        end
    end
end

function CallbackRegistry:UnregisterEvent(event)
    self.events[event] = nil;
end


local Processor = CreateFrame("Frame");

local function Processor_OnUpdate(self, elapsed)
    self:SetScript("OnUpdate", nil);
    if self.triggerQueue and self.anyDelayedTrigger then
        self.anyDelayedTrigger = nil;
        for event, args in pairs(self.triggerQueue) do
            CallbackRegistry:Trigger(event, args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
        end
        self.triggerQueue = nil;
    end
end

function CallbackRegistry:TriggerOnNextUpdate(event, ...)
    --Use Case: in case Lua error appears and clogs other important processes
    if self.events[event] then
        if not Processor.anyDelayedTrigger then
            Processor.triggerQueue = {};
            Processor.anyDelayedTrigger = true;
        end
        Processor.triggerQueue[event] = {...};
        Processor:SetScript("OnUpdate", Processor_OnUpdate);
    end
end
