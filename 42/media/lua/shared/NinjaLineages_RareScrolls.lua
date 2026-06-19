require "NinjaLineages_Utils"
require "NinjaLineages_Skills"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.RareScrolls = NinjaLineages.RareScrolls or {}

local RareScrolls = NinjaLineages.RareScrolls
local RARE_LOOT_WEIGHT = 0.2

RareScrolls.Definitions = {
    creation_rebirth = {
        itemType = "Base.NL_CreationRebirthScroll",
        unlockField = "creationRebirthUnlocked",
        pages = "KAGE",
        lootWeight = RARE_LOOT_WEIGHT,
        messages = {
            chance = "UI_NL_CreationRebirthStudyChance",
            unlocked = "UI_NL_Unlock_CreationRebirth",
            failed = "UI_NL_CreationRebirthStudyFailed",
            alreadyUnlocked = "UI_NL_Error_CreationRebirthAlreadyUnlocked",
            maxChakra = "UI_NL_Error_CreationRebirthMaxChakra",
        },
        getLearningChance = function(player)
            local maximum = NinjaLineages.Chakra.getMaxChakra(player)
            local guaranteedAt =
                NinjaLineages.Constants.Senju.CreationRebirth.SCROLL_GUARANTEED_MAX_CHAKRA
            return math.max(0, math.min(1, maximum / guaranteedAt))
        end,
        canStudy = function(player)
            local minimum = NinjaLineages.Constants.Senju.CreationRebirth.SCROLL_MIN_MAX_CHAKRA
            if NinjaLineages.Chakra.getMaxChakra(player) < minimum then
                return false, "maxChakra"
            end
            return true
        end,
    },
    kirigakure = {
        itemType = "Base.NL_KirigakureScroll",
        unlockField = "kirigakureUnlocked",
        pages = "KAGE",
        lootWeight = RARE_LOOT_WEIGHT,
        messages = {
            chance = "UI_NL_KirigakureStudyChance",
            unlocked = "UI_NL_Unlock_Kirigakure",
            failed = "UI_NL_KirigakureStudyFailed",
            alreadyUnlocked = "UI_NL_Error_KirigakureAlreadyUnlocked",
        },
        getLearningChance = function(player)
            local level = NinjaLineages.Skills.getJutsuProwessLevel(player)
            return math.min(1, (level + 1) * 0.125)
        end,
    },
}

RareScrolls.ByItemType = {}
for id, definition in pairs(RareScrolls.Definitions) do
    definition.id = id
    RareScrolls.ByItemType[definition.itemType] = definition
end

function RareScrolls.get(id)
    return RareScrolls.Definitions[id]
end

function RareScrolls.getByItemType(itemType)
    return RareScrolls.ByItemType[itemType]
end

function RareScrolls.getForItem(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and RareScrolls.getByItemType(fullType) or nil
end

function RareScrolls.isUnlocked(player, id)
    local definition = RareScrolls.get(id)
    local data = definition and NinjaLineages.getNLData(player)
    return data and data[definition.unlockField] == true
end

function RareScrolls.getLearningChance(player, id)
    local definition = RareScrolls.get(id)
    if not definition or not definition.getLearningChance then return 0 end
    return math.max(0, math.min(1, definition.getLearningChance(player)))
end

function RareScrolls.canStudy(player, id)
    local definition = RareScrolls.get(id)
    if not definition then return false, "invalidScroll" end
    if RareScrolls.isUnlocked(player, id) then return false, "alreadyUnlocked" end
    if definition.canStudy then return definition.canStudy(player) end
    return true
end

function RareScrolls.unlock(player, id, messageKey)
    local definition = RareScrolls.get(id)
    if not definition or RareScrolls.isUnlocked(player, id) then return false end

    local data = NinjaLineages.getNLData(player)
    data[definition.unlockField] = true
    NinjaLineages.transmitPlayerData(player)
    if messageKey then player:Say(getText(messageKey)) end
    return true
end

function RareScrolls.tryLearn(player, id)
    local definition = RareScrolls.get(id)
    local canStudy, reason = RareScrolls.canStudy(player, id)
    if not canStudy then return false, reason end

    if ZombRandFloat(0.0, 1.0) <= RareScrolls.getLearningChance(player, id) then
        RareScrolls.unlock(player, id, definition.messages.unlocked)
        return true
    end

    player:Say(getText(definition.messages.failed))
    return false, "failed"
end

function RareScrolls.getPages(definition)
    definition = type(definition) == "table" and definition or RareScrolls.get(definition)
    return definition
        and (NinjaLineages.Balance.Progression.TrainingPages[definition.pages] or 0)
        or 0
end

function RareScrolls.getErrorMessage(definition, reason)
    definition = type(definition) == "table" and definition or RareScrolls.get(definition)
    return definition and definition.messages[reason] or nil
end

NinjaLineages.CreationRebirth = NinjaLineages.CreationRebirth or {}

function NinjaLineages.CreationRebirth.isScroll(item)
    local definition = RareScrolls.getForItem(item)
    return definition and definition.id == "creation_rebirth" or false
end

function NinjaLineages.CreationRebirth.isUnlocked(player)
    return RareScrolls.isUnlocked(player, "creation_rebirth")
end

function NinjaLineages.CreationRebirth.getLearningChance(player)
    return RareScrolls.getLearningChance(player, "creation_rebirth")
end

function NinjaLineages.CreationRebirth.canStudy(player)
    return RareScrolls.canStudy(player, "creation_rebirth")
end

function NinjaLineages.CreationRebirth.unlock(player, messageKey)
    return RareScrolls.unlock(player, "creation_rebirth", messageKey)
end

function NinjaLineages.CreationRebirth.tryLearn(player)
    return RareScrolls.tryLearn(player, "creation_rebirth")
end
