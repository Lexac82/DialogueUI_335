local _, addon = ...;

-- Lays out the reward, cost and requirement rows under the quest text, and handles hover,
-- selection and clicks. Port of retail's FormatRewards (DialogueUI.lua 3082-3206),
-- HighlightRewardChoice / SelectRewardChoice (2149-2214) and RequestSellPrice (2257-2300).
local ThemeUtil = addon.ThemeUtil;
local NineSlice = addon.NineSlice;
local FrameSize = addon.FrameSize;

local CreateFrame = CreateFrame;
local GetItemInfo = GetItemInfo;
local IsModifiedClick = IsModifiedClick;
local IsDressableItem = IsDressableItem;
local ResetCursor = ResetCursor;
local SetCursor = SetCursor;
local floor = math.floor;
local max = math.max;

local GAP = 8;                            -- ITEM_BUTTON_SPACING, at frame size multiplier 1
local CHOICE_COLUMNS = 2;
local DIM_ALPHA = 0.25;
local PRICE_RETRY_DELAY = 0.8;

local HIGHLIGHT_FRONT = "RewardChoice-Highlight.blp";
local HIGHLIGHT_BACK = "RewardChoice-Highlight-Back.blp";

local L = addon.L;
local GetDBBool = addon.GetDBBool;

local RewardLayout = {};
RewardLayout.__index = RewardLayout;

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------

function RewardLayout:AcquireBig()
    local count = self.bigCount + 1;
    self.bigCount = count;
    local button = self.bigPool[count];
    if not button then
        button = addon.CreateRewardItemButton(self.host.ContentFrame, self);
        self.bigPool[count] = button;
    end
    button.isChoice = false;
    return button
end

function RewardLayout:AcquireSmall()
    local count = self.smallCount + 1;
    self.smallCount = count;
    local button = self.smallPool[count];
    if not button then
        button = addon.CreateRewardSmallButton(self.host.ContentFrame, self);
        self.smallPool[count] = button;
    end
    return button
end

function RewardLayout:ReleaseAll()
    self:HideHighlight();
    self.timerFrame:SetScript("OnUpdate", nil);
    for i = 1, self.bigCount do
        local button = self.bigPool[i];
        button:Release();
        button.frame:SetScript("OnEvent", nil);
        button.frame:UnregisterEvent("MODIFIER_STATE_CHANGED");
        button:SetStyle(1);
        button:SetSellMarker(false);
    end
    for i = 1, self.smallCount do
        self.smallPool[i]:Release();
    end
    self.bigCount = 0;
    self.smallCount = 0;
    self.choiceButtons = {};
    self.chosen = nil;
    self.page = nil;
    self.upgradeRetried = false;
    self.upgradeTimer:SetScript("OnUpdate", nil);
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

