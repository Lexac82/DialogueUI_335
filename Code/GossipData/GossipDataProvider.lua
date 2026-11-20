local _, addon = ...;

-- Reads the first-contact page: greeting text plus the list of rows (quests and gossip options).
-- Port of retail's HandleGossip / HandleQuestGreeting row building (DialogueUI.lua:1242, :1917), 3.3.5a APIs only.
-- Each call is valid only during its own event (GOSSIP_SHOW / QUEST_GREETING).
local L = addon.L;

local GossipDataProvider = {};
addon.GossipDataProvider = GossipDataProvider;

local UnitLevel = UnitLevel;
local UnitFactionGroup = UnitFactionGroup;
local lower, find, format = string.lower, string.find, string.format;
local sort = table.sort;

local ICON_PATH = "Interface\\AddOns\\DialogueUI_335\\Textures\\Icons\\";
local CLIENT_ICON_PATH = "Interface\\GossipFrame\\";     -- client files, not in wow-docs: check in game

-- Row spacing, from retail (DialogueUI.lua:43-44), unscaled.
local PARAGRAPH_SPACING = 4 * 12 * 0.35;                 -- text to options
local SECTION_SPACING = 2 * 12;                          -- PARAGRAPH_BUTTON_SPACING
local TIGHT_SPACING = 1;
GossipDataProvider.GAPS = {paragraph = PARAGRAPH_SPACING, section = SECTION_SPACING, tight = TIGHT_SPACING, none = 0};

-- Both follow the font size (retail OnFontSizeChanged). The table is changed in place: QuestTextLayout reads it per page.
addon.CallbackRegistry:Register("FontSizeChanged", function(baseFontSize)
    GossipDataProvider.GAPS.paragraph = 4 * baseFontSize * 0.35;
    GossipDataProvider.GAPS.section = 2 * baseFontSize;
end);

-- Quest level colours (retail QuestDifficulty.lua): "Bright" on the Brown theme, "Dark" on the Dark theme.
local DIFFICULTY_COLORS = {
    Bright = {VeryHard = "f85658", Hard = "ff9845", Normal = "e9c21b", Easy = "81c285", Trivial = "b2a6a5", Unfinished = "b3b3b3"},
    Dark = {VeryHard = "ff7370", Hard = "ed953c", Normal = "d9c726", Easy = "91be93", Trivial = "b2a6a5", Unfinished = "b3b3b3"},
};

local function GetColors()
    return addon.ThemeUtil:IsDarkMode() and DIFFICULTY_COLORS.Dark or DIFFICULTY_COLORS.Bright
end

local function GetLevelColor(levelDiff)
    local colors = GetColors();
    if levelDiff > 5 then
        return colors.VeryHard
    elseif levelDiff >= 3 then
        return colors.Hard
    elseif levelDiff >= -2 then
        return colors.Normal
    elseif levelDiff >= -5 then
        return colors.Easy
    end
    return colors.Trivial
end

-- Settings > Quest Difficulty (retail QuestDifficultyStyle): 0 Off, 1 Level (coloured level left of the title),
-- 2 Name (difficulty word on the right of the button when the quest is outside the normal range, -2 .. +2),
-- 3 Both (not in retail: level on the left and the difficulty word on the right).
local function GetDifficultyStyle()
    return addon.GetDBValue("QuestDifficultyStyle") or 1
end

-- Retail GetQuestDifficultyLabel: nil for Normal.
local function GetDifficultyLabel(row)
    local level = row.level;
    if not level or level <= 0 then
        return nil
    end
    local diff = level - (UnitLevel("player") or level);
    if diff > 5 then
        return L["Quest Difficulty VeryHard"]
    elseif diff >= 3 then
        return L["Quest Difficulty Hard"]
    elseif diff >= -2 then
        return nil
    elseif diff >= -5 then
        return L["Quest Difficulty Easy"]
    end
    return L["Quest Difficulty Trivial"]
end

