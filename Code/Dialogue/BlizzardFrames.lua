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

-- Some servers open the default windows themselves (not through the frame events) and only answer gossip and quest
-- selections while that window counts as shown. Hiding it would also close the conversation (its OnHide calls
-- CloseGossip / CloseQuest). So when such a window shows up while our UI is active, it stays "shown" but hangs under a
-- hidden parent: nothing is drawn or clickable, no hide ever fires, and its OnHide is taken off in case the server
-- hides it itself. Only frames seen opening this way are touched, so other servers keep the plain behaviour above.
local hiddenParent = CreateFrame("Frame");
hiddenParent:Hide();
local savedOnHide = {};
local serverOpened = {};     -- frames the server has been seen opening on its own

local function SilenceOnHide(frame, state)
    if state then
        if savedOnHide[frame] == nil then
            savedOnHide[frame] = frame:GetScript("OnHide") or false;
            frame:SetScript("OnHide", nil);
        end
    elseif savedOnHide[frame] ~= nil then
        frame:SetScript("OnHide", savedOnHide[frame] or nil);
        savedOnHide[frame] = nil;
    end
end

local function SetParked(frame, state)
    SilenceOnHide(frame, state);
    pcall(frame.SetParent, frame, state and hiddenParent or UIParent);
end

local function OnServerShow(frame)
    if addon.defaultUIActive then
        return
    end
    serverOpened[frame] = true;
    frame:UnregisterAllEvents();      -- the server's code may have registered them again
    SetParked(frame, true);
end

for _, info in ipairs(FRAME_EVENTS) do
    if info.frame then
        info.frame:HookScript("OnShow", OnServerShow);
    end
end

-- "Use WoW's Default UI In Instance" (Core.lua). The book UI and the event listener read addon.defaultUIActive.
addon.defaultUIActive = false;

function addon.SetDefaultUIActive(state)
    state = state and true or false;
    if state == addon.defaultUIActive then
        return
    end
    addon.defaultUIActive = state;
    SetBlizzardFrames(not state);
    for _, info in ipairs(FRAME_EVENTS) do
        if info.frame and serverOpened[info.frame] then
            SetParked(info.frame, not state);
        end
    end
    addon.CallbackRegistry:Trigger("DefaultUIActiveChanged", state);
end
