require "NinjaLineages_Items"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISCraftingUI"

NinjaLineages = NinjaLineages or {}

if not NinjaLineages.originalReadItem then
    NinjaLineages.originalReadItem = ISInventoryPaneContextMenu.readItem
end

ISInventoryPaneContextMenu.readItem = function(item, player)
    if not NinjaLineages.CreationRebirth.isScroll(item) then
        return NinjaLineages.originalReadItem(item, player)
    end

    local playerObj = getSpecificPlayer(player)
    local canStudy, reason = NinjaLineages.CreationRebirth.canStudy(playerObj)
    if not canStudy then
        local messageKey = reason == "alreadyUnlocked"
            and "UI_NL_Error_CreationRebirthAlreadyUnlocked"
            or "UI_NL_Error_CreationRebirthMaxChakra"
        playerObj:Say(getText(messageKey))
        return
    end

    local chance = NinjaLineages.CreationRebirth.getLearningChance(playerObj) * 100
    playerObj:Say(getText("UI_NL_CreationRebirthStudyChance", string.format("%.1f", chance)))

    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(NLCreationRebirthReadAction:new(playerObj, item))
    ISCraftingUI.ReturnItemToOriginalContainer(playerObj, item)
end