-- "|cffRRGGBB62|r  Title". Level 0 or nil, or style not Level: just the title.
local function FormatQuestTitle(row)
    local level = row.level;
    if (GetDifficultyStyle() % 2) ~= 1 or not level or level <= 0 then
        return row.title
    end
    local hex;
    if row.kind == "active" and not row.complete then
        hex = GetColors().Unfinished;
    elseif row.trivial then
        hex = GetColors().Trivial;
    else
        hex = GetLevelColor(level - (UnitLevel("player") or level));
    end
    return format("|cff%s%d|r  %s", hex, level, row.title)
end

-- Quest detail pages have no level API. The level comes from the quest log (quest already taken) or from the
-- list the player picked the quest from (remembered by title). A single-quest NPC or an item-started quest
-- opens the details directly: no level is known there until the quest is in the log.
local levelByTitle = {};

local function RememberLevels(quests)
    for _, row in ipairs(quests) do
        if row.title and row.level and row.level > 0 then
            levelByTitle[row.title] = row.level;
        end
    end
end

-- Questie-335 (optional, used only when it is loaded): its database knows the level of quests not taken yet.
-- The quest id is found from the title and the quest giver (QuestieDB.GetQuestIDFromName), the level comes from
-- QuestieLib.GetEffectiveQuestLevel. These are Questie's own functions, not WoW APIs: everything is protected.
local function FindQuestieLevel(title)
    if not (QuestieLoader and QuestieCompat and IsAddOnLoaded("Questie-335")) then
        return nil
    end
    local ok, level = pcall(function()
        local QuestieDB = QuestieLoader:ImportModule("QuestieDB");
        local QuestieLib = QuestieLoader:ImportModule("QuestieLib");
        local guid = QuestieCompat.UnitGUID("npc") or QuestieCompat.UnitGUID("questnpc");
        local questId = QuestieDB.GetQuestIDFromName(title, guid, true);
        if questId and questId > 0 then
            return (QuestieLib.GetEffectiveQuestLevel(questId))
        end
    end);
    if ok and type(level) == "number" and level > 0 then
        return level
    end
end

local function FindQuestLevel(title)
    if not title or title == "" then
        return nil
    end
    for i = 1, GetNumQuestLogEntries() do
        local name, level, _, _, isHeader = GetQuestLogTitle(i);
        if name == title and not isHeader and level and level > 0 then
            return level
        end
    end
    return levelByTitle[title] or FindQuestieLevel(title)
end

-- Header pill text of the quest details page (Settings > Quest Difficulty), coloured like the quest list:
-- Level "36 Quest", Name "Quest - Very Hard", Both "36 Quest - Very Hard". Off, or no known level: the type alone.
-- Brown theme: plain text, the level and difficulty share the font and colour of the Quest label.
-- Dark theme: coloured like the quest list.
function GossipDataProvider:FormatHeaderType(typeText, title)
    local style = GetDifficultyStyle();
    local level = style ~= 0 and FindQuestLevel(title) or nil;
    if not level then
        return typeText
    end
    local hex;
    if addon.ThemeUtil:IsDarkMode() then
        hex = GetLevelColor(level - (UnitLevel("player") or level));
    end
    local function Paint(s)
        return hex and format("|cff%s%s|r", hex, s) or s
    end
    local text = typeText;
    if (style % 2) == 1 then
        text = format("%s %s", Paint(level), text);
    end
    local label = style >= 2 and GetDifficultyLabel({level = level}) or nil;     -- nil for Normal, as in the list
    if label then
        text = format("%s - %s", text, Paint(label));
    end
    return text
end

-- Quest icons (converted BLPs in Textures/Icons). Frequency values as wow-docs: 1 normal, 2 daily, 3 weekly.
local ICON_AVAILABLE = ICON_PATH .. "AvailableQuest.blp";
local ICON_DAILY = ICON_PATH .. "DailyQuest.blp";
local ICON_WEEKLY = ICON_PATH .. "WeeklyQuest.blp";
local ICON_REPEATABLE = ICON_PATH .. "RepeatableQuest.blp";
local ICON_COMPLETE = ICON_PATH .. "CompleteQuest.blp";
local ApplyQuestVisual;     -- below; GossipDataProvider:RefreshQuestText needs it
local ICON_INCOMPLETE = ICON_PATH .. "IncompleteQuest.blp";

