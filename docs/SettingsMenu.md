# Settings menu

Port of retail's settings window (`..\DialogueUI\Code\Settings\Settings.xml` / `Settings.lua`). Code: `Code/Settings/Settings.lua`. Theme work is in `docs/Theme.md`.

## Status

| Item | State |
|---|---|
| Window shell (frame, header, tabs UI / Control / Gameplay, close button, dividers, decor picture) | done |
| Opens with `/dui`, `/dialogui`, and F1 while the dialogue is shown (Esc and F1 close it) | done |
| Option row + arrow option widget (`< value >` with one bar per choice) | done |
| UI tab: **Theme** (Brown / Dark) | done |
| UI tab: **Frame Size** (Extra Small 0.9 / Small 1.0 / Medium 1.1 / Large 1.25) | written, **not tested in the game**, see "Frame Size: what was done" |
| UI tab: **Font Size** (10 / 12 / 14 / 16) | written, **not tested in the game**, see "Font Size: what was done" |
| UI tab: **Orientation** (Left / Right / Custom) with **Move Position** and **Reset Position** rows under Custom | written, **not tested in the game**, see "Orientation: what was done" |
| UI tab: **Hide UI** checkbox (new row type **Checkbox**) | written, **not tested in the game**, see "Hide UI: what was done" |
| UI tab: **Show Copy Text Button** checkbox (button + Clipboard window) | written, **not tested in the game**, see "Show Copy Text Button: what was done" |
| UI tab: **Show NPC Name** checkbox | written, **not tested in the game**, see "Show NPC Name: what was done" |
| UI tab: **Show Quest Type** checkbox (not in retail) | written, **not tested in the game**, see "Show Quest Type: what was done" |
| UI tab: **Quest** subheader label after Show Quest Type (new row type **Subheader**, as retail) | written, **not tested in the game**, see "Subheader: what was done" |
| UI tab: **Instant Quest Text** checkbox (after Show Quest Type, before the Quest subheader), bound to Blizzard's CVar (`addon.INSTANT_TEXT_CVAR` = `questFadingDisable`, **name unverified**, not in wow-docs; `cvarFunc` field of the Checkbox row reads / writes it with `GetCVar` / `SetCVar` in `pcall`, so a wrong name just shows unchecked). `QuestTextLayout` already reads it at every page, so it applies at once | written, **not tested in the game** |
| Quest group: **Quest Difficulty** (Off / Level / Name / Both) | written, **not tested in the game**, see "Quest Difficulty: what was done" |
| Quest group: **Show Upgrade Arrow** checkbox (arrow + setting) | written, **not tested in the game**, see "Show Upgrade Arrow: what was done" |
| Quest group: **Mark Highest Sell Price** checkbox (logic existed, row + live toggle added) | written, **not tested in the game**, see "Mark Highest Sell Price: what was done" |
| Quest group: **Use Blizzard Tooltip** checkbox (row + top-frame take-out) | written, **not tested in the game**, see "Use Blizzard Tooltip: what was done" |
| **Readables** subheader label after Use Blizzard Tooltip (same Subheader row type as Quest, no options under it yet) | written, **not tested in the game**, see "Subheader: what was done" |
| Readables group: **Frame Size** (Extra Small 0.9 / Small 1.0 / Medium 1.1 / Large 1.25, `BookUISize`) | written, **not tested in the game**, see "Readables Frame Size: what was done" |
| Readables group: **Keep Window Open** checkbox (`BookKeepUIOpen`) | written, **not tested in the game**, see "Readables Keep Window Open: what was done" |
| Readables group: **Show Location** checkbox (`BookShowLocation`, live toggle added) | written, **not tested in the game**, see "Readables Show Location: what was done" |
| Readables group: **Show Item Description** checkbox (`BookUIItemDescription`, live toggle added) | written, **not tested in the game**, see "Readables Show Item Description: what was done" |
| Readables group: **Darken Screen** checkbox (`BookDarkenScreen`, logic and live toggle already existed) | written, **not tested in the game**, see "Readables Darken Screen: what was done" |
| Control tab: **Input Device** (Keyboard & Mouse only, no arrows), **Use Custom Bindings** checkbox, then Confirm / Toggle Settings / Option 1-9 key rows (new row type **Keybinding**) | written, **not tested in the game**, see "Control tab: what was done" |
| Control tab: **Quest** subheader label (same Subheader row type as the UI tab), placed before Press Tab To Select Reward | written, **not tested in the game** |
| Control tab: **Press Button To Scroll Down** checkbox (`ScrollDownThenAcceptQuest`) | written, **not tested in the game**, see "Press Button To Scroll Down: what was done" |
| Control tab: **Press Escape To Decline Quest** checkbox (`EscapeToDeclineQuest`; Decline / Cancel now go back to the list only for quests chosen from a list) | written, **not tested in the game**, see "Press Escape To Decline Quest: what was done" |
| Other options (Font, Hide UI sub-options, ...), Control tab extras (Right Click To Close, Press Tab To Select Reward, Disable Hotkey For Teleport), rest of the Gameplay tab | not started |
| Gameplay tab: Quest Item Display + Ignore Seen Items, Await World Map, Move, Reset Position (Auto Quest Popup skipped) | done |
| Gameplay tab: **Quest** subheader, **Valuable Reward Popup** (equipment upgrades by Pawn, new popup) with Move / Reset Position rows | written, **not tested in the game**, see "Valuable Reward Popup: what was done". Textures converted and in place |
| Gameplay tab: **Auto Complete Quest** | skipped, see "Auto Complete Quest: skipped" |
| **Minimap** tab (4th tab, not in retail): **Show Minimap Button** checkbox + the minimap button itself (Logo, opens Settings) | written, **not tested in the game**, see "Minimap tab: what was done" |
| Gameplay tab: **Gossip** group (Auto Select Option, Force Gossip, Skip GameObject, Show Hint) | skipped, no label either, see "Gossip group: skipped" |

