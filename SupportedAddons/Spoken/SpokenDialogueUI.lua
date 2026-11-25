-- SpokenDialogueUI.lua: Spoken's side of the DialogueUI support.
--
-- NOT loaded by DialogueUI. It is meant to be copied into the Spoken addon's folder, with the
-- Spoken.toc beside it that lists it: see the README.md of DialogueUI.
-- DialogueUI's settings, Other Addons tab, switch it on and off (Spoken Buttons).
--
-- What it adds, with the stock Spoken addons and nothing else changed:
--   * a row of Spoken's round buttons at the top right of DialogueUI's quest and gossip window
--     (Play and Skip) and of its book view (Play and Skip), which DialogueUI would otherwise leave
--     without them, as it hides the game's UI and Spoken's own buttons with it.
--
-- It talks to DialogueUI only through what Code\SpokenSupport.lua there publishes (DUIQuestFrame,
-- DUIBookFrame, DialogueUI_DB) and to Spoken through its public API (Spoken:CreateDialogueUIRow,
-- Spoken:GetCurrent, Spoken:Skip). Play on a quest or gossip page asks
-- Spoken Quests for the page's recorded line, which it keeps in its own environment (VoiceOver);
-- without that, the quest window gets Skip only. Plain Lua 5.1, no environment: it runs as it is.
--
-- Nothing here may raise into the game: every entry point runs under pcall.

local VERSION = 1
-- DialogueUI reads this to tell the file is in place (Settings, Other Addons).
_G.DialogueUI_SpokenBridge = { version = VERSION }