function ApplyQuestVisual(row)
    if row.kind == "active" then
        row.icon = row.complete and ICON_COMPLETE or ICON_INCOMPLETE;
        row.art = row.complete and 1 or 4;
    else
        if row.weekly then
            row.icon = ICON_WEEKLY;
        elseif row.daily then
            row.icon = ICON_DAILY;
        elseif row.repeatable then
            row.icon = ICON_REPEATABLE;
        else
            row.icon = ICON_AVAILABLE;
        end
        row.art = (row.weekly or row.daily or row.repeatable) and 2 or 1;
    end

    -- Right-hand note (retail SetQuestTypeText): difficulty name (style Name), else Trivial, else Repeatable
    -- (not for daily / weekly).
    row.note = nil;
    local style = GetDifficultyStyle();
    local difficultyLabel = (style == 2 or style == 3) and GetDifficultyLabel(row) or nil;
    if difficultyLabel then
        row.note = difficultyLabel;
    elseif row.trivial then
        row.note = L["Quest Type Trivial"];
    elseif row.repeatable and not (row.daily or row.weekly) then
        row.note = L["Quest Type Repeatable"];
    end
    row.text = FormatQuestTitle(row);
end

-- Settings > Quest Difficulty changed with a list page open: rebuild the level prefix and the right-hand note of
-- the stored quest rows (the page's rows are kept, only text and note change).
function GossipDataProvider:RefreshQuestText(page)
    if not (page and page.rows) then
        return
    end
    for _, row in ipairs(page.rows) do
        if row.kind == "available" or row.kind == "active" then
            ApplyQuestVisual(row);
        end
    end
end

-- Gossip option icons by the 3.3.5a type string. A nil entry falls back to the plain gossip icon.
-- Client icons are used where no converted BLP exists yet.
-- Keys are lower case: wow-docs lists the types capitalised ("Vendor"), the client may send them lower case.
local ICON_BY_TYPE = {
    gossip = ICON_PATH .. "Gossip.blp",
    vendor = ICON_PATH .. "Buy.blp",
    trainer = ICON_PATH .. "Trainer.blp",
    binder = ICON_PATH .. "Innkeeper.blp",
    banker = ICON_PATH .. "Buy.blp",
    tabard = CLIENT_ICON_PATH .. "TabardGossipIcon",
    battlemaster = CLIENT_ICON_PATH .. "BattleMasterGossipIcon",
};

-- Flight points have one icon per faction. The NPC's own faction is used:
-- Alliance, Horde, otherwise neutral (UnitFactionGroup returns nil for neutral NPCs, unverified).
local TAXI_ICONS = {Alliance = "travelA.blp", Horde = "travelH.blp", neutral = "travelL.blp"};

local function GetTaxiIcon()
    local faction = UnitFactionGroup("npc");
    return ICON_PATH .. (TAXI_ICONS[faction] or TAXI_ICONS.neutral)
end

local ICON_STABLE = ICON_PATH .. "Stablemaster.blp";

-- AskDirection.blp must exist in Textures/Icons (converted from temp_png).
local ICON_DIRECTIONS = ICON_PATH .. "AskDirection.blp";

-- City guard "where is ...?" menu: these options are plain gossip, so only their text tells them apart.
-- Retail does the same with a text table (GossipData_Icon.lua, "Pin ..." entries). English texts only, lower case,
-- compared after stripping the leading "The ". The Minimap\Tracking files are client files, not in wow-docs:
-- check in game. Anything not listed keeps the plain gossip icon.
local TRACKING_PATH = "Interface\\Minimap\\Tracking\\";
local DIRECTION_ICONS = {
    ["auction house"] = TRACKING_PATH .. "Auctioneer",
    ["bank"] = TRACKING_PATH .. "Banker",
    ["mailbox"] = TRACKING_PATH .. "Mailbox",
    ["battlemaster"] = TRACKING_PATH .. "BattleMaster",
    ["inn"] = ICON_PATH .. "Innkeeper.blp",
    ["stable master"] = ICON_PATH .. "Stablemaster.blp",
    ["class trainer"] = ICON_PATH .. "Trainer.blp",
    ["weapons trainer"] = ICON_PATH .. "Trainer.blp",
    ["profession trainer"] = ICON_PATH .. "Mine.blp",

    -- Class trainer menu (one option per class). The retail-only classes (Demon Hunter, Monk, Evoker) are not used.
    ["death knight"] = ICON_PATH .. "CHDeathknight.blp",
    ["druid"] = ICON_PATH .. "CHDruid.blp",
    ["hunter"] = ICON_PATH .. "CHHunter.blp",
    ["mage"] = ICON_PATH .. "CHMage.blp",
    ["paladin"] = ICON_PATH .. "CHPaladin.blp",
    ["priest"] = ICON_PATH .. "CHPriest.blp",
    ["rogue"] = ICON_PATH .. "CHRogue.blp",
    ["shaman"] = ICON_PATH .. "CHShaman.blp",
    ["warlock"] = ICON_PATH .. "CHWarlock.blp",
    ["warrior"] = ICON_PATH .. "CHWarrior.blp",

    -- Profession trainer menu (one option per profession). First Aid uses the client's own spell icon
    -- (not in wow-docs: check in game).
    ["first aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["alchemy"] = ICON_PATH .. "Alchemy.blp",
    ["blacksmithing"] = ICON_PATH .. "Blacksmithing.blp",
    ["cooking"] = ICON_PATH .. "Cooking.blp",
    ["enchanting"] = ICON_PATH .. "Enchanting.blp",
    ["engineering"] = ICON_PATH .. "Engineering.blp",
    ["fishing"] = ICON_PATH .. "Fishing.blp",
    ["herbalism"] = ICON_PATH .. "Herbalism.blp",
    ["inscription"] = ICON_PATH .. "Inscription.blp",
    ["jewelcrafting"] = ICON_PATH .. "Jewelcrafting.blp",
    ["leatherworking"] = ICON_PATH .. "Leatherworking.blp",
    ["mining"] = ICON_PATH .. "Mining.blp",
    ["skinning"] = ICON_PATH .. "Skinning.blp",
    ["tailoring"] = ICON_PATH .. "Tailoring.blp",
};
-- Class icons are drawn bigger than the 14 px option icons.
local CLASS_ICON_SIZE = 20;
local CLASS_ICON_FILES = {};
for _, class in ipairs({"death knight", "druid", "hunter", "mage", "paladin", "priest", "rogue", "shaman", "warlock", "warrior"}) do
    CLASS_ICON_FILES[DIRECTION_ICONS[class]] = true;
end

-- Flight masters get the faction flight icon, as on the flight master's own page.
local DIRECTION_FLIGHT = {
    ["flight master"] = true, ["hippogryph master"] = true, ["gryphon master"] = true,
    ["wind rider master"] = true, ["bat handler"] = true,
};

local function GetDirectionIcon(lowered)
    local key = string.gsub(lowered, "^the ", "");
    key = string.gsub(key, "[%.%?!]+$", "");
    if DIRECTION_FLIGHT[key] then
        return GetTaxiIcon()
    end
    return DIRECTION_ICONS[key]
end

local function GetOptionIcon(text, gossipType)
    local kind = gossipType and lower(gossipType) or "gossip";
    if kind == "taxi" then
        return GetTaxiIcon()
    end
    local lowered = text and lower(text) or "";
    -- Text matches work on the English client only: there is no option ID in 3.3.5a.
    if find(lowered, "stable", 1, true) then
        return ICON_STABLE
    elseif find(lowered, "direction", 1, true) then
        return ICON_DIRECTIONS
    end
    if kind == "gossip" then
        local icon = GetDirectionIcon(lowered);
        if icon then
            return icon
        end
    end
    return ICON_BY_TYPE[kind] or ICON_BY_TYPE.gossip
end

-- Quest log lookup by title: tells whether a quest the player has is complete (the gossip lists do not).
local function FindLogEntry(title)
    if not title or title == "" then return end
    for i = 1, GetNumQuestLogEntries() do
        local name, _, _, _, isHeader, _, isComplete, isDaily = GetQuestLogTitle(i);
        if name == title and not isHeader then
            return isComplete, isDaily
        end
    end
end

-- Complete first, then available, then in progress; each group in game order (retail SortFunc_PrioritizeCompleteQuest).
local function SortQuests(a, b)
    if a.complete ~= b.complete then
        return a.complete
    elseif (a.kind == "available") ~= (b.kind == "available") then
        return a.kind == "available"
    end
    return a.order < b.order
end

local function DebugDump(event, ...)
    if addon.GetDBBool("DebugGossip") then
        local count = select("#", ...);
        local parts = {};
        for i = 1, count do
            parts[i] = tostring((select(i, ...)));
        end
        print("DialogueUI_335 " .. event .. " (" .. count .. " values): " .. table.concat(parts, ", "));
    end
end

-- Reads the lists the gossip window gives: values come in repeating groups, the group size is derived from the count.
local function Pack(...)
    return select("#", ...), {...}      -- # is unreliable with nil holes (isTrivial is nil for normal quests)
end

local function ReadGossipQuests(quests)
    local numAvailable = GetNumGossipAvailableQuests() or 0;
    local availableCount, available = Pack(GetGossipAvailableQuests());
    DebugDump("GetGossipAvailableQuests", GetGossipAvailableQuests());
    local stride = numAvailable > 0 and (availableCount / numAvailable) or 3;
    for i = 1, numAvailable do
        local base = (i - 1) * stride;
        quests[#quests + 1] = {
            kind = "available", index = i, order = #quests + 1, complete = false,
            title = available[base + 1], level = available[base + 2], trivial = available[base + 3] and true or false,
            select = SelectGossipAvailableQuest,
        };
    end

    local numActive = GetNumGossipActiveQuests() or 0;
    local activeCount, active = Pack(GetGossipActiveQuests());
    DebugDump("GetGossipActiveQuests", GetGossipActiveQuests());
    stride = numActive > 0 and (activeCount / numActive) or 3;
    for i = 1, numActive do
        local base = (i - 1) * stride;
        local title = active[base + 1];
        local logComplete = FindLogEntry(title);
        -- A 4th value per active quest is read as "is complete" when the client sends one (UNVERIFIED: wow-docs
        -- lists 3 values; check with DebugGossip). The quest log answers when the title matches.
        local listComplete = stride >= 4 and active[base + 4] and active[base + 4] ~= 0;
        quests[#quests + 1] = {
            kind = "active", index = i, order = #quests + 1, complete = (logComplete == 1) or (listComplete and true or false),
            title = title, level = active[base + 2], trivial = active[base + 3] and true or false,
            select = SelectGossipActiveQuest,
        };
    end
    RememberLevels(quests);
end

-- QUEST_GREETING lists: separate getters per field.
local function ReadGreetingQuests(quests)
    for i = 1, GetNumAvailableQuests() or 0 do
        local isTrivial, frequency, isRepeatable = GetAvailableQuestInfo(i);
        quests[#quests + 1] = {
            kind = "available", index = i, order = #quests + 1, complete = false,
            title = GetAvailableTitle(i), level = GetAvailableLevel(i),
            trivial = isTrivial and true or false,
            daily = frequency == 2, weekly = frequency == 3,
            repeatable = isRepeatable and true or false,
            select = SelectAvailableQuest,
        };
    end
    for i = 1, GetNumActiveQuests() or 0 do
        local title = GetActiveTitle(i);
        local isComplete = FindLogEntry(title);
        -- Greeting window: GetActiveTitle may also return isComplete (UNVERIFIED, docs list the title only).
        local _, titleComplete = GetActiveTitle(i);
        if titleComplete and titleComplete ~= 0 then
            isComplete = 1;
        end
        quests[#quests + 1] = {
            kind = "active", index = i, order = #quests + 1, complete = isComplete == 1,
            title = title, level = GetActiveLevel(i),
            trivial = IsActiveQuestTrivial(i) and true or false,
            select = SelectActiveQuest,
        };
    end
    RememberLevels(quests);
end

-- Red option text (retail: <Skip Chapter> style options) is made legible on parchment and gets the red icon.
-- ThemeUtil:AdjustTextColor does the replacement (red on Brown, blue on Dark, as retail). Textures/Icons/Gossip-Red.blp.
local ICON_RED = ICON_PATH .. "Gossip-Red.blp";

local function AdjustRedText(text)
    return addon.ThemeUtil:AdjustTextColor(text)
end

-- "The auction house" -> "The Auction House": menu entries come from the server in sentence case. Whole sentences
-- (ending in . ? ! or ...) are left alone, and so is text with colour codes or non-ASCII letters (other languages).
local function TitleCase(text)
    if string.find(text, "[|\128-\255]") or string.find(text, "[%.%?!]%s*$") then
        return text
    end
    return (string.gsub(text, "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end))
end

local function ReadOptions()
    local options = {};
    local raw = {GetGossipOptions()};
    DebugDump("GetGossipOptions", GetGossipOptions());
    for i = 1, GetNumGossipOptions() or 0 do
        local text, gossipType = raw[2 * i - 1], raw[2 * i];
        local adjusted, isRed = AdjustRedText(text or "");
        adjusted = TitleCase(adjusted);
        local icon = isRed and ICON_RED or GetOptionIcon(text, gossipType);
        options[#options + 1] = {
            kind = "option", index = i, text = adjusted, optionType = gossipType,
            icon = icon, iconSize = CLASS_ICON_FILES[icon] and CLASS_ICON_SIZE or nil, art = 0,
            select = function(index) SelectGossipOption(index) end,
        };
    end
    return options
end

-- Orders the rows and sets the gap above each one. Returns the row list.
local function BuildRows(quests, options)
    sort(quests, SortQuests);
    for _, quest in ipairs(quests) do
        ApplyQuestVisual(quest);
    end

    local anyNewOrComplete = false;
    for _, quest in ipairs(quests) do
        if quest.kind == "available" or quest.complete then
            anyNewOrComplete = true;
            break
        end
    end
    local optionsFirst = not anyNewOrComplete;

    local rows = {};
    local function AddOptions(gapFirst)
        for i, option in ipairs(options) do
            option.gap = i == 1 and gapFirst or "none";
            rows[#rows + 1] = option;
        end
    end

    if optionsFirst then
        AddOptions("paragraph");
    end
    local last;
    for _, quest in ipairs(quests) do
        if not last then
            quest.gap = "section";
        elseif last.kind ~= quest.kind or last.complete ~= quest.complete then
            quest.gap = "section";
        else
            quest.gap = "tight";
        end
        last = quest;
        rows[#rows + 1] = quest;
    end
    if not optionsFirst then
        AddOptions(#quests > 0 and "section" or "paragraph");
    end

    for i, row in ipairs(rows) do
        if i <= 9 then
            row.keySlot = i;        -- Option 1-9 of Settings > Control (the key itself is looked up when the row is laid out)
        end
    end
    return rows
end

-- event: "GOSSIP_SHOW" or "QUEST_GREETING". Returns {body, rows}.
function GossipDataProvider:Read(event)
    local quests, options = {}, {};
    local body;
    if event == "QUEST_GREETING" then
        body = GetGreetingText();
        ReadGreetingQuests(quests);
    else
        body = GetGossipText();
        ReadGossipQuests(quests);
        options = ReadOptions();
    end
    return {body = body, rows = BuildRows(quests, options), isList = true}
end
