local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local MainFrame = LootUI.MainFrame;
local After = addon.API.After;

-- /lootui test [seconds]          the notification ("You Received"): items arrive, a stack grows, money rolls up
-- /lootui test manual [seconds]   the loot window of the game with fake slots (click a row, or Take All)
-- seconds: the frame stays up that long, then fades out. Without it the frame stays until closed.
-- /lootui test all [seconds]      a big loot window with every kind of row: each quality, quest, mount, pet, locked,
--                                 stacks, junk, money
-- /lootui test close                closes it
-- Nothing here touches the real loot API. Item names and icons come from the item cache when it has them.

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark";

-- {itemID, quantity, forced quality or nil, name fallback, mount}
local ITEMS = {
    {49623, 1, nil, "Shadowmourne"},
    {44151, 1, nil, "Reins of the Blue Proto-Drake", true},
    {36908, 2, nil, "Frost Lotus"},
    {33470, 14, nil, "Frostweave Cloth"},
    {2589, 5, 0, "Linen Cloth"},
    {2592, 3, 0, "Wool Cloth"},
    {36912, 7, nil, "Saronite Ore"},
    {36910, 4, nil, "Titanium Ore"},
    {35623, 2, nil, "Eternal Air"},
    {35624, 3, nil, "Eternal Earth"},
    {36903, 5, nil, "Adder's Tongue"},
    {36860, 1, nil, "Eternal Fire"},
    {41163, 2, nil, "Titansteel Bar"},
};

-- {itemID, quantity, forced quality, name, kind, icon}
-- kind: "mount", "pet", "quest", "locked" (red icon); icon: shown when the item is not in the cache yet.
-- Quality is forced so every row looks the same whether or not the game knows the item.
local ALL_ITEMS = {
    {49623, 1, 5, "Shadowmourne (legendary)", nil, "Interface\\Icons\\INV_Axe_113"},
    {42943, 1, 7, "Bloodied Arcanite Reaper (heirloom)", nil, "Interface\\Icons\\INV_Axe_09"},
    {50274, 1, 4, "Shadowfrost Shard (epic)", nil, "Interface\\Icons\\INV_Misc_Gem_Ruby_03"},
    {40395, 1, 4, "Torch of Holy Fire (epic)", nil, "Interface\\Icons\\INV_Mace_28"},
    {37665, 1, 3, "Rare Item (rare)", nil, "Interface\\Icons\\INV_Jewelry_Ring_53"},
    {37663, 1, 3, "Another Rare Item (rare)", nil, "Interface\\Icons\\INV_Chest_Plate10"},
    {36908, 2, 2, "Frost Lotus (uncommon)", nil, "Interface\\Icons\\INV_Misc_Herb_FrostLotus"},
    {33470, 14, 1, "Frostweave Cloth (common)", nil, "Interface\\Icons\\INV_Fabric_Frostweave"},
    {44151, 1, 4, "Reins of the Blue Proto-Drake (mount)", "mount", "Interface\\Icons\\Ability_Mount_Drake_Blue"},
    {44738, 1, 3, "Kirin Tor Familiar (pet)", "pet", "Interface\\Icons\\INV_Misc_Orb_02"},
    {1, 1, 1, "Quest Item: Sealed Letter", "quest", "Interface\\Icons\\INV_Letter_15"},
    {2, 8, 1, "Quest Item: Scourge Insignia", "quest", "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"},
    {3, 1, 3, "Quest Item (rare quality): Ancient Tablet", "quest", "Interface\\Icons\\INV_Misc_Book_09"},
    {4, 1, 3, "Locked Item (cannot loot yet)", "locked", "Interface\\Icons\\INV_Misc_Key_14"},
    {2589, 5, 0, "Linen Cloth (poor)", nil, "Interface\\Icons\\INV_Fabric_Linen_01"},
    {2592, 3, 0, "Wool Cloth (poor)", nil, "Interface\\Icons\\INV_Fabric_Wool_01"},
    {36912, 7, 1, "Saronite Ore (stack)", nil, "Interface\\Icons\\INV_Ore_Saronite_01"},
    {41163, 20, 2, "Titansteel Bar (stack of 20)", nil, "Interface\\Icons\\INV_Ingot_Titansteel_blue"},
};

local function MakeItem(entry, slotIndex)
    local id, quantity, forcedQuality, fallbackName, kind, fallbackIcon = unpack(entry);
    local isMount = kind == "mount";
    local name, link, quality, _, _, _, subType, _, equipSlot, icon = GetItemInfo(id);
    return {
        slotType = Def.SLOT_TYPE_ITEM,
        slotIndex = slotIndex,
        id = id,
        icon = icon or fallbackIcon or FALLBACK_ICON,
        name = (kind and fallbackName) or name or fallbackName,
        quantity = quantity,
        quality = forcedQuality or quality or 3,
        link = link or ("item:" .. id),
        subType = (isMount and _G.MOUNT) or (kind == "pet" and _G.COMPANION_PETS) or subType,
        isQuest = kind == "quest" or nil,
        locked = kind == "locked" or nil,
        hideCount = equipSlot ~= nil and equipSlot ~= "",
        looted = false,
        test = true,
    }
