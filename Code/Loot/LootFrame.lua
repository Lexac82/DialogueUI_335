local _, addon = ...;
local LootUI = addon.LootUI;
local Def = LootUI.Def;
local L = addon.L;

local CreateFrame = CreateFrame;
local InCombatLockdown = InCombatLockdown;
local tremove = table.remove;
local ipairs = ipairs;
local min = math.min;
local max = math.max;
local ceil = math.ceil;

-- The loot window. Two modes, as Plumber's:
--   manual mode        the loot window of the game: rows are clickable, Take All and Close are shown.
--   notification mode  auto loot: a "You Received" list that fades in and out by itself.
-- The window has no art of its own: the background (GenericFrame-Tiled-Large) hangs from it and animates its size.
local MainFrame = CreateFrame("Frame", "DialogueUI335LootFrame", addon.UIRoot);
LootUI.MainFrame = MainFrame;
MainFrame:Hide();
MainFrame:SetAlpha(0);

local P = Def.FRAME_PADDING;
local SPACING = Def.ROW_SPACING;
local AUTO_HIDE_DELAY = 3.0;        -- 2.0 s + FADE_DELAY_PER_ITEM per row
local FADE_SPEED = 8;               -- alpha per second, fade in
local FADE_OUT_SPEED = 4;           -- alpha per second, TryHide(true)


---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

function MainFrame:Init()
    self.Init = nil;

    self:UpdateFrameStrata();
    self:SetToplevel(true);
    self:SetClampedToScreen(true);
    self:EnableMouse(false);
    self.isUISpecialFrame = false;

    self.BackgroundFrame = LootUI.CreateBackground(self);
    self.BackgroundFrame:UpdatePixel();

    -- Pooled rows
    self.itemFramePool = LootUI.CreatePool(function()
        return LootUI.CreateItemFrame(self, self)
    end, function(row)
        row:Reset();
    end);
    self.dotPool = LootUI.CreatePool(function()
        return LootUI.CreateDot(self)
    end, function(dot)
        dot:Hide();
        dot:ClearAllPoints();
    end);

    self.Header = self:CreateFontString(nil, "OVERLAY");
    self.Header:SetFontObject(LootUI.GetFont("DUI335_LootHeader", 12, {"DarkModeGrey70", "DarkModeGrey70"}));
    self.Header:SetJustifyH("CENTER");
    self.Header:SetPoint("BOTTOM", self, "TOP", 0, Def.HEADER_GAP + 8);
    self.Header:SetText(L["You Received"]);
    self.Header:Hide();

    self.HeaderWidgetContainer = CreateFrame("Frame", nil, self);
    self.HeaderWidgetContainer:SetAllPoints(self);
    self.HeaderWidgetContainer:SetFrameLevel(self:GetFrameLevel() + 5);
    self.HeaderWidgetContainer:Hide();

    self.CloseButton = LootUI.CreateCloseButton(self.HeaderWidgetContainer, self);
    self.CloseButton:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, Def.HEADER_GAP + 6);
    self.TakeAllButton = LootUI.CreateTakeAllButton(self.HeaderWidgetContainer, self);
    self.TakeAllButton:SetPoint("RIGHT", self.CloseButton, "LEFT", -6, 0);

    self:SetScript("OnShow", self.OnShow);
    self:SetScript("OnHide", self.OnHide);
    self:SetScript("OnEnter", self.OnEnter);
    self:SetScript("OnLeave", self.OnLeave);
    self:SetScript("OnMouseUp", self.OnMouseUp);

    self:LoadPosition();
end


---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------

function MainFrame:LoadPosition()
    self:ClearAllPoints();
    local width = UIParent:GetWidth();
    -- Grow Upwards: the bottom left is the fixed corner, so the window gets taller towards the top.
    local point = addon.GetDBBool("LootUI_GrowUpwards") and "BOTTOMLEFT" or "TOPLEFT";
    -- Plumber's default: the left edge a third of the screen right of the centre line.
    self:SetPoint(point, UIParent, "CENTER", math.floor((0.5 - 0.3333) * width), 60);
