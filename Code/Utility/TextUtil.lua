local _, addon = ...;

local TextUtil = {};
addon.TextUtil = TextUtil;

local gmatch = string.gmatch;

-- Splits text into paragraphs at control characters (newlines) and drops lone spaces.
-- Same rule as retail's API.SplitParagraph.
function TextUtil.SplitParagraph(text)
    local paragraphs = {};

    if text then
        local n = 0;
        for paragraph in gmatch(text, "[%C]+") do
            if paragraph ~= " " then
                n = n + 1;
                paragraphs[n] = paragraph;
            end
        end
    end

    return paragraphs
end
