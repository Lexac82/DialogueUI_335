local _, addon = ...;

-- Spoken (the voice player). Its side is not here: it is in the Spoken folders under SupportedAddons, which are
-- copied over the Spoken addons' own (see README.md). This only registers
-- Spoken as running, so the Other Addons tab can say whether it is, and publishes nothing else.
-- What the file reads from DialogueUI is published by Code\SpokenSupport.lua.

addon.AddSupportedAddOn("Spoken", function() end, { "Spoken" });