end

-- Not while the window sits under the mouse (manual loot with Loot Under Mouse): that position is set per loot.
addon.CallbackRegistry:Register("SettingChanged.LootUI_GrowUpwards", function()
    if not (MainFrame.manualMode and Def.LOOT_UNDER_MOUSE) then
        MainFrame:LoadPosition();
    end
end);

-- Send to Back: the notification window (not the manual loot window, which must be usable) sits behind other UI.
function MainFrame:UpdateFrameStrata()
    if Def.LOW_FRAME_STRATA and not self.manualMode then
        self:SetFrameStrata("MEDIUM");
        self:Lower();
    else
        self:SetFrameStrata("DIALOG");
    end
end

addon.CallbackRegistry:Register("SettingChanged.LootUI_LowFrameStrata", function()
    if not MainFrame.Init then
        MainFrame:UpdateFrameStrata();
    end
end);

function MainFrame:PositionUnderMouse()
    local x, y = GetCursorPosition();
    local scale = self:GetEffectiveScale();
    x = x / scale - Def.ROW_WIDTH / 2;
    y = max(y / scale + 24, 350);
    self:ClearAllPoints();
    self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y);
    self:Raise();
end


---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

function MainFrame:ReleaseAll()
    if self.activeFrames then
        self.activeFrames = nil;
        self.itemFramePool:ReleaseAll();
        self:SetMaxPage(nil);
        self:SetClickedFrameIndex(nil);
    end
end

function MainFrame:AcquireItemFrame()
    return self.itemFramePool:Acquire()
end

function MainFrame:SetClickedFrameIndex(index)
    self.clickedFrameIndex = index;
end

function MainFrame:SetBottomFrameIndex(index)
    self.bottomFrameIndex = index;
end

local function RowsHeight(count)
    return count * Def.ROW_HEIGHT + (count - 1) * SPACING
end

