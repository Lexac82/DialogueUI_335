local _, addon = ...;

-- Listens to the gossip and quest events and tells the dialogue frame what to do. Same role as retail's Core.lua.

local After = addon.API.After;
local CallbackRegistry = addon.CallbackRegistry;
local MainFrame = addon.DialogueUI;

-- Opening events. Each one is a conversation step.
local ShowEvents = {
    GOSSIP_SHOW = true,
    QUEST_GREETING = true,
    QUEST_DETAIL = true,
    QUEST_PROGRESS = true,
    QUEST_COMPLETE = true,
};

-- QUEST_FINISHED ends every quest page. GOSSIP_CLOSED ends a gossip window.
local HideEvents = {
    GOSSIP_CLOSED = true,
    QUEST_FINISHED = true,
};

-- Closing events are acted on a moment later. Choosing a quest in the list closes the gossip window and opens the
-- quest page right after, and accepting a quest can reopen the list: the frame should stay up for both.
local HIDE_DELAY = 0.15;

local EL = CreateFrame("Frame");
local hideToken = 0;

function EL:CancelPendingHide()
    hideToken = hideToken + 1;
end

function EL:HideNextUpdate()
    hideToken = hideToken + 1;
    local token = hideToken;
    After(HIDE_DELAY, function()
        if token == hideToken then
            MainFrame:HideUI();
        end
    end);
end

function EL:OnEvent(event)
    if addon.defaultUIActive then
        return
    end
    if ShowEvents[event] then
        self:CancelPendingHide();
        MainFrame:ShowUI(event);
    elseif HideEvents[event] then
        self:HideNextUpdate();
    elseif event == "QUEST_ITEM_UPDATE" then
        MainFrame:OnItemUpdate();
    end
end

for event in pairs(ShowEvents) do
    EL:RegisterEvent(event);
end
for event in pairs(HideEvents) do
    EL:RegisterEvent(event);
end
EL:RegisterEvent("QUEST_ITEM_UPDATE");
EL:SetScript("OnEvent", EL.OnEvent);

-- "Use WoW's Default UI In Instance": dungeons and raids get Blizzard's windows.
-- Zone events only matter while the setting is on.
local InstanceWatcher = CreateFrame("Frame");

local function UpdateForInstance()
    local inInstance = IsInInstance();
    addon.SetDefaultUIActive(inInstance and true or false);
end

InstanceWatcher:SetScript("OnEvent", UpdateForInstance);

CallbackRegistry:Register("SettingChanged.DisableDUIInInstance", function(state)
    if state == true then
        InstanceWatcher:RegisterEvent("PLAYER_ENTERING_WORLD");
        InstanceWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA");
        UpdateForInstance();
    else
        InstanceWatcher:UnregisterAllEvents();
        addon.SetDefaultUIActive(false);
    end
end);

-- Our windows close when the default UI takes over.
CallbackRegistry:Register("DefaultUIActiveChanged", function(active)
    if active then
        EL:CancelPendingHide();
        MainFrame:HideUI();
    end
end);
