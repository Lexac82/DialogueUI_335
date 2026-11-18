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

-- Short text for reward rows: "12g 34s 56c". Plain colour: the Brown theme does not colourise it.
function MoneyUtil:GetShortText(copper)
    copper = floor(copper or 0);
    local gold = floor(copper / 10000);
    local silver = floor((copper % 10000) / 100);
    local rest = copper % 100;

    local parts = {};
    if gold > 0 then
        parts[#parts + 1] = Thousands(gold) .. "g";
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "s";
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = rest .. "c";
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
