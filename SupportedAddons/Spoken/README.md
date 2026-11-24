# Spoken support for DialogueUI

Adds Spoken's round **Play** and **Skip** buttons to DialogueUI's quest and gossip window and to its
book view. DialogueUI hides the game's UI, which is where Spoken draws its own buttons, so without
this they are not there.

It works with the Spoken addon as downloaded: nothing in Spoken has to be edited except the one line
in its `.toc` below.

## Install

1. Copy

   `Interface\AddOns\DialogueUI\SupportedAddons\Spoken\SpokenDialogueUI.lua`

   to

   `Interface\AddOns\Spoken\SpokenDialogueUI.lua`

2. Open `Interface\AddOns\Spoken\Spoken.toc` in a text editor and add this line at the **end**, after
   the other files (keep it on its own line, spelled exactly like the file):

   ```
   SpokenDialogueUI.lua
   ```

   Example, the end of a `Spoken.toc` before and after:

   ```
   3.3.5\embeds.xml
   addon.xml
   Transcript.xml
   Compendium.xml
   SpokenDialogueUI.lua
   ```

   Do not put it first: it needs the Spoken addon's own files to have loaded.

3. Start the game, or type `/reload`.

4. In DialogueUI's settings, **Other Addons** tab, check **Spoken Buttons** to switch it on.

## Check that it works

- In **Other Addons**, **Spoken Buttons** is not greyed out (it is off until you check it). Hover over it: if the file or the `.toc`
  line is missing, the tooltip says so.
- Open a quest or gossip window: the round buttons are at the top right of the paper, the Skip button
  greyed until something speaks.
- Open a book: Play and Skip are left of its close button.

## Notes

- The `.toc` is read when the game starts. A change to it needs a full restart of the game, not only
  `/reload`.
- When Spoken is updated, its `.toc` is usually replaced, and the line has to be added again. The copied
  file itself stays.
- **Play** on a quest or gossip page needs Spoken Quests to be installed and loaded; without it the quest
  window has Skip only. Play on a book needs Spoken Readables.
- If a Spoken Quests of your own already draws these buttons on DialogueUI (a build that has its own
  DialogueUI bridge), the file steps aside and draws nothing, so the buttons are never doubled.
- To remove it: delete the line from `Spoken.toc` and the file from the Spoken folder, or just clear the
  **Spoken Buttons** checkbox.

## What it reads from DialogueUI

`Code\SpokenSupport.lua` in DialogueUI publishes `DUIQuestFrame`, `DUIBookFrame` and the page and size
information the file reads. The settings are stored in `DialogueUI_DB` as `SpokenButtons`. The file puts `DialogueUI_SpokenBridge` in the global table so DialogueUI can tell it
is in place.
