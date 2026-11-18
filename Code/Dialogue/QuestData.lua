local _, addon = ...;

-- Reads quest text and rewards for the current conversation step, using 3.3.5a APIs only.
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

local GetNumQuestRewards = GetNumQuestRewards;
local GetNumQuestChoices = GetNumQuestChoices;
local GetNumQuestItems = GetNumQuestItems;
local GetQuestItemInfo = GetQuestItemInfo;
local GetQuestItemLink = GetQuestItemLink;
local GetRewardMoney = GetRewardMoney;
local GetRewardXP = GetRewardXP;                    -- bare entry in wow-docs: signature unverified
local GetRewardHonor = GetRewardHonor;
local GetRewardTalents = GetRewardTalents;
local GetRewardTitle = GetRewardTitle;
local GetRewardSpell = GetRewardSpell;
local GetQuestMoneyToGet = GetQuestMoneyToGet;
local IsQuestCompletable = IsQuestCompletable;
local GetSuggestedGroupNum = GetSuggestedGroupNum;

-- Order numbers and "small row" flags from retail's QuestRewards.lua BuildRewardList.
local ORDER_XP = 1;
local ORDER_MONEY = 2;
local ORDER_SPELL = 100;
local ORDER_TITLE = 200;
local ORDER_ITEM = 300;
local ORDER_HONOR = 510;
local ORDER_TALENTS = 520;
local ORDER_ARENA = 530;

-- Reads one quest item. itemType: "reward", "choice" or "required".
-- `missing` is true when the client has not cached the item yet (QUEST_ITEM_UPDATE fires later).
local function ReadItem(itemType, index)
    local name, texture, count, quality, isUsable = GetQuestItemInfo(itemType, index);
    return {
        kind = "item",
        itemType = itemType,
        index = index,
        name = name,
        texture = texture,
        count = count or 1,
        quality = quality or 1,
        isUsable = isUsable,
        link = GetQuestItemLink(itemType, index),
        missing = (name == nil or name == ""),
    }
end

local function SortRewards(a, b)
    if a.small ~= b.small then
        return a.small and true or false     -- small rows first
    end
    return a.order < b.order
end