-- Stacks the active rows and sizes the window. fixedWidth: manual mode keeps the full width.
function MainFrame:LayoutActiveFrames()
    local frames = self.activeFrames;
    if not frames or #frames == 0 then
        self:TryHide(true);
        return
    end

    for i, row in ipairs(frames) do
        row:ClearAllPoints();
        if i == 1 then
            row:SetPoint("TOPLEFT", self, "TOPLEFT", P, -P);
        else
            row:SetPoint("TOPLEFT", frames[i - 1], "BOTTOMLEFT", 0, -SPACING);
        end
        row.index = i;
    end

    self:SetBottomFrameIndex(#frames);

    -- The window fits the widest row; every row gets that width.
    local rowWidth = Def.ROW_MIN_WIDTH;
    for _, row in ipairs(frames) do
        rowWidth = max(rowWidth, row:GetDesiredWidth());
    end
    for _, row in ipairs(frames) do
        row:SetRowWidth(rowWidth);
    end
    self.rowWidth = rowWidth;

    local width = rowWidth + 2 * P;
    local height = RowsHeight(#frames) + 2 * P;
    self:SetWidth(width);
    self:SetHeight(height);
    self:SetBackgroundSize(width, height);
end

function MainFrame:SetBackgroundSize(width, height)
    if self:IsShown() and self:GetAlpha() > 0.05 and not LootUI.noFade then
        self.BackgroundFrame:AnimateSize(width, height);
    else
        self.BackgroundFrame:SetBackgroundSize(width, height);
    end
end

function MainFrame:SetBackgroundAlpha(alpha)
    self.BackgroundFrame:SetBackgroundAlpha(alpha);
    LootUI.UpdateTextOutline(alpha);
end

-- Opacity setting ("LootUI_BackgroundAlpha", Plumber's key): the background of the notification window.
addon.CallbackRegistry:Register("SettingChanged.LootUI_BackgroundAlpha", function(value)
    if type(value) ~= "number" then
        return
    end
    value = math.min(1, math.max(0, value));
    if value < 0.01 then
        value = 0;
    end
    Def.BG_OPACITY = value;
    if MainFrame.BackgroundFrame and not MainFrame.manualMode then
        MainFrame:SetBackgroundAlpha(value);
    end
end);

-- After clicks the bottom rows may be gone: the window shrinks to the last row that still has an item.
function MainFrame:UpdateBackgroundHeightAfterClicks()
    if not self.clickedFrameIndex then
        return
    end
    self:SetClickedFrameIndex(nil);
    if not (self.activeFrames and self.bottomFrameIndex and self.bottomFrameIndex > 0) then
        return
    end

    local bottom;
    for i = #self.activeFrames, 1, -1 do
        if self.activeFrames[i].hasItem then
            bottom = i;
            break
        end
    end
    if bottom and bottom ~= self.bottomFrameIndex then
        self:SetBottomFrameIndex(bottom);
        local height = RowsHeight(bottom) + 2 * P;
        self:SetHeight(height);
        self.BackgroundFrame:AnimateSize((self.rowWidth or Def.ROW_WIDTH) + 2 * P, height);
    end
end

-- Dots on the left for notifications that need more than one page. They only show progress.
function MainFrame:SetMaxPage(pages)
    self.dotPool:ReleaseAll();
    if pages and pages > 1 then
        local n = pages - 1;
        local size, gap = Def.DOT_SIZE, 0;
        local top = 0.5 * (n * (size + gap) - gap);
        for i = 1, n do
            local dot = self.dotPool:Acquire();
            dot:SetPoint("TOPRIGHT", self, "LEFT", -6, top - (i - 1) * (size + gap));
            dot:Show();
        end
    end
end

function MainFrame:GetFocusedItemFrame()
    if self.activeFrames then
        for _, row in ipairs(self.activeFrames) do
            if row:IsMouseOver() then
                return row
            end
        end
    end
end

-- The game cleared a slot (the item was taken): slide that row out.
function MainFrame:SetLootSlotCleared(slotIndex)
    if self.activeFrames then
        for _, row in ipairs(self.activeFrames) do
            if row.data and row.data.slotIndex == slotIndex and row.hasItem then
                row:EnableMouseScript(0);
                row:PlaySlideOutAnimation();
                row.hasItem = nil;
                self:UpdateBackgroundHeightAfterClicks();
                return true
            end
        end
    end
end


---------------------------------------------------------------------------
-- Show / hide
---------------------------------------------------------------------------

local function OnUpdate_FadeOut(self, elapsed)
    self.alpha = self.alpha - FADE_OUT_SPEED * elapsed;
    if self.alpha <= 0 then
        self.alpha = 0;
        self:SetScript("OnUpdate", nil);
        self:Hide();
    end
    self:SetAlpha(self.alpha);
end

local function OnUpdate_FadeOut_IfNotFocused(self, elapsed)
    if self.isFocused then
        return
    end
    self.t = self.t + elapsed;
    if self.t > 0.1 then
        self.t = 0;
        if not self:IsMouseOver() then
            self:TryHide(true);
        end
    end
end

-- forceHide: fade out now. Otherwise wait until the mouse is away.
function MainFrame:TryHide(forceHide)
    if forceHide and LootUI.noFade then
        -- The preview in the Settings (LootTest.lua): no fade out, the window is gone at once.
        self.isUpdatingPage = nil;
        self.alpha = 0;
        self:SetScript("OnUpdate", nil);
        self:SetAlpha(0);
        self:Hide();
    elseif forceHide then
        self.isUpdatingPage = nil;
        self.alpha = self:GetAlpha();
        self:SetScript("OnUpdate", OnUpdate_FadeOut);
    else
        self.t = 0;
        self:SetScript("OnUpdate", OnUpdate_FadeOut_IfNotFocused);
    end
end

function MainFrame:SetFocused(state)
    self.isFocused = state and true or false;
end

function MainFrame:OnShow()
    if self.manualMode then
        self.TakeAllButton:UpdateHotkey();
    end
end

function MainFrame:OnHide()
    if self.manualMode then
        CloseLoot();
    end
    self:ReleaseAll();
    self.isFocused = false;
    self.manualMode = nil;
    self.errorMode = nil;
    self.HeaderWidgetContainer:Hide();
    self:AddToUISpecialFrames(false);
end

function MainFrame:OnEnter()
    self:SetFocused(true);
end

function MainFrame:OnLeave()
    self:SetFocused(false);
end

function MainFrame:OnMouseUp(button)
    if button == "RightButton" then
        self:CloseFromClick();
    end
end

-- Right click or the close button: close the loot window of the game and fade out.
function MainFrame:CloseFromClick()
    CloseLoot();
    self:TryHide(true);
end

-- Esc closes the manual window: an override binding clicks the close button while the window is open (out of combat).
-- Documented replacement for FrameXML's UISpecialFrames, which is not in wow-docs. Kept under the old name.
function MainFrame:AddToUISpecialFrames(state)
    if state then
        if not InCombatLockdown() then
            SetOverrideBindingClick(self, true, "ESCAPE", self.CloseButton:GetName(), "LeftButton");
            self.isUISpecialFrame = true;
        end
    elseif self.isUISpecialFrame then
        ClearOverrideBindings(self);
        self.isUISpecialFrame = false;
    end
end

function MainFrame:IsInManualMode()
    return self.manualMode
end

function MainFrame:SetManualMode(state)
    state = state == true;
    if state or self.manualMode then
        self:ReleaseAll();
    end
    self.manualMode = state;
    self:UpdateFrameStrata();

    if state then
        self.Header:Hide();
        self.HeaderWidgetContainer:Show();
        self:SetBackgroundAlpha(1);             -- the opacity setting is for the notification window only
        self.isFocused = false;
        self:EnableMouse(true);
        if Def.LOOT_UNDER_MOUSE then
            self:PositionUnderMouse();
        end
    else
        self.Header:Show();
        self.HeaderWidgetContainer:Hide();
        self:SetBackgroundAlpha(Def.BG_OPACITY);
        self:EnableMouse(false);
        if Def.LOOT_UNDER_MOUSE then
            self:LoadPosition();
        end
    end
    self:AddToUISpecialFrames(state);
end


---------------------------------------------------------------------------
-- Notification mode (auto loot): items that were received
---------------------------------------------------------------------------

local function MergeData(d1, d2)
    if d1 and d2 and d1.slotType == d2.slotType then
        if d1.slotType == Def.SLOT_TYPE_MONEY then
            d1.quantity = (d1.quantity or 0) + (d2.quantity or 0);
            d1.copper = (d1.copper or 0) + (d2.copper or 0);
            return true
        elseif d1.slotType == Def.SLOT_TYPE_CURRENCY then
            if d1.id == d2.id then
                d1.quantity = d1.quantity + d2.quantity;
                return true
            end
        elseif d1.slotType == Def.SLOT_TYPE_ITEM then
            if d1.id == d2.id and not d1.mergedData and not d2.mergedData then
                d1.quantity = d1.quantity + d2.quantity;
                return true
            elseif Def.MERGE_SIMILAR_ITEMS then
                return LootUI.MergeSimilarItems(d1, d2)
            end
        end
    end
    return false
end

local function OnUpdate_FadeIn(self, elapsed)
    self.alpha = self.alpha + FADE_SPEED * elapsed;
    if self.alpha >= 1 then
        self.alpha = 1;
        self:SetScript("OnUpdate", nil);
    end
    self:SetAlpha(self.alpha);
end

local function OnUpdate_FadeIn_All_ThenHide(self, elapsed)
    if self.alpha < 1 then
        self.alpha = min(1, self.alpha + FADE_SPEED * elapsed);
        self:SetAlpha(self.alpha);
    end
    if self.isFocused then
        self.t = 0;
        return
    end
    self.t = self.t + elapsed;
    if self.t >= AUTO_HIDE_DELAY then
        self.t = 0;
        self:SetScript("OnUpdate", nil);
        self:DisplayNextPage();
    end
end

local function OnUpdate_FadeOut_ThenDisplayNextPage(self, elapsed)
    if self.isFocused then
        return
    end
    self.anyAlphaChange = nil;
    for _, row in ipairs(self.activeFrames or {}) do
        if row.toAlpha then
            self.anyAlphaChange = true;
            row.alpha = row.alpha - FADE_SPEED * elapsed;
            if row.alpha <= 0 then
                row.alpha = 0;
                row.toAlpha = nil;
            end
            row:SetAlpha(row.alpha);
        end
    end
    if not self.anyAlphaChange then
        self.isUpdatingPage = nil;
        self:SetScript("OnUpdate", nil);
        self:ReleaseAll();
        self:DisplayLootResult();
    end
end

-- Rows were added while the window is already up: they fade in one by one.
local function OnUpdate_FadeIn_Individual(self, elapsed)
    self.anyAlphaChange = nil;
    for _, row in ipairs(self.activeFrames or {}) do
        if row.toAlpha then
            self.anyAlphaChange = true;
            row.alpha = row.alpha + FADE_SPEED * elapsed;
            if row.alpha >= 1 then
                row.alpha = 1;
                row.toAlpha = nil;
            end
            row:SetAlpha(row.alpha);
        end
    end
    if self.alpha < 1 then
        self.alpha = min(1, self.alpha + FADE_SPEED * elapsed);
        self:SetAlpha(self.alpha);
    end
    if not (self.anyAlphaChange or self.alpha < 1) then
        if self.isFocused then
            self.t = 0;
            return
        end
        self.t = self.t + elapsed;
        if self.t >= AUTO_HIDE_DELAY then
            self.t = 0;
            self:SetScript("OnUpdate", nil);
            self:DisplayNextPage();
        end
    end
end

-- "You Received" above the notification window; Hide "You Received" Text ("LootUI_HideTitle") leaves it empty.
function MainFrame:UpdateHeaderText()
    if addon.GetDBBool("LootUI_HideTitle") then
        self.Header:SetText("");
    else
        self.Header:SetText(L["You Received"]);
    end
end

addon.CallbackRegistry:Register("SettingChanged.LootUI_HideTitle", function()
    if not MainFrame.Init then
        MainFrame:UpdateHeaderText();
    end
end);

-- Takes the queued items and shows them (merged by item, up to MAX_ITEM_PER_PAGE per page).
function MainFrame:DisplayLootResult()
    local queue = LootUI.GetLootQueue();
    if not queue then
        self:TryHide();
        return
    end

    self:SetManualMode(false);

    -- Merge the queue
    local i = 1;
    while queue[i] do
        local j = i + 1;
        while queue[j] do
            if MergeData(queue[i], queue[j]) then
                tremove(queue, j);
            else
                j = j + 1;
            end
        end
        i = i + 1;
    end

    -- Rows already on screen take the new data of the same item (the count animates).
    local numExisting = self.activeFrames and #self.activeFrames or 0;
    local updateExisting = false;
    if numExisting > 0 then
        local k = 1;
        while queue[k] do
            local found;
            for _, row in ipairs(self.activeFrames) do
                if row:IsSameItem(queue[k]) then
                    found = row;
                    break
                end
            end
            if found then
                found:SetData(queue[k]);
                updateExisting = true;
                tremove(queue, k);
            else
                k = k + 1;
            end
        end
    end

    local numTotal = #queue + numExisting;
    self:SetMaxPage(ceil(numTotal / Def.MAX_ITEM_PER_PAGE));

    -- Switching pages: wait, unless something on screen changed.
    if self.isUpdatingPage and not updateExisting then
        return
    end

    table.sort(queue, LootUI.SortFunc_LootSlot);

    self.alpha = self:GetAlpha();
    local fadeIndividual = self:IsShown() and self.alpha > 0.25 and not LootUI.noFade;

    local thisPage;
    if numTotal > Def.MAX_ITEM_PER_PAGE then
        thisPage = {};
        for n = 1, Def.MAX_ITEM_PER_PAGE - numExisting do
            thisPage[n] = tremove(queue, 1);
        end
    else
        thisPage = queue;
        LootUI.WipeLootQueue();
    end

    local enableState = Def.AUTO_LOOT_ENABLE_TOOLTIP and 2 or 0;
    for _, data in ipairs(thisPage) do
        local row = self:AcquireItemFrame();
        row:SetData(data);
        self.activeFrames = self.activeFrames or {};
        self.activeFrames[#self.activeFrames + 1] = row;
        row:EnableMouseScript(enableState);
        row.hasItem = true;
        row:Show();
    end

    local numFrames = self.activeFrames and #self.activeFrames or 0;
    if numFrames == 0 then
        self:TryHide(true);
        return
    end

    AUTO_HIDE_DELAY = LootUI.testHoldTime or (2.0 + numFrames * Def.FADE_DELAY_PER_ITEM);
    self:UpdateHeaderText();

    self:LayoutActiveFrames();
    self.t = 0;

    if fadeIndividual then
        self.anyAlphaChange = true;
        for n = 1, numExisting do
            self.activeFrames[n].alpha = self.activeFrames[n]:GetAlpha();
        end
        for n = numExisting + 1, numFrames do
            local row = self.activeFrames[n];
            row.alpha = 0;
            row.toAlpha = 1;
            row:SetAlpha(0);
        end
        self:SetScript("OnUpdate", OnUpdate_FadeIn_Individual);
    else
        self:SetScript("OnUpdate", OnUpdate_FadeIn_All_ThenHide);
        self:Show();
        self.anyAlphaChange = nil;
        for _, row in ipairs(self.activeFrames) do
            row.toAlpha = nil;
            row.alpha = 1;
            row:SetAlpha(1);
        end
        -- The preview in the Settings (LootTest.lua): no fade in, the window appears at once.
        self.alpha = LootUI.noFade and 1 or 0;
        self:SetAlpha(self.alpha);
    end
end

function MainFrame:DisplayNextPage()
    local queue = LootUI.GetLootQueue();
    if queue and #queue > 0 then
        self.anyAlphaChange = true;
        self.isUpdatingPage = true;
        for _, row in ipairs(self.activeFrames or {}) do
            row.toAlpha = 0;
            row.alpha = row:GetAlpha();
        end
        self:SetScript("OnUpdate", OnUpdate_FadeOut_ThenDisplayNextPage);
        return true
    end
    self:TryHide();
    return false
end


---------------------------------------------------------------------------
-- Manual mode: the loot window of the game
---------------------------------------------------------------------------

function MainFrame:DisplayPendingLoot(list)
    list = list or LootUI.GetSortedLootList();
    if not list then
        return
    end
    self:SetManualMode(true);

    local frames = {};
    self.activeFrames = frames;
    for i, data in ipairs(list) do
        local row = self:AcquireItemFrame();
        row:SetData(data);
        frames[i] = row;
        row:SetAlpha(1);
        row.toAlpha = nil;
        row:EnableMouseScript(1);
        row.hasItem = true;
        row:Show();
    end

    self:LayoutActiveFrames();
    self.alpha = self:GetAlpha();
    self:SetScript("OnUpdate", OnUpdate_FadeIn);
    self:Show();
end

-- LOOT_CLOSED: the rows stop reacting and the window fades out.
function MainFrame:ClosePendingLoot()
    if not self:IsShown() then
        return
    end
    self.isUpdatingPage = nil;
    self.alpha = self:GetAlpha();
    for _, row in ipairs(self.activeFrames or {}) do
        row:EnableMouseScript(0);
    end
    self:EnableMouse(false);
    self.manualMode = false;            -- the game's window is already closed: do not CloseLoot again
    self:SetScript("OnUpdate", OnUpdate_FadeOut);
end

-- After the fade-in, the rows that were looted slide out, then the ones that failed come up again.
local function OnUpdate_FadeIn_ThenHideLootedFrames(self, elapsed)
    self.alpha = min(1, self.alpha + FADE_SPEED * elapsed);
    self:SetAlpha(self.alpha);
    if self.alpha < 1 then
        self.t = 0;
        return
    end
    self.t = self.t + elapsed;
    if self.t > 0.5 then
        self.t = 0;
        self:SetScript("OnUpdate", nil);
        for i, row in ipairs(self.lootedFrames or {}) do
            row:PlaySlideOutAnimation((i - 1) * 0.1);
        end
        self.lootedFrames = nil;
        if self.lootErrorCallback then
            local callback = self.lootErrorCallback;
            self.lootErrorCallback = nil;
            callback(self);
        end
    end
end

local function DisplayUnlootedItems(self)
    local list = LootUI.GetSortedLootList();
    if not list then
        return
    end
    self:ReleaseAll();
    local frames = {};
    self.activeFrames = frames;
    for _, data in ipairs(list) do
        if not data.looted then
            local row = self:AcquireItemFrame();
            row:SetData(data);
            frames[#frames + 1] = row;
            row:SetAlpha(1);
            row:EnableMouseScript(1);
            row.hasItem = true;
            row:Show();
        end
    end
    self:LayoutActiveFrames();
end

-- Auto loot could not take everything (bag full, rolls pending ...): all rows show, the taken ones slide out and
-- the rest stays as a normal loot window.
function MainFrame:OnErrored()
    local list = LootUI.GetSortedLootList();
    if not (list and #list > 0) or self.errorMode then
        return
    end
    self.errorMode = true;
    self:SetManualMode(true);

    local frames, looted = {}, {};
    self.activeFrames = frames;
    self.lootedFrames = looted;

    for i, data in ipairs(list) do
        local row = self:AcquireItemFrame();
        row:SetData(data);
        frames[i] = row;
        row:SetAlpha(1);
        row.toAlpha = nil;
        row:Show();
        if data.looted then
            row:EnableMouseScript(0);
            row.hasItem = nil;
            looted[#looted + 1] = row;
        else
            row:EnableMouseScript(1);
            row.hasItem = true;
        end
    end

    self:LayoutActiveFrames();
    self.t = 0;
    self.alpha = self:GetAlpha();

    if #looted > 0 then
        local delay = #looted * 0.1 + 0.25;
        self.lootErrorCallback = function(frame)
            frame.t = 0;
            frame:SetScript("OnUpdate", function(f, elapsed)
                f.t = f.t + elapsed;
                if f.t > delay then
                    f:SetScript("OnUpdate", nil);
                    DisplayUnlootedItems(f);
                end
            end);
        end
    else
        self.lootErrorCallback = nil;
    end

    self:SetScript("OnUpdate", OnUpdate_FadeIn_ThenHideLootedFrames);
    self:Show();
end

-- Take All: top to bottom.
function MainFrame:LootAllItemsSorted()
    for _, row in ipairs(self.activeFrames or {}) do
        local data = row.data;
        if row.hasItem and data and data.test then
            self:TestTake(row);
        elseif row.hasItem and data and data.slotIndex and data.slotIndex > 0 then
            LootSlot(data.slotIndex);
        end
    end
end

-- Preview: a row of the fake window was clicked. Same visuals as a slot the game cleared.
function MainFrame:TestTake(row)
    if row.hasItem then
        self:SetClickedFrameIndex(row.index);
        self:SetLootSlotCleared(row.data.slotIndex);
    end
end

-- The window must stop and hide when the default loot is back (module off) or on a UI scale change.
function MainFrame:Disable()
    self:Hide();
    self:SetAlpha(0);
    self:SetScript("OnUpdate", nil);
end

function MainFrame:OnUIScaleChanged()
    if self.BackgroundFrame then
        self.BackgroundFrame:UpdatePixel();
    end
end
