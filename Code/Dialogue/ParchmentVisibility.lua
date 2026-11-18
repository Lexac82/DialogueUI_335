


local _, addon = ...;

-- Shows the parchment while talking to an NPC and hides it when the conversation ends.

local CreateParchmentBackground = addon.CreateParchmentBackground;
local QuestData = addon.QuestData;
local GossipData = addon.GossipData;

local parchment = CreateParchmentBackground(UIParent);

local eventFrame = CreateFrame("Frame");

-- Last page shown, so QUEST_ITEM_UPDATE can redraw it when item data arrives late.
local lastEvent, lastPage;

-- Goodbye, Cancel, Esc and right click end up here: close the game side, then the parchment hides itself.
-- Nothing is open in the test page (lastEvent is nil), so only the parchment closes.
parchment:SetCloseHandler(function()
    if lastEvent == "GOSSIP_SHOW" then
        CloseGossip();
    elseif lastEvent then
        CloseQuest();
    end
    lastEvent, lastPage = nil, nil;
end);

local retryFrame = CreateFrame("Frame");
local retryElapsed = 0;
local RETRY_DELAY = 0.5;

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

-- First-contact pages: greeting text plus a list of quests and options (no quest header).
local LIST_EVENTS = {
    GOSSIP_SHOW = true,
    QUEST_GREETING = true,
};

-- Closing events are acted on a moment later. Choosing a quest in the list closes the gossip window and opens the
-- quest page right after, and accepting a quest can reopen the list: the parchment should stay up for both.
local HIDE_DELAY = 0.15;
local hideFrame = CreateFrame("Frame");
local hideElapsed = 0;

local function CancelPendingHide()
    hideFrame:SetScript("OnUpdate", nil);
end

local function HideSoon()
    hideElapsed = 0;
    hideFrame:SetScript("OnUpdate", function(frame, dt)
        hideElapsed = hideElapsed + dt;
        if hideElapsed >= HIDE_DELAY then
            frame:SetScript("OnUpdate", nil);
            parchment:Hide();
            lastEvent, lastPage = nil, nil;
        end
    end);
end

for event in pairs(SHOW_EVENTS) do
    eventFrame:RegisterEvent(event);
end
for event in pairs(HIDE_EVENTS) do
    eventFrame:RegisterEvent(event);
end

-- TEST ONLY: show the parchment shortly after the player loads. Remove when done testing.
local TEST_ENABLED = false; -- set to true to show the test quest page after login
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

-- TEST ONLY: one page with every reward type at once (choices, items, money, XP, spell, title, honor,
-- talents, arena points, costs, requirements, suggested players). Item name, icon, quality and link come from
-- GetItemInfo. Items the client has not cached are requested from the server first (see RequestTestItems).
-- Tooltips use the item link (no quest is open).
local TEST_ITEM_IDS = {19019, 50645, 3416, 3765, 2592, 6948, 2589};
local TEST_WAIT_MAX = 15;       -- seconds to wait for the server before showing placeholders

-- Returns true when every test item is cached. For the others, a hyperlink tooltip is set on the hidden scan
-- tooltip, which makes the client ask the server for the item (the only way in 3.3.5a).
local function RequestTestItems()
    local allCached = true;
    for _, itemID in ipairs(TEST_ITEM_IDS) do
        if not GetItemInfo(itemID) then
            allCached = false;
            addon.TooltipScan:ScanHyperlink("item:" .. itemID .. ":0:0:0:0:0:0:0:0");
        end
    end
    return allCached
end

local function TestItem(itemType, index, itemID, count, quality, isUsable)
    local name, link, itemQuality, _, _, _, _, _, _, texture = GetItemInfo(itemID);
    return {
        kind = "item", itemType = itemType, index = index, test = true,
        name = name or ("Test Item " .. itemID),
        texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark",
        count = count or 1,
        quality = itemQuality or quality or 1,
        isUsable = isUsable ~= false,
        link = link or ("item:" .. itemID .. ":0:0:0:0:0:0:0:0"),
    }
end