-- Rewards shown on both the accept page and the turn-in page. Items are split into
-- the fixed list and the choice group.
local function ReadRewards(page, canChoose)
    local list = {};
    local missing = false;

    local xp = GetRewardXP and GetRewardXP() or 0;
    if xp and xp > 0 then
        list[#list + 1] = {kind = "xp", amount = xp, small = true, order = ORDER_XP};
    end

    local money = GetRewardMoney() or 0;
    if money > 0 then
        list[#list + 1] = {kind = "money", amount = money, small = true, order = ORDER_MONEY};
    end

    local spellTexture, spellName, isTradeskill, isLearned = GetRewardSpell();
    if spellTexture then
        list[#list + 1] = {kind = "spell", texture = spellTexture, name = spellName,
            isTradeskill = isTradeskill, isLearned = isLearned, order = ORDER_SPELL};
    end

    local title = GetRewardTitle();
    if title and title ~= "" then
        list[#list + 1] = {kind = "title", name = title, order = ORDER_TITLE};
    end

    local numRewards = GetNumQuestRewards() or 0;
    for i = 1, numRewards do
        local item = ReadItem("reward", i);
        item.order = ORDER_ITEM + i;
        missing = missing or item.missing;
        list[#list + 1] = item;
    end

    local honor = GetRewardHonor() or 0;
    if honor > 0 then
        list[#list + 1] = {kind = "honor", amount = honor, small = true, order = ORDER_HONOR};
    end

    local talents = GetRewardTalents() or 0;
    if talents > 0 then
        list[#list + 1] = {kind = "talents", amount = talents, small = true, order = ORDER_TALENTS};
    end

    -- Arena points: exists in 3.3.5a but is not in wow-docs (UNVERIFIED), so it is guarded.
    local getArena = _G.GetRewardArenaPoints;
    local arena = getArena and getArena() or 0;
    if arena and arena > 0 then
        list[#list + 1] = {kind = "arena", amount = arena, small = true, order = ORDER_ARENA};
    end

    local choices = {};
    local numChoices = GetNumQuestChoices() or 0;
    for i = 1, numChoices do
        local item = ReadItem("choice", i);
        missing = missing or item.missing;
        choices[#choices + 1] = item;
    end

    -- One choice: it is simply given ("You will receive"), as retail does.
    if numChoices == 1 then
        local item = choices[1];
        item.order = ORDER_ITEM;
        list[#list + 1] = item;
        choices = {};
    end

    table.sort(list, SortRewards);

    page.rewards = list;
    page.choices = choices;
    page.canChoose = canChoose and #choices > 1 or false;
    page.hasChoiceHeader = #choices > 1;
    if missing then
        page.incomplete = true;
    end
end

-- Quest type pills for the header. Each entry: {kind = "type"|"tag", text = label, icon = texture or nil}.
-- The dialogue APIs (valid during the quest event) tell daily / weekly / PvP. The Dungeon / Raid / Elite /
-- Heroic / Group tag exists only in the quest log, so it is found by title and is missing on the accept page
-- of a quest the player has not taken yet. 3.3.5a has no legendary / campaign / important quest types.
local ICON_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\";
local ICON_AVAILABLE = ICON_PATH .. "AvailableQuest.blp";
local ICON_DAILY = ICON_PATH .. "DailyQuest.blp";
local ICON_WEEKLY = ICON_PATH .. "WeeklyQuest.blp";

local QUEST_TAG_ICON = {
    Dungeon = ICON_PATH .. "QuestTag-Dungeon.blp",
    Heroic = ICON_PATH .. "QuestTag-Dungeon.blp",
    Raid = ICON_PATH .. "QuestTag-Raid.blp",
};

local QUEST_TAG_LABEL = {
    Dungeon = "Dungeon",
    Raid = "Raid",
    Heroic = "Heroic",
    Elite = "Elite",
    Group = "Group",
    PVP = "PvP",
};

local function FindLogEntry(title)
    if not title or title == "" then return end
    for i = 1, GetNumQuestLogEntries() do
        local name, _, tag, suggestedGroup, isHeader, _, _, isDaily = GetQuestLogTitle(i);
        if name == title and not isHeader then
            return tag, suggestedGroup, isDaily
        end
    end
end

local function ReadTags(page)
    local tags = {};
    local logTag, logGroup, logDaily = FindLogEntry(page.title);

    if QuestIsWeekly and QuestIsWeekly() then
        tags[#tags + 1] = {kind = "type", text = "Weekly", icon = ICON_WEEKLY};
    elseif (QuestIsDaily and QuestIsDaily()) or logDaily then
        tags[#tags + 1] = {kind = "type", text = "Daily", icon = ICON_DAILY};
    else
        tags[#tags + 1] = {kind = "type", text = "Quest", icon = ICON_AVAILABLE};
    end

    local label = logTag and QUEST_TAG_LABEL[logTag];
    if not label and QuestFlagsPVP and QuestFlagsPVP() then
        label = QUEST_TAG_LABEL.PVP;
    end
    if label then
        local group = logGroup and logGroup > 1 and logGroup or page.suggested;
        if group and group > 1 then
            label = label .. " (" .. group .. ")";
        end
        tags[#tags + 1] = {kind = "tag", text = label, icon = logTag and QUEST_TAG_ICON[logTag]};
    end

    page.tags = tags;
end

local PAGE_READERS = {
    -- Accept/decline page: title, quest body, objective and the rewards on offer.
    QUEST_DETAIL = function()
        local page = {
            title = GetTitleText(),
            body = GetQuestText(),
            objective = GetObjectiveText(),
        };
        local suggested = GetSuggestedGroupNum and GetSuggestedGroupNum() or 0;
        if suggested and suggested > 1 then
            page.suggested = suggested;
        end
        ReadTags(page);
        ReadRewards(page, false);
        return page
    end,
    -- Turn-in page while the quest is incomplete: required items and money.
    QUEST_PROGRESS = function()
        local page = {
            title = GetTitleText(),
            body = GetProgressText(),
            required = {},
            completable = IsQuestCompletable() and true or false,   -- enables the Continue button
        };
        ReadTags(page);
        local numItems = GetNumQuestItems() or 0;
        for i = 1, numItems do
            local item = ReadItem("required", i);
            if item.missing then
                page.incomplete = true;
            end
            page.required[#page.required + 1] = item;
        end
        local moneyToGet = GetQuestMoneyToGet() or 0;
        if moneyToGet > 0 then
            page.moneyToGet = moneyToGet;
        end
        return page
    end,
    -- Turn-in page once the quest is complete: reward text and the rewards (a choice can be made).
    QUEST_COMPLETE = function()
        local page = {
            title = GetTitleText(),
            body = GetRewardText(),
        };
        ReadTags(page);
        ReadRewards(page, true);
        return page
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
