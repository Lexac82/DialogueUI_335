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
| Quest group: **Quest Difficulty** (Off / Level / Name / Both) | written, **not tested in the game**, see "Quest Difficulty: what was done" |
| Quest group: **Show Upgrade Arrow** checkbox (arrow + setting) | written, **not tested in the game**, see "Show Upgrade Arrow: what was done" |
| Other options (Font, Hide UI sub-options, Book, ...), Control tab, Gameplay tab | not started |

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
- Not ported: the scroll bar (needed when a tab has more than ~10 rows), gamepad support.

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
- `TooltipCompare:IsUpgrade(link)` returns `isUpgrade, isReady`. Rule as retail: item level higher than the equipped item, best case over the slots (ring / trinket: 2 slots; an empty slot counts as an upgrade; one-hand weapon: 2nd slot only when it holds a weapon, an empty or shield / held-item offhand is ignored). `isReady` is false while `GetItemInfo` has no item level yet.
- `RewardLayout:UpdateUpgradeMarkers` runs after every layout: only big buttons of kind item, not "required", usable (`entry.isUsable`, so unusable items get the red "!" and no arrow). Not-ready items are asked again once after 0.8 s. `SettingChanged.ShowUpgradeArrow` re-runs it without a redraw (a reward choice is kept).
- `RewardItemButton:SetUpgradeMarker(shown, animate)`: 32 px arrow, `CENTER` on the icon's `BOTTOMLEFT` (1, 5), on its own frame above the border. While choosing a reward (`page.canChoose`) it flies up as retail (0.5 s delay, 12 px rise over 0.5 s with outSine, fade in).
- Not ported: cosmetic items (no such thing in 3.3.5a), third-party evaluators, the small reward rows, the Quest Item Display.
- **Texture (converted, in `Textures\Shared\`):** `ItemIsUpgrade.blp` (64 x 64, retail's `Art/Icons/ItemIsUpgrade.png`).
- To look at: arrow on choices and on fixed rewards, both themes, a ring / trinket / one-hand weapon with empty and full slots, a shield equipped with a one-hand weapon reward, toggling the checkbox with a quest page open, items not cached yet (arrow appears after ~1 s), arrow vs the quality triangle and count text.

## Later options (not planned in detail yet)

From retail's UI tab: Font, Hide UI sub-options, then the Quest group (Mark Highest Sell Price, Use Blizzard Tooltip, ...), Readables (Book size and options). Control and Gameplay tabs follow `Settings_Definitions` in retail. Open questions from `SettingsMenu-Questions.md` (items 2, 5, 6): which options to include, live vs reload, and the two tooltip settings.