end

local function MakeMoney(copper, slotIndex)
    return {
        slotType = Def.SLOT_TYPE_MONEY,
        slotIndex = slotIndex,
        copper = copper,
        quantity = copper,
        name = addon.MoneyUtil:GetShortText(copper),
        quality = 1,
        looted = false,
        test = true,
    }
end

local function EnsureReady()
    if MainFrame.Init then
        MainFrame:Init();
    end
    LootUI.forceEnabled = true;
end

-- seconds: how long the frame stays up, then it fades out. nil: it stays until it is closed
-- (right click, the close button, Esc in the manual window, or /lootui test close).
local testToken = 0;

local function HoldFor(seconds)
    testToken = testToken + 1;
    local token = testToken;
    LootUI.testHoldTime = 99999;            -- no auto hide while the test runs
    if seconds then
        After(seconds, function()
            if token == testToken then
                LootUI.testHoldTime = nil;
                MainFrame:CloseFromClick();
            end
        end);
    end
    return token
end

local function CloseTest()
    testToken = testToken + 1;
    LootUI.testHoldTime = nil;
    if not MainFrame.Init then
        MainFrame:CloseFromClick();
    end
end

local function TestNotification(seconds)
    EnsureReady();
    local token = HoldFor(seconds);
    MainFrame.errorMode = nil;
    LootUI.QueueDisplayLoot(MakeItem(ITEMS[1], 0));
    LootUI.QueueDisplayLoot(MakeItem(ITEMS[3], 0));
    LootUI.QueueDisplayLoot(MakeMoney(123456, 0));
    LootUI.QueueDisplayLoot(MakeItem(ITEMS[5], 0));
    LootUI.QueueDisplayLoot(MakeItem(ITEMS[6], 0));
    -- More than one page of rows (MAX_ITEM_PER_PAGE), so the page dots show.
    for i = 8, #ITEMS do
        LootUI.QueueDisplayLoot(MakeItem(ITEMS[i], 0));
    end

    -- Same item again: the row's count animates, money rolls up.
    After(1.5, function()
        if token ~= testToken then return end
        LootUI.QueueDisplayLoot(MakeItem(ITEMS[3], 0));
        LootUI.QueueDisplayLoot(MakeMoney(5050, 0));
    end);
    -- A mount, glowing; it makes the list a longer one.
    After(2.5, function()
        if token ~= testToken then return end
        LootUI.QueueDisplayLoot(MakeItem(ITEMS[2], 0));
        LootUI.QueueDisplayLoot(MakeItem(ITEMS[4], 0));
        LootUI.QueueDisplayLoot(MakeItem(ITEMS[7], 0));
    end);
end

local function TestManual(seconds)
    EnsureReady();
    HoldFor(seconds);
    local list = {};
    list[1] = MakeMoney(98765, -1);
    for i, entry in ipairs(ITEMS) do
        list[#list + 1] = MakeItem(entry, -(i + 1));
    end
    table.sort(list, LootUI.SortFunc_LootSlot);
    MainFrame.errorMode = nil;
    MainFrame:DisplayPendingLoot(list);
end

local function TestAll(seconds)
    EnsureReady();
    HoldFor(seconds);
    local list = {};
    list[1] = MakeMoney(1234567, -1);
    for i, entry in ipairs(ALL_ITEMS) do
        list[#list + 1] = MakeItem(entry, -(i + 1));
    end
    table.sort(list, LootUI.SortFunc_LootSlot);
    MainFrame.errorMode = nil;
    MainFrame:DisplayPendingLoot(list);
end

SLASH_DUILOOTUI1 = "/lootui";
SlashCmdList["DUILOOTUI"] = function(message)
    local command, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$");
    command = string.lower(command or "");
    if command == "test" and string.lower(rest) == "close" then
        CloseTest();
    elseif command == "test" then
        local manual = string.find(string.lower(rest), "manual", 1, true) ~= nil;
        local seconds = tonumber(string.match(rest, "(%d+%.?%d*)"));
        if seconds and seconds <= 0 then
            seconds = nil;
        end
        if string.find(string.lower(rest), "all", 1, true) then
            TestAll(seconds);
        elseif manual then
            TestManual(seconds);
        else
            TestNotification(seconds);
        end
    else
        addon.API.PrintMessage("/lootui test [seconds]  |  /lootui test manual [seconds]  |  /lootui test all [seconds]");
    end
end
