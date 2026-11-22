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
-- CloseGossip / CloseQuest). So on such a server the windows hang under a hidden parent from the start: they can still
-- be "shown", but nothing is drawn or clickable, no hide ever fires, and their OnHide is taken off in case the server
-- hides them itself. They must be parked before the server shows them: parking a visible frame fires its OnHide.
-- Only that server is touched (found by its CoAResourceSegmentBar frame), others keep the plain behaviour above.
local hiddenParent = CreateFrame("Frame");
hiddenParent:Hide();
local savedOnHide = {};
local parkingActive = false;

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

local function ParkFrames(state)
    for _, info in ipairs(FRAME_EVENTS) do
        local frame = info.frame;
        -- A frame that is visible already is left alone: moving it would hide it.
        if frame and (not state or not frame:IsShown()) then
            SetParked(frame, state);
        end
    end
end

-- The server's frame may be created after this file loads, so it is looked for again at login.
local function CheckServer()
    if parkingActive or not _G.CoAResourceSegmentBar then
        return
    end
    parkingActive = true;
    if not addon.defaultUIActive then
        ParkFrames(true);
    end
end

CheckServer();
if not parkingActive then
    local watcher = CreateFrame("Frame");
    watcher:RegisterEvent("PLAYER_LOGIN");
    watcher:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents();
        CheckServer();
    end);
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
    if parkingActive then
        ParkFrames(not state);
    end
    addon.CallbackRegistry:Trigger("DefaultUIActiveChanged", state);
end