-- Places buttons left to right, wrapping at the text width. Small rows and big buttons never share a row.
-- Returns the offset below the last row.
function RewardLayout:PlaceRows(offsetY, entries, itemWidth, gridWidth)
    local host = self.host;
    local textWidth = host.textWidth;
    local gap = FrameSize:Scale(GAP);
    local cursorX, rowY, rowHeight, lastSmall = 0, offsetY, 0, nil;
    local items = host.revealItems;

    for i = 1, #entries do
        local entry = entries[i];
        local small = entry.small and true or false;
        local button, width;

        if small then
            button = self:AcquireSmall();
            button:SetEntry(entry);
            width = button:FitWidth(gridWidth);
        else
            button = self:AcquireBig();
            button:SetEntry(entry);
            width = button:Fit(itemWidth, gridWidth + gap, 2);
        end

        if cursorX > 0 and (lastSmall ~= small or cursorX + width > textWidth + 0.5) then
            rowY = rowY + rowHeight + gap;
            cursorX = 0;
            rowHeight = 0;
        end

        local frame = button.frame;
        frame:ClearAllPoints();
        frame:SetPoint("TOPLEFT", host.ContentFrame, "TOPLEFT", cursorX, -rowY);
        frame:Show();
        items[#items + 1] = {region = frame, length = 0};

        if not small then
            -- Hover, modifier cursor.
            frame:SetScript("OnEvent", function()
                self:UpdateCursor(button);
            end);
        end

        cursorX = cursorX + width + gap;
        rowHeight = max(rowHeight, frame:GetHeight());
        lastSmall = small;
    end

    return rowY + rowHeight
end

-- The choice group: 2 columns of fixed-width buttons.
function RewardLayout:PlaceChoices(offsetY, choices, itemWidth)
    local host = self.host;
    local items = host.revealItems;
    local rows = 0;
    local gap = FrameSize:Scale(GAP);
    local height = 0;                   -- the same for every big button

    for i = 1, #choices do
        local entry = choices[i];
        local button = self:AcquireBig();
        button.isChoice = true;
        button:SetEntry(entry);
        button:SetStyle(self.page.canChoose and 2 or 1);
        button:SetWidth(itemWidth);

        local column = (i - 1) % CHOICE_COLUMNS;
        local row = floor((i - 1) / CHOICE_COLUMNS);
        rows = max(rows, row + 1);

        local frame = button.frame;
        frame:ClearAllPoints();
        height = frame:GetHeight();
        frame:SetPoint("TOPLEFT", host.ContentFrame, "TOPLEFT", column * (itemWidth + gap),
            -(offsetY + row * (height + gap)));
        frame:Show();
        items[#items + 1] = {region = frame, length = 0};

        frame:SetScript("OnEvent", function()
            self:UpdateCursor(button);
        end);

        self.choiceButtons[#self.choiceButtons + 1] = button;
    end

    return offsetY + rows * (height + gap) - gap
end

-- Adds the costs, requirements and rewards below `offsetY`. Returns the new offset.
function RewardLayout:Layout(offsetY, page)
    self:ReleaseAll();
    self.page = page;

    local host = self.host;
    local spacing = host.paragraphSpacing;
    local gap = FrameSize:Scale(GAP);
    local gridWidth = floor((host.textWidth - 3 * gap) / 4);    -- retail quarterFrameWidth
    local itemWidth = 2 * gridWidth + gap;

    if page.moneyToGet then
        offsetY = offsetY + spacing;
        offsetY = host:InsertSubHeader(offsetY, "Costs");
        offsetY = self:PlaceRows(offsetY, {{kind = "requiredMoney", amount = page.moneyToGet, small = true}}, itemWidth, gridWidth);
    end

    if page.required and #page.required > 0 then
        offsetY = offsetY + spacing;
        offsetY = host:InsertSubHeader(offsetY, "Requirements");
        offsetY = self:PlaceRows(offsetY, page.required, itemWidth, gridWidth);
    end

    local rewards = page.rewards or {};
    local choices = page.choices or {};
    if #rewards > 0 or #choices > 0 then
        offsetY = offsetY + spacing;
        local entryCount = #rewards + (#choices > 0 and 1 or 0);
        offsetY = host:InsertSubHeader(offsetY, entryCount == 1 and L["Reward"] or L["Rewards"]);

        if #choices > 0 then
            local header = page.canChoose and L["Reward Choose"] or L["Reward Choices"];
            offsetY = host:FormatParagraph(offsetY, header) + gap;
            offsetY = self:PlaceChoices(offsetY, choices, itemWidth);
            if #rewards > 0 then
                offsetY = offsetY + spacing;
                offsetY = host:FormatParagraph(offsetY, L["Reward Items"]) + gap;
            end
        end

        if #rewards > 0 then
            offsetY = self:PlaceRows(offsetY, rewards, itemWidth, gridWidth);
        end
    end

    self:UpdateSellMarker();
    self:UpdateUpgradeMarkers();

    -- Load every item's data now, so the tooltip is complete the moment the player hovers.
    local entries = {};
    for _, list in ipairs({page.required or {}, choices, rewards}) do
        for i = 1, #list do
            entries[#entries + 1] = list[i];
        end
    end
    addon.RewardTooltip:Prefetch(entries);

    return offsetY
end

---------------------------------------------------------------------------
-- Highest sell price marker
---------------------------------------------------------------------------

function RewardLayout:UpdateSellMarker()
    local buttons = self.choiceButtons;
    if not self.page or not self.page.canChoose or #buttons < 2 then
        return
    end
    for i = 1, #buttons do
        buttons[i]:SetSellMarker(false);
    end
    if not GetDBBool("MarkHighestSellPrice") then
        return
    end

    -- As retail RequestSellPrice: unit price (stack count ignored); a choice with no price
    -- (not cached yet, or unsellable) means no marker, after one more try later.
    local best, bestPrice, missing = nil, 0, false;
    for i = 1, #buttons do
        local entry = buttons[i].entry;
        local price = entry.link and select(11, GetItemInfo(entry.link));
        if not price or price == 0 then
            missing = true;
        elseif price > bestPrice then
            best, bestPrice = buttons[i], price;
        end
    end
    if best and not missing then
        best:SetSellMarker(true);
    end

    -- Items not in the cache yet report no price: ask once more later.
    if missing and not self.priceRetried then
        self.priceRetried = true;
        local elapsed = 0;
        local page = self.page;
        self.timerFrame:SetScript("OnUpdate", function(frame, dt)
            elapsed = elapsed + dt;
            if elapsed >= PRICE_RETRY_DELAY then
                frame:SetScript("OnUpdate", nil);
                if self.page == page then
                    self:UpdateSellMarker();
                end
            end
        end);
    elseif not missing then
        self.priceRetried = false;
    end
end

---------------------------------------------------------------------------
-- Upgrade arrow
---------------------------------------------------------------------------

-- Retail RequestItemUpgrade: an item not in the cache gives no item level, so ask once more later.
function RewardLayout:UpdateUpgradeMarkers()
    local page = self.page;
    if not page then
        return
    end

    local enabled = GetDBBool("ShowUpgradeArrow");
    local animate = page.canChoose;
    local missing = false;

    for i = 1, self.bigCount do
        local button = self.bigPool[i];
        local entry = button.entry;
        local show = false;
        if enabled and entry and entry.kind == "item" and entry.itemType ~= "required" and entry.isUsable and entry.link then
            local isUpgrade, isReady = addon.TooltipCompare:IsUpgrade(entry.link);
            if entry.testUpgrade then
                show = true;                -- /dialogui test forces the arrow
            elseif isReady then
                show = isUpgrade;
            else
                missing = true;
            end
        end
        button:SetUpgradeMarker(show, animate);
    end

    if missing and not self.upgradeRetried then
        self.upgradeRetried = true;
        local elapsed = 0;
        self.upgradeTimer:SetScript("OnUpdate", function(frame, dt)
            elapsed = elapsed + dt;
            if elapsed >= PRICE_RETRY_DELAY then
                frame:SetScript("OnUpdate", nil);
                if self.page == page then
                    self:UpdateUpgradeMarkers();
                end
            end
        end);
    end
end

---------------------------------------------------------------------------
-- Hover highlight and selection
---------------------------------------------------------------------------

function RewardLayout:GetHighlight()
    if not self.highlight then
        local frame = CreateFrame("Frame", nil, self.host.ContentFrame);
        frame:Hide();
        -- Back: red glow, ADD blend, only while nothing is chosen. Front: the gold outline.
        local back = NineSlice:Create(frame, ThemeUtil:GetTextureFile(HIGHLIGHT_BACK), {256, 64}, 16, 16, "ARTWORK");
        NineSlice:SetBlendMode(back, "ADD");
        NineSlice:SetVertexColor(back, 0.65, 0, 0);
        local front = NineSlice:Create(frame, ThemeUtil:GetTextureFile(HIGHLIGHT_FRONT), {256, 64}, 16, 16, "OVERLAY");
        frame.back = back;
        frame.front = front;
        self.highlight = frame;
    end
    return self.highlight
end

function RewardLayout:ShowHighlight(button)
    local frame = self:GetHighlight();
    frame:SetParent(button.frame);
    frame:ClearAllPoints();
    frame:SetAllPoints(button.frame);
    frame:SetFrameLevel(button.frame:GetFrameLevel() + 3);
    NineSlice:SetShown(frame.back, self.chosen == nil);
    frame:Show();
end

function RewardLayout:HideHighlight()
    if self.highlight then
        self.highlight:Hide();
    end
end

function RewardLayout:SelectChoice(button)
    self.chosen = button;
    for i = 1, #self.choiceButtons do
        local other = self.choiceButtons[i];
        other:SetStyle(1);
        other:FadeTo(other == button and 1 or DIM_ALPHA);
    end
    NineSlice:SetShown(self:GetHighlight().back, false);
    addon.RewardTooltip:Hide();
    if self.onChoiceChanged then
        self.onChoiceChanged(button.entry.index);
    end
end

-- Settings > Control > Press Tab To Select Reward (retail CycleRewardChoice): the next (delta 1) or previous (-1)
-- choosable reward, wrapping around. Nothing chosen yet: Tab picks the first one. Returns true when it did something.
function RewardLayout:CycleChoice(delta)
    local buttons = self.choiceButtons;
    if not (self.page and self.page.canChoose) or #buttons == 0 then
        return false
    end
    local current = 0;
    for i = 1, #buttons do
        if buttons[i] == self.chosen then
            current = i;
        end
    end
    local id = current + delta;
    if id > #buttons then
        id = 1;
    elseif id < 1 then
        id = #buttons;
    end
    self:SelectChoice(buttons[id]);
    return true
end

-- 1-based choice index passed to GetQuestReward, 0 when there is no choice to make, nil while undecided.
function RewardLayout:GetChoiceIndex()
    local page = self.page;
    if not page or not page.canChoose then
        return 0
    end
    return self.chosen and self.chosen.entry.index or nil
end

-- Sheen on every choice: tells the player a reward must be chosen first (retail FlashRewardChoices).
function RewardLayout:FlashChoices()
    for i = 1, #self.choiceButtons do
        self.choiceButtons[i]:PlaySheen();
    end
end

---------------------------------------------------------------------------
-- Button callbacks
---------------------------------------------------------------------------

-- Ctrl (dress-up modifier) over a dressable item shows the inspect cursor.
function RewardLayout:UpdateCursor(button)
    local entry = button.entry;
    if entry and entry.link and IsModifiedClick("DRESSUP") and IsDressableItem(entry.link) then
        if _G.ShowInspectCursor then
            _G.ShowInspectCursor();
        else
            SetCursor("INSPECT_CURSOR");
        end
    else
        ResetCursor();
    end
end

local NO_TOOLTIP = { money = true, requiredMoney = true };

function RewardLayout:OnButtonEnter(button)
    local entry = button.entry;
    if not entry then
        return
    end
    if button.isChoice and self.page and self.page.canChoose then
        self:ShowHighlight(button);
    end
    if not NO_TOOLTIP[entry.kind] then
        addon.RewardTooltip:Show(button.frame, button.icon or button.frame, entry);
    end
    if button.isChoice or entry.kind == "item" then
        button.frame:RegisterEvent("MODIFIER_STATE_CHANGED");
        self:UpdateCursor(button);
    end
end

function RewardLayout:OnButtonLeave(button)
    self:HideHighlight();
    addon.RewardTooltip:Hide();
    button.frame:UnregisterEvent("MODIFIER_STATE_CHANGED");
    ResetCursor();
end

function RewardLayout:OnButtonClick(button, mouseButton)
    local entry = button.entry;
    if not entry then
        return
    end

    if mouseButton == "RightButton" and addon.GetDBBool("RightClickToCloseUI") then
        self.host.owner:RequestClose();         -- Settings > Control > Right Click To Close UI
        return
    end

    if entry.link and IsModifiedClick("CHATLINK") then
        local insertLink = _G.ChatEdit_InsertLink;          -- FrameXML, not in wow-docs (UNVERIFIED)
        if insertLink then
            insertLink(entry.link);
        end
        return
    end
    if entry.link and IsModifiedClick("DRESSUP") then
        local dressUp = _G.DressUpItemLink;                  -- FrameXML, not in wow-docs (UNVERIFIED)
        if dressUp then
            dressUp(entry.link);
        end
        return
    end

    if mouseButton == "LeftButton" and button.isChoice and self.page and self.page.canChoose then
        self:SelectChoice(button);
    end
end

-- host: QuestTextLayout.
local function CreateRewardLayout(host)
    local self = setmetatable({}, RewardLayout);
    self.host = host;
    self.bigPool, self.smallPool = {}, {};
    self.bigCount, self.smallCount = 0, 0;
    self.choiceButtons = {};
    self.timerFrame = CreateFrame("Frame", nil, host.ContentFrame);
    self.upgradeTimer = CreateFrame("Frame", nil, host.ContentFrame);
    -- Turning the option on or off with a page open applies at once (no redraw, a reward choice stays).
    addon.CallbackRegistry:Register("SettingChanged.ShowUpgradeArrow", function()
        self:UpdateUpgradeMarkers();
    end);
    addon.CallbackRegistry:Register("SettingChanged.MarkHighestSellPrice", function()
        self:UpdateSellMarker();
    end);
    return self
end

addon.CreateRewardLayout = CreateRewardLayout;
