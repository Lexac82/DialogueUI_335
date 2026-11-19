# Book UI: structure, textures and checklist

Port of the retail Book UI (readable books, letters, plaques, tombstones) to 3.3.5a. Reference: `..\DialogueUI\Code\Book\` (`BookUI.lua`, `BookUI_Component.lua`, `BookUI_Atlas.lua`, `BookUI.xml`). Lua only, no XML. **Checked in game:** Metal (stone) and Parchment skins, background and footer, text layout and scrolling, multi-page buttons (click, hover colour, centring), position. **Not yet checked in game:** real readables from the bags (flavor-text strip, Plain Letter sender, item lookup), Esc and bag-key closing, cinematic closing, resuming the scroll position, dragging and saved position, the open fly-in. No Lua interpreter was available: the files pass the editor's LuaLS syntax check.

## Files

| File | Job |
| --- | --- |
| `Code/Book/BookFormatter.lua` | Parses `ItemTextGetText` (plain text or `<HTML>`) into text and image blocks. Port of retail's `Formatter`. |
| `Code/Book/BookItem.lua` | Finds the bag slot of the item being read, its flavor text, the Plain Letter sender, and the zone / coordinates for world objects. |
| `Code/Book/BookUI.lua` | The frame, skins, header, page buttons, scrolling, layout, source-item strip, show / hide, Esc key. |
| `Code/Book/BookEvents.lua` | `ITEM_TEXT_*` events, page caching, closing rules, Blizzard `ItemTextFrame` off, bag-key and cutscene closing. |
| `Code/Tooltip/TooltipScan.lua` | New `ScanBagItem(bag, slot)`. |

## Textures (BLP, need converting)

The PNGs are in `temp/`. After conversion they go to `Textures/Book/` with these names, and `temp/` is removed.

| File | Size | Used by |
| --- | --- | --- |
| `TextureKit-Parchment.blp` | 1024×2048 | Parchment kit (default, `ItemTextGetMaterial()` nil or `Parchment`) |
| `TextureKit-Metal.blp` | 1024×2048 | Metal kit (`Stone`, `Marble`, `Silver`, `Bronze`) |
| `ScreenDarken.blp` | 1024×512 | Screen vignette |

### Kit atlas (both kits share the layout; px in the 1024×2048 file)

| Region | Atlas px (x0–x1, y0–y1) | Use |
| --- | --- | --- |
| Full page | 0–1024, 0–1152 | Background when the text fits and the frame is full height |
| Top piece | 0–1024, 0–(192 + 744 × ratio) | Background top, cropped to the frame height |
| Bottom cap | 0–1024, 1152–1408 | Bottom of the two-piece background (covers text scrolling under it) |
| Header overlap | 128–896, 1408–1488 | Strip over the top of the text, fades in when the text has scrolled |
| Footer divider | 0–768, 1488–1520 | Fades with the distance to the bottom of the scroll |
| Header divider | 0–768, 1520–1552 | Under the title, split in two around the page buttons |
| Close button | 768–832 / 832–896, 1488–1552 | Normal / hover |
| Page button | 780–820 selected, 844–884 normal, 908–948 hover; rows 1564–1604 | Page numbers |
| Item ring | 768–864, 1616–1712 | Ring around the flavor-text icon |

The bottom cap sits 20 units lower than retail's default (`FOOTER_SHIFT` in `BookUI.lua`, tuned in game); the top piece's crop height follows it.

Scale: `0.53333` px per atlas px times the frame size setting. Frame 409.6 × up to 477.9 (size index 1).

## Behaviour

- **Skin:** Parchment (dark brown text) or Metal (grey text with shadow). Page-number colours and the small print follow the skin.
- **Layout:** text is cut into blocks (`p`, `h1`–`h3`, images), measured with a hidden FontString (`GetStringHeight`) and stacked. If everything fits, the frame shrinks to the text (two-piece background). If not, it is full height and scrolls.
- **Multi-page books:** all pages are cached first (`ItemTextNextPage` on every READY), then shown as one scrolling text with page-number buttons (up to 9; with more pages the first and last stay and the current page is centred). If all pages fit without scrolling, no buttons. Clicking a button scrolls to the page. Shift + wheel jumps to the previous / next page.
- **Scrolling:** `InitSmoothScrollFrame` in `Code/Scroll/Scroll_EasySmooth.lua` (shared with the parchment). Wheel moves by `round(4 × (font size + line spacing))`. The bottom divider fades with the distance to the end, the header overlap fades in once the text moved under the title.
- **Title:** biggest of 18 / 16 / 14 that fits on one line, otherwise 14 on two lines. Friz Quadrata (retail uses Trajan, which is not in this addon).
- **Remembered position:** reopening the same book scrolls back to where the player stopped (session only). The book is identified by title, first-page length and the first 24 characters.
- **Movable:** left-drag moves the book, position saved in `BookPosition`.
- **Closing:** close button, right click, Esc, bag keys, talking to an NPC, a cinematic or movie, or when the game closes the readable (walking away), unless `BookKeepUIOpen` is true.
- **Esc:** override binding on `ESCAPE` to the close button while the book is open (3.3.5a has no `SetPropagateKeyboardInput`). It cannot change in combat, so it is re-applied on `PLAYER_REGEN_ENABLED`.
- **Blizzard frame:** `ItemTextFrame:UnregisterAllEvents()`. Turned back on if the module is disabled.
- **Location (world objects):** "Zone  x, y" above the title, from `GetRealZoneText` and `GetPlayerMapPosition`. It calls `SetMapToCurrentZone()` unless the world map is open.
- **Item flavor text:** for a readable item from the bags, the quoted line of its tooltip plus its icon (round via `SetPortraitToTexture`, square fallback) above the book. The strip sits on tan paper (`Textures/Theme_Brown/GenericFrame-Tiled-Large.blp`, tiled 9-slice) as wide as the book, with dark brown text.
- **Plain Letter sender:** for item 8383 the white second tooltip line is shown above the title.
- **PvP rank badge sizes:** `pvprank01`–`14`, `pvprankalliance`, `pvprankhorde` get fixed sizes (A Treatise on Military Ranks).

## Settings (`DialogueUI_335_DB`, change with `/run`, apply on the next book)

| Key | Default | Meaning |
| --- | --- | --- |
| `BookUIEnabled` | true | Off switch: `/run DialogueUI_335_DB.BookUIEnabled = false` then `/reload`. The old key `BookSizeIndex` is migrated to `BookUISize` |
| `BookUISize` | 1 | 0 to 4 = 0.9, 1.0, 1.1, 1.25, 1.4 times |
| `BookFontSize` | 12 | Paragraph size 8–24 (headings are +4 / +6, small print −2) |
| `BookDarkenScreen` | false | Dark vignette |
| `BookShowLocation` | true | Zone and coordinates for world objects |
| `BookUIItemDescription` | true | Item icon and flavor text above the book |
| `BookKeepUIOpen` | false | Keep the book when the game closes the readable |

## 3.3.5a differences from retail

- No `C_Item`, `C_Map`, `C_Timer`: item data from bags and tooltips, location from `GetPlayerMapPosition`, timers with OnUpdate.
- No `GetItemIDByGUID`: the readable's item is found from the name (bag scan, plus a hook on `UseContainerItem` for a right click in the last 3 seconds).
- No `MaskTexture`: the header divider is two halves with a gap, the item icon uses `SetPortraitToTexture`.
- No `SetTextScale`, `SetMaxLines`, `IsTruncated`, `GetWrappedWidth`: the title steps the font size and measures with `GetStringWidth` / `GetStringHeight`.
- No texture sublevels: creation order inside a layer decides.
- Height of wrapped text is read straight after `SetText` (retail waits a frame).

## Not ported (by choice or not in WotLK)

- TTS read-along, gamepad and joystick control, mobile mode, swipe scrolling, F1 settings key, copy-text button, `ITEM_TEXT_TRANSLATION` progress bar.
- Artifact-book picture crops (Legion), `ParchmentLarge` and `Progenitor` materials, later-expansion cutscene hooks (only `CINEMATIC_START` / `PLAY_MOVIE` close the book).
- Dark mode colours and the right-side layout option.

## UNVERIFIED (not in wow-docs or not checked in game)

- Everything: the whole module is untested in the client.
- `ItemTextFrame` and its events being the only thing that opens the Blizzard window.
- FrameXML bag functions hooked for the bag keys: `OpenAllBags`, `ToggleBackpack`, `ToggleAllBags`, `ToggleBag` (each hooked only if it exists).
- `WorldMapFrame` (checked before calling `SetMapToCurrentZone`).
- The Plain Letter tooltip layout (second white line).
- `SetPortraitToTexture` with a texture region as first argument (docs name it `frameName`).
- `SetToplevel`, `FontString:SetWidth(0)` meaning "no wrap", `ClearOverrideBindings` with a frame as owner.
- `GetContainerItemInfo` fifth return value (`readable`), already relied on by `Widget_QuestItemDisplay.lua`.
- Blizzard's own tooltip flavor text being the last quoted (`"`) line.

## Open questions

- Confirm both kit BLPs line up with the coordinates above in game (draw one crop).
- Check the fly-in (48 units, 0.5 s) feels right at 3.3.5a frame rates.
