local _, addon = ...;

-- Finds which item (bag slot) the player is reading, and reads extra lines for the book header:
-- the item's flavor text, the sender of a Plain Letter, and the player's location for world objects.
--
-- 3.3.5a does not give the item ID of the readable: ItemTextGetItem returns only the name, and UnitGUID("npc")
-- is not documented for readables. So the bag slot comes from two sources:
--   1. a hook on UseContainerItem (right click in the bags), checked within 3 seconds,
--   2. a scan of the bags for a readable item with the same name.
-- A readable that is not in the bags (a book on the ground, a plaque) is treated as a world object.

local BookItem = {};
addon.BookItem = BookItem;

local TooltipScan = addon.TooltipScan;

local match = string.match;
local format = string.format;
local GetTime = GetTime;
local GetContainerItemLink = GetContainerItemLink;
local GetContainerItemInfo = GetContainerItemInfo;
local GetContainerNumSlots = GetContainerNumSlots;
local GetItemInfo = GetItemInfo;

local PLAIN_LETTER_ID = 8383;
local LAST_USE_WINDOW = 3;          -- seconds a right click counts as "the book that was just opened"
local NUM_BAGS = 4;                 -- bag IDs 0 (backpack) to 4

local lastBag, lastSlot, lastTime;

local function RememberUse(bag, slot)
    lastBag, lastSlot, lastTime = bag, slot, GetTime();
end

-- UseContainerItem is the call behind a right click on a bag slot (hooksecurefunc is in wow-docs).
if hooksecurefunc and UseContainerItem then
    hooksecurefunc("UseContainerItem", RememberUse);
end

local function GetSlotItem(bag, slot, title)
    local link = GetContainerItemLink(bag, slot);
    if not link then
        return
    end
    local name = GetItemInfo(link);
    if name and name == title then
        return link
    end
end

-- Returns {bag, slot, link, itemID} or nil when the readable is not an item from the bags.
function BookItem:Resolve(title)
    if not title or title == "" then
        return
    end

    if lastBag and (GetTime() - lastTime) <= LAST_USE_WINDOW then
        local link = GetSlotItem(lastBag, lastSlot, title);
        if link then
            return { bag = lastBag, slot = lastSlot, link = link, itemID = tonumber(match(link, "item:(%d+)")) };
        end
    end

    for bag = 0, NUM_BAGS do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local _, _, _, _, readable = GetContainerItemInfo(bag, slot);
            if readable then
                local link = GetSlotItem(bag, slot, title);
                if link then
                    return { bag = bag, slot = slot, link = link, itemID = tonumber(match(link, "item:(%d+)")) };
                end
            end
        end
    end
end

-- The quoted flavor line at the bottom of the item tooltip ("..."), and the item's icon.
-- Returns icon, text or nil.
function BookItem:GetDescription(info)
    if not (info and info.bag) then
        return
    end
    local lines = TooltipScan:ScanBagItem(info.bag, info.slot);
    for i = #lines, 2, -1 do
        local text = lines[i].left;
        if text and match(text, "^\"") then
            local icon = select(10, GetItemInfo(info.link));
            return icon, text
        end
    end
end

-- Plain Letter: the white second line of the tooltip names the sender (as retail's QueryLetterSender).
-- UNVERIFIED in 3.3.5a: the tooltip layout of this item was not checked in game.
function BookItem:GetLetterSender(info)
    if not (info and info.itemID == PLAIN_LETTER_ID) then
        return
    end
    local lines = TooltipScan:ScanBagItem(info.bag, info.slot);
    local line = lines[2];
    if line and line.left and line.lr and line.lr > 0.99 and line.lg > 0.99 and line.lb > 0.99 then
        return line.left
    end
end

-- "Zone  x, y" for books and plaques standing in the world.
-- SetMapToCurrentZone changes the world map, so it is skipped while the map is open.
function BookItem:GetLocation()
    local worldMap = _G.WorldMapFrame;      -- FrameXML frame, not in wow-docs
    if not (worldMap and worldMap:IsShown()) then
        SetMapToCurrentZone();
    end
    local zone = GetRealZoneText();
    if not zone or zone == "" then
        zone = GetZoneText();
    end
    local x, y = GetPlayerMapPosition("player");
    if x and y and (x > 0 or y > 0) then
        return format("%s  %.0f, %.0f", zone or "", x * 100, y * 100)
    end
    return zone
end
