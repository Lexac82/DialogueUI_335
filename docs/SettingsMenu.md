# Settings menu

Port of retail's settings window (`..\DialogueUI\Code\Settings\Settings.xml` / `Settings.lua`). Code: `Code/Settings/Settings.lua`.

## Decisions

- Same structure and textures as retail. Tabs: **UI | Control | Gameplay** (no Camera, no Accessibility).
- Opens with `/dui` or `/dialogui`, and with **F1** while the dialogue is shown (override binding in `FooterButtons.lua`, like Space and Esc). While the window is open F1 and Esc close it.
- First step: the shell only. The tabs are empty.

## Layout (retail numbers at font height 12)

```
+--------------------------------------------------------------+  frame 733 x 454, padding 14
| [UI] [CONTROL] [GAMEPLAY]                              [ X ] |  header: tabs 36 high, gap 4
|==============================================================|  header divider (9 px)
|                                    |                         |
|  option list                       |  preview (hidden)       |
|  432 x 378 (10.5 rows of 36)       |  description text       |
|  one page frame per tab            |  (right area, 273 wide) |
|                                    |                         |
+--------------------------------------------------------------+
```

- List and description area are in the golden ratio: width = round((432 + 1.5 * 14) / 0.618).
- Background: `GenericFrame-Tiled-Large` (already converted), 80 px corners, 16 px drop shadow outside the frame edge.
- Selected tab: dark plate (`Settings-TabButton-Selection`) with cream text. Other tabs: dark brown text. Hover: `Settings-ButtonHighlight`.
- Not ported: the decor picture in the right area (retail masks it with `Mask-SettingsDecor`, no mask in 3.3.5a), the scroll bar (comes with the first long tab), gamepad support.

## Textures

In `temp\`, waiting for BLP conversion. Destination: `Textures\Theme_Brown\`. Keep the file names.

| File | Size | Used by | Needed now |
|---|---|---|---|
| Settings-CloseButton | 256x128 | close button: background, hover and X icon in one sheet | yes |
| Settings-TabButton-Selection | 128x64 | selected tab plate | yes |
| Settings-ButtonHighlight | 128x64 | tab hover, later option row hover | yes |
| Settings-Divider-H | 256x16 | line under the header | yes |
| Settings-Divider-V | 16x256 | line between list and description | yes |
| Settings-Checkbox | 128x128 | checkbox option | later |
| Settings-ArrowOption | 128x128 | `< value >` option and its arrows | later |
| Settings-DropdownButton | 512x256 | dropdown option | later |
| Settings-Keybinding | 512x512 | keybinding option | later |
| Settings-PreviewBorder | 64x64 | frame around preview pictures | later |
| Settings-SubOptionIcon | 64x64 | marker in front of child options | later |
| Settings-Move, Settings-Reset | 64x64 | position buttons (Gameplay) | later |
| DropdownMenu-Component | - | popup menu of the dropdown | later |
| LabelBackground | - | sub-header label | later |

Already converted and reused: `GenericFrame-Tiled-Large`, `ScrollBar-Vertical-*`, `HotkeyBackground`.
Dropped: `Settings-BackgroundShadow` (retail code never loads it), the whole `Theme_Dark` set.

After conversion: move the `.blp` files to `Textures\Theme_Brown\` and delete `temp\`. The code already points at the `.blp` paths.

## Not tested in the game

Written without a client to run it. Check: slice corners of the close button and the tab plate, divider thickness, F1 and Esc while the dialogue is open, F1 outside the dialogue (should still be "target self").
