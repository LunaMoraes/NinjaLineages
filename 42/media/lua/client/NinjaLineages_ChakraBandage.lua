require "TimedActions/ISApplyBandage"

local originalComplete = ISApplyBandage.complete

function ISApplyBandage:complete()
    local removedChakraBandage = not self.doIt
        and self.bodyPart
        and self.bodyPart:getBandageType() == "Base.NL_ChakraBandage"
    local completed = originalComplete(self)
    if removedChakraBandage and completed == true then
        local item = self.character:getInventory():getItemFromType("Base.NL_ChakraBandage")
        if item then
            self.character:getInventory():Remove(item)
            pcall(function() sendRemoveItemFromContainer(self.character:getInventory(), item) end)
        end
    end
    return completed
end
