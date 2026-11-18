--Reserved space below so all localization files line up

local _, addon = ...;
local L = addon.L;

-- Blizzard's own global strings are used where they exist (FrameXML, not in wow-docs), so they follow the client
-- language. The English text is the fallback. Strings with values are format strings: "%d" number, "%s" text.


-- Footer buttons
L["Accept"] = ACCEPT or "Accept";
L["Continue"] = CONTINUE or "Continue";
L["Complete Quest"] = COMPLETE or "Complete Quest";
L["Incomplete"] = INCOMPLETE or "Incomplete";
L["Decline"] = DECLINE or "Decline";
L["Cancel"] = CANCEL or "Cancel";
L["Goodbye"] = GOODBYE or "Goodbye";

-- Settings window
L["UI"] = "UI";
L["Control"] = "Control";
L["Gameplay"] = "Gameplay";

-- Settings: UI tab
L["Theme"] = "Theme";
L["Theme Desc"] = "Select a color theme for the UI.";
L["Theme Brown"] = "Brown";
L["Theme Dark"] = "Dark";
L["Frame Size"] = "Frame Size";
L["Frame Size Desc"] = "Set the size of the dialogue UI.\n\nDefault: Medium";
L["Size Extra Small"] = "Extra Small";
L["Size Small"] = "Small";
L["Size Medium"] = "Medium";
L["Size Large"] = "Large";
L["Font Size"] = "Font Size";
L["Font Size Desc"] = "Set the font size for the UI.\n\nDefault: 12";
L["Frame Orientation"] = "Orientation";
L["Frame Orientation Desc"] = "Place the UI on the left or right side of the screen.\n\nCustom lets you drag the UI anywhere while this window is open.\n\nDefault: Right";
L["Orientation Left"] = "Left";
L["Orientation Right"] = "Right";
L["Orientation Custom"] = "Custom";
L["Move Position"] = "Move";
L["Reset Position"] = "Reset Position";
L["Move Position Desc"] = "Show the UI so you can drag it to a new position.";
L["Reset Position Desc"] = "Reset the UI's position.";
L["Hide UI"] = "Hide UI";
L["Hide UI Desc"] = "Fade out the game UI when you interact with an NPC.";
L["Show Copy Text Button"] = "Show Copy Text Button";
L["Show Copy Text Button Desc"] = "Show a Copy Text button on the top right of the dialogue UI.\n\nIt also includes game data like NPC and item IDs (and quest IDs of quests already in your log).";
L["Copy Text"] = "Copy Text";
L["Drag To Move"] = "Left-click and drag to move the window.";
L["Edit Mode Title"] = "Dialogue UI";
L["Edit Mode Body"] = "Drag this window to where you want it. Close the settings window to hide it.";

-- Quest types and tags
L["Quest"] = "Quest";
L["Quest Frequency Daily"] = "Daily";
L["Quest Frequency Weekly"] = "Weekly";
L["Quest Type Repeatable"] = "Repeatable";
L["Quest Type Trivial"] = "Trivial";
L["Quest Type Dungeon"] = "Dungeon";
L["Quest Type Raid"] = "Raid";
L["Quest Type Heroic"] = "Heroic";
L["Quest Type Elite"] = "Elite";
L["Quest Type Group"] = "Group";
L["Quest Type PvP"] = "PvP";

-- Quest text
L["Quest Objectives"] = "Objectives";
L["Format Suggested Players"] = QUEST_SUGGESTED_GROUP_NUM or "Suggested Players [%d]";
L["Quest Accepted Alert"] = ERR_QUEST_ACCEPTED_S or "Quest accepted: %s";

-- Rewards
L["Reward"] = "Reward";
L["Rewards"] = "Rewards";
L["Reward Choose"] = REWARD_CHOOSE or "Choose your reward:";
L["Reward Choices"] = REWARD_CHOICES or "You will be able to choose one of these rewards:";
L["Reward Items"] = REWARD_ITEMS or "You will also receive:";
L["Requirements"] = "Requirements";
L["Money"] = MONEY or "Money";
L["Honor Points"] = "Honor";
L["Arena Points"] = "Arena Points";
L["Talent Points"] = "Talent Points";
L["Experience"] = "Experience";
L["Title"] = "Title";
L["Format Talent Point Row"] = "+%d Talent Point";
L["Format Talent Points Row"] = "+%d Talent Points";

-- Reward tooltip
L["Show Comparison"] = "Show Comparison";
L["Hide Comparison"] = "Hide Comparison";
L["Sell Price"] = SELL_PRICE or "Sell Price";
L["Format Item Level"] = ITEM_LEVEL or "Item Level %d";
L["Format You Have"] = "- You have |cffffffff%d|r";
L["Format In Bank"] = " (|cffffffff%d|r in bank)";
L["Format Replace Item"] = "Replace %s";
L["Equipped Item"] = "equipped item";
L["Different Item Type"] = "Different item type than the equipped one.";
L["Identical Stats"] = "Identical Stats";
L["Format Reward Title"] = "You will be granted the title \"%s\".";
L["Format Reward Honor"] = "You will receive %d honor points.";
L["Format Reward Talent Point"] = "You will receive %d talent point.";
L["Format Reward Talent Points"] = "You will receive %d talent points.";
L["Format Reward Arena"] = "You will receive %d arena points.";
L["Format Reward Experience"] = "You will gain %d experience%s.";
L["Format Of Your Level"] = " (%d%% of your level)";

-- Quest Item Display
L["Click To Read"] = "Left Click to Read";
L["Begins A Quest"] = "Begins a Quest";
