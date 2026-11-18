# Settings menu: open questions

Notes for the next session. The retail-architecture refactor is finished and committed (`d261989`), so the settings menu is the next task. These questions need answers before any code is written.

## Where things stand

- Settings live in `DefaultValues` in `Initialization.lua`. Read them with `addon.GetDBValue` / `GetDBBool`, write them with `addon.SetDBValue`. Every write fires a `SettingChanged.<key>` callback, so a menu only has to call `SetDBValue`.
- Settings that exist today:
  - Reward tooltip: `UseBlizzardTooltip`, `TooltipShowItemComparison`
  - Rewards: `MarkHighestSellPrice`
  - Quest Item Display: `QuestItemDisplay`, `QuestItemDisplayHideSeen`, `QuestItemDisplayAwaitWorldMap`, `QuestItemDisplayFontSize`
  - Book: `BookUIEnabled`, `BookUISize`, `BookFontSize`, `BookKeepUIOpen`, `BookShowLocation`, `BookUIItemDescription`, `BookDarkenScreen`
  - Debug: `DebugGossip` (not meant for the menu)
- Live behavior: only `QuestItemDisplay` (off clears the popup) and `BookDarkenScreen` react to changes immediately. Book size and font apply the next time a book opens. `QuestItemDisplayFontSize` applies after `/reload`.
- Retail reference: `..\DialogueUI\Code\Settings\` (`Settings.lua`, `Settings.xml`, `Settings_DropdownMenu.lua`, ...). Retail's own option definitions use the same key names as ours.
- There is no F1 binding anywhere in our code yet.
- Rules to keep in mind (see `CLAUDE.md`): only APIs documented in `D:\PersonalProjects\wow-docs`, no retail-only APIs (`Settings`, `ScrollBox`, `C_*`), text through `addon.L`, flat `.toc`.

## Questions

1. **Layout.** One frame with tabs or sections like retail's menu, or a simpler scrolling list of options?
2. **Contents.** Which options should the menu expose?
   - the existing settings listed above;
   - the frame size and font size that retail has (our dialogue frame size is currently fixed);
   - anything else from retail's list worth porting (for example camera, hide UI, keybindings, TTS)?
3. **F1 binding.** There is none today. Options:
   - F1 opens the menu only while the dialogue frame is shown (uses an override binding, the same mechanism as the Space and Esc keys in `FooterButtons.lua`);
   - F1 works anywhere in the game, which replaces the game's own F1 binding;
   - a slash command only, plus a button on the dialogue frame.

   My lean: a slash command everywhere, with F1 only inside the dialogue.
4. **Look.** Should the menu use the parchment theme (reusing `TextureSlice`, the fonts and the option-button art) or plain Blizzard-style widgets?
5. **Live vs reload.** Should the menu make Book size, Book font and the Quest Item Display font apply immediately, which needs extra work, or is "applies on next use / after `/reload`" fine for now?
6. **Settings that exist only as `/run` today.** `UseBlizzardTooltip` and `TooltipShowItemComparison` are currently toggled by `/run` or Shift. Both go into the menu?
