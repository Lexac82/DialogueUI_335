# Dialogue UI (3.3.5a)

A port of the retail **Dialogue UI** addon to **World of Warcraft: Wrath of the Lich King 3.3.5a**. It replaces the default quest and gossip windows with a clean, readable dialogue screen, and adds a few quality-of-life features around quests and readable objects.

![Theme](Preview/Theme.png)

## Features

### Two themes
Pick the **Brown** (parchment) or **Dark** theme. You can also change the frame size, font size and which side of the screen the window sits on (or drag it anywhere).

### Quest dialogue
- Quest text, objectives and rewards on one page, with a footer of Accept / Continue / Complete buttons.
- Number-key shortcuts for the options in a quest or gossip list, and a key to confirm.
- Optional **Instant Quest Text** (no fade-in), **Hide UI** while talking to an NPC, and a **Show NPC Name** toggle.

### Quest type label
Shows the type of quest (Daily, Weekly, Dungeon, Raid, Heroic, Elite, Group, PvP, Repeatable) above the title.

![Quest type](Preview/QuestTypeText.png)

### Quest difficulty in the list
When an NPC offers several quests, show the quest level, the difficulty name, or both next to each quest.

![Quest difficulty](Preview/QuestDifficultyStyle.png)

### Mark the highest sell price
When you must choose a reward, the item that sells for the most is marked.

![Highest sell price](Preview/MarkHighestSellPrice.png)

### Upgrade arrow and Valuable Reward Popup (needs Pawn)
With the [Pawn](https://www.curseforge.com/wow/addons/pawn) addon installed, reward items that are upgrades for your character get a green arrow. A popup lets you equip such an item directly after turning in the quest.

![Valuable reward popup](Preview/QuickSlotQuestReward.png)

### Quest Item Display
When a quest item is added to your bags, its description is shown and you can use it without opening your bags.

![Quest item display](Preview/QuestItemDisplay.png)

### Copy Text button
Copy the dialogue text, along with NPC and item IDs, to paste elsewhere.

![Copy text](Preview/CopyTextButton.png)

### Readables
Books, notes and other readable objects open in their own window. Choose its size, keep it open when you walk away, show the object's location and item description, and darken the screen behind it.

![Readables](Preview/BookUI.png)

### Settings
Open the settings with **/dui** or **/dialogui**, with **F1** while a dialogue is open, or with the minimap button. Tabs: **UI**, **Control** (including custom key bindings), **Gameplay** and **Minimap**.

## Installation

1. Download this repository (Code > Download ZIP) or clone it.
2. Put the folder in `World of Warcraft\Interface\AddOns\` and make sure it is named `DialogueUI_335`.
3. Start the game and enable **Dialogue UI** in the AddOns list on the character select screen.

## Notes

- Built for client **3.3.5a** (Interface 30300) only.
- Inspired by [Dialogue UI (YUI-Dialogue)](https://github.com/Peterodox/YUI-Dialogue) by Peterodox, the retail version of this addon. Some retail features (such as Auto Complete Quest and the Gossip options group) are not included because they do not apply to 3.3.5a.
- Pawn is optional and only needed for the upgrade arrow and the Valuable Reward Popup.