-- The two words on the Play button's tooltip, in the client's language (machine-written; a native
-- speaker's check is welcome). The rest of the text on screen is Spoken's own.
local WORDS = {
    enUS = { Play = "Play", Stop = "Stop" },
    deDE = { Play = "Abspielen", Stop = "Stopp" },
    esES = { Play = "Reproducir", Stop = "Detener" },
    esMX = { Play = "Reproducir", Stop = "Detener" },
    frFR = { Play = "Lecture", Stop = "Arrêter" },
    ptBR = { Play = "Reproduzir", Stop = "Parar" },
    ruRU = { Play = "Играть", Stop = "Остановить" },
    koKR = { Play = "재생", Stop = "중지" },
    zhCN = { Play = "播放", Stop = "停止" },
    zhTW = { Play = "播放", Stop = "停止" },
}
local function Word(key)
    return (WORDS[GetLocale()] or WORDS.enUS)[key]
end

local ROUND = 24
-- Room above and below the row's line, in UIParent's units, and where DialogueUI puts the text
-- when the window is not lowered (the gossip page's, 42 under the top at its size 1).
local LINE_ROOM, GOSSIP_TEXT_TOP, BASE_WIDTH = 36, 42, 546.13
local LOOK_EVERY = 0.5

local EVENTS = {
    HandleQuestDetail = "QUEST_DETAIL", HandleQuestProgress = "QUEST_PROGRESS",
    HandleQuestComplete = "QUEST_COMPLETE", HandleQuestGreeting = "QUEST_GREETING",
    HandleGossip = "GOSSIP_SHOW",
}

local function Setting(key, default)
    local db = _G.DialogueUI_DB
    if type(db) == "table" and db[key] ~= nil then return db[key] end
    return default
end

local function Ready()
    return type(_G.Spoken) == "table" and _G.Spoken.CreateDialogueUIRow ~= nil
        and Setting("SpokenButtons", false)
end

--- Another file already puts the buttons there: a Spoken Quests with its own bridge hooked.
local function SomeoneElseDraws()
    local env = _G.VoiceOver
    local bridge = type(env) == "table" and rawget(env, "DialogueUIBridge")
    return type(bridge) == "table" and bridge.driver ~= nil
end

local function IsSpeaking(line)
    local head = Spoken.GetCurrent and Spoken:GetCurrent()
    return head ~= nil and line ~= nil and head.fileName == line.fileName
        and not (Spoken.IsPaused and Spoken:IsPaused())
end

--------------------------------------------------------------------------------
-- A dialog's row
--------------------------------------------------------------------------------

--- A tooltip on the dialog itself: the game's is a child of UIParent, which DialogueUI hides.
local function TooltipOn(dialog, name)
    local tip
    return function()
        if not tip then
            tip = CreateFrame("GameTooltip", name, dialog, "GameTooltipTemplate")
            tip:SetFrameStrata("TOOLTIP")
        end
        tip:SetScale(UIParent:GetEffectiveScale() / math.max(0.01, dialog:GetEffectiveScale() or 1))
        return tip
    end
end

local function SetEnabled(button, on)
    if (button:IsEnabled() and true or false) ~= on then
        if on then button:Enable() else button:Disable() end
    end
end

--------------------------------------------------------------------------------
-- The quest and gossip window
--------------------------------------------------------------------------------

local quest = {}

--- Spoken Quests' lookups, or nil: its addon and player objects in its own environment.
local function QuestInternals()
    local env = _G.VoiceOver
    if type(env) ~= "table" then return nil end
    local addon, player = rawget(env, "Addon"), rawget(env, "Player")
    if type(addon) == "table" and type(player) == "table" and addon.GetVisibleLine
        and addon.InvokeQuestHandler and player.QueuedClipFor and player.Remove then
        return addon, player
    end
end

local function QuestEvent(frame)
    return frame:IsShown() and EVENTS[frame.handler] or nil
end

function quest:Line(event)
    local addon = QuestInternals()
    if not (addon and event) then return nil end
    local ok, found = pcall(addon.GetVisibleLine, addon, event)
    return ok and found or nil
end

function quest:Play(event)
    local addon, player = QuestInternals()
    if not addon then return end
    player.playNow = true
    pcall(addon.InvokeQuestHandler, addon, event, "DialogueUI Spoken button", true)
    player.playNow = nil
end

function quest:Stop(line)
    local _, player = QuestInternals()
    local clip = player and line and player:QueuedClipFor(line)
    if clip then player:Remove(clip) end
end

function quest:Build(frame)
    local row = Spoken:CreateDialogueUIRow(frame, TooltipOn(frame, "SpokenDialogueUIQuestTip"))
    self.row = row
    -- Where the row's right end is: the paper's top right, inside the frame by its transparent margin.
    self.anchor = CreateFrame("Frame", nil, frame)
    self.anchor:SetSize(1, 1)
    row:SetTip(row.play, function(tip)
        local speaking = self.line ~= nil and IsSpeaking(self.line)
        tip:SetText(Word(speaking and "Stop" or "Play"))
    end)
    row.play:SetScript("OnClick", function()
        if self.line and IsSpeaking(self.line) then
            self:Stop(self.line)
        elseif self.event then
            self:Play(self.event)
        end
        self.lookedAt = 0
        row:RefreshTip(row.play)
    end)
end

function quest:Place(frame)
    local row = self.row
    local scale = UIParent:GetEffectiveScale() / math.max(0.01, frame:GetEffectiveScale() or 1)
    local right = tonumber(frame.paperRightInset) or 0
    local top = tonumber(frame.paperTopInset) or 0
    local x, y = -(right + 14 * scale), -(top + (LINE_ROOM + ROUND / 2) * scale)
    if self.x ~= x or self.y ~= y then
        self.x, self.y = x, y
        self.anchor:ClearAllPoints()
        self.anchor:SetPoint("RIGHT", frame, "TOPRIGHT", x, y)
    end
    local list = {}
    if row.skip:IsShown() then table.insert(list, row.skip) end
    if row.play:IsShown() then table.insert(list, row.play) end
    row:Place(list, self.anchor)
    -- DialogueUI's Copy Text button left of the row, on its middle.
    local copy = frame.CopyTextButton
    if type(copy) == "table" and copy.IsShown and copy:IsShown() and select(2, copy:GetPoint(1)) ~= row.frame then
        copy:ClearAllPoints()
        copy:SetPoint("RIGHT", row.frame, "LEFT", -4, 0)
    end
end

function quest:Draw()
    local frame = _G.DUIQuestFrame
    if type(frame) ~= "table" then return end
    local event = Ready() and not SomeoneElseDraws() and QuestEvent(frame) or nil
    if not event then
        if self.row and self.row.frame:IsShown() then
            self.row.frame:Hide()
            self.row:HideTips()
        end
        return
    end
    if not self.row then self:Build(frame) end
    local row = self.row
    row.frame:Show()
    local now = GetTime()
    if self.event ~= event or not self.lookedAt or now - self.lookedAt >= LOOK_EVERY then
        self.event, self.lookedAt = event, now
        self.line = self:Line(event)
    end
    -- Play only where Spoken Quests lets its line be reached; Skip always.
    row.play:SetShown(QuestInternals() ~= nil)
    SetEnabled(row.play, self.line ~= nil)
    local state = self.line ~= nil and IsSpeaking(self.line) and "stop" or "play"
    if row.play.state ~= state then row.play:SetState(state) end
    SetEnabled(row.skip, Spoken.GetCurrent ~= nil and Spoken:GetCurrent() ~= nil)
    self:Place(frame)
end

--- Room under the window's top edge for the row, kept as DialogueUI lays the page out.
function quest:ReconcileRoom()
    local frame = _G.DUIQuestFrame
    if type(frame) ~= "table" or type(frame.SetTopRoom) ~= "function" then return end
    local room = 0
    if Ready() and not SomeoneElseDraws() then
        local size = (tonumber(frame.frameWidth) or BASE_WIDTH) / BASE_WIDTH
        local scale = UIParent:GetEffectiveScale() / math.max(0.01, frame:GetEffectiveScale() or 1)
        room = math.max(0, math.floor((2 * LINE_ROOM + ROUND) * scale - GOSSIP_TEXT_TOP * size + 0.5))
    end
    if self.room ~= room then
        self.room = room
        frame:SetTopRoom(room)
    end
end

--------------------------------------------------------------------------------
-- The book view
--------------------------------------------------------------------------------

local book = {}

local function Books()
    local b = _G.SpokenBooks
    if type(b) == "table" and b.PlaceOf and b.BookById and b.IsNarrating and b.StopReading and b.SyncTo
        and b.HasAudio then
        return b
    end
end

--- The open book's key and its first page, as Spoken Readables keys them.
function book:Open()
    local b = Books()
    local pageId = b and b.lastPage
    local key = pageId and b:PlaceOf(pageId)
    local entry = key and b:BookById(key)
    if not entry then return nil, nil end
    return key, entry.pages[1] or pageId
end

function book:Build(view)
    local row = Spoken:CreateDialogueUIRow(view, TooltipOn(view, "SpokenDialogueUIBookTip"))
    self.row = row
    row:SetTip(row.play, function(tip)
        local key = self:Open()
        local b = Books()
        tip:SetText(Word(key and b and b:IsNarrating(key) and "Stop" or "Play"))
    end)
    row.play:SetScript("OnClick", function()
        local b = Books()
        local key, first = self:Open()
        if b and key and b:IsNarrating(key) then
            b:StopReading(key)
        elseif b and first then
            b:SyncTo(first, nil, true)
        end
        row:RefreshTip(row.play)
    end)
end

function book:Draw()
    local view = _G.DUIBookFrame
    if type(view) ~= "table" then return end
    -- Spoken Readables draws its own row on the book view (UI\DialogueUIBook.lua); two rows
    -- on the same spot overlap and the one underneath cannot be clicked.
    local readablesDraws = type(_G.SpokenBooks) == "table" and _G.SpokenBooks.SetupDialogueUIBook ~= nil
    local show = Ready() and not SomeoneElseDraws() and not readablesDraws and view:IsShown()
    if not show then
        if self.row and self.row.frame:IsShown() then
            self.row.frame:Hide()
            self.row:HideTips()
        end
        return
    end
    if not self.row then self:Build(view) end
    local row = self.row
    row.frame:Show()
    local b = Books()
    row.play:SetShown(b ~= nil)
    local key, first = self:Open()
    SetEnabled(row.play, b ~= nil and first ~= nil and b:HasAudio(first) and true or false)
    local state = key and b and b:IsNarrating(key) and "stop" or "play"
    if row.play.state ~= state then row.play:SetState(state) end
    SetEnabled(row.skip, Spoken.GetCurrent ~= nil and Spoken:GetCurrent() ~= nil)
    local list = {}
    if row.skip:IsShown() then table.insert(list, row.skip) end
    if row.play:IsShown() then table.insert(list, row.play) end
    -- From the left of the book's own close button, on its middle.
    row:Place(list, type(view.CloseButton) == "table" and view.CloseButton or nil)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function Tick()
    Safe(quest.Draw, quest)
    Safe(book.Draw, book)
end

local function Hook()
    if not _G.Spoken then return end
    -- Children of the dialogs, which run only while they are open; the quest window sets its own
    -- scripts anew, so none of them is hooked.
    for _, name in ipairs({ "DUIQuestFrame", "DUIBookFrame" }) do
        local dialog = _G[name]
        if type(dialog) == "table" and dialog.GetEffectiveScale then
            local watch = CreateFrame("Frame", nil, dialog)
            local since = 0
            watch:SetScript("OnShow", function() Safe(Tick) end)
            watch:SetScript("OnHide", function() Safe(Tick) end)
            watch:SetScript("OnUpdate", function(_, elapsed)
                since = since + elapsed
                if since >= 0.1 then
                    since = 0
                    Safe(Tick)
                end
            end)
        end
    end
    -- Room for the row and the settings changing while no dialog is open.
    local reconcile = CreateFrame("Frame")
    local waited = 0
    reconcile:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited >= 1 then
            waited = 0
            Safe(quest.ReconcileRoom, quest)
        end
    end)
    Safe(quest.ReconcileRoom, quest)
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Safe(Hook)
end)
