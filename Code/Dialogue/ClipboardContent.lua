local _, addon = ...;

-- Plain text of the open page for the Copy Text window. Port of retail's GetContentForClipboard, with what
-- 3.3.5a knows: no quest ID in the dialogue (it is found in the quest log by title, so a quest that has not been
-- accepted yet has none), no gossip option IDs, item IDs from the item links.
-- event: GOSSIP_SHOW, QUEST_GREETING, QUEST_DETAIL, QUEST_PROGRESS or QUEST_COMPLETE. page: the table the page was read into.
local L = addon.L;

local ClipboardContent = {};
addon.ClipboardContent = ClipboardContent;

local gsub = string.gsub;
local match = string.match;
local sub = string.sub;
local tonumber = tonumber;
local concat = table.concat;

-- Colors and hyperlinks would show up as raw |c...|r and |H...|h codes in the edit box.
local function Strip(text)
    if not text then
        return ""
    end
    text = gsub(text, "|c%x%x%x%x%x%x%x%x", "");
    text = gsub(text, "|r", "");
    text = gsub(text, "|H.-|h(.-)|h", "%1");
    text = gsub(text, "|T.-|t", "");
    return text
end

-- NPC ID from the GUID. Since 3.3.0 the creature ID is the four hex digits before the last 8 (docs: Hogger
-- 0xF13001C0000005D2 -> 0x1C0). Only creature (F13) and vehicle (F15) GUIDs carry one.
local function GetNPCID(guid)
    if not guid then
        return
    end
    local kind = sub(guid, 1, 5);
    if kind == "0xF13" or kind == "0xF15" then
        return tonumber(sub(guid, -12, -9), 16)
    end
end

local function FindQuestID(title)
    if not title or title == "" then
        return
    end
    for i = 1, GetNumQuestLogEntries() do
        local name, _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i);
        if not isHeader and name == title and questID and questID ~= 0 then
            return questID
        end
    end
end

local function QuestLine(title)
    local questID = FindQuestID(title);
    if questID then
        return "[Quest: " .. questID .. "] " .. title
    end
    return "[Quest] " .. title
end

local function ItemLine(item)
    local itemID = item.link and match(item.link, "item:(%d+)");
    local text = (itemID and ("[ItemID: " .. itemID .. "] ") or "") .. (item.name or "");
    if item.count and item.count > 1 then
        text = text .. " x" .. item.count;
    end
    return text
end

local function AmountLine(label, amount)
    return label .. ": " .. amount
end

-- One reward entry (QuestData ReadRewards) as one line.
local function RewardLine(entry)
    local kind = entry.kind;
    if kind == "item" then
        return ItemLine(entry)
    elseif kind == "xp" then
        return AmountLine(L["Experience"], entry.amount)
    elseif kind == "money" then
        return AmountLine(L["Money"], GetCoinText(entry.amount))
    elseif kind == "honor" then
        return AmountLine(L["Honor Points"], entry.amount)
    elseif kind == "talents" then
        return AmountLine(L["Talent Points"], entry.amount)
    elseif kind == "arena" then
        return AmountLine(L["Arena Points"], entry.amount)
    elseif kind == "title" then
        return AmountLine(L["Title"], entry.name or "")
    elseif kind == "spell" then
        return "[Spell] " .. (entry.name or "")
    end
end

local function AddRewards(lines, page)
    local rewards, choices = page.rewards, page.choices;
    if rewards and #rewards > 0 then
        lines[#lines + 1] = "";
        lines[#lines + 1] = L["Rewards"];
        lines[#lines + 1] = "";
        for _, entry in ipairs(rewards) do
            lines[#lines + 1] = RewardLine(entry);
        end
    end
    if choices and #choices > 0 then
        lines[#lines + 1] = "";
        lines[#lines + 1] = page.canChoose and L["Reward Choose"] or L["Reward Choices"];
        lines[#lines + 1] = "";
        for _, entry in ipairs(choices) do
            lines[#lines + 1] = ItemLine(entry);
        end
    end
end

local function AddRequirements(lines, page)
    local items, money = page.required, page.moneyToGet;
    if (items and #items > 0) or money then
        lines[#lines + 1] = "";
        lines[#lines + 1] = L["Requirements"];
        lines[#lines + 1] = "";
        if money then
            lines[#lines + 1] = GetCoinText(money);
        end
        for _, item in ipairs(items or {}) do
            lines[#lines + 1] = ItemLine(item);
        end
    end
end

local function AddRows(lines, rows)
    if not rows or #rows == 0 then
        return
    end
    lines[#lines + 1] = "";
    for _, row in ipairs(rows) do
        if row.kind == "option" then
            local tag = "[Option]";
            local kind = row.optionType and string.lower(row.optionType);
            if kind and kind ~= "" and kind ~= "gossip" then
                tag = "[Option: " .. kind .. "]";
            end
            lines[#lines + 1] = tag .. " " .. (row.text or "");
        else
            lines[#lines + 1] = QuestLine(row.title);
        end
    end
end

-- Returns the text, or nil when there is nothing to copy (no page open).
function ClipboardContent:Build(event, page)
    if not (event and page) then
        return
    end

    local lines = {};
    local npcName = UnitName("npc");
    local npcID = GetNPCID(UnitGUID("npc"));
    if npcName then
        lines[#lines + 1] = npcID and ("[NPC: " .. npcID .. "] " .. npcName) or ("[NPC] " .. npcName);
    end

    if page.isList then
        lines[#lines + 1] = page.body or "";
        AddRows(lines, page.rows);
    else
        if page.title and page.title ~= "" then
            lines[#lines + 1] = QuestLine(page.title);
        end
        lines[#lines + 1] = "";
        lines[#lines + 1] = page.body or "";
        if page.objective and page.objective ~= "" then
            lines[#lines + 1] = "";
            lines[#lines + 1] = L["Quest Objectives"];
            lines[#lines + 1] = "";
            lines[#lines + 1] = page.objective;
        end
        if event == "QUEST_PROGRESS" then
            AddRequirements(lines, page);
        else
            AddRewards(lines, page);
        end
    end

    return Strip(concat(lines, "\n"))
end
