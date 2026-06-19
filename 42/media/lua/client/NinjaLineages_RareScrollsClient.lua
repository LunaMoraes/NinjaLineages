require "NinjaLineages_RareScrolls"
require "TimedActions/ISReadABook"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISCraftingUI"

NinjaLineages = NinjaLineages or {}

if not NinjaLineages.originalReadItem then
    NinjaLineages.originalReadItem = ISInventoryPaneContextMenu.readItem
end

NLRareScrollReadAction = ISReadABook:derive("NLRareScrollReadAction")

local function resetReadProgress(character, item)
    item:setAlreadyReadPages(0)
    character:setAlreadyReadPages(item:getFullType(), 0)
    syncItemFields(character, item)
end

function NLRareScrollReadAction:isBook(item)
    return true
end

function NLRareScrollReadAction:complete()
    local completed = ISReadABook.complete(self)
    if completed ~= true then return completed end

    NinjaLineages.RareScrolls.tryLearn(self.character, self.rareScrollId)
    resetReadProgress(self.character, self.item)
    return true
end

function NLRareScrollReadAction:new(character, item, rareScrollId)
    local action = ISReadABook.new(self, character, item)
    action.rareScrollId = rareScrollId
    return action
end

ISInventoryPaneContextMenu.readItem = function(item, player)
    local definition = NinjaLineages.RareScrolls.getForItem(item)
    if not definition then
        return NinjaLineages.originalReadItem(item, player)
    end

    local playerObj = getSpecificPlayer(player)
    local canStudy, reason = NinjaLineages.RareScrolls.canStudy(playerObj, definition.id)
    if not canStudy then
        local messageKey = NinjaLineages.RareScrolls.getErrorMessage(definition, reason)
        if messageKey then playerObj:Say(getText(messageKey)) end
        return
    end

    local chance = NinjaLineages.RareScrolls.getLearningChance(playerObj, definition.id) * 100
    playerObj:Say(getText(definition.messages.chance, string.format("%.1f", chance)))

    item:setNumberOfPages(NinjaLineages.RareScrolls.getPages(definition))

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(NLRareScrollReadAction:new(playerObj, item, definition.id))
    ISCraftingUI.ReturnItemToOriginalContainer(playerObj, item)
end
