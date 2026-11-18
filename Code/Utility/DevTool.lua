local _, addon = ...;

-- Developer tools. /duitest shows a quest page with every reward type at once (choices, items, money, XP, spell,
-- title, honor, talents, arena points, costs, requirements, suggested players) and a long text, so layout and
-- scrolling can be checked without a quest. Close it with Esc, Cancel or right click.

local After = addon.API.After;
local MainFrame = addon.DialogueUI;

local GetItemInfo = GetItemInfo;
local UnitExists = UnitExists;

local ICON_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\";
local PORTRAIT_UNIT = "target";             -- the portrait comes from the selected target
local CHECK_INTERVAL = 0.5;
local WAIT_MAX = 15;                        -- seconds to wait for the server before showing placeholders

-- 8 paragraphs, 500+ words, so the scrolling can be seen
local TEST_BODY = "Traveler, you arrive at a dark hour. For three nights now, a pale light has burned in the old watchtower on Gallows Ridge, and no one in Thornwick Hollow has slept soundly since. The shepherds say the light moves, drifting from window to window as though something were searching the empty rooms. Last week, young Merrin went up the ridge to bring back a lost ewe, and he has not been seen again. His mother sits by the well each evening and stares at the hill.\n"
    .. "The tower was raised long ago by the Order of the Silver Lantern, a company of scholars who studied the stars and the spirits that walk beneath them. When the order fell into ruin, its keepers vanished one by one, and the doors were sealed with iron and wax. Nobody here remembers why. The elders only say that some things were locked away for good reason, and that the reason was written down somewhere inside.\n"
    .. "I would not ask this of you if I had another choice. My own hands shake too badly to hold a blade, and the men of the village are farmers, not soldiers. But I have seen how you carry yourself, and I believe you can do what we cannot. Climb the ridge before sunrise, while the light is weakest, and find a way inside. Whatever is awake in that place must be stopped, or at least understood.\n"
    .. "Be warned that the path is not safe. Wolves with eyes like cold embers have been seen near the old quarry, and the fog on the upper slope clings to the skin and fills the mind with whispers. Keep to the rocks and do not follow any voice, even if it sounds like someone you know. Several searchers have turned back with stories of a woman in grey who walks beside them and never leaves footprints.\n"
    .. "Speak to no one on the ridge road, and take no food or drink from strangers. The shepherds leave offerings at the stone markers, bread and salt, to keep the wanderers calm, and I would ask you to do the same. A small kindness costs little, and in these hills it has saved more than one life.\n"
    .. "Inside the tower you will need to find the Lantern Keeper's journal. It should lie in the observatory at the very top, beneath the broken brass dome. I believe it names the ritual that sealed the tower and the means to undo it. Take the journal and, if you can, the silver lens that was set into the great telescope. Without that lens, the light will simply return the moment you leave.\n"
    .. "If you find Merrin, bring him home first, and do not worry about anything else. The village has little coin, but we have gathered what we could: a purse of silver, a good wool cloak woven by the women of the Hollow, and my late husband's hunting knife, which has never failed its owner. Take it with our blessing. Come back alive, and you will always have a warm seat by our fire and a roof over your head, whatever road you travel next.\n"
    .. "Go now, and may the old stars watch over you. I will keep a candle burning in the window until you return.";
local TEST_OBJECTIVE = "Retrieve the Lantern Keeper's Journal and the Silver Lens from Gallows Ridge Tower.";

-- Item name, icon, quality and link come from GetItemInfo. Tooltips use the item link (no quest is open).
local TEST_ITEM_IDS = {19019, 50645, 3416, 3765, 2592, 6948, 2589};

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
            {kind = "type", text = "Daily", icon = ICON_PATH .. "DailyQuest.blp"},
            {kind = "tag", text = "Dungeon (3)", icon = ICON_PATH .. "QuestTag-Dungeon.blp"},
        },
        moneyToGet = 25000,
        required = {TestItem("required", 1, 2589, 10, 1)},
        rewards = rewards,
        choices = choices,
        canChoose = true,
    }
end

local function ShowTestPage()
    local page = BuildTestPage();
    MainFrame:Show();
    MainFrame:UpdatePortrait(UnitExists(PORTRAIT_UNIT) and PORTRAIT_UNIT or nil);
    MainFrame:SetTitle(page.title);
    MainFrame:SetTags(page.tags);
    MainFrame:SetCompleteIcon(true);
    MainFrame:SetQuestText(page.body, page.objective, page);
    MainFrame:SetPage("QUEST_COMPLETE", page);
end

-- Asks for the uncached items, then shows the page once they all arrived (or after WAIT_MAX).
local function StartTestPage()
    local waited = 0;
    local function Step()
        if RequestTestItems() or waited >= WAIT_MAX then
            ShowTestPage();
        else
            waited = waited + CHECK_INTERVAL;
            After(CHECK_INTERVAL, Step);
        end
    end
    Step();
end

SLASH_DUITEST1 = "/duitest";
SlashCmdList["DUITEST"] = StartTestPage;
