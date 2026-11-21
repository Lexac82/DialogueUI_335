local _, addon = ...;

-- Keys of the dialogue (retail Keybindings.lua `BindingUtil`, keyboard and mouse only, no Text To Speech).
-- Actions: Confirm (Accept / Continue / Complete, or the first row of a list), Settings (open / close the settings
-- window), Option1..Option9 (the rows of a first-contact list). Esc is not an action: it always says goodbye.
--
-- Settings > Control > "Use Custom Bindings" off: the default keys below. On: the player's keys (saved in
-- DialogueUI_DB.CustomBindings = {action = key}); an action without a custom key keeps its default key unless the
-- player took that key for another action.
local L = addon.L;
local CallbackRegistry = addon.CallbackRegistry;
local pairs = pairs;
local type = type;
local DB_Bindings;

local BindingUtil = {};
addon.BindingUtil = BindingUtil;

local DefaultKeybindings = {
    Confirm = "SPACE",
    Settings = "F1",
    Option1 = "1",
    Option2 = "2",
    Option3 = "3",
    Option4 = "4",
    Option5 = "5",
    Option6 = "6",
    Option7 = "7",
    Option8 = "8",
    Option9 = "9",
};
BindingUtil.DefaultKeybindings = DefaultKeybindings;

local SetBindingResult = {
    Unchanged = 0,
    Success = 1,
    Conflict = 2,
    Invalid = 3,
};

-- Keys that cannot be assigned (pressing one cancels the assignment).
local InvalidKeys = {
    ESCAPE = true,
    UNKNOWN = true,
    PRINTSCREEN = true,
    LALT = true,
    RALT = true,
    LSHIFT = true,
    RSHIFT = true,
    LCTRL = true,
    RCTRL = true,
    TAB = true,
    BACKSPACE = true,
    CAPSLOCK = true,
};

BindingUtil.KeyToAction = {};
BindingUtil.ActionToKey = {};

function BindingUtil:IsKeyInvalid(key)
    return InvalidKeys[key]
end

function BindingUtil:GetBindingKey(action)
    return self.ActionToKey[action]
end

function BindingUtil:GetKeyAction(key)
    return self.KeyToAction[key]
end

-- Saves action = key and takes the key away from any other action.
function BindingUtil:SetBindingKey(action, key)
    for a, k in pairs(DB_Bindings) do
        if k == key then
            DB_Bindings[a] = nil;
        end
    end
    DB_Bindings[action] = key;
end

-- key nil: back to the default key. override: take the key from the action that has it.
function BindingUtil:CheckAndSetBindingKey(action, newKey, override)
    local result;

    if newKey and self:IsKeyInvalid(newKey) then
        result = SetBindingResult.Invalid;
    elseif not DB_Bindings then
        result = SetBindingResult.Invalid;
    elseif self:GetBindingKey(action) == newKey then
        result = SetBindingResult.Unchanged;
    else
        local oldAction = newKey and self:GetKeyAction(newKey);
        if oldAction and not override then
            result = SetBindingResult.Conflict;
        else
            self:SetBindingKey(action, newKey);
            result = SetBindingResult.Success;
        end
    end

    if result == SetBindingResult.Success then
        self:LoadBindings();
    end

    return result
end

function BindingUtil:LoadBindings()
    self.KeyToAction = {};
    self.ActionToKey = {};

    if not DB_Bindings then return end;

    local key;

    for action, defaultKey in pairs(DefaultKeybindings) do
        key = DB_Bindings[action];
        if key == defaultKey then
            key = nil;
            DB_Bindings[action] = nil;
        end
        if key ~= nil then
            if type(key) == "string" and not self.KeyToAction[key] then
                self.KeyToAction[key] = action;
                self.ActionToKey[action] = key;
            else
                DB_Bindings[action] = nil;
            end
        end
    end

    for action, defaultKey in pairs(DefaultKeybindings) do
        if not self.ActionToKey[action] then
            if not self.KeyToAction[defaultKey] then
                self.ActionToKey[action] = defaultKey;
                self.KeyToAction[defaultKey] = action;
            end
        end
    end

    self:UpdateSettings();
end

do  -- What the dialogue uses
    local ActiveActionKeys = {};

    function BindingUtil:UpdateSettings()
        ActiveActionKeys = {};

        if addon.GetDBBool("UseCustomBindings") then
            for action, key in pairs(self.ActionToKey) do
                ActiveActionKeys[action] = key;
            end
        else
            for action, key in pairs(DefaultKeybindings) do
                ActiveActionKeys[action] = key;
            end
        end

        CallbackRegistry:Trigger("CustomBindingChanged");
    end

    function BindingUtil:GetActiveActionKey(action)
        return ActiveActionKeys[action]
    end

    function BindingUtil:GetActiveConfirmKey()
        return ActiveActionKeys.Confirm
    end

    function BindingUtil:GetActionTooltip(action)
        local key = self:GetActiveActionKey(action);
        if key then
            return L["Bound To"] .. key
        else
            return L["Not Bound"]
        end
    end
end

CallbackRegistry:Register("ADDON_LOADED", function(savedVariable)
    if not (savedVariable.CustomBindings and type(savedVariable.CustomBindings) == "table") then
        savedVariable.CustomBindings = {};
    end
    DB_Bindings = savedVariable.CustomBindings;
    BindingUtil:LoadBindings();
end);

CallbackRegistry:Register("SettingChanged.UseCustomBindings", function()
    BindingUtil:LoadBindings();
end);
