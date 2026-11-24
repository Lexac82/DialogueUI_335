local _, addon = ...;

-- Support for the Spoken addons (Spoken, Spoken Quests, Spoken Readables).
--
-- Retail's DialogueUI keeps its windows in globals (DUIQuestFrame, DUIBookFrame) with a known set of fields and
-- methods, and the Spoken addons were written against those. This port keeps its windows private, so this file
-- publishes the same shapes over them. Nothing here changes how DialogueUI behaves; it only adds names and
-- hooks. Without a Spoken addon installed it is idle.
--
--   DUIQuestFrame       the quest and gossip window's frame
--   DUIBookFrame        the book view's frame
--   DUIFont_*           font objects Spoken reads the look of the text from

local CallbackRegistry = addon.CallbackRegistry;
local Main = addon.DialogueUI;
local frame = Main.frame;
local floor, min, max = math.floor, math.min, math.max;

_G.DialogueUI_SpokenAPI = { version = 1 };
_G.DUIQuestFrame = frame;


-- Fonts ----------------------------------------------------------------------------------------------------------

-- Proxies read the live FontString, so a size change shows without republishing.
local function FontProxy(getFontString)
    return {
        GetFont = function()
            local fs = getFontString();
            if fs then
                return fs:GetFont()
            end
        end,
        GetTextColor = function()
            local fs = getFontString();
            if fs then
                return fs:GetTextColor()
            end
            return 1, 1, 1, 1
        end,
    };
end

_G.DUIFont_Quest_Paragraph = Main.QuestText.paragraphFont;
_G.DUIFont_QuestType_Left = Main.QuestText.paragraphFont;      -- its colour follows the theme as the tag text's does
_G.DUIFont_Quest_Title_18 = FontProxy(function() return Main.FrontFrame.Header.Title end);


-- The quest window ------------------------------------------------------------------------------------------------

local HANDLERS = {
    GOSSIP_SHOW = "HandleGossip",
    QUEST_GREETING = "HandleQuestGreeting",
    QUEST_DETAIL = "HandleQuestDetail",
    QUEST_PROGRESS = "HandleQuestProgress",
    QUEST_COMPLETE = "HandleQuestComplete",
};

local function Nothing() end

-- Methods Spoken hooks with hooksecurefunc. They run, empty, when the thing they name happens.
for _, name in pairs(HANDLERS) do
    frame[name] = Nothing;
end
frame.LoadTheme = Nothing;
frame.UpdateFrameSize = Nothing;
frame.UpdateFrameBaseOffset = Nothing;

-- The FontStrings of the text on the page, as retail's fontStringPool lists them.
frame.fontStringPool = {
    EnumerateActive = function()
        local text, i = Main.QuestText, 0;
        return function()
            i = i + 1;
            if i <= text.fontStringCount then
                local fs = text.fontStrings[i];
                fs.ttsFlag = true;
                fs.isTranslation = false;
                return i, fs
            end
        end
    end,
};

frame.ContentFrame = Main.QuestText.ContentFrame;
frame.ScrollFrame = Main.QuestText.ScrollArea;
frame.FrontFrame = Main.FrontFrame;
frame.Parchments = { Main.top };

function frame:IsScrollable()
    return Main.QuestText.ScrollArea:IsScrollable()
end

function frame:ScrollTo(value)
    Main.QuestText.ScrollArea:ScrollTo(value);
end

function frame:HideUI()
    Main:RequestClose();
end

-- Room under the window's top edge for a row of buttons (see ParchmentBackground:SetTopRoom).
function frame:SetTopRoom(room)
    Main:SetTopRoom(room);
end

-- What the window measured itself at, and where it sits, in its own units.
local function Measure()
    local M = Main.metrics;
    frame.frameWidth = M.width;
    frame.frameHeight = M.fullH;
    -- The paper is narrower than the frame: its right edge, and its top, as far in as the art's margins.
    frame.paperRightInset = M.width / 1024 * 135;
    frame.paperTopInset = M.width / 1024 * 7;
    local orientation = addon.GetDBValue("FrameOrientation");
    if orientation == 3 then
        frame.frameOffsetX = nil;       -- dragged: Spoken reads where the window is
    else
        local viewport = min(UIParent:GetWidth(), UIParent:GetHeight() * 16 / 9);
        local offset = floor(viewport * 0.25 + 0.5);
        frame.frameOffsetX = orientation == 1 and -offset or offset;
    end
end
Measure();

CallbackRegistry:Register("FrameSizeChanged", function()
    Measure();
    frame:UpdateFrameSize();
    frame:UpdateFrameBaseOffset();
end);
CallbackRegistry:Register("SettingChanged.FrameOrientation", function()
    Measure();
    frame:UpdateFrameBaseOffset();
end);
CallbackRegistry:Register("ThemeChanged", function()
    frame:LoadTheme();
end);

-- The page that is showing: named before the page is built; its handler runs once the page is, and again when it
-- is built anew (an item reward arriving, the text size changing).
local baseShowUI = Main.ShowUI;

function frame:ShowUI(event)
    self.handler = HANDLERS[event];
    baseShowUI(Main, event);
end

function Main:ShowUI(event)
    frame:ShowUI(event);
end

local function PageBuilt()
    local handler = frame.handler;
    if handler and frame:IsShown() then
        Measure();
        frame[handler](frame);
    end
end
hooksecurefunc(Main.QuestText, "SetQuestText", PageBuilt);
hooksecurefunc(Main.QuestText, "SetListPage", PageBuilt);

-- frame.CopyTextButton is set in DialogueUI.lua when the button is first made.


-- The book view --------------------------------------------------------------------------------------------------

local Book = addon.Book;

local function PublishBook()
    Book:Init();
    local view = Book.frame;
    _G.DUIBookFrame = view;
    view.CloseButton = Book.closeButton;
    view.Header = { Title = Book.title, Location = Book.location };
    view.ScrollFrame = Book.scrollFrame;
    view.ContentFrame = Book.scrollChild;
    view.textureKitID = Book.kitID or 1;
    _G.DUIFont_Book_Title = FontProxy(function() return Book.title end);

    -- The book view draws every block, so no FontString is ever handed to another paragraph.
    Book.scrollFrame.SetObjectData = Nothing;
    view.RebuildContentFromCache = Nothing;

    -- Block `index` of the book to the top of the view.
    function view:ScrollToContent(index)
        local block = Book.Cache.content[index];
        if block and block.offsetY then
            Book:ScrollTo(max(0, block.offsetY - (Book.scrollFromOffsetY or 0)));
        end
    end

    hooksecurefunc(Book, "SetTextureKit", function(_, kitID)
        view.textureKitID = kitID;
    end);

    -- scroll.content: the blocks as laid out; scroll.contentIndexObject: the FontString drawing each text block.
    hooksecurefunc(Book, "RenderContent", function()
        local scroll = Book.scrollFrame;
        local content = Book.Cache.content;
        local objects, n = {}, 0;
        for index, block in ipairs(content) do
            if block.text then
                n = n + 1;
                local item = Book.textItems and Book.textItems[n];
                objects[index] = item and item.fs or nil;
            end
        end
        scroll.content = content;
        scroll.contentIndexObject = objects;
        view:RebuildContentFromCache();
    end);
end

-- After the saved settings are in: the book view is made at once instead of with the first book, so the Spoken
-- addons find it when the world loads.
CallbackRegistry:Register("ADDON_LOADED", function()
    local ok, err = pcall(PublishBook);
    if not ok then
        geterrorhandler()(err);
    end
end);
