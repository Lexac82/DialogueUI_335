local _, addon = ...;

-- Optional support for private-server transmog modules: is the appearance of an item collected yet?
-- Two sources, one interface (Get / Request / "TransmogStatusChanged"):
--
-- 1. Original mod-transmog (setting ShowTransmogStatus, UseTransmogPlus off). The only thing it offers a client is the
--    player command ".transmog sync", which prints "TRANSMOG_SYNC:<itemId>" system lines, one per collected item.
--    We send it once, collect the IDs, and hide those lines from chat. An item of a transmogrifiable slot that is not in
--    the set counts as "uncollected". The set holds exact item IDs, so an item whose look is known through another
--    item with the same model still shows as uncollected (the server's own check does not use the look either).
--
-- 2. mod-transmog-plus (UseTransmogPlus on). Protocol of its client addon (wow-mod-transmog-plus, collection_tooltips.lua):
--      we send   SendAddonMessage("transmog", "GetCollectionStatus:<itemId>", "WHISPER", <own name>)
--      server replies the same way (a whisper from ourselves to ourselves), prefix "transmog":
--        "CollectionStatus:<itemId>:<state>"   state 0 = uncollected, 1 = collected, 2 = not eligible
--        "CollectionUpdated:<itemId>"          a new appearance was learned: every cached result may be stale
--
-- On a server without the matching module nobody answers, so nothing is shown.
local CallbackRegistry = addon.CallbackRegistry;
local GetDBBool = addon.GetDBBool;

local CreateFrame = CreateFrame;
local SendAddonMessage = SendAddonMessage;
local SendChatMessage = SendChatMessage;
local GetItemInfo = GetItemInfo;
local GetTime = GetTime;
local UnitName = UnitName;
local tonumber = tonumber;
local match = string.match;
local find = string.find;

local PREFIX = "transmog";
local STATE_BY_NUMBER = {[0] = "uncollected", [1] = "collected", [2] = "ineligible"};

local SYNC_COMMAND = ".transmog sync";
local SYNC_TIMEOUT = 10;                   -- seconds without an answer (or without the next line) before giving up
local RESYNC_DELAY = 2;                    -- after equipping or a "learned" message, so the server has stored it

-- Slots that never count for transmog: the ones the original module excludes (Transmogrification::CanNeverTransmog)
-- plus necks, which have no look of their own. Anything else that can be equipped counts as eligible; the server's
-- own configuration may exclude more.
local NEVER_TRANSMOG_SLOTS = {
    INVTYPE_BAG = true,
    INVTYPE_RELIC = true,
    INVTYPE_NECK = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_AMMO = true,
    INVTYPE_QUIVER = true,
};

local TransmogStatus = {};
addon.TransmogStatus = TransmogStatus;

---------------------------------------------------------------------------
-- Source 2: mod-transmog-plus (addon messages)
---------------------------------------------------------------------------

local statusByItem = {};
local pendingByItem = {};

local function ClearPlusCache()
    statusByItem = {};
    pendingByItem = {};
end

local function RequestPlus(itemID)
    if statusByItem[itemID] or pendingByItem[itemID] then
        return
    end
    pendingByItem[itemID] = true;
    SendAddonMessage(PREFIX, "GetCollectionStatus:" .. itemID, "WHISPER", UnitName("player"));
end

-- Listeners get the item ID, or nil when everything may have changed.
local function OnPlusMessage(message)
    local itemID, number = match(message, "^CollectionStatus:(%d+):(%d+)$");
    if itemID then
        itemID = tonumber(itemID);
        local state = STATE_BY_NUMBER[tonumber(number)];
        if state then
            pendingByItem[itemID] = nil;
            statusByItem[itemID] = state;
            CallbackRegistry:Trigger("TransmogStatusChanged", itemID);
        end
        return
    end

    itemID = match(message, "^CollectionUpdated:(%d+)$");
    if itemID then
        -- One new look counts for every item that shares its model, so forget all results.
        ClearPlusCache();
        statusByItem[tonumber(itemID)] = "collected";
        CallbackRegistry:Trigger("TransmogStatusChanged");
    end
    -- Anything else is our own request coming back: a whisper to ourselves is also an event for ourselves.
end

---------------------------------------------------------------------------
-- Source 1: original mod-transmog (.transmog sync)
---------------------------------------------------------------------------

local syncState = "idle";                  -- "idle", "waiting" (sent, no line yet), "receiving"
local syncSet = nil;                       -- item IDs of the last finished sync; nil until the first one
local syncNew;                             -- the set being collected
local syncSawBegin;                        -- the module's "Performing ... sync" line has come
local syncDeadline = 0;
local syncFinishedAt = 0;
local syncGaveUp = false;                  -- no answer to .transmog sync: do not ask again this session
local resyncAt;                            -- time of a planned sync (equipment changed, appearance learned)
-- The module's own begin / complete texts are localized, so they are learned from the first sync and hidden
-- from the next one on.
local syncTexts = {};

local timerFrame = CreateFrame("Frame");

local function Tick()
    local now = GetTime();
    if syncState ~= "idle" and now >= syncDeadline then
        syncState = "idle";
        if syncNew and next(syncNew) then
            -- The complete line did not come, but items did: use them.
            syncSet = syncNew;
            syncFinishedAt = now;
            CallbackRegistry:Trigger("TransmogStatusChanged");
        else
            syncGaveUp = true;              -- server without the module (or the command is off)
        end
    end
    if resyncAt and syncState == "idle" and now >= resyncAt then
        resyncAt = nil;
        TransmogStatus:StartSync();
    end
    if syncState == "idle" and not resyncAt then
        timerFrame:SetScript("OnUpdate", nil);
    end
end

local function ArmTimer()
    timerFrame:SetScript("OnUpdate", Tick);
end

function TransmogStatus:StartSync()
    if syncState ~= "idle" then
        return
    end
    syncState = "waiting";
    syncNew = {};
    syncSawBegin = false;
    syncDeadline = GetTime() + SYNC_TIMEOUT;
    ArmTimer();
    SendChatMessage(SYNC_COMMAND, "SAY");
end

local function FinishSync()
    syncSet = syncNew;
    syncState = "idle";
    syncFinishedAt = GetTime();
    CallbackRegistry:Trigger("TransmogStatusChanged");
end

local function PlanResync()
    if syncSet and not syncGaveUp then
        resyncAt = GetTime() + RESYNC_DELAY;
        ArmTimer();
    end
end

-- Called once per system message (event handler). Keeps the sync state.
local function OnSystemMessage(message)
    if not message then
        return
    end
    if syncState == "idle" then
        -- "<item link> added to your appearance collection": the set is out of date.
        if not TransmogStatus:IsPlus() and TransmogStatus:IsEnabled() and find(message, "|Hitem:", 1, true) then
            PlanResync();
        end
        return
    end

    local itemID = match(message, "^TRANSMOG_SYNC:(%d+)$");
    if itemID then
        syncNew[tonumber(itemID)] = true;
        syncState = "receiving";
        syncDeadline = GetTime() + SYNC_TIMEOUT;
    elseif syncState == "waiting" and not syncSawBegin then
        syncSawBegin = true;
        syncTexts[message] = true;
        syncDeadline = GetTime() + SYNC_TIMEOUT;
    else
        syncTexts[message] = true;
        FinishSync();
    end
end

-- Chat filter: runs once per chat frame, so it must not depend on the order of events. The sync lines are always
-- hidden; the module's own begin / complete texts only during and right after a sync we started.
local function SystemFilter(_, _, message)
    if message then
        if match(message, "^TRANSMOG_SYNC:%d+$") then
            return true
        end
        if syncTexts[message] and (syncState ~= "idle" or GetTime() - syncFinishedAt < 0.5) then
            return true
        end
    end
    return false
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter);

