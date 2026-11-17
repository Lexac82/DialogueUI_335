


local _, addon = ...;

-- Shows the parchment while talking to an NPC and hides it when the conversation ends.

local CreateParchmentBackground = addon.CreateParchmentBackground;
local QuestData = addon.QuestData;

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
local TEST_BODY = "Traveler, you arrive at a dark hour. For three nights now, a pale light has burned in the old watchtower on Gallows Ridge, and no one in Thornwick Hollow has slept soundly since. The shepherds say the light moves, drifting from window to window as though something were searching the empty rooms. Last week, young Merrin went up the ridge to bring back a lost ewe, and he has not been seen again. His mother sits by the well each evening and stares at the hill.\n"
    .. "The tower was raised long ago by the Order of the Silver Lantern, a company of scholars who studied the stars and the spirits that walk beneath them. When the order fell into ruin, its keepers vanished one by one, and the doors were sealed with iron and wax. Nobody here remembers why. The elders only say that some things were locked away for good reason, and that the reason was written down somewhere inside.\n"
    .. "I would not ask this of you if I had another choice. My own hands shake too badly to hold a blade, and the men of the village are farmers, not soldiers. But I have seen how you carry yourself, and I believe you can do what we cannot. Climb the ridge before sunrise, while the light is weakest, and find a way inside. Whatever is awake in that place must be stopped, or at least understood.\n"
    .. "Be warned that the path is not safe. Wolves with eyes like cold embers have been seen near the old quarry, and the fog on the upper slope clings to the skin and fills the mind with whispers. Keep to the rocks and do not follow any voice, even if it sounds like someone you know. Several searchers have turned back with stories of a woman in grey who walks beside them and never leaves footprints.\n"
    .. "Speak to no one on the ridge road, and take no food or drink from strangers. The shepherds leave offerings at the stone markers, bread and salt, to keep the wanderers calm, and I would ask you to do the same. A small kindness costs little, and in these hills it has saved more than one life.\n"
    .. "Inside the tower you will need to find the Lantern Keeper's journal. It should lie in the observatory at the very top, beneath the broken brass dome. I believe it names the ritual that sealed the tower and the means to undo it. Take the journal and, if you can, the silver lens that was set into the great telescope. Without that lens, the light will simply return the moment you leave.\n"
    .. "If you find Merrin, bring him home first, and do not worry about anything else. The village has little coin, but we have gathered what we could: a purse of silver, a good wool cloak woven by the women of the Hollow, and my late husband's hunting knife, which has never failed its owner. Take it with our blessing. Come back alive, and you will always have a warm seat by our fire and a roof over your head, whatever road you travel next.\n"
    .. "Go now, and may the old stars watch over you. I will keep a candle burning in the window until you return."; -- 8 paragraphs, 500+ words, so the scrolling can be seen
local TEST_OBJECTIVE = "Retrieve the Lantern Keeper's Journal and the Silver Lens from Gallows Ridge Tower.";
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
                parchment:SetTitle("Quest Title");
                parchment:SetQuestText(TEST_BODY, TEST_OBJECTIVE);
            end
        end);
    end
    if SHOW_EVENTS[event] then
        -- Quest text is only valid during its own event, so read it here.
        local page = QuestData:GetPage(event);
        parchment:Show();
        parchment:UpdatePortrait();
        parchment:SetTitle(page.title);
        parchment:SetQuestText(page.body, page.objective);
    elseif HIDE_EVENTS[event] then
        parchment:Hide();
    end
end);
