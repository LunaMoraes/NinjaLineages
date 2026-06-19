require "Items/ProceduralDistributions"
require "NinjaLineages_RareScrolls"

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

local function addRareScrolls()
    if not ProceduralDistributions or not ProceduralDistributions.list then return end

    for _, distribution in pairs(ProceduralDistributions.list) do
        local items = distribution and distribution.items
        if items and containsBook(items) then
            for _, definition in pairs(NinjaLineages.RareScrolls.Definitions) do
                if not containsItem(items, definition.itemType) then
                    table.insert(items, definition.itemType)
                    table.insert(items, definition.lootWeight)
                end
            end
        end
    end
end

NinjaLineages.addEventOnce(
    "server.distributions.onPostDistributionMerge",
    Events.OnPostDistributionMerge,
    addRareScrolls
)
