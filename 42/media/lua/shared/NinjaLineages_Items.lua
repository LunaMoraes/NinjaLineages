require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "NinjaLineages_Progression"
require "NinjaLineages_ScrollUtils"
require "TimedActions/ISReadABook"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CreationRebirth = NinjaLineages.CreationRebirth or {}
AcceptItemFunction = AcceptItemFunction or {}
RecipeCodeOnTest = RecipeCodeOnTest or {}

local CREATION_REBIRTH_SCROLL = "Base.NL_CreationRebirthScroll"

function RecipeCodeOnTest.NinjaLineagesUzumakiOnly(item, result)
    local player = nil
    pcall(function()
        if getPlayer then player = getPlayer() end
    end)
    if not player then
        pcall(function()
            if getSpecificPlayer then player = getSpecificPlayer(0) end
        end)
    end
    if not player then return false end
    local resultType = result and result:getFullType() or ""
    if resultType == "Base.NL_AlarmSeal" then
        return NinjaLineages.Progression.isCompleted(player, "alarm_seal")
    end
    return NinjaLineages.Progression.isCompleted(player, "storage_seal")
end

-- (NinjaLineages.ScrollUtils.isSealedScroll now in NinjaLineages.ScrollUtils)

function AcceptItemFunction.NinjaLineagesSealedScroll(container, item)
    if not container or not item then return false end
    if container:getItems():size() >= 1 then return false end
    if NinjaLineages.ScrollUtils.isSealedScroll(item) then return false end
    local ok, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not ok or isContainer ~= true then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    return okCategory and tostring(category) == "Bag"
end

function NinjaLineages.CreationRebirth.isScroll(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == CREATION_REBIRTH_SCROLL
end

function NinjaLineages.CreationRebirth.isUnlocked(player)
    local data = NinjaLineages.getNLData(player)
    return data and data.creationRebirthUnlocked == true
end

function NinjaLineages.CreationRebirth.getLearningChance(player)
    local maximum = NinjaLineages.Chakra.getMaxChakra(player)
    local guaranteedAt = NinjaLineages.Constants.Senju.CreationRebirth.SCROLL_GUARANTEED_MAX_CHAKRA
    return math.max(0, math.min(1, maximum / guaranteedAt))
end

function NinjaLineages.CreationRebirth.canStudy(player)
    if NinjaLineages.CreationRebirth.isUnlocked(player) then
        return false, "alreadyUnlocked"
    end

    local minimum = NinjaLineages.Constants.Senju.CreationRebirth.SCROLL_MIN_MAX_CHAKRA
    if NinjaLineages.Chakra.getMaxChakra(player) < minimum then
        return false, "maxChakra"
    end

    return true
end

function NinjaLineages.CreationRebirth.unlock(player, messageKey)
    if NinjaLineages.CreationRebirth.isUnlocked(player) then return false end

    local data = NinjaLineages.getNLData(player)
    data.creationRebirthUnlocked = true
    NinjaLineages.transmitPlayerData(player)
    if messageKey then
        player:Say(getText(messageKey))
    end
    return true
end

function NinjaLineages.CreationRebirth.tryLearn(player)
    local canStudy, reason = NinjaLineages.CreationRebirth.canStudy(player)
    if not canStudy then
        return false, reason
    end

    local chance = NinjaLineages.CreationRebirth.getLearningChance(player)
    if ZombRandFloat(0.0, 1.0) <= chance then
        NinjaLineages.CreationRebirth.unlock(player, "UI_NL_Unlock_CreationRebirth")
        return true
    end

    player:Say(getText("UI_NL_CreationRebirthStudyFailed"))
    return false, "failed"
end

NLCreationRebirthReadAction = ISReadABook:derive("NLCreationRebirthReadAction")

local function resetCreationRebirthReadProgress(character, item)
    item:setAlreadyReadPages(0)
    character:setAlreadyReadPages(item:getFullType(), 0)
    syncItemFields(character, item)
end

function NLCreationRebirthReadAction:isBook(item)
    return true
end

function NLCreationRebirthReadAction:complete()
    local completed = ISReadABook.complete(self)
    if completed ~= true then return completed end

    NinjaLineages.CreationRebirth.tryLearn(self.character)
    resetCreationRebirthReadProgress(self.character, self.item)
    return true
end

function NLCreationRebirthReadAction:new(character, item)
    return ISReadABook.new(self, character, item)
end
