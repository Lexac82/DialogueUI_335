local _, addon = ...;

-- Shows the parchment while talking to an NPC and hides it when the conversation ends.

local CreateParchmentBackground = addon.CreateParchmentBackground;

local parchment = CreateParchmentBackground(UIParent);

local eventFrame = CreateFrame("Frame");

-- Opening events: gossip, quest greeting, and quest pages. Each one is a conversation step.
local SHOW_EVENTS = {
    GOSSIP_SHOW = true,
    QUEST_GREETING = true,
    QUEST_DETAIL = true,
    QUEST_PROGRESS = true,
    QUEST_COMPLETE = true,
};

-- QUEST_FINISHED ends every quest page. GOSSIP_CLOSED ends a gossip window.
local HIDE_EVENTS = {
    GOSSIP_CLOSED = true,
    QUEST_FINISHED = true,
};

for event in pairs(SHOW_EVENTS) do
    eventFrame:RegisterEvent(event);
end
for event in pairs(HIDE_EVENTS) do
    eventFrame:RegisterEvent(event);
end

-- TEST ONLY: show the parchment shortly after the player loads. Remove when done testing.
local TEST_SHOW_DELAY = 1; -- seconds after PLAYER_ENTERING_WORLD
local TEST_PORTRAIT_UNIT = "target"; -- portrait comes from the selected target
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- TEST ONLY
        local elapsed = 0;
        self:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt;
            if elapsed >= TEST_SHOW_DELAY then
                self:SetScript("OnUpdate", nil);
                parchment:Show();
                parchment:UpdatePortrait(UnitExists(TEST_PORTRAIT_UNIT) and TEST_PORTRAIT_UNIT or nil);
            end
        end);
    end
    if SHOW_EVENTS[event] then
        parchment:Show();
        parchment:UpdatePortrait();
    elseif HIDE_EVENTS[event] then
        parchment:Hide();
    end
end);
