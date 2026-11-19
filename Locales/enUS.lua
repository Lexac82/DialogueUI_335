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
L["Show NPC Name On Page"] = "Show NPC Name";
L["Show NPC Name On Page Desc"] = "Show the NPC name on the page.";
L["Show Quest Type"] = "Show Quest Type";
L["Show Quest Type Desc"] = "Show the quest type (Quest, Daily, Weekly, Dungeon, ...) above the quest title.";
L["Show Copy Text Button"] ="Show Copy Text Button";
L["Show Copy Text Button Desc"] = "Show a Copy Text button on the top right of the dialogue UI.\n\nIt also includes game data like NPC and item IDs (and quest IDs of quests already in your log).";
L["Copy Text"] = "Copy Text";
L["Drag To Move"] = "Left-click and drag to move the window.";
L["Edit Mode Title"] = "Dialogue UI";
L["Edit Mode Body"] = "Drag this window to where you want it. Close the settings window to hide it.";

-- Quest types and tags
L["Quest"] = "Quest";
L["Readables"] = "Readables";
L["BookUI Frame Size Desc"] = "Set the size of the Book UI.\n\nDefault: Small";
L["BookUI Keep UI Open"] = "Keep Window Open";
L["BookUI Keep UI Open Desc"] = "Keep the window open when you move away from the object.\n\nPress Escape or right-click on the UI to close it.";
L["BookUI Show Location"] = "Show Location";
L["BookUI Show Location Desc"] = "Show the object's location in the header.\n\nOnly works for game objects, not items in your bags.";
L["BookUI Show Item Description"] = "Show Item Description";
L["BookUI Show Item Description Desc"] = "If the item has any description on its tooltip, display it on the top of the UI.";
L["BookUI Darken Screen"] = "Darken Screen";
L["BookUI Darken Screen Desc"] = "Darken the area below the UI to help you concentrate on the content.";

-- Settings: Control tab (retail enUS where it exists)
L["Input Device"] = "Input Device";
L["Input Device Desc"] = "Affects hotkey icons and UI layout.";
L["Input Device KBM"] = "Keyboard & Mouse";
L["Use Custom Bindings"] = "Use Custom Bindings";
L["Use Custom Bindings Desc"] = "Enable this option to use your own bindings.";
L["Primary Control Key Desc"] = "Press this key to select the first available option like Accept Quest.";
L["Right Click To Close UI"] = "Right Click To Close UI";
L["Right Click To Close UI Desc"] = "Right click on the dialogue UI to close it.";
L["Press Button To Scroll Down"] = "Press Button To Scroll Down";
L["Press Button To Scroll Down Desc"] = "If the content is taller than the viewport, pressing the Confirm Button will scroll the page down instead of accepting quest.";
L["Press Tab To Select Reward"] ="Press Tab To Select Reward";
L["Press Tab To Select Reward Desc"] = "Press Tab to cycle through choosable rewards when you turn in the quest. Shift-Tab goes back.";
L["Keybinding Hint"] = "Click, then press the key you want to use.\nRight click: back to the default key.\nEsc: cancel.";
L["Bound To"] = "Bound to: ";
L["Not Bound"] = NOT_BOUND or "Not Bound";
L["Action Confirm"] = "Confirm";
L["Action Settings"] = "Toggle Settings";
L["Action Option1"] = "Option 1";
L["Action Option2"] = "Option 2";
L["Action Option3"] = "Option 3";
L["Action Option4"] = "Option 4";
L["Action Option5"] = "Option 5";
L["Action Option6"] = "Option 6";
L["Action Option7"] = "Option 7";
L["Action Option8"] = "Option 8";
L["Action Option9"] = "Option 9";
L["Action Option Desc"] = "Press this key to select option %d of the list (quests and gossip options).";
L["Action Settings Desc"] = "Press this key to open or close the settings window while the dialogue is shown.";

L["Quest Frequency Daily"] = "Daily";
L["Quest Frequency Weekly"] = "Weekly";
L["Quest Type Repeatable"] = "Repeatable";
L["Quest Difficulty VeryHard"] = "Very Hard";
L["Quest Difficulty Hard"] = "Hard";
L["Quest Difficulty Easy"] = "Easy";
L["Quest Difficulty Trivial"] = "Low Level";
L["Quest Difficulty Option"] = "Quest Difficulty";
L["Mark Highest Sell Price"] = "Mark Highest Sell Price";
L["Mark Highest Sell Price Desc"] = "Show you which item has the highest sell price when you are choosing a reward.";
L["Use Blizzard Tooltip"] = "Use Blizzard Tooltip";
L["Use Blizzard Tooltip Desc"] = "Use Blizzard tooltip for the quest reward button instead of our special tooltip.";
L["Click To Copy To Clipboard"] = "Click to copy to clipboard";
L["Show Upgrade Arrow"] = "Show Upgrade Arrow (Pawn Required)";
L["Show Upgrade Arrow Desc"] = "Show a green arrow %s on a reward item if it is an upgrade for your character, according to the Pawn addon: the item scores higher than the one you have equipped in that slot in at least one of your Pawn scales.\n\nArmor of a different type than the one you have equipped (cloth over leather, for example) is never marked.";
L["Show Upgrade Arrow Pawn Missing"] = "Requires the Pawn addon (not found).\n\nDownload: |cff0000ee%s|r\n\nClick the copy icon, press Ctrl+C, then paste the link into your browser.";
L["Quest Difficulty Option Desc"] = "Choose how quest difficulty is displayed when the NPC offers you a list of quests.";
L["QuestDifficultyStyle Off"] = "OFF";
L["QuestDifficultyStyle Off Desc"] = "Quest level and difficulty are now hidden.";
L["QuestDifficultyStyle Level"] = "Level";
L["QuestDifficultyStyle Level Desc"] = "Display the quest level to the left of the quest title.";
L["QuestDifficultyStyle Name"] = "Name";
L["QuestDifficultyStyle Both"] = "Both";
L["QuestDifficultyStyle Both Desc"] = "Display the quest level to the left of the quest title, and the difficulty name on the right of the quest button if the quest level is outside the recommended range.";
L["QuestDifficultyStyle Name Desc"] = "Display the difficulty name on the right of the quest button if the quest level is outside the recommended range.\n(The quest level is +3 or -3 from your character level)";
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