Rules for every session (from `CLAUDE.md`): only APIs documented in `D:\PersonalProjects\wow-docs`, no retail-only APIs, text through `addon.L`, flat `.toc`, settings go through `addon.GetDBValue` / `SetDBValue` with a `SettingChanged.<key>` callback, PNGs go to `temp\` for BLP conversion (the user converts them, then you move them to `Textures\`). Nothing here has been tested in the game client, say so in your reports.

## Layout (retail numbers at font height 12)

```
+--------------------------------------------------------------+  frame 733 x 454, padding 14
| [UI] [CONTROL] [GAMEPLAY]                              [ X ] |  header: tabs 36 high, gap 4
|==============================================================|  header divider (9 px)
|                                    |                         |
|  option list                       |  preview (hidden)       |
|  432 x 378 (10.5 rows of 36)       |  description text       |
|  one page frame per tab            |  (right area, 273 wide) |
|                                    |  decor picture (Dalaran)|
+--------------------------------------------------------------+
```

- List and description area are in the golden ratio: width = round((432 + 1.5 * 14) / 0.618).
- Option rows: `CreateOptionRow` / `CreateArrowOption` in `Settings.lua`. Options are listed in the `Schematic` table (fields follow retail: `type`, `name`, `description`, `dbKey`, `choices`). Rows are built once at load, `RefreshTab` re-reads the saved values.
- Arrow option bars: 16x4 piece of `Settings-ArrowOption` (x 0-16, y 124-128), tiled slice with 1 texel margins, height tuned by eye (`ARROWOPTION_BAR_HEIGHT`).
- The decor picture has no mask in 3.3.5a: it is a body plus a fade band (`SetGradientAlpha`) that follow the description height (`SettingsUI:UpdateDecor`).
- Preview pictures (retail `Art/PreviewPicture`): an option with `preview = "Name"` and `ratio` (1 square, 2 twice as wide as high) shows `Textures\PreviewPicture\Name.blp` above its description, with the tiled `Settings-PreviewBorder` 1 px outside; the text and the decor picture move down (`SettingsUI:SetDescription(text, optionData)`). Written, **not tested in the game**. Used by Theme and Show Copy Text Button. Converted and in `Textures\PreviewPicture\`: `Theme.blp` (512 x 256), `CopyTextButton.blp` (256 x 256). Every further option picture is a retail JPG to convert the same way.
- Scrolling: see "Scrolling: what was done". Not ported: gamepad support.

## Frame Size: what was done (not tested in the game)

- `FrameSize` (default 2 = Medium) is in `DefaultValues`. `Code/Utility/FrameSize.lua` (`addon.FrameSize:GetMultiplier()`) maps 0..3 to 0.9, 1.0, 1.1, 1.25 and fires `"FrameSizeChanged"` after the setting changed (and once at load with the saved value). It is the one source of the multiplier.
- `ParchmentBackground.lua`: the file-level constants became `ComputeMetrics(m)`; `ParchmentBackground:ApplySize()` re-sizes and re-anchors the frame, parchment pieces, header, divider, portrait, check mark, title (font height too, `FontUtil:SetQuestTitleFontHeight`), gossip and footer dividers. `QuestTextLayout:SetSize` and `Footer:SetSize` take over the text box width, paddings, top offsets and button widths.
- `DialogueUI.lua`: on `"FrameSizeChanged"` the open page is laid out again from the stored page (no reveal fade; `SetPage` again on QUEST_COMPLETE because the redraw clears the reward choice).
- Option and strings: `Settings.lua` UI tab (after Theme), `Locales/enUS.lua` (`Frame Size`, `Frame Size Desc`, `Size Extra Small/Small/Medium/Large`).

### Answers to the investigation questions

1. **Retail's viewport formula was not copied.** Our frame width is fixed (`546.13 x m`) and everything else is linear in `m`, so each size is the Medium layout scaled. That keeps Medium identical to before (one difference: the text box now uses the exact divider width 358.4 x m instead of 358 x m, 0.2 units per side). Retail's 0.618 x viewport height x m can only be matched after checking what `WorldFrame:GetSize()` returns in 3.3.5a (not checked, not in the docs I looked at), so whether our Medium equals retail's visible size at a given resolution is **still unverified**.
2. **Scaled by m** (as retail): paddings (26, 36), header offset, portrait size and position, title font height (18), title offsets, check mark, gossip divider offset, topLight offset, quest and list text top offsets (28 + 40, 42, 6), footer inset, and all atlas pieces (via width / 1024). **Not scaled** (fixed in retail or font-based): body, sub-header and button fonts (12), paragraph spacing, sub-header sizes, header tag pills, option button padding and icons, reward button sizes and gaps (8), `BUTTON_GAP`. Retail's `maxSizeMultiplier` caps (quest portrait model) have no counterpart here yet.
3. Text width, reward grid (`quarterFrameWidth` = (textWidth - 3 x 8) / 4), list rows and footer buttons (half of frame width minus inset and gap) are all derived from the new widths, so they follow the multiplier. Reward and item buttons are not scaled themselves.
4. **Not checked.** `Parchment.blp` pieces are stretched at 0.48 to 0.67 units per texel; look for blur or gaps at 0.9 and 1.25.

### To look at in the game

Frame edges and parchment seams at all four sizes; header, portrait, title and check mark positions; footer buttons and divider; body text wrap and reward rows at 0.9 and 1.25; changing the size with a quest page, a first-contact page and QUEST_COMPLETE open (reward choice kept?); title font height changes live; Brown and Dark theme after a size change; Book size is untouched.

## Font Size: what was done (not tested in the game)

Same scheme as retail (`FontUtil.lua` `FONT_OBJECT_HEIGHT`, `FontSizeChanged`), without Mobile Device Mode (no 5th size).

- `FontSizeBase` (default 1 = 12) in `DefaultValues`. `FontUtil.lua`: a table maps font object names to a height per choice (`HEIGHT_1` = 10/12/14/16 for paragraph, sub-header, option buttons, tooltip title; `HEIGHT_2` = 8/10/12/14 for items, hotkeys, quest-type note, tooltip body; item count 8/10/10/12). `GetQuestFont` / `GetColoredFont` / `GetCountFont` take the height from it when the name is listed, and `SettingChanged.FontSizeBase` re-sets the existing font objects and fires `"FontSizeChanged"(baseFontSize, id)`.
- Listeners: `QuestTextLayout` (line spacing 0.35 x size, paragraph spacing 4 x that, sub-header height), `GossipDataProvider.GAPS` (paragraph / section gaps), `OptionButton` (retail formulas: hotkey size = size + 8, icon = size + 2, paddings; hotkey box is re-applied in `Layout`), `RewardItemButton` (3-line limit = 3.2 x item font height), `ParchmentBackground` (`ApplySize`, re-measures footer and text box), `DialogueUI` (redraws the open page, shared with `FrameSizeChanged`).
- Not affected: title (frame size drives it), Book (its own `BookFontSize`), Quest Item Display, alert, header tag pills, the settings window itself.
- Known gaps: reward item buttons keep their fixed height 36 (two lines of the 14 font are ~38 high, may be tight at size 16); the hotkey box in the tooltip stays 20; `realignAfterClicks` (retail re-aligns the arrow under the mouse) is not ported.
- To look at: every size on a quest page, QUEST_COMPLETE with rewards (reward choice is cleared by the redraw), first-contact list with icons/notes, footer button height and divider, sub-header ("Objectives") background height, hotkey boxes, Esc / Space labels; changing the size live with the page open; combined with the four frame sizes.

## Orientation: what was done (not tested in the game)

Retail's `FrameOrientation` (1 Left, 2 Right) moves the main dialogue frame to a side of the screen (`UpdateFrameBaseOffset`: CENTER anchor, X offset = viewport width x (3/4 - 0.5), sign flipped for Left), docks retail's chat frame on the other side, opens the settings window on the other side of the dialogue (`MoveToBestPosition`) and shifts the camera. We port the frame and the settings window; camera and chat frame are not used here.

- `FrameOrientation` (default 2 = Right) in `DefaultValues`; value 3 = **Custom**, which retail does not have. Our parchment used to be draggable always; now it is draggable **only** in Custom, while the Settings window is open on the UI tab (`CanMove` in `ParchmentBackground.lua` checks both; `SettingsUI:IsOnUITab()`). Left / Right ignore `ParchmentPosition`.
- `ParchmentBackground.lua`: `ApplyPosition` places the frame (Left / Right offset, or the saved `ParchmentPosition` in Custom, Right until something was dragged). Called on `SettingChanged.FrameOrientation` (also fires once at load) and every time the parchment is shown. The viewport is `min(UIParent width, 16/9 x UIParent height)`; retail uses `WorldFrame:GetSize()`, not verified for 3.3.5a, so UIParent units are used (they match `SetPoint`). `IsUsingCustomPosition`, `ResetPosition`.
- Settings rows: new row type **Custom** (retail's Move / Reset rows: branch mark, 24 px icon from `Settings-Move.blp` / `Settings-Reset.blp`, label, whole row is the button). Rows can depend on other options (`requiredParentValueAnd`, `validationFunc` as in retail); hidden rows are skipped and the rest are stacked (`SettingsUI:LayoutRows`). Reset Position is hidden until something was dragged, as in retail.
- **Move Position** (`MainFrame:ToggleEditMode`, `DialogueUI.lua`): shows a small sample page ("Dialogue UI", a hint text, only a Goodbye button) so the frame can be dragged without a conversation. Closes with its button, Esc, closing Settings, leaving the UI tab, or leaving Custom. A real conversation replaces it.
- The **Move** row is a toggle: while the sample is shown it keeps the hover glow (own glow frame, `isToggledFunc`, `SettingsUI:RefreshToggles`; the normal hover glow skips it so it is not doubled). While the parchment can be dragged (Custom, Settings open on the UI tab) it shows the Move icon at 48 px (double the row icon) in the middle of the frame (`moveMark` in `ParchmentBackground.lua`, no mouse so drags pass through).
- `SettingsUI:MoveToBestPosition`: window on the opposite side of the dialogue (Left puts it on the right, Right on the left; centered when no dialogue is up). Left / Right only: in Custom it does nothing, so the window keeps its position (also when the Move sample appears or the window is reopened). Runs when the window opens, when the orientation changes, and when the parchment appears or hides (`ParchmentShown` / `ParchmentHidden`, from the frame's OnShow / OnHide), so the window follows a conversation that starts or ends while it is open. Camera: not ported (not used).
- Strings: `Frame Orientation`, `Frame Orientation Desc`, `Orientation Left/Right/Custom`, `Move Position (Desc)`, `Reset Position (Desc)`, `Edit Mode Title/Body` in `Locales/enUS.lua`.
- To look at: Left / Right / Custom on the first load (default Right, centre of the frame at 1/4 of the screen width); dragging in Custom only with Settings open on the UI tab, not on the Control tab or with Settings closed; Move shows and hides the sample; Esc with the sample open closes it, and Esc closes Settings afterwards; Reset appears after a drag and puts the frame back on the Right; positions survive /reload; Settings window side in all three modes; Frame Size change in Custom keeps the frame centered where it was; Move / Reset icons in Brown and Dark.

## Hide UI: what was done (not tested in the game)

Retail (`Camera.lua`, `FadeHelper`): when the dialogue opens, `UIParent` alpha fades 1 to 0 (0.5 s), then `SetGameUIShown(false)`; on close it shows again and fades in (0.25 s). Combat, `PLAY_MOVIE` and `CINEMATIC_START` bring it back at once; nothing is hidden in combat. Turning the option on or off with a dialogue open applies at once.

- `HideUI` (default true, as retail) in `DefaultValues`. Checkbox row type in `Settings.lua` (`CreateCheckbox`: 24 px box from `Settings-Checkbox`, 12 px tick, whole row is the click target, sub-option branch mark like the Custom rows is not added yet because there are no sub-options).
- `Code/Dialogue/HideUI.lua`: `FadeHelper` ported without the retail-only parts (`SetGameUIShown` becomes `UIParent:Hide()` / `Show()`, as Alt+Z does; no alternate power bar, no sparkles / `Outline` CVar, no camera). It reacts to `"ParchmentShown"` / `"ParchmentHidden"`, so pages that replace each other (frame stays shown) do not fade. The Move Position sample does not hide the UI.
- **Problem it solves:** hiding `UIParent` hides all its children, and 3.3.5a has no `SetGameUIShown`. `Code/Utility/UIRoot.lua` adds `addon.UIRoot` (frame on `WorldFrame`, same corners and scale as `UIParent`, scale re-synced every frame). The dialogue frame, Settings window, reward tooltip (frame and its delay driver), alert and Book frame now use it as parent. Anchors still point at `UIParent` (anchoring to a hidden frame works). `FadeHelper` is on `UIRoot` too (a frame created without a parent goes under `UIParent`), so it keeps running while `UIParent` is hidden. `ParchmentHidden` is triggered from the parchment's own `OnHide` script: a later `SetScript("OnHide")` had replaced the earlier `HookScript`, so the event never fired and the UI was never faded back in.
- Not ported: Show Chat Window, Show EXP Bar, Hide Sparkles, Hide Unit Names, Hide UI Enhanced Mode; Quest Item Display and the Blizzard tooltip stay on `UIParent` (hidden with it).
- To look at: UI fades out on opening an NPC and back in on Goodbye / Esc; quest chains (accept, next page) do not flicker; checkbox off with the dialogue open brings the UI back, on hides it; Settings window, tooltips, alert and Book stay visible while the UI is hidden; combat during a dialogue (UI returns, no "action blocked" message); Alt+Z during a dialogue; /reload with the dialogue open; changing the UI scale; Frame Size / Orientation still place the frame correctly under UIRoot (positions saved earlier); both themes for the checkbox.

## Show Copy Text Button: what was done (not tested in the game)

Retail (`Clipboard.lua`, `DialogueUI.lua` Clipboard section): a 24 px button in the top right corner (`-8, -8`) of the dialogue opens a window with the page's text in a multi-line edit box, to select and copy with Ctrl+C. The text also holds game IDs. Click the button again, click outside, press Esc in the box or type into the box to close it.

- `ShowCopyTextButton` (default false, as retail) in `DefaultValues`; checkbox row after Hide UI; strings `Show Copy Text Button (Desc)`, `Copy Text`, `Requirements`, `Money` in `Locales/enUS.lua`.
- `Code/Dialogue/Clipboard.lua`: the window (480 x 480, `ClipboardBackground` 9-slice, scroll frame + edit box in 12 px insets, Friz Quadrata 12, light grey text), `addon.CreateCopyTextButton` (icon 16 px in a 24 px button, alpha 0.6 and 1 on hover, theme slot of the sheet, tooltip "Copy Text" below the button with the custom `TooltipFrame`), `Clipboard:ShowContent / CloseIfFromSameSender / CloseIfShown`.
- `Code/Dialogue/ClipboardContent.lua`: builds the text from the stored page (`lastEvent`, `lastPage` in `DialogueUI.lua`): `[NPC: id] name`, quest line, body, Objectives, Rewards (xp, money, spell, title, items, honor, talents, arena) and the choices, Requirements on QUEST_PROGRESS, the quest / option rows on first-contact pages. Color codes and hyperlinks are stripped.
- `DialogueUI.lua`: creates the button on `SettingChanged.ShowCopyTextButton` (parent: the parchment frame), follows `ThemeChanged`, closes the window on a new page and when the parchment hides.
- **Position:** retail's `-8, -8` from the frame corner put the button in the transparent margin of `Parchment.blp` (the paper ends 135 of 1024 texels in from each side and starts 7 texels below the frame top), so it floated beside the paper. `ParchmentBackground:AnchorCornerWidget` anchors it 10 units inside the paper's top right corner (`cornerButtonX/Y` in the metrics, follows the frame size).
- **Not the same as retail (3.3.5a limits):** no `GLOBAL_MOUSE_DOWN` / `GLOBAL_MOUSE_UP`, so a click outside and the end of a selection drag are read with `IsMouseButtonDown` in the window's `OnUpdate`. No retail scroll bar: a small rail + thumb (wheel, thumb drag, drag-selecting past the edge scrolls) from `ScrollBar-Vertical-Rail / Thumb.blp`. No quest ID in the dialogue API: it is taken from the quest log by title, so a quest not accepted yet has `[Quest] title` without an ID. No gossip option IDs (`[Option] text`, `[Option: vendor] text` for typed options). NPC ID parsed from `UnitGUID("npc")` with the 3.3.0 layout from the docs (`sub(guid, -12, -9)`): not checked in the game. No `SetHighlightColor` (default selection color), no translator button / layout of two top widgets, no preview picture (`Art/PreviewPicture/CopyTextButton.jpg`). `GetCoinText` is used for money (documented in `API/Money.lua`).
- **Textures (converted, in `Textures\Shared\`):** `CopyTextButton.blp` (256 x 32), `ClipboardBackground.blp` (128 x 128). The scroll bar uses `Theme_Brown\ScrollBar-Vertical-*.blp`.
- To look at: button position at all four frame sizes (against the check mark on QUEST_COMPLETE), both themes (icon slot 1 and 2), tooltip position, opening on every page type, Ctrl+A / Ctrl+C in the box, scrolling a long quest (wheel, thumb, drag-select), click outside / on the button / Esc, closing with the dialogue, Hide UI on (window and tooltip must stay visible), toggling the checkbox with a dialogue open.

## Show NPC Name: what was done (not tested in the game)

Retail (`DialogueUI.lua` `ConcatenateNPCName`): with `ShowNPCNameOnPage` on and `UnitExists("npc")`, the page's main text becomes `Name: text` (gossip welcome text, quest text of every page type, quest greeting). Changing the option with a page open redraws it.

- `ShowNPCNameOnPage` (default false, as retail) in `DefaultValues`; checkbox after Show Copy Text Button; strings `Show NPC Name On Page (Desc)` in `Locales/enUS.lua`.
- `QuestTextLayout.lua`: local `ConcatenateNPCName`, used in `SetListPage` and `SetQuestText` (only when a page is given, so the Move sample is untouched). It runs at layout time, so the stored page, the Clipboard text and the Frame / Font Size redraws keep the plain body. Not applied to the objective text, as in retail.
- `DialogueUI.lua`: `SettingChanged.ShowNPCNameOnPage` calls `RedrawPage` (no reveal fade, QUEST_COMPLETE reward choice is cleared by the redraw like for the size changes).
- Not done: preview picture (`Art/PreviewPicture`), translated strings for other locales (only enUS exists here).
- To look at: gossip, quest greeting, quest detail / progress / complete with the option on; toggling with a page open; name when the NPC has no name; Frame Size change keeps the prefix; Copy Text content has no extra prefix.

## Show Quest Type: what was done (not tested in the game)

Not in retail (retail always shows its quest header tags). Here it is a checkbox, **off by default**: off means nothing is shown above the title.

- `ShowQuestType` (default false) in `DefaultValues`; checkbox after Show NPC Name with `preview = "QuestType"`, `ratio = 2`; strings `Show Quest Type (Desc)` in `Locales/enUS.lua`.
- `ParchmentBackground:SetTags` passes nil to `HeaderTags` when the option is off. `DialogueUI.lua`: `SettingChanged.ShowQuestType` re-applies the stored page's tags (quest pages only).
- The temporary hardcoded Weekly + Dungeon (5) tags in `QuestData.lua` were removed after the screenshot.
- **Preview border:** retail scales the tiled slice (margin 8) by 768 / screen height, i.e. one texel = one screen pixel. Ours used 1 unit per texel (about 40% thicker at 1080p), now `BACKGROUND_SCALE` (0.75). Affects Theme, Copy Text Button and Quest Type previews.
- **Preview picture:** `Textures\PreviewPicture\QuestType.blp` (512 x 128). The screenshot was 409 x 124 and was stretched to 512 x 128 for the power of 2, so the option uses `ratio = 409 / 124`. `SetDescription` now takes any `ratio` (width / height; the width is capped at the full preview width, the height follows from the ratio, text and decor move with it), so the picture shows at its original proportions. Ratio 1 and 2 behave as before.
- To look at: option off (no pills), on (pills), toggling with a quest page open, gossip pages (no pills either way), both themes.

## Subheader: what was done (not tested in the game)

Retail's `{type = "Subheader", name = L["Quest"]}` row (`SetSubheader` in `Settings.lua`): a group label, not an option.

- Schematic: `{type = "Subheader", name = L["Quest"]}` after Show Quest Type (`L["Quest"]` already existed).
- `CreateOptionRow` (`Settings.lua`): label upper case in `DUI335_SettingsSubheader` (retail `DUIFont_Settings_Disabled`: LightBrown / DarkModeGrey50), no widget, no hover glow, no click, hovering clears the description. Background plate `LabelBackground.blp` (both themes exist): 3 x font height high, text width + 2.2 x font height wide (min = height), starting one font height left of the label, `CreateSubheaderBackground`.
- The plate is the top left 204 x 54 texels of the 256 x 64 file, margins 24 / 24 / 24 / 16. 24 + 16 > 36, so the margins are scaled by 0.9 to fit (assumed to match retail's slice squeeze, not checked). `CreateEdges` maps the whole file, so its texcoords are overridden for the region.
- A second label, **Readables**, follows the Quest group (after Use Blizzard Tooltip): `{type = "Subheader", name = L["Readables"]}`, new string `L["Readables"]` in `Locales/enUS.lua`. Retail puts its Book options under it (`BookUI Enable`, Frame Size, ...), to be ported later.
- To look at: plate shape and text alignment in both themes, hover on the row (no glow, empty description), the Quest label fits inside the row height.

## Quest Difficulty: what was done (not tested in the game)

Retail (`QuestDifficulty.lua`, `QuestDifficultyStyle`): 0 Off, 1 Level (default), 2 Name. **Both** (3) is not in retail: level prefix and difficulty word together. Only applies to the quest rows of the first-contact list (GOSSIP_SHOW / QUEST_GREETING).

- `QuestDifficultyStyle` (default 1) in `DefaultValues`. Option under the Quest subheader, `preview = "QuestDifficultyStyle"`, `ratio = 2`; strings copied from retail's enUS (`Quest Difficulty ...`, `QuestDifficultyStyle ...`).
- `GossipDataProvider.lua`: **Off** = no level, no difficulty word. **Level** = coloured level left of the title (as before). **Name** = no level; difficulty word as the right-hand note when level minus player level is above 2 or below -2 (> 5 Very Hard, 3..5 Hard, -3..-5 Easy, < -5 Low Level; Normal shows nothing). The note replaces Trivial / Repeatable when there is a difficulty word, as in retail. Quest level comes from `GetAvailableLevel` / `GetGossipAvailableQuests` etc. (3.3.5a gives it directly, so no "level not cached yet" placeholder like retail's `IsQuestLevelCached`).
- `GossipDataProvider:RefreshQuestText(page)` rebuilds text and note of the stored rows; `DialogueUI.lua` calls it and `RedrawPage` when the setting changes with a list page open.
- `Settings.lua`: option rows now accept retail's `tooltip` function; it replaces the description with the text of the chosen value (`QuestDifficultyStyle_Tooltip`).
- Not ported: retail's `validationFunc` (hides the row on clients without the API; 3.3.5a always has it), the "Unfinished" grey of active quests in Name mode (no level colour there anyway).
- **Texture (converted, in `Textures\PreviewPicture\`):** `QuestDifficultyStyle.blp` (512 x 256, retail's `QuestDifficultyStyle.jpg`).
- To look at: the three styles on a GOSSIP_SHOW and a QUEST_GREETING list with quests of different levels, switching the style with the list open, note width vs long titles, both themes, preview picture and per-value description.

## Show Upgrade Arrow: what was done (not tested in the game)

Retail (`ItemEvaluator.lua`, `API.lua` item level delta, `ItemButtonSharedMixin:ShowUpgradeIcon`): a green arrow at the bottom left of a reward item's icon when the item is a potential upgrade. The 335 addon had no arrow at all, so both the arrow and the setting were added.

- `ShowUpgradeArrow` (default true, as retail) in `DefaultValues`. Checkbox after Quest Difficulty (Quest group), strings `Show Upgrade Arrow (Desc)`. Retail's extra tooltip text about third-party evaluators (Pawn etc.) is not ported: only the item level rule exists here.
- **Pawn required (replaces the retail item level rule, which did not suit us).** `TooltipCompare:IsPawnAvailable()` checks, at call time, that Pawn's globals exist (`PawnGetItemData`, `PawnGetItemDataForInventorySlot`, `PawnCommon.Scales`), so load order does not matter. `TooltipCompare:IsUpgrade(link)` returns `isUpgrade, isReady`: with Pawn, the item is an upgrade when its Pawn value beats the equipped item (without enchants / gems) in at least one of the player's enabled scales, in any of its slots (ring / trinket: 2 slots; an empty slot counts as an upgrade when the item has any value; one-hand weapon: 2nd slot only when it holds a weapon). Armor slots holding another armor type (cloth over leather) are skipped. Without Pawn nothing is an upgrade. `isReady` is false while `GetItemInfo` has no data for the item. Written against Pawn 1.3.8 in `AddOns\Pawn` (`Item.Values` = `{scale, value, unenchantedValue, ...}`); **not tested in the game**.
- **Menu:** label "Show Upgrade Arrow (Pawn Required)". Without Pawn the checkbox is dimmed and unchecked, the description adds that Pawn is missing plus the download link (https://warperia.com/addon-wotlk/pawn/download/ -> see `PAWN_URL` in `Settings.lua`), a copy icon (the Copy Text button from `Clipboard.lua`) sits right after the option name while the option is disabled (option field `copyLink`, made in `CreateCheckbox`, shown by `widget:Refresh`). The icon and a click on the row open the Clipboard window with the link already selected (`Clipboard:ShowContent(text, sender, selectAll)`), ready for Ctrl+C. 3.3.5a addons cannot write to the clipboard, open a browser or make clickable URLs. Not tested in the game. New checkbox fields: `isDisabledFunc`, `onDisabledClick`.
- `RewardLayout:UpdateUpgradeMarkers` runs after every layout: only big buttons of kind item, not "required", usable (`entry.isUsable`, so unusable items get the red "!" and no arrow). Not-ready items are asked again once after 0.8 s. `SettingChanged.ShowUpgradeArrow` re-runs it without a redraw (a reward choice is kept).
- `RewardItemButton:SetUpgradeMarker(shown, animate)`: 32 px arrow, `CENTER` on the icon's `BOTTOMLEFT` (1, 5), on its own frame above the border. While choosing a reward (`page.canChoose`) it flies up as retail (0.5 s delay, 12 px rise over 0.5 s with outSine, fade in).
- Not ported: cosmetic items (no such thing in 3.3.5a), third-party evaluators, the small reward rows, the Quest Item Display.
- **Texture (converted, in `Textures\Shared\`):** `ItemIsUpgrade.blp` (64 x 64, retail's `Art/Icons/ItemIsUpgrade.png`).
- To look at: arrow on choices and on fixed rewards, both themes, a ring / trinket / one-hand weapon with empty and full slots, a shield equipped with a one-hand weapon reward, toggling the checkbox with a quest page open, items not cached yet (arrow appears after ~1 s), arrow vs the quality triangle and count text.

## Mark Highest Sell Price: what was done (not tested in the game)

Retail (`DialogueUI.lua` `RequestSellPrice`, `SetHighestSellPrice`): on a reward choice with 2+ choices, a 15 px gold coin at the icon's top left marks the choice with the highest vendor price.

- The coin (`RewardItemButton:SetSellMarker`) and the logic (`RewardLayout:UpdateSellMarker`) already existed; the setting had no menu row. Added: checkbox after Show Upgrade Arrow (`preview = "MarkHighestSellPrice"`, `ratio = 1`), strings `Mark Highest Sell Price (Desc)` (retail enUS), and `SettingChanged.MarkHighestSellPrice` re-runs the marker without a redraw.
- Logic now as retail: unit price (stack count ignored); if any choice has no price (not cached or unsellable) nothing is marked, and it asks once more after 0.8 s. Before, the best of the known prices was marked, with count.
- Default is now **false** as retail (was true).
- **Texture (converted, in `Textures\PreviewPicture\`):** `MarkHighestSellPrice.blp` (256 x 256, retail's preview).
- To look at: 2+ choices with different prices, one unsellable choice (no coin), uncached items (coin after ~1 s), toggling with the page open, coin vs the upgrade arrow and quality triangle.

## Use Blizzard Tooltip: what was done (not tested in the game)

Retail (`RewardTooltipCode.lua`): a plain checkbox (no preview), default off. On: the reward button shows the default `GameTooltip` at the same anchor instead of our tooltip. Retail also moves `GameTooltip` under a top frame (`TakeOutGameTooltip`) so it stays above the dialogue, and puts it back (`RestoreGameTooltip`) on leave / when the option is turned off.

- The logic (`RewardTooltip:ShowBlizzard`, `UseBlizzardTooltip` default false) already existed as a `/run` switch; added the checkbox after Mark Highest Sell Price (Quest group) and the strings `Use Blizzard Tooltip (Desc)` (retail enUS).
- `TooltipItem.lua`: `RewardTooltip:TakeOutGameTooltip` / `RestoreGameTooltip` as retail, but the top frame (TOOLTIP strata, level 100) is a child of `addon.UIRoot`. That fixes the gap noted under Hide UI: the Blizzard tooltip no longer disappears with `UIParent`. `SettingChanged.UseBlizzardTooltip` (off) restores the parent.
- Not ported: retail's `GameTooltip_ShowCompareItem` call (not in the docs for 3.3.5a, so the Blizzard tooltip has no comparison; our own tooltip keeps Shift comparison), currency / reputation / skill / follower / war mode entries (do not exist in 3.3.5a), `ShowHyperlink`, reward context text.
- To look at: checkbox on, hover an item and a spell reward (default tooltip at the icon's top right); with Hide UI on the tooltip stays visible; off again with a page open (our tooltip returns, normal GameTooltip works elsewhere, e.g. bags / world units); both themes for the row.

## Readables Frame Size: what was done (not tested in the game)

Retail (`BookUI.lua`): `BookUISize` 0..3 = 0.9 / 1.0 / 1.1 / 1.25 (4 = 1.4 is only forced by Mobile Device Mode); `CalculateSizeData` multiplies every raw size by `PIXEL_SCALE (0.53333) x multiplier`; default 1 (Small). The option is only shown while "Use new UI for Readable Objects" is on; we have no such switch (the new UI is always on), so the row is always shown.

- Our `Code/Book/BookUI.lua` already used the same table (`SIZE_SCALES`), `PIXEL_SCALE` and default (`BookUISize = 1`), so **no size values changed**; only the menu row was missing.
- Row: ArrowOption under the Readables subheader (`Settings.lua`), 4 choices (the 1.4 step is left out, no Mobile mode), strings reuse `Size ...`; `BookUI Frame Size Desc` is new in `Locales/enUS.lua`.
- Size is read in `CalculateSizeData` every time a book is built. `SettingChanged.BookUISize` (and `BookFontSize`) now also call `Book:Build()` again on an open book from the cached pages (reading position kept), so the change shows at once (`RebuildOpenBook` in `BookUI.lua`). Retail does the same through `Settings_FrameSize` (re-run `CalculateSizeData` + `Resize`), but leaves images until the cache is wiped; ours re-lays out images too.
- To look at: all four sizes on a short and a long book, a book with images, close button / title / page buttons / footer positions, change with a book open (old size stays until the next one).

## Readables Keep Window Open: what was done (not tested in the game)

Retail (`BookUI.lua` EventListener, `Settings.lua`): plain checkbox `BookKeepUIOpen` (default off, no preview) under Readables. The game sends `ITEM_TEXT_CLOSED` when you walk away from the object (or interact with another one); with the option on the book is not hidden then. It closes with Esc, right click or the close button. Talking to an NPC (`GOSSIP_SHOW`, `QUEST_*`) and cinematics still close it. Retail only shows the row while "Use new UI for Readable Objects" is on; we have no such switch, so it is always shown.

- The behaviour already existed: `BookEvents.lua` `ScheduleCloseCheck` skips `Book:Hide()` when `GetDBBool("BookKeepUIOpen")`, and `Initialization.lua` has the default `false`. Only the menu row was missing.
- Added: checkbox after the Readables Frame Size row (`Settings.lua`), strings `BookUI Keep UI Open (Desc)` (retail enUS) in `Locales/enUS.lua`. No live callback needed: the value is read when the game closes the readable.
- Esc / right click are the same as retail (`Book` binds Esc while shown, right click hides, see `BookUI.lua`).
- To look at: option on, open a book and walk away (stays open, Esc and right click close it, `CloseItemText` is called on hide); option off (closes ~0.03 s after walking away); opening another readable while one is kept open; talking to an NPC with it kept open (closes); toggling with a book open; both themes for the row.

## Readables Show Location: what was done (not tested in the game)

Retail (`BookUI.lua`, `HeaderFrameMixin:SetLocation`): checkbox `BookShowLocation`, no preview. For a readable that is a game object (not a bag item) the header shows its location (zone and coordinates) above the title. Toggling with the book open shows / hides it at once.

- The display already existed: `Book:UpdateSourceButton` shows `BookItem:GetLocation()` ("Zone  x, y", `GetRealZoneText` + `GetPlayerMapPosition`) for world readables, and the Plain Letter sender for bag items (not tied to the option). Default is `true` in `Initialization.lua` (retail: false, a deliberate difference noted there), left as is.
- Added: the checkbox after Keep Window Open, strings `BookUI Show Location (Desc)` (retail enUS), and a live `SettingChanged.BookShowLocation` callback in `BookUI.lua`. The location is stored in `Book.worldLocation` at build time, so turning the option on later shows the position where the book was opened. If the option was off at build time it is read when switched on (the player's current position, which differs if they walked away with Keep Window Open on).
- Difference to retail: retail stores the location per object in its cache; ours is read at build time.
- To look at: world book / plaque with the option on and off, toggling with the book open, a bag item (no location, letter sender still shown), zone text with the world map open.

## Readables Show Item Description: what was done (not tested in the game)

Retail (`BookUI.lua` `Settings_BookUIItemDescription`, `BookUI_Component.lua` `SourceItemButtonMixin`): your guess was right, it is for readables. When the readable is an **item** (e.g. a letter or note in the bags), the quoted flavor line at the bottom of its tooltip (`"Dear friend, ..."`) is shown in a strip with the item's round icon above the book frame. Plain checkbox, no preview, default off in retail. It affects nothing else (no layout of the book itself, no other setting). Retail polls the tooltip up to 3 times (0.2 s) until the line is there.

- The display already existed: `BookItem:GetDescription` (scans the bag item's tooltip for the last line starting with `"`), `Book:ShowSource` (round icon, text, paper strip) and `UpdateSourceButton`, all driven by `BookUIItemDescription` (default `true` in `Initialization.lua`, retail: false, deliberate difference noted there, left as is). Readables standing in the world have no item, so nothing shows for them.
- Added: checkbox after Show Location (`Settings.lua`), strings `BookUI Show Item Description (Desc)` (retail enUS) and a live `SettingChanged.BookUIItemDescription` callback in `BookUI.lua` (shows / hides the strip on an open book from a bag item).
- Not done: retail's tooltip re-poll (ours scans the bag slot directly), the first-time-on case for an item whose tooltip is not loaded yet.
- To look at: a bag readable with a quoted line (e.g. a letter) with the option on / off, toggling with the book open, a world readable (no change), both themes for the row.

