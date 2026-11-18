local _, addon = ...;

-- Parent for the frames that must stay visible while Hide UI has hidden UIParent (retail's SetGameUIShown(false)
-- keeps its own frames, 3.3.5a has no such call: hiding UIParent hides every child).
-- The root hangs on WorldFrame and copies UIParent's scale and corners, so a frame placed relative to UIParent
-- looks the same under either parent. Anchoring to a hidden UIParent still works.

local UIParent = UIParent;
local WorldFrame = WorldFrame;

local root = CreateFrame("Frame", "DialogueUI335Root", WorldFrame);
root:SetFrameStrata("MEDIUM");      -- children copy the strata at creation, WorldFrame's is BACKGROUND
root:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0);
root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0);
addon.UIRoot = root;

local lastScale;

local function SyncScale()
    local scale = UIParent:GetEffectiveScale() / WorldFrame:GetEffectiveScale();
    if scale ~= lastScale then
        lastScale = scale;
        root:SetScale(scale);
    end
end

SyncScale();

-- The UI scale can change at any time (options, resolution), and the order of the game's own handlers is not known,
-- so the scale is compared every frame (two calls).
root:SetScript("OnUpdate", SyncScale);