local function BuildTestPage()
    local choices = {
        TestItem("choice", 1, 19019, 1, 5),                 -- Thunderfury (legendary)
        TestItem("choice", 2, 50645, 1, 4),                 -- Leggings of Northern Lights (epic)
        TestItem("choice", 3, 3416, 1, 3, false),           -- Martyr's Chain (rare), shown as unusable
        TestItem("choice", 4, 3765, 1, 2),                  -- Brigand's Pauldrons
    };
    local rewards = {
        {kind = "xp", amount = 12450, small = true, order = 1},
        {kind = "money", amount = 123456, small = true, order = 2},
        {kind = "honor", amount = 350, small = true, order = 510},
        {kind = "talents", amount = 1, small = true, order = 520},
        {kind = "arena", amount = 25, small = true, order = 530},
        {kind = "spell", name = "Test Spell Reward", texture = "Interface\\Icons\\Spell_Nature_Regeneration", order = 100},
        {kind = "title", name = "Test the Brave", order = 200},
        TestItem("reward", 1, 2592, 5, 1),                  -- stack of 5
        TestItem("reward", 2, 6948, 1, 1),
    };
    return {
        title = "Quest Title",
        body = TEST_BODY,
        objective = TEST_OBJECTIVE,
        suggested = 3,
        tags = {
            {kind = "type", text = "Daily", icon = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\DailyQuest.blp"},
            {kind = "tag", text = "Dungeon (3)", icon = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\QuestTag-Dungeon.blp"},
        },
        moneyToGet = 25000,
        required = {TestItem("required", 1, 2589, 10, 1)},
        rewards = rewards,
        choices = choices,
        canChoose = true,
    }
end

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:RegisterEvent("QUEST_ITEM_UPDATE");

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" and TEST_ENABLED then
        -- TEST ONLY
        local elapsed, sinceCheck = 0, 0;
        self:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt;
            sinceCheck = sinceCheck + dt;
            if elapsed < TEST_SHOW_DELAY or sinceCheck < 0.5 then
                return
            end
            sinceCheck = 0;
            -- Ask for uncached items, then show once they all arrived (or after TEST_WAIT_MAX).
            if RequestTestItems() or elapsed >= TEST_SHOW_DELAY + TEST_WAIT_MAX then
                self:SetScript("OnUpdate", nil);
                parchment:Show();
                parchment:UpdatePortrait(UnitExists(TEST_PORTRAIT_UNIT) and TEST_PORTRAIT_UNIT or nil);
                local testPage = BuildTestPage();
                parchment:SetTitle(testPage.title);
                parchment:SetTags(testPage.tags);
                parchment:SetCompleteIcon(true);
                parchment:SetQuestText(testPage.body, testPage.objective, testPage);
                parchment:SetPage("QUEST_COMPLETE", testPage);
            end
        end);
    end
    if LIST_EVENTS[event] then
        CancelPendingHide();
        local page = GossipData:Read(event);
        parchment:Show();
        parchment:SetListPage(event, page);
        lastEvent, lastPage = event, page;
    elseif SHOW_EVENTS[event] then
        CancelPendingHide();
        -- Quest text is only valid during its own event, so read it here.
        local page = QuestData:GetPage(event);
        parchment:Show();
        parchment:UpdatePortrait();
        parchment:SetTitle(page.title);
        parchment:SetTags(page.tags);
        parchment:SetCompleteIcon(event == "QUEST_COMPLETE");
        parchment:SetQuestText(page.body, page.objective, page);
        parchment:SetPage(event, page);
        lastEvent, lastPage = event, page;
    elseif HIDE_EVENTS[event] then
        HideSoon();
    elseif event == "QUEST_ITEM_UPDATE" then
        -- Item data arrived: redraw once (retail re-runs the handler 0.5 s later).
        if lastPage and lastPage.incomplete then
            retryElapsed = 0;
            retryFrame:SetScript("OnUpdate", function(frame, dt)
                retryElapsed = retryElapsed + dt;
                if retryElapsed >= RETRY_DELAY then
                    frame:SetScript("OnUpdate", nil);
                    if lastEvent then
                        local page = QuestData:GetPage(lastEvent);
                        parchment:SetQuestText(page.body, page.objective, page);
                        if lastEvent == "QUEST_COMPLETE" then
                            parchment:SetPage(lastEvent, page);     -- the redraw clears the reward choice
                        end
                        lastPage = page;
                    end
                end
            end);
        end
    end
end);