## Readables Darken Screen: what was done (not tested in the game)

Retail (`BookUI.lua` `Settings_BookDarkenScreen`, `BookUI.xml` `ScreenVignette`): `BookDarkenScreen` (default true in retail, **false here**) only shows / hides a dark gradient texture (`ScreenDarken`) behind the **Book** frame, on the side of the screen under the book. It affects nothing else. It is a Readables option, not a dialogue one: retail's dialogue frame has its own always-on `SharedVignette` (full-screen `ScreenVignette`, fades in 0.74 s / out 0.5 s, shared with the Book through `TryShow` / `TryHide`), which no setting controls.

- Already in ours: `Book.vignette` (`ScreenDarken.blp`, full-screen anchors, drawn behind the pages), shown in `Book:ShowUI` from `BookDarkenScreen` (default now false), and a live `SettingChanged.BookDarkenScreen` callback. Only the menu row was missing.
- Added: checkbox after Show Item Description (`Settings.lua`), strings `BookUI Darken Screen (Desc)` (retail enUS).
- Not done: the dialogue frame has **no** screen vignette in this addon (retail's `SharedVignette`), and it is not tied to this setting in retail either, so it was left out. It could be added as a separate visual feature.
- To look at: book open with the option on / off, toggling with the book open, vignette side and size at the four book sizes.

## Control tab: what was done (not tested in the game)

Retail (`Settings.lua` Control tab, `Settings_Keybinding.lua`, `Keybindings.lua` `BindingUtil`, `KeyboardControl.lua`): Input Device, then Use Custom Bindings (branch mark = depends on the option above), then a key button per action (Confirm, Text To Speech, Toggle Settings, Option 1-9). Click a key button, press a key to assign it; right click puts the default back.

- **Input Device:** ArrowOption with one choice, "Keyboard & Mouse" (`InputDevice` = 1 in `DefaultValues`). A single choice hides the arrows (`CreateArrowOption`); the bar stays. No Xbox / PlayStation / Switch (no gamepad in 3.3.5a).
- **Use Custom Bindings:** checkbox (`UseCustomBindings`, default false), shown while `InputDevice` = 1. The key rows under it (`branchLevel = 2`, two steps of branch mark) are shown only while it is on. The branch mark now works for every row type (`CreateOptionRow`), not just Custom rows; `branchLevel` 0 = no mark, default 1.
- **`Code/Utility/Keybindings.lua` (`addon.BindingUtil`, new, in the .toc):** retail's logic without TTS and gamepad. Defaults: Confirm SPACE, Settings F1, Option 1-9 = `1`..`9`. Custom keys are saved in `DialogueUI_335_DB.CustomBindings = {action = key}`. A key belongs to one action (assigning it takes it from the other one); an action without a custom key keeps its default unless the player took that key. Invalid keys: Esc, Tab, Backspace, CapsLock, modifiers, PrintScreen. `GetActiveActionKey(action)` is what the dialogue uses (defaults when custom bindings are off). It fires `"CustomBindingChanged"` on every change and on load. Retail's `PrimaryControlKey` option (Space / interact key / off) was **not** ported.
- **Keys in the dialogue (replaces the hard-coded ones):** `FooterButtons.lua` `UpdateKeys` binds the Confirm key to Accept / Continue / Complete (or to the first row of a list, or Goodbye when there are no rows), the Settings key to the settings toggle, Option N keys to the list rows. Esc stays Decline / Cancel / Goodbye (not rebindable in retail either). The key badge of Accept / Continue / Complete shows the Confirm key (no badge when it has none). `GossipDataProvider` rows carry `keySlot` (1-9) instead of a fixed `key`; `QuestTextLayout` looks the key up when it lays the row out ("N. text" prefix and badge), and `DialogueUI.lua` redraws an open list when a key changes. `SettingsUI:UpdateKeys` uses the Settings key for the toggle (Esc closes the window as before).
- **Keybinding row (`CreateKeybinding`, `Settings.lua`):** 144 x 24 button, `Settings-Keybinding.blp` rows normal / hover / waiting (retail texcoords, the sheet layout is assumed to match retail's PNG), text color by state and theme. Left click waits for a key (click again, click away, scroll, change tab, close the window or Esc cancel); right click resets to the default. Row description = what the action does + hint + "Bound to: KEY".
- **Capturing a key in 3.3.5a (`KeybindCapture`):** retail uses a keyboard frame with `SetPropagateKeyboardInput(false)` and `GLOBAL_MOUSE_DOWN`; neither exists. While waiting, every candidate key (A-Z, 0-9, F1-F12, numpad, arrows, punctuation, Space, Enter ...) is an override binding that clicks one hidden button with the key name as the mouse button argument (`SetOverrideBindingClick`'s last parameter), so the game does nothing else with the key. The dialogue's and window's own override bindings are released while waiting (`"KeyCaptureChanged"`) and set again after. A click elsewhere is read with `IsMouseButtonDown`. Not started in combat; entering combat cancels it.
- **Right Click To Close UI** (`RightClickToCloseUI`, default true as retail; checkbox after the key rows, shown while `InputDevice` = 1, no branch mark as retail's): a right click on the parchment or its text closes the dialogue (`ParchmentBackground:RequestClose`, same as Goodbye), a right click on a reward item too (`RewardLayout:OnButtonClick`, before the modified-click checks as retail), and on the Book frame (the Book closed on right click unconditionally before; now only with the option on, as retail). Other buttons (footer, list rows) are not closed by a right click. Retail checks `IsMouseMotionFocus` on its frame; here the paper and the text area each have their own OnMouseUp. Not tested in the game: also check that right click on the Move sample closes it, and that left-drag in Custom still works.
- **Press Tab To Select Reward** (`CycleRewardHotkeyEnabled`, default false as retail; checkbox after Right Click To Close UI, shown while `InputDevice` = 1): on QUEST_COMPLETE with a reward to choose, Tab selects the next choosable reward (first one when none is chosen) and wraps around; Shift-Tab goes back (retail does the same with the modifier). `RewardLayout:CycleChoice` uses the normal `SelectChoice`, so the Complete button enables itself as with a click. Tab / Shift-Tab are override bindings (`FooterButtons.lua` `UpdateKeys`, hidden buttons `DialogueUI335CycleReward(Back)`), only set while a choice is pending, so Tab keeps its game function otherwise. Not tested in the game (check that Shift-TAB reaches the override binding).
- Not done: modifier combinations (Shift-A etc.), mouse buttons as keys, the other retail Control option (**Disable Hotkey For Teleport**: skipped on purpose. Retail's `GossipData_Teleport.lua` is a list of creature IDs of post-WotLK one-way teleporters (Delves, Dornogal, Suramar / Antorus portals, LFR NPCs ...); the few WotLK-era entries are an engineering item (Wormhole Generator) and a game object (Ulduar Teleporter), neither a creature gossip. The option would do nothing. If a WotLK one-way teleport NPC turns up, add a list and `GossipDataProvider:IsGossipHotkeyEnabled` check then), key names are shown as the game names them (`NUMPAD1`, `PAGEUP`), not localized.
- **To look at (first thing: is the key name really passed as the click's button argument?):** Use Custom Bindings on / off shows / hides the 11 rows with the branch marks; assign a letter to Confirm and Accept a quest with it (badge text, Space no longer accepts); assign `A` to Option 1 and use it on a gossip list; assign F2 to Toggle Settings and open / close the window with it; assign a key that is already used (the other row becomes default or "Not Bound"); right click resets; Space / F1 / Esc while waiting must not jump / open / close anything (Esc only cancels); click away / wheel / tab / close cancel; combat while waiting; Input Device row has no arrows; both themes for the key button; settings and bindings survive /reload.

## Press Button To Scroll Down: what was done (not tested in the game)

Retail (`DialogueUI.lua` `ScrollDownOrAcceptQuest`, `IsScrollPassObjectives`, `SetQuestTextRange`): plain checkbox `ScrollDownThenAcceptQuest` (default off, no preview), no dependency on other options. On a quest offer (QUEST_DETAIL), when the Confirm key is pressed and the quest text (body and objectives, not the rewards under it) is not fully in view, the page scrolls to the bottom instead of accepting; the next press accepts. A mouse click on Accept always accepts.

- Added: the setting in `DefaultValues`, the checkbox after Press Tab To Select Reward (Control tab, under the Quest label), strings `Press Button To Scroll Down (Desc)` (retail enUS).
- `QuestTextLayout`: `questTextEnd` (offset where the quest text ends, stored in `SetQuestText` before the suggested group size and the rewards), `IsScrollPassObjectives` (retail's `questTextRange`, computed on demand so Frame / Font Size changes follow; the target is capped at the real scroll range) and `ScrollToBottom`. `ParchmentBackground:ScrollDownIfNeeded`.
- Key: a mouse click and a key press cannot be told apart on one button in 3.3.5a, so on QUEST_DETAIL with the option on `FooterButtons.lua` binds the Confirm key to a hidden button (`DialogueUI335ScrollOrAccept`) that scrolls, or clicks Accept when the text is in view. `SettingChanged.ScrollDownThenAcceptQuest` re-binds. Retail's "no feedback" return value is not needed (the Accept button only shows its press feedback when it is clicked).
- Not ported: retail's auto-accept quest path (`ScrollDownOrAcceptQuest(true)` for auto-accept quests has no 335 counterpart).
- To look at: a quest with long text and the option on (first Confirm press scrolls, second accepts, rewards below the objectives are not scrolled past the first press), a short quest (accepts at once), option off (accepts at once), mouse click on Accept with the option on, Frame / Font Size change with the quest open, custom Confirm key, other pages (list, QUEST_COMPLETE) unaffected.

## Press Escape To Decline Quest: what was done (not tested in the game)

Retail (`DialogueUI.lua` `HideUI(cancelPopupFirst, fromPressingKey)`, `MarkQuestIsFromGossip`, `SetButtonDeclineQuest` / `SetButtonCancelQuestProgress`, `KeyboardControl.lua`): plain checkbox `EscapeToDeclineQuest` (default off, no preview). A quest chosen from a list (gossip or quest greeting) is marked `questIsFromGossip`. The Decline button (quest offer) and the Cancel button (quest progress) of such a quest call `DeclineQuest()` (back to the previous page); any other quest closes the conversation. Pressing **Esc** closes everything, unless this option is on and the quest came from a list: then Esc does `DeclineQuest()` like the button.

- Added: the setting in `DefaultValues`, the checkbox after Press Button To Scroll Down (Control tab, under the Quest label), strings `Press Escape To Decline Quest (Desc)` (retail enUS).
- `ParchmentBackground`: `MarkQuestIsFromGossip` / `IsQuestFromGossip`; the mark is set in `OnClick_Row` (`QuestTextLayout.lua`) for quest rows (not option rows) and cleared when a list page is shown and when the frame hides.
- `FooterButtons.lua`: `OnClick_Decline` (Decline, and Cancel on QUEST_PROGRESS) goes back for a marked quest, closes otherwise. **Behaviour change:** before, Decline always called `DeclineQuest()`; now a quest that did not come from a list (single-quest NPC, quest item) closes with `RequestClose` as retail. QUEST_COMPLETE keeps closing. Esc is no longer a binding to the exit button but to a hidden button (`DialogueUI335EscapeKey`): option on + marked quest on QUEST_DETAIL / QUEST_PROGRESS -> `DeclineQuest()`, anything else -> `RequestClose()` (retail's Esc closes everything, so with the option off Esc no longer goes back, which the old Decline key did). Esc still belongs to the Settings window while it is open.
- Not ported: retail's `not InCombatLockdown()` check (a modern restriction), the gossip-confirm popup cancel (`requireGossipConfirm`, no such popup here), `FlagQuestDeclined` (repeat-decline hint, not in 335).
- Unverified: whether `DeclineQuest()` makes the 3.3.5a client send the list again (GOSSIP_SHOW / QUEST_GREETING). If it does not, Decline just closes the dialogue, as before.
- To look at: quest chosen from a gossip list and from a quest greeting list (Decline button, Esc with the option on and off, Cancel on QUEST_PROGRESS), a quest from an NPC without a list (Decline / Esc close), option rows (no mark), Esc on the list and on QUEST_COMPLETE (closes), Esc with the Settings window open, accept a quest and see the list again (mark cleared), right click still closes.

## Auto Quest Popup (and its Move Position): skipped

Retail reroutes QUEST_DETAIL to a popup when the event carries a `questStartItemID`, when `QuestIsFromAreaTrigger()` is true (declined before, or `QuestGetAutoAccept()` / in combat), and uses `AddAutoQuestPopUp`, `RemoveAutoQuestPopUp`, `ShowQuestOffer`, `PlayAutoAcceptQuestSound`, `AcknowledgeAutoAcceptQuest` and the QUEST_ACCEPTED questID payload. 3.3.5a has none of these (only an undocumented `QuestGetAutoAccept` stub in wow-docs; Objective Tracker popups came with Cataclysm), so the feature cannot trigger. Not implemented; both rows stay off the Gameplay tab. Not verified in game (no Blizzard FrameXML source available); if auto-accept quests turn out to matter, print `QuestGetAutoAccept()` on QUEST_DETAIL for a known one (e.g. the Death Knight start) and revisit.

## Gameplay tab: Quest Item Display (not tested in the game)

Retail rows: Quest Item Display (checkbox, preview picture, ratio 2) with four sub-rows shown only while it is on: Ignore Seen Items, Await World Map, Move, Reset Position. The popup and its options (`QuestItemDisplay`, `QuestItemDisplayHideSeen`, `QuestItemDisplayAwaitWorldMap`, `QuestItemDisplayPosition`) already existed in `Widget_QuestItemDisplay.lua`; they had no menu rows and no Move mode.

- Rows: `Settings.lua` Gameplay tab, sub-rows use `requiredParentValueAnd = {QuestItemDisplay = true}`. Retail's `requireSameParentValue` has no equivalent here, this is the same thing. Retail calls the world map key `QuestItemDisplayDynamicFrameStrata`; ours stays `QuestItemDisplayAwaitWorldMap`.
- Move: `QuestItemDisplay:ToggleEditMode()` shows a sample popup (question mark icon, title, "Left-click and drag to move the window.", no button, no countdown) at the current position. Drag to move, close button or right click ends it. It also ends when the Settings window closes, the tab is left, or the option is turned off. Not started in combat (the popup holds a secure button).
- Reset Position: shown only when a custom position is saved (`validationFunc`). Dragging the popup updates the row at once (`SettingChanged.QuestItemDisplayPosition`).
- Await World Map: now applies at once (`SettingChanged.QuestItemDisplayAwaitWorldMap` calls `ApplyWorldMapState`), not only on the next popup.
- Texture: preview picture `Textures\PreviewPicture\QuestItemDisplay.blp` (converted, in place).
- To look at: the preview picture, the sub-rows appearing and going with the checkbox, Move (sample appears, drag, Reset appears, Reset, close with the X / right click / switching tab / closing Settings), Move during combat (does nothing), Await World Map toggled with the map open and a popup showing, Ignore Seen Items on and off with a looted quest item.

## Valuable Reward Popup: what was done (not tested in the game)

Retail (`Widget_QuickSlot.lua`, `Widget_ItemButton.lua`, `ItemEvaluator.lua`): `QuickSlotQuestReward` (default off). Turning in a quest starts a 3 s watch of `CHAT_MSG_LOOT`. A new item of the player's own is classified (equipment, container, cosmetic, mount, pet, toy, decor); equipment only counts when the item evaluator (item level, or a third party like Pawn) says upgrade. A popup button then offers to use / equip it: coloured strip by quality, round icon border, upgrade arrow at the icon, optional hotkey badge, close button with the auto close countdown (4 s idle, 2 s when the game equipped it, 1 s after the click), "Equipped" text in green when done. Left empty at the bottom centre (196 up) or at a saved position. Move / Reset rows as the Quest Item Display. Retail's popup also opens chests and learns cosmetics, mounts, pets and toys.

- **Scope (your decision): equipment only, no secure frames.** No chests (opening one has a Use effect, so `UseContainerItem` is protected: it would need `SecureActionButtonTemplate`, not in wow-docs), no mounts / pets (needs a "known" check with the companion APIs), no cosmetics / toys / decor (do not exist). The "Press Button To Use" hotkey is in (see below).
- **Pawn required**, same rule as Show Upgrade Arrow (`TooltipCompare:IsUpgrade`, which already compares the item to every slot it fits and skips other armor types). Without Pawn the checkbox is greyed out and unchecked, the label says "(Pawn Required)", a copy icon / click opens the Clipboard window with the download link (the `UpgradeArrow_*` functions are reused), and the Move / Reset rows stay hidden.
- Setting `QuickSlotQuestReward` (default false) and `QuickSlotPosition = {x, y}` (center, from the bottom left) in `Initialization.lua`. Rows: Gameplay tab, under a new Quest subheader, after the Quest Item Display rows. Move toggles a sample popup (purple strip, question mark icon, drag it; close button, right click, closing Settings, leaving the tab or turning the option off ends it). Reset only shows with a saved position; a middle click on the popup resets it too (as retail). Dragging only works in the sample, so a click on a real popup can never turn into a drag.
- `FooterButtons.lua` `OnClick_Complete` triggers `"TriggerQuestFinished"` after `GetQuestReward`. `Code/Widget/Widget_QuickSlot.lua` (new, in the .toc after Quest Item Display) listens for 3 s (plus 1 s while it waits for the item to reach the bags, `BAG_UPDATE`, as retail), reuses `addon.IsOwnLootMessage` (the own-loot patterns of the Quest Item Display) and asks again once after 0.8 s when the item is not cached (`isReady` false).
- Popup: `Textures\Shared\QuestFlyoutButton.blp` (512 x 512: six 64 px strips grey / green / blue / purple / red / teal, the round border at 416,416, 96 px). Sizes as retail (border 52, icon 52 x 64/96, strip height text + 24, text starts 40/96 x 52 into the strip, text at most 192 wide). The strip keeps its proportions (the left texcoord moves with the width). The upgrade arrow is `ItemIsUpgrade.blp` (already there). Strip colour by quality (poor / common grey, uncommon green, rare blue, epic purple, others red). The close button is `WidgetCloseButton.blp` and only shows the countdown (ring of 60 dots, as the Quest Item Display); it works in the sample only, as retail's `SetInteractable(false)`.
- Equip: left click calls `EquipItemByName(link)` (not `UseContainerItem`, which would sell the item if a vendor window is open). The button is greyed out in combat. The popup follows `PLAYER_EQUIPMENT_CHANGED` / `BAG_UPDATE`: equipped -> "Equipped" and a 1 s countdown; item gone (sold, traded) -> the popup closes. Right click closes. The countdown pauses while the cursor is over the popup (read with `GetCursorPosition`, no `IsMouseMotionFocus`).
- **Press Button To Use** (`QuickSlotUseHotkey`, default true as retail; checkbox under the Move / Reset rows, no branch mark, shown with the popup option and Pawn): the popup shows a dark key badge (space bar icon for Space, otherwise the key name) before the text, and the Confirm key (`BindingUtil:GetActiveConfirmKey`, so custom bindings count) equips the item. It is an override binding that clicks the popup button (`DialogueUI335QuickSlotPopup`), set while the popup is usable, out of combat, and cleared when it closes, after equipping or when disabled. It takes the key (Space = jump) for the few seconds the popup is up, as retail. The badge goes away with "Equipped". The Move sample shows the badge but binds nothing. Toggling the option or changing the Confirm key updates a shown popup.
- Not the same as retail: no `GLOBAL_MOUSE_DOWN` (right click uses the button's own `OnClick`), no `HideUI` handling (the popup is on `UIParent`, like the Quest Item Display; it fades in with the UI when the dialogue closes), the loot message pattern is used to find the link (`|Hitem:...|h[name]|h`, assumes the 3.3.5a format). A ring / trinket goes to the slot the game picks (the first), even when Pawn compared it to the second.
- **Textures (converted, in place):** `Textures\Shared\QuestFlyoutButton.blp` (512 x 512), `Textures\PreviewPicture\QuickSlotQuestReward.blp` (512 x 256, shown with `ratio = 2`).
- To look at: with Pawn installed and a Pawn scale enabled, turn in a quest with a reward that beats the equipped item (popup appears above the action bar, slides up, ring fills in 4 s, click equips -> "Equipped", closes ~1 s later); a reward that is not an upgrade, a reward already worn (2 s), several loot lines in a row (the last upgrade replaces the earlier popup), combat while it shows (greyed out, back after combat), bind-on-equip confirmation, hover pauses the ring, right click closes, an item still uncached; Move sample (drag, Reset appears, Reset, close with X / right click / tab change / closing Settings), position survives /reload; no Pawn (greyed checkbox, copy link, no Move rows); option off while a popup shows.

## Minimap tab: what was done (not tested in the game)

Not in retail. A fourth tab, **Minimap**, with one checkbox, and a minimap button that opens the Settings window. Modelled on DragonUI's settings button (`DragonUI\modules\minimap_collector.lua`: round button orbiting the minimap rim at a saved angle, left-drag to move, square orbit when `GetMinimapShape()` says SQUARE), without its collector, skinning or fade.

- Settings: `ShowMinimapButton` (default true) and `MinimapButtonAngle` (default 215, degrees, written by dragging, no menu row) in `DefaultValues`. Tab entry `L["Minimap"]` in `TAB_ENTRIES` and a 4th `Schematic` entry with the checkbox (`Settings.lua`). Strings in `Locales/enUS.lua`.
- `Code/Widget/MinimapButton.lua` (new, in the .toc after `Settings.lua`): `DialogueUI335MinimapButton`, 31 px child of `Minimap`, a **Button**, so DragonUI's minimap module collects and skins it like any addon launcher (a plain Frame was tried first and DragonUI ignored it, which was not wanted), standard minimap parts (`UI-Minimap-Background` disc, `Textures\Logo.blp` icon as a plain texture (`SetPortraitToTexture` drew nothing for it), `MiniMap-TrackingBorder` ring, zoom-button highlight). Click = `SettingsUI:Toggle()`; tooltip with the click and drag hints. `SettingChanged.ShowMinimapButton` creates / shows / hides it (also fires once at load).
- Drag: `OnUpdate` while dragging reads the cursor angle around the minimap centre and saves it; a click arriving within 0.2 s after a drag is ignored.
- Orbit radius is half the minimap width + 5, so the button hangs on the rim. Other minimap addons that reshape the minimap are only handled through `GetMinimapShape`.
- Unverified: `Textures\Logo.tga` is used by path without conversion (TGA loads in the client as is, but it must be a power of 2 size); `SetPortraitToTexture` with a custom file; the look next to DragonUI's minimap frame.
- To look at: button on the rim at the default angle, click opens / closes Settings (also with the Minimap tab open), drag around the rim and position survives /reload, checkbox off hides it at once and on (fresh character / default) shows it, tooltip, DragonUI minimap (round and square), logo not clipped by the ring.

## Gossip group: skipped

Retail's Gameplay tab has a **Gossip** subheader with Auto Select Option, Force Gossip (+ Skip GameObject sub-option) and Show Hint. None of them can do anything in 3.3.5a, so by decision the whole group is left out: no label, no rows, no settings, no `DefaultValues`, no code.

- **Auto Select Option** (`AutoSelectGossip`): retail's `GossipData_AutoSelect.lua` is a table keyed by `gossipOptionID`, all Legion to Midnight content (Delves, Dornogal, Trading Post, Horrific Visions, Suramar). 3.3.5a gossip options have no ID (`GetGossipOptions` returns text and type only), and none of the listed options exists in WotLK. Nothing to select.
- **Force Gossip** (`ForceGossip`, `ForceGossipSkipGameObject`): retail's client auto-selects a gossip menu that has a single option and no quests, and `C_GossipInfo.ForceGossip()` / this option overrides that so the dialogue is shown. 3.3.5a has no such client behaviour (it always fires `GOSSIP_SHOW` and shows the list; whether a banker or similar shows a menu at all is decided by the server) and no `C_GossipInfo`. Nothing to force. Based on the retail code and the 3.3.5a docs; no Blizzard FrameXML source was available to confirm, so if an NPC is found in game whose gossip never reaches the addon, revisit.
- **Show Hint** (`ShowDialogHint`): adds a button that answers the Timewalking quiz. Timewalking is Mists of Pandaria and later, so nothing exists to support.
- The 335 addon has no `HandleAutoSelect` / `ForceGossip` logic either (checked with a search), so there was nothing to hide.

## Auto Complete Quest: skipped

Retail (`GossipData_AutoQuest.lua`, `DialogueUI.lua` `HandleQuestProgress` / `HandleQuestComplete`, `QuestFlyout.lua`): `AutoCompleteQuest` completes a quest without showing its page, when its ID or its name is on a fixed list, and shows the completion text and the rewards in a separate flyout (with a button to open a chest reward). The list is only retail content (Midnight, Khaz Algar weekly, Delves, Darkmoon Faire, Hallow's End Candy Bucket (Cataclysm IDs), Midsummer Bonfire, Worldsoul ...). Nothing on it is a WotLK quest I could confirm, and 3.3.5a has no way to get a quest name from an ID, so a list would have to be hand-made English titles. Skipped by decision (like Auto Quest Popup): no setting, no row, no flyout. If it is wanted later: a list of quest titles in `GossipDataProvider`, `CompleteQuest()` on QUEST_PROGRESS when `IsQuestCompletable()`, `GetQuestReward(0)` on QUEST_COMPLETE when there is no choice, and the text in the alert frame.

## Simplify Currency Rewards: skipped

Retail's option makes currency, major faction reputation and honor rewards small rows. 3.3.5a has no quest currency rewards (`GetNumRewardCurrencies` / `GetQuestCurrencyInfo` are Cataclysm), and Emblems are normal items here, so they already show as item buttons. Only honor and arena points are currency-like, and `QuestData.lua` already shows both as small rows (always the simplified form). A setting would only switch those two to big buttons, so it was left out. If it is ever wanted: `small = SimplifyCurrencyReward` in `ReadRewards` and `honor` / `arena` branches in `RewardItemButton:SetEntry`; the client already has the icons (`Interface\PVPFrame\PVP-Currency-*`, `PVP-ArenaPoints-Icon`), and retail's preview picture would not fit (it shows currency items).

## Scrolling: what was done (not tested in the game)

Retail: `ScrollFrame` (clips children) + `ScrollFrameMixin` (view size, content height -> range, offset, wheel = one row) + `addon.CreateScrollBar` (`Scroll_Bar.lua`). Same here.

- `Code/Scroll/Scroll_Bar.lua` (new, in the .toc): up / down arrows (hold repeats), rail, thumb that widens from 4 to 12 on hover / drag (retail's expand / shrink animation) and shrinks back, Brown / Dark vertex colors as retail, textures `ScrollBar-Vertical-*.blp` (already converted). No scroll-to-bottom arrow or new-message dot.
- `Settings.lua`: the list is a real `ScrollFrame` (3.3.5a has no `clipChildren`) with a scroll child that holds the pages. The bar sits 4 right of the list and replaces the vertical divider while the tab scrolls (retail). `LayoutRows` sets the content height, so Move / Reset rows appearing or hiding change the range. Each tab keeps its own offset. Wheel moves one row (36), instantly, as retail.
- 3.3.5a clips drawing but not mouse input: rows react only while the pointer is inside the list (`IsPointerInList`), the hover glow is parented to the row's page so it is clipped, and the hover is re-evaluated one frame after a scroll.
- Not ported: `AdjustScrollToObject` (keybinding / gamepad only).
- To look at: add enough rows to scroll (the UI tab has 14 at Custom), wheel, arrows (hold), thumb drag, hover animation, both themes, tab switch keeps the offset, glow and description of the row under the pointer after scrolling, rows half visible at the bottom edge, bar and divider swap when Move / Reset appear.

## Later options (not planned in detail yet)

From retail's UI tab: Font, Hide UI sub-options, then the Quest group (Mark Highest Sell Price, Use Blizzard Tooltip, ...), Readables (Book size and options). Control and Gameplay tabs follow `Settings_Definitions` in retail. Open questions from `SettingsMenu-Questions.md` (items 2, 5, 6): which options to include, live vs reload, and the two tooltip settings.
