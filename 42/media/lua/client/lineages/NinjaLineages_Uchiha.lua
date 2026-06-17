require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Moodles"
require "NinjaLineages_UI"
require "NinjaLineages_Balance"
require "lineages/NinjaLineages_UchihaPassives"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Uchiha = NinjaLineages.Uchiha or {}

local consts = NinjaLineages.Constants
local observedSharinganStages = setmetatable({}, { __mode = "k" })

local function updateSharinganProgress(player)
    if not NinjaLineages.hasSharingan(player) then return end

    local stage = NinjaLineages.getSharinganStage(player)
    local lastStage = observedSharinganStages[player]
    if lastStage == nil then
        observedSharinganStages[player] = stage
        return
    end

    if stage > lastStage then
        if stage == 1 then
            player:Say(getText("UI_NL_Unlock_SharinganTomoe1"))
        elseif stage == 2 then
            player:Say(getText("UI_NL_Unlock_SharinganTomoe2"))
        elseif stage == 3 then
            player:Say(getText("UI_NL_Unlock_SharinganTomoe3"))
        end
    end
    observedSharinganStages[player] = stage
end

local function updateSharinganMoodle(player)
    local data = NinjaLineages.getNLData(player)
    if not NinjaLineages.hasSharingan(player) or not data.eyePowerActive then
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.5)
        return
    end

    local stage = NinjaLineages.getSharinganStage(player)
    if data.mangekyoUnlocked then
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.9)
    elseif stage == 3 then
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.8)
    elseif stage == 2 then
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.7)
    elseif stage == 1 then
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.6)
    else
        NinjaLineages.Moodles.setValue("NLSharinganTomoe", player, 0.5)
    end
end

local function applyKamuiVisionItem(player)
    local data = NinjaLineages.getNLData(player)
    local level = data.kamuiVisionLevel or 0
    local equipped = NinjaLineages.Utils.Inventory.getWornItemByType(player, consts.Uchiha.Vision.ITEMS)
    local desiredType = level > 0 and consts.Uchiha.Vision.ITEMS[level] or nil
    if equipped and desiredType and equipped:getFullType() == desiredType then
        NinjaLineages.Utils.Inventory.wearItem(player, equipped)
        if level == 1 then
            NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.4)
        elseif level == 2 then
            NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.3)
        else
            NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.2)
        end
        return
    end

    if equipped then
        NinjaLineages.Utils.Inventory.removeWornItem(player, equipped)
    end

    if level <= 0 then
        NinjaLineages.Utils.Inventory.removeWornItemsByType(player, consts.Uchiha.Vision.ITEMS)
        NinjaLineages.Utils.Inventory.removeInventoryItems(player, consts.Uchiha.Vision.ITEMS)
        NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.5)
        return
    end

    NinjaLineages.Utils.Inventory.removeWornItemsByType(player, consts.Uchiha.Vision.ITEMS)
    NinjaLineages.Utils.Inventory.removeInventoryItems(player, consts.Uchiha.Vision.ITEMS)
    local inv = player:getInventory()
    if not inv then return end
    local item = inv:AddItem(desiredType)
    if item then
        NinjaLineages.Utils.Inventory.wearItem(player, item)
    end

    if level == 1 then
        NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.4)
    elseif level == 2 then
        NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.3)
    else
        NinjaLineages.Moodles.setValue("NLKamuiVision", player, 0.2)
    end
end

local function updateKamuiVisionPresentation(player)
    applyKamuiVisionItem(player)
end

local function isSinglePlayerGame()
    if NinjaLineages.isClient() then return false end
    if NinjaLineages.isServer() then return false end
    return true
end

function NinjaLineages.Uchiha.canUseKamuiTestUnlock(player)
    if not isSinglePlayerGame() then return false end
    if not NinjaLineages.hasSharingan(player) then return false end
    if NinjaLineages.getSharinganStage(player) < 3 then return false end
    return NinjaLineages.getNLData(player).mangekyoUnlocked ~= true
end

function NinjaLineages.Uchiha.unlockKamuiForSinglePlayerTest(player)
    if not NinjaLineages.Uchiha.canUseKamuiTestUnlock(player) then
        player:Say(getText("UI_NL_Error_ThirdTomoeRequired"))
        return
    end

    local data = NinjaLineages.getNLData(player)
    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(player)
    updateSharinganMoodle(player)
    player:Say(getText("UI_NL_Unlock_MangekyoAwakened"))
end

-- Mangekyo unlock authority is now in NinjaLineages.UchihaPassives (shared/server).

NinjaLineages.registerPlayerUpdate("uchiha.update", function(player)
    updateSharinganProgress(player)
    updateSharinganMoodle(player)
    updateKamuiVisionPresentation(player)
end)


NinjaLineages.registerCreatePlayer("uchiha.init", function(player)
    observedSharinganStages[player] = NinjaLineages.getSharinganStage(player)
    updateKamuiVisionPresentation(player)
    updateSharinganMoodle(player)
end)

if not NinjaLineages.isClient() and Events.OnCharacterDeath then
    NinjaLineages.addEventOnce(
        "client.uchiha.onCharacterDeath.unlockMangekyoSPOnly",
        Events.OnCharacterDeath,
        NinjaLineages.UchihaPassives.unlockMangekyoIfEligible
    )
end