local function GetSyncStatus(itemID)
    if not syncSet then
        return nil
    end
    local equipSlot = select(9, GetItemInfo(itemID));
    if not equipSlot then
        return nil                          -- not cached yet
    end
    if equipSlot == "" or NEVER_TRANSMOG_SLOTS[equipSlot] then
        return "ineligible"
    end
    return syncSet[itemID] and "collected" or "uncollected"
end

---------------------------------------------------------------------------
-- Public interface
---------------------------------------------------------------------------

function TransmogStatus:IsEnabled()
    return GetDBBool("ShowTransmogStatus")
end

-- true: the server runs mod-transmog-plus (own protocol); false: the original module (.transmog sync).
function TransmogStatus:IsPlus()
    return GetDBBool("UseTransmogPlus")
end

function TransmogStatus:GetItemID(link)
    return link and tonumber(match(link, "item:(%d+)"))
end

-- "uncollected", "collected", "ineligible", or nil while unknown (or the setting is off).
function TransmogStatus:Get(itemID)
    if not itemID or not self:IsEnabled() then
        return nil
    end
    if self:IsPlus() then
        return statusByItem[itemID]
    end
    return GetSyncStatus(itemID)
end

function TransmogStatus:IsUncollected(itemID)
    return self:Get(itemID) == "uncollected"
end

function TransmogStatus:Request(itemID)
    if not itemID or not self:IsEnabled() then
        return
    end
    if self:IsPlus() then
        RequestPlus(itemID);
    elseif not syncSet and not syncGaveUp then
        self:StartSync();                   -- one sync answers for every item
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame");
frame:RegisterEvent("CHAT_MSG_ADDON");
frame:RegisterEvent("CHAT_MSG_SYSTEM");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_ADDON" then
        -- Only the server's reply counts: it comes as a whisper from ourselves. Other players can send
        -- this prefix on any channel, or whisper it under their own name.
        if arg1 == PREFIX and arg3 == "WHISPER" and arg4 == UnitName("player") and arg2 then
            OnPlusMessage(arg2);
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(arg1);
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Equipping adds the appearance to the collection.
        ClearPlusCache();
        if not TransmogStatus:IsPlus() and TransmogStatus:IsEnabled() then
            PlanResync();
        end
    else
        -- The sync set survives a loading screen; plus answers are asked again.
        ClearPlusCache();
    end
end);

local function SettingsChanged()
    ClearPlusCache();
    CallbackRegistry:Trigger("TransmogStatusChanged");
end
CallbackRegistry:Register("SettingChanged.ShowTransmogStatus", SettingsChanged);
CallbackRegistry:Register("SettingChanged.UseTransmogPlus", SettingsChanged);
