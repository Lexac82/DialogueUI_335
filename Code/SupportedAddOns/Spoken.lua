local _, addon = ...;

-- Spoken (the voice player). Its side is not here: it is the file SupportedAddons\Spoken\SpokenDialogueUI.lua, which is
-- copied into the Spoken addon's folder and listed in its .toc (see SupportedAddons\README.md). This only registers
-- Spoken as running, so the Other Addons tab can say whether it is, and publishes nothing else.
-- What the file reads from DialogueUI is published by Code\SpokenSupport.lua.

addon.AddSupportedAddOn("Spoken", function() end, { "Spoken" });
