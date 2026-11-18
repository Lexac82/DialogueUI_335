local _, addon = ...;

-- "Quest accepted: <title>" at the top right of the screen. Port of the QUEST_ACCEPTED part of retail's
-- AlertFrame.lua (fade in 0.25 s, hold for the reading time, fade out 0.25 s). One message at a time: a new one replaces the old.
local L = addon.L;
local FontUtil = addon.FontUtil;

local GetQuestLogTitle = GetQuestLogTitle;

local FADE_TIME = 0.25;
local HOLD_BASE = 2;                -- seconds
local HOLD_PER_CHAR = 0.04;
local OFFSET = 36;                  -- retail alertFrameOffset

local alert = CreateFrame("Frame", nil, addon.UIRoot);
alert:SetFrameStrata("DIALOG");
alert:SetWidth(64);
alert:SetHeight(12);
alert:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -OFFSET, -OFFSET);
alert:SetAlpha(0);
alert:Hide();

local text = alert:CreateFontString(nil, "OVERLAY");
text:SetFontObject(FontUtil:GetOutlinedFont("DUI335_Alert", 12, {0.87, 0.86, 0.75}));
text:SetJustifyH("RIGHT");
text:SetPoint("TOPRIGHT", alert, "TOPRIGHT", 0, 0);

local elapsed, holdTime;

local function OnUpdate(_, dt)
    elapsed = elapsed + dt;
    if elapsed < FADE_TIME then
        alert:SetAlpha(elapsed / FADE_TIME);
    elseif elapsed < FADE_TIME + holdTime then
        alert:SetAlpha(1);
    elseif elapsed < 2 * FADE_TIME + holdTime then
        alert:SetAlpha(1 - (elapsed - FADE_TIME - holdTime) / FADE_TIME);
    else
        alert:SetScript("OnUpdate", nil);
        alert:SetAlpha(0);
        alert:Hide();
    end
end

local function ShowMessage(message)
    text:SetText(message);
    elapsed = 0;
    holdTime = HOLD_BASE + #message * HOLD_PER_CHAR;
    alert:SetAlpha(0);
    alert:Show();
    alert:SetScript("OnUpdate", OnUpdate);
end

local events = CreateFrame("Frame");
events:RegisterEvent("QUEST_ACCEPTED");
events:SetScript("OnEvent", function(_, event, questLogIndex)
    -- UNVERIFIED: wow-docs does not list the arguments of QUEST_ACCEPTED. In 3.3.5a the first is the quest log index.
    local title = questLogIndex and GetQuestLogTitle(questLogIndex);
    if title and title ~= "" then
        ShowMessage(L["Quest Accepted Alert"]:format(title));
    end
end);
