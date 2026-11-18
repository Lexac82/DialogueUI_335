# Theme (Brown / Dark)

How retail's theming works, and how it maps to this port. Retail files: `Code/Utility/ThemeUtil.lua` plus a `LoadTheme` or `ThemeChanged` hook in each widget.

## Retail

- Setting `Theme`: 1 = Brown (default), 2 = Dark. Changing it calls `ThemeUtil:SetThemeByID`.
- `ThemeUtil` keeps `THEME_ID` and `TEXTURE_PATH` (`Art/Theme_Brown/` or `Art/Theme_Dark/`). Both folders hold the same file names. Code never hardcodes the folder, it calls `ThemeUtil:GetTextureFile(name)`.
- On a theme change, `SetThemeByID` does four things:
  1. Recolors the shared font objects (`FONT_OBJECT_COLOR`: font name -> {Brown color, Dark color}). Every FontString using them changes at once.
  2. Calls `LoadTheme()` on the big frames (dialogue, settings, quest item display, dropdown menu).
  3. Triggers the `ThemeChanged` callback for small widgets (generic frame, help tip, translator button, quest difficulty colors).
  4. Swaps the red/blue text-color replacement (`AdjustTextColor`).
- Each `LoadTheme` re-sets the textures of its pieces and re-applies per-theme tweaks.
- Per-theme logic outside textures and fonts:
  - Portrait tint: Brown `(1, 0.9, 0.78)`, Dark white.
  - Money text is colored only in Dark.
  - Item names use quality colors only in Dark (Brown: dark brown).
  - Quest level colors: separate "Bright" and "Dark" palettes.
  - Brown replaces pure red text with `|cff9B2020` (legibility), Dark replaces pure blue with `|cff0078FF`.
  - Header widget hover style, quest item display button text color, selected item name color.

## This port today

- `ThemeUtil` only returns the Brown path. No theme id, no callbacks.
- Fonts are created with their color baked in (`FontUtil:GetColoredFont(name, size, color)`), and many colors are local constants in widgets (OptionButton, RewardItemButton, RewardSmallButton, HeaderTags, Widget_QuestItemDisplay, TooltipFrame, Settings).
- Textures are set once when a widget is created. Nothing re-applies them.

## Status (implemented, not tested in the game)

- `ThemeUtil`: theme id, texture paths, `COLORS`, `RegisterFont`, `BindTexture`, `BindSlice`, `AdjustTextColor`, `GetWarningColor`, `GetQualityColor`, `GetFixedTextureFile`. `SetThemeByID` runs from `SettingChanged.Theme`. Instead of retail's per-widget `LoadTheme`, textures are bound once (`BindTexture` / `BindSlice`) and `ThemeUtil` re-applies them; widgets that pick a file or color on the fly (option buttons, reward buttons, quest item display button text, portrait tint) listen to `ThemeChanged`.
- `FontUtil`: fonts take `{BrownKey, DarkKey}`; the Book keeps fixed colors (its own kit) and its paper strip always uses the Brown file.
- Dark-only behavior: quest level palette, money colors, item name quality colors, white portrait, blue text replacement, 128x32 gossip glow.
- Theme option: first option of the UI tab (arrow option, Brown / Dark). The option row and arrow widget are the base for the other options.
- Not themed yet: the decor picture of the settings window (not ported).

## Plan (done)

1. `ThemeUtil`: theme id, texture path per theme, `COLORS`, `ThemeUtil:SetThemeByID`, `IsDarkMode`, getters (quality, item select), triggers `ThemeChanged`. Reads the `Theme` setting (`SettingChanged.Theme` fires once at load).
2. `FontUtil`: fonts get a color key per theme; on a theme change the font objects are recolored in one place (same idea as retail's `FONT_OBJECT_COLOR`). The local color constants in widgets go away.
3. Each widget that sets a texture registers for `ThemeChanged` and re-applies it.
4. The per-theme tweaks listed above.
5. `Theme` option in the UI tab (Brown / Dark).

## Textures

- Dark set: 33 PNGs in `temp\Theme_Dark\`, to convert to `.blp` and place in `Textures\Theme_Dark\` with the same file names.
- Theme-independent files stay in `Textures\Theme_Brown\` and are used by both themes (they are identical or have no Dark version): `Coin-Copper/Silver/Gold`, `XP-Purple`, `ScrollBar-Vertical-Buttons/Rail/Thumb`, `ButtonHighlight-Add`, `RewardChoice-Highlight`, `RewardChoice-Highlight-Back`, `RewardChoice-Sheen`. `ThemeUtil` will hold this list. (Textures cannot fall back at runtime in 3.3.5a, there is no file-exists check.)
- All Dark files have the same size as their Brown file, except `ButtonHighlight-Gossip`: Brown 128x64, Dark 128x32. The highlight slice in `OptionButton.lua` assumes 128x64 and needs the size per theme.
- `Parchment.tga` in `Theme_Brown` is not touched by this.
