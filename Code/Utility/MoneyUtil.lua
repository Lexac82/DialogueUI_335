local _, addon = ...;

-- Money text and coin icon choice for the reward rows (retail API.GenerateMoneyText / SetCoinIcon).
local MoneyUtil = {};
addon.MoneyUtil = MoneyUtil;

local floor = math.floor;
local format = string.format;

-- 1234567 -> "1,234,567". BreakUpLargeNumbers is FrameXML and not in wow-docs.
local function Thousands(n)
    local s = format("%d", n);
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse();
    return (out:gsub("^,", ""))
end
MoneyUtil.Thousands = Thousands;

-- Short text for reward rows: "12g 34s 56c". Colored only in the Dark theme (retail GenerateMoneyText).
local COIN_COLOR = { g = "|cffffbb18", s = "|cffc5d2e8", c = "|cffe3b277" };

function MoneyUtil:GetShortText(copper)
    copper = floor(copper or 0);
    local gold = floor(copper / 10000);
    local silver = floor((copper % 10000) / 100);
    local rest = copper % 100;

    local colorized = addon.ThemeUtil:IsDarkMode();
    local function Part(amount, unit)
        local text = amount .. unit;
        if colorized then
            return COIN_COLOR[unit] .. text .. "|r"
        end
        return text
    end

    local parts = {};
    if gold > 0 then
        parts[#parts + 1] = Part(Thousands(gold), "g");
    end
    if silver > 0 then
        parts[#parts + 1] = Part(silver, "s");
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = Part(rest, "c");
    end
    return table.concat(parts, " ")
end

-- Coin icon file by size, as retail: under 1 silver copper, under 1 gold silver, else gold.
function MoneyUtil:GetCoinFile(copper)
    if copper < 100 then
        return "Coin-Copper.blp"
    elseif copper < 10000 then
        return "Coin-Silver.blp"
    end
    return "Coin-Gold.blp"
end
