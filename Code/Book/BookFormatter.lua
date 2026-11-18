local _, addon = ...;

-- Turns the text of a readable (ItemTextGetText) into content blocks for the book frame.
-- Port of retail's Formatter:FormatText / FormatParagraph / FormatHTML (Code/Book/BookUI.lua).
-- The formatter only parses. It hands the blocks to a sink (BookUI.lua) that stores and measures them.

local BookFormatter = {};
addon.BookFormatter = BookFormatter;

local SplitParagraph = addon.TextUtil.SplitParagraph;
local Round = addon.MathUtil.Round;

local match = string.match;
local find = string.find;
local gsub = string.gsub;
local lower = string.lower;
local ipairs = ipairs;

-- Width of Blizzard's own page (ParchmentLarge). An <IMG width="206"> takes 206 / 412 of the text width.
local WOW_PAGE_WIDTH = 412;

local IgnoredTags = {
    ["<br/>"] = true,
    ["</p>"] = true,
    ["<HTML><BODY>"] = true,
    ["</BODY></HTML>"] = true,
};

local ValidAlignments = {
    left = "LEFT",
    center = "CENTER",
    right = "RIGHT",
};

-- Tags that have their own font in BookUI.lua. Any other tag is shown as a paragraph.
local FontTags = {
    p = true, h1 = true, h2 = true, h3 = true, title = true, smallprint = true,
};

-- Sizes of pictures that carry no width / height in the book text (file names are lowercase).
-- PvP rank badges are used in "A Treatise on Military Ranks" (Stormwind City).
-- Retail's artifact book crops (Legion) are not ported.
local TextureSize = {};
do
    local badge = {40, 40};
    for i = 1, 14 do
        local name = i < 10 and ("0" .. i) or tostring(i);
        TextureSize["interface\\pvprankbadges\\pvprank" .. name] = badge;
    end
    TextureSize["interface\\pvprankbadges\\pvprankalliance"] = {86, 100};
    TextureSize["interface\\pvprankbadges\\pvprankhorde"] = {86, 100};
end

local function CleanUpTags(text)
    -- Strips the tags that wrap a paragraph.
    text = gsub(text, "^<[^<>]+>", "", 1);
    text = gsub(text, "^<[^<>]+>", "", 1);
    text = gsub(text, "<[^<>]+>$", "", 1);
    text = gsub(text, "<[^<>]+>$", "", 1);
    text = gsub(text, "<[^<>]+>$", "", 1);
    text = gsub(text, "<BR/>", "\n");
    return text
end

-- Plain text book: one paragraph block per line.
local function FormatParagraph(text, ctx)
    local sink = ctx.sink;
    local anyAdded = false;
    for _, paragraphText in ipairs(SplitParagraph(text)) do
        if paragraphText ~= "" then
            anyAdded = true;
            sink:StoreText("p", paragraphText, "LEFT", ctx.paragraphSpacing);
        end
    end
    if anyAdded then
        sink:RemoveLastTextSpacingBelow();
    end
end

-- Works out the size of an <IMG>. Returns imageWidth, imageHeight (in frame units) or nil to skip it.
local function GetImageSize(file, width, height, ctx)
    local contentWidth = ctx.contentWidth;

    if not (width and height) then
        local known = TextureSize[file];
        if known then
            width, height = known[1], known[2];
        end
    end

    -- Only one of the two given: make it square, never wider than the text.
    if width and not height then
        width = math.min(width, contentWidth);
        height = width;
    elseif height and not width then
        height = math.min(height, contentWidth);
        width = height;
    end

    if not (width and height) then
        -- Unknown picture: 61.8% of the text width, square.
        local size = Round(contentWidth * 0.618);
        return size, size
    end

    local scale = width / WOW_PAGE_WIDTH;
    local imageWidth = Round(contentWidth * scale);
    local imageHeight = Round(imageWidth * height / width);
    return imageWidth, imageHeight
end

local function FormatHTML(text, ctx)
    local sink = ctx.sink;
    local paragraphSpacing = ctx.paragraphSpacing;
    local numTexts = 0;
    local anyAdded = false;

    for _, paragraphText in ipairs(SplitParagraph(text)) do
        if not IgnoredTags[paragraphText] then
            local tag = match(paragraphText, "^</*([%w]+)/*>");
            if not tag then
                tag = match(paragraphText, "^<([%w]+)%s");
            end

            if tag and not IgnoredTags[tag] then
                tag = lower(tag);

                if tag == "img" then
                    local file = match(paragraphText, "src=\"([^\"]+)\"");
                    if file then
                        file = lower(file);
                        local width = tonumber(match(paragraphText, "width=\"(%d+)"));
                        local height = tonumber(match(paragraphText, "height=\"(%d+)"));
                        local align = match(paragraphText, "align=\"(%a+)") or "center";

                        if file == "interface\\common\\spacer" then
                            sink:AddSpacerToNextContent(paragraphSpacing);
                        else
                            local imageWidth, imageHeight = GetImageSize(file, width, height, ctx);
                            -- Images are always centred (retail does the same, see issue #98 in its code).
                            sink:StoreImage(file, align, imageWidth, imageHeight);
                        end
                    end
                else
                    local align = match(paragraphText, "^<[%w]+%s+align=\"(%a+)\"");
                    align = align and ValidAlignments[lower(align)] or "LEFT";

                    paragraphText = CleanUpTags(paragraphText);
                    if paragraphText ~= "" then
                        numTexts = numTexts + 1;
                        -- The first line is often the book title again. The header already shows it.
                        if numTexts > 1 or paragraphText ~= ctx.titleText then
                            anyAdded = true;
                            sink:StoreText(FontTags[tag] and tag or "p", paragraphText, align, paragraphSpacing);
                        end
                    end
                end
            else
                paragraphText = CleanUpTags(paragraphText);
                if paragraphText ~= "" then
                    numTexts = numTexts + 1;
                    anyAdded = true;
                    sink:StoreText("p", paragraphText, "LEFT", paragraphSpacing);
                end
            end
        end
    end

    if anyAdded then
        sink:RemoveLastTextSpacingBelow();
    end
end

-- ctx: sink (StoreText, StoreImage, AddSpacerToNextContent, RemoveLastTextSpacingBelow), titleText,
-- paragraphSpacing, contentWidth.
function BookFormatter.Format(text, ctx)
    if not text or text == "" then
        return
    end
    if find(text, "<HTML>") then
        FormatHTML(text, ctx);
    else
        FormatParagraph(text, ctx);
    end
end
