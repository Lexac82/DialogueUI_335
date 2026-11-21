local _, addon = ...;

-- Auctionator (2.6.x for 3.3.5a): auction price, median price and disenchant value in the item tooltip.
-- Auctionator adds these by hooking GameTooltip, which our tooltip is not, so they are added here from its
-- public globals. Its own "ShowTipWithPricing" is a local function and cannot be called.
-- Not shown: the vendor line (our tooltip already shows the sell price) and the disenchant breakdown shown
-- with its "details" option (that code is private to Auctionator).
local GetCoinTextureString = GetCoinTextureString;
local IsShiftKeyDown = IsShiftKeyDown;
local GetItemInfo = GetItemInfo;
local tonumber = tonumber;
local type = type;

local ADDON_NAME = "Auctionator";
local WHITE = "|cFFFFFFFF";

local REQUIRED = {
    "Atr_GetAuctionPrice",
    "Atr_GetMeanPrice",
    "Atr_GetDisenchantValue",
    "Atr_GetBonding",
};

-- Auctionator keeps its tooltip options in per-character saved variables: 1 is on.
local function IsOn(name)
    return _G[name] == 1
end

local function Localize(text)
    if type(ZT) == "function" then
        return ZT(text)
    end
    return text
end

local function Price(copper)
    return WHITE .. GetCoinTextureString(copper)
end

local function Unknown()
    return WHITE .. Localize("unknown") .. "  "
end

local function OnAddOnLoaded()
    local GetAuctionPrice = Atr_GetAuctionPrice;
    local GetMeanPrice = Atr_GetMeanPrice;
    local GetDisenchantValue = Atr_GetDisenchantValue;
    local GetBonding = Atr_GetBonding;

    local function provider(tooltip, link, count)
        if not addon.GetDBBool("ShowAuctionHouseTooltip") or not addon.GetDBBool("ShowAuctionatorTooltip") then
            return
        end
        local itemName = GetItemInfo(link);
        local itemID = tonumber(link:match("item:(%d+)"));
        if not itemName or not itemID then
            return
        end

        -- Stack prices for the whole reward while Shift is held (or while it is not, with option 2).
        local multiplier, suffix = 1, "";
        local showStack = IsShiftKeyDown();
        if _G.AUCTIONATOR_SHIFT_TIPS == 2 then
            showStack = not showStack;
        end
        if count and count > 1 and showStack then
            multiplier = count;
            suffix = "|cFFAAAAFF x" .. count .. "|r";
        end

        if IsOn("AUCTIONATOR_A_TIPS") then
            -- Bonding: 1 soulbound, 4 and 5 quest items. Auctionator cannot price those.
            -- Its table of bonding types (gAtr_MI) is the one thing GetBonding needs.
            local bonding = type(_G.gAtr_MI) == "string" and GetBonding(itemID) or 0;
            local label = Localize("Auction") .. suffix;
            if bonding == 1 then
                tooltip:AddDoubleLine(label, WHITE .. Localize("BOP") .. "  ");
            elseif bonding == 4 or bonding == 5 then
                tooltip:AddDoubleLine(label, WHITE .. Localize("Quest Item") .. "  ");
            else
                local price = GetAuctionPrice(itemName);
                tooltip:AddDoubleLine(label, price and Price(price * multiplier) or Unknown());
                local median = GetMeanPrice(itemName);
                if median then
                    tooltip:AddDoubleLine(Localize("Auction median") .. suffix, Price(median * multiplier));
                end
            end
        end

        if IsOn("AUCTIONATOR_D_TIPS") then
            local dePrice = GetDisenchantValue(link);
            if dePrice then
                local label = Localize("Disenchant") .. suffix;
                if dePrice > 0 then
                    tooltip:AddDoubleLine(label, Price(dePrice * multiplier));
                else
                    tooltip:AddDoubleLine(label, Unknown());
                end
            end
        end
    end

    DialogueUI_API.RegisterItemTooltipProvider(ADDON_NAME, provider);
end

addon.AddSupportedAddOn(ADDON_NAME, OnAddOnLoaded, REQUIRED);
