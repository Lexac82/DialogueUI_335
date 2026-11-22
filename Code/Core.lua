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

-- A greeting with nothing to choose is often followed at once by a shop, trainer or bank window. It is shown a moment
-- late, so those windows can cancel it and the parchment does not flash up first.
local EMPTY_SHOW_DELAY = 0.2;
local InteractionEvents = {
    MERCHANT_SHOW = true,
    TRAINER_SHOW = true,
    BANKFRAME_OPENED = true,
    TAXIMAP_OPENED = true,
    AUCTION_HOUSE_SHOW = true,
    PETITION_SHOW = true,
};

local function IsEmptyGossip()
    return (GetNumGossipOptions() or 0) == 0
        and (GetNumGossipAvailableQuests() or 0) == 0
        and (GetNumGossipActiveQuests() or 0) == 0
end

local EL = CreateFrame("Frame");
local hideToken = 0;

function EL:CancelPendingHide()
    hideToken = hideToken + 1;
end

-- Any later event moves hideToken on, which cancels the pending show.
function EL:ShowLater(event)
    hideToken = hideToken + 1;
    local token = hideToken;
    After(EMPTY_SHOW_DELAY, function()
        if token == hideToken then
            MainFrame:ShowUI(event);
        end
    end);
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
        if event == "GOSSIP_SHOW" and not MainFrame:IsShown() and IsEmptyGossip() then
            self:ShowLater(event);
        else
            self:CancelPendingHide();
            MainFrame:ShowUI(event);
        end
    elseif InteractionEvents[event] then
        -- Cancels a pending show; a parchment already up is closed (the game side is done with the gossip).
        self:CancelPendingHide();
        if MainFrame:IsShown() and not MainFrame:IsEditMode() then
            MainFrame:HideUI();
        end
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
for event in pairs(InteractionEvents) do
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
