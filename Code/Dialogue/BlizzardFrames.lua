local _, addon = ...;

-- Stops the default gossip and quest windows from opening, so only the parchment shows.
-- Both frames are opened by their own OnEvent handlers (ShowUIPanel), so without events they never appear.
-- Our event frame in Core.lua listens to the same events and is not affected.

local function DisableFrame(frame)
    if frame then
        frame:UnregisterAllEvents();
    end
end

DisableFrame(GossipFrame);  -- GOSSIP_SHOW, GOSSIP_CLOSED
DisableFrame(QuestFrame);   -- QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, QUEST_FINISHED, QUEST_ITEM_UPDATE
