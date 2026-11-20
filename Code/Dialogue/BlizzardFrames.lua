local _, addon = ...;

-- Stops the default gossip and quest windows from opening, so only the parchment shows.
-- Both frames are opened by their own OnEvent handlers (ShowUIPanel), so without events they never appear.
-- Our event frame in Core.lua listens to the same events and is not affected.

-- The events Blizzard's frames register themselves in their XML. Needed to give the default UI back in instances.
local FRAME_EVENTS = {
    {frame = GossipFrame, events = {"GOSSIP_SHOW", "GOSSIP_CLOSED"}},
    {frame = QuestFrame, events = {"QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ITEM_UPDATE"}},
};

-- state true: Blizzard's windows are off (our UI shows). state false: Blizzard's windows are back.
local function SetBlizzardFrames(state)
    for _, info in ipairs(FRAME_EVENTS) do
        local frame = info.frame;
        if frame then
            if state then
                frame:UnregisterAllEvents();
            else
                for _, event in ipairs(info.events) do
                    frame:RegisterEvent(event);
                end
            end
        end
    end
end

SetBlizzardFrames(true);

-- "Use WoW's Default UI In Instance" (Core.lua). The book UI and the event listener read addon.defaultUIActive.
addon.defaultUIActive = false;

function addon.SetDefaultUIActive(state)
    state = state and true or false;
    if state == addon.defaultUIActive then
        return
    end
    addon.defaultUIActive = state;
    SetBlizzardFrames(not state);
    addon.CallbackRegistry:Trigger("DefaultUIActiveChanged", state);
end
