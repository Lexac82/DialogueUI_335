local _, addon = ...;

-- Reads quest text for the current conversation step, using 3.3.5a APIs only.
-- Each call is valid only during its own event; call it right after the event fires.
local QuestData = {};
addon.QuestData = QuestData;

local GetTitleText = GetTitleText;
local GetQuestText = GetQuestText;
local GetObjectiveText = GetObjectiveText;
local GetProgressText = GetProgressText;
local GetRewardText = GetRewardText;
local GetGreetingText = GetGreetingText;
local GetGossipText = GetGossipText;

local PAGE_READERS = {
    -- Accept/decline page: title, quest body and objective.
    QUEST_DETAIL = function()
        return {
            title = GetTitleText(),
            body = GetQuestText(),
            objective = GetObjectiveText(),
        };
    end,
    -- Turn-in page while the quest is incomplete.
    QUEST_PROGRESS = function()
        return {
            title = GetTitleText(),
            body = GetProgressText(),
        };
    end,
    -- Turn-in page once the quest is complete: rewards.
    QUEST_COMPLETE = function()
        return {
            title = GetTitleText(),
            body = GetRewardText(),
        };
    end,
    -- Questgiver greeting: no quest title yet.
    QUEST_GREETING = function()
        return {
            body = GetGreetingText(),
        };
    end,
    -- Gossip window: no quest title.
    GOSSIP_SHOW = function()
        return {
            body = GetGossipText(),
        };
    end,
};

-- Returns a plain table for the event's page. Missing fields are nil.
function QuestData:GetPage(event)
    local reader = PAGE_READERS[event];
    if not reader then
        return {};
    end
    return reader();
end
