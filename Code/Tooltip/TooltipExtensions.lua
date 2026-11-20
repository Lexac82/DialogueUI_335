local _, addon = ...;

-- Lets other addons add lines to our item tooltip. Our tooltip is not a GameTooltip, so the hooks other addons
-- put on GameTooltip never run for it. An addon registers an item provider instead:
--
--     DialogueUI_335_API.RegisterItemTooltipProvider("MyAddon", function(tooltip, itemLink, count)
--         tooltip:AddLine("Some text", 1, 1, 1);
--         tooltip:AddDoubleLine("Left", "Right");
--     end);
--
-- `tooltip` only records lines (see TooltipCapture.lua). `count` is the stack size of the reward, or nil.
-- Providers are called every time the tooltip is drawn, so they should be cheap.
-- Addons we support ourselves live in Code/SupportedAddOns.
local TooltipCapture = addon.TooltipCapture;

local TooltipExtensions = {};
addon.TooltipExtensions = TooltipExtensions;

local geterrorhandler = geterrorhandler;
local pcall = pcall;
local type = type;

local providers = {};              -- ordered list of {name, func}
local reported = {};               -- provider name -> true once its error was reported

-- `early` (optional) draws the provider's lines above the transmog line instead of after the sell price.
function TooltipExtensions:RegisterItemProvider(name, func, early)
    if type(name) ~= "string" or type(func) ~= "function" then
        return false
    end
    early = early and true or false;
    for i = 1, #providers do
        if providers[i].name == name then
            providers[i].func = func;          -- the same addon registering again replaces itself
            providers[i].early = early;
            return true
        end
    end
    providers[#providers + 1] = {name = name, func = func, early = early};
    return true
end

-- Runs the providers for `link` that match `early`. Returns the recorded lines in registration order.
-- A provider that errors is skipped and its error is reported once, so a broken addon cannot break the tooltip.
function TooltipExtensions:GetItemLines(link, count, early)
    local lines = {};
    if not link then
        return lines
    end
    early = early and true or false;
    for i = 1, #providers do
        local provider = providers[i];
        if provider.early == early then
            local capture = TooltipCapture:New();
            capture.link = link;
            local ok, err = pcall(provider.func, capture, link, count);
            if ok then
                for j = 1, #capture.lines do
                    lines[#lines + 1] = capture.lines[j];
                end
            elseif not reported[provider.name] then
                reported[provider.name] = true;
                geterrorhandler()("DialogueUI_335: tooltip provider \"" .. provider.name .. "\" failed: " .. tostring(err));
            end
        end
    end
    return lines
end

-- The only global of the extension API. `version` changes only when an existing call breaks.
DialogueUI_335_API = {
    version = 1,
    RegisterItemTooltipProvider = function(name, func, early)
        return TooltipExtensions:RegisterItemProvider(name, func, early)
    end,
};
