require "Items/ProceduralDistributions"

local SCROLL_TYPE = "Base.NL_CreationRebirthScroll"
local SCROLL_WEIGHT = 0.2

local function containsItem(items, fullType)
    for i = 1, #items, 2 do
        if items[i] == fullType then return true end
    end
    return false
end

local function containsBook(items)
    for i = 1, #items, 2 do
        local itemType = items[i]
        if itemType == "Book" or (type(itemType) == "string" and itemType:match("^Book[A-Z]")) then
            return true
        end
    end
    return false
end

local function addCreationRebirthScroll()
    if not ProceduralDistributions or not ProceduralDistributions.list then return end

    for _, distribution in pairs(ProceduralDistributions.list) do
        local items = distribution and distribution.items
        if items and containsBook(items) and not containsItem(items, SCROLL_TYPE) then
            table.insert(items, SCROLL_TYPE)
            table.insert(items, SCROLL_WEIGHT)
        end
    end
end

Events.OnPostDistributionMerge.Add(addCreationRebirthScroll)
