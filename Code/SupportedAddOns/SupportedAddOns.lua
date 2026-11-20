local _, addon = ...;

-- Support for other addons, one file each in this folder. Same idea as retail's SupportedAddOns.lua.
-- A file calls addon.AddSupportedAddOn(addonName, onLoaded, requiredGlobals). Once the world has loaded
-- (every addon had its turn), onLoaded runs if the addon is loaded and every name in requiredGlobals is a
-- global that exists. Files should talk to the other addon only through its public globals.
local IsAddOnLoaded = IsAddOnLoaded;

local List = {};

function addon.AddSupportedAddOn(addonName, onLoaded, requiredGlobals)
    List[#List + 1] = {addonName, onLoaded, requiredGlobals};
end

local function CheckSupportedAddOns()
    for i = 1, #List do
        local addonName, onLoaded, requiredGlobals = List[i][1], List[i][2], List[i][3];
        if IsAddOnLoaded(addonName) then
            local ready = true;
            if requiredGlobals then
                for j = 1, #requiredGlobals do
                    if _G[requiredGlobals[j]] == nil then
                        ready = false;
                        break
                    end
                end
            end
            if ready then
                onLoaded();
            end
        end
    end
    List = {};
end

addon.CallbackRegistry:Register("PLAYER_ENTERING_WORLD", CheckSupportedAddOns);
