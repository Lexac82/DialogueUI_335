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
| Other options (Font, Frame Orientation, Hide UI, Book, ...), Control tab, Gameplay tab | not started |

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
- Not ported: the scroll bar (needed when a tab has more than ~10 rows), gamepad support, preview pictures (`Art/PreviewPicture`).

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

## Later options (not planned in detail yet)

From retail's UI tab: Font, Frame Orientation (probably not useful with our draggable frame), Hide UI and its sub-options, Show Copy Text Button, Show NPC Name On Page, then the Quest group (Mark Highest Sell Price, Use Blizzard Tooltip, ...), Readables (Book size and options). Control and Gameplay tabs follow `Settings_Definitions` in retail. Open questions from `SettingsMenu-Questions.md` (items 2, 5, 6): which options to include, live vs reload, and the two tooltip settings.
