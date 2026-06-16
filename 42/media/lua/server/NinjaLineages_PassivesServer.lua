require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ServerPassives = NinjaLineages.ServerPassives or {}

local Passives = NinjaLineages.ServerPassives
local consts = NinjaLineages.Constants
local uzumakiHealthState = setmetatable({}, { __mode = "k" })

local function isLivePlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

-- --------------------------------------------------------------------------
-- Byakugan server authority
-- --------------------------------------------------------------------------

local function getWornByakuganSight(player)
    return NinjaLineages.Utils.Inventory.getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function addOwnedTrait(player, data, markerKey, trait)
    if not trait then return false end
    if player:hasTrait(trait) then return false end

    player:getCharacterTraits():add(trait)
    data[markerKey] = true
    return true
end

local function removeOwnedTrait(player, data, markerKey, trait)
    if not trait then return false end
    if data[markerKey] ~= true then return false end

    if player:hasTrait(trait) then
        player:getCharacterTraits():remove(trait)
    end
    data[markerKey] = nil
    return true
end

local function removeTrackedByakuganSight(player, data)
    local changed = false
    local equipped = getWornByakuganSight(player)
    if equipped then
        NinjaLineages.Utils.Inventory.removeWornItem(player, equipped)
        changed = true
    end

    local inv = player:getInventory()
    if inv and data.byakuganSightItemId then
        local item = inv:getItemById(data.byakuganSightItemId)
        if item then
            inv:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inv, item) end)
            changed = true
        end
    end

    data.byakuganSightItemId = nil
    data.byakuganAddedSightItem = nil
    return changed
end

local function ensureByakuganSight(player, data)
    local equipped = getWornByakuganSight(player)
    if equipped then
        NinjaLineages.Utils.Inventory.wearItem(player, equipped)
        local hadId = data.byakuganSightItemId
        data.byakuganSightItemId = equipped:getID()
        return hadId ~= data.byakuganSightItemId
    end

    local inv = player:getInventory()
    if not inv then return false end

    local item = inv:AddItem("Base.NL_ByakuganSight")
    if not item then return false end

    NinjaLineages.Utils.Inventory.wearItem(player, item)
    data.byakuganSightItemId = item:getID()
    data.byakuganAddedSightItem = true
    return true
end

function Passives.applyByakugan(player)
    if not isLivePlayer(player) then return end

    local data = NinjaLineages.getNLData(player)
    if not data then return end

    local changed = false
    local active = NinjaLineages.hasByakugan(player)
        and data.eyePowerActive == true
        and NinjaLineages.Chakra.getChakra(player) > 0

    if active then
        changed = ensureByakuganSight(player, data) or changed
        changed = addOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED) or changed
        changed = addOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING) or changed
    else
        if data.eyePowerActive and NinjaLineages.hasByakugan(player) then
            data.eyePowerActive = false
            changed = true
        end

        changed = removeTrackedByakuganSight(player, data) or changed
        NinjaLineages.Utils.Inventory.refreshWornItemModifiers(player)
        changed = removeOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED) or changed
        changed = removeOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING) or changed
    end

    if changed then
        NinjaLineages.transmitPlayerData(player)
    end
end

-- --------------------------------------------------------------------------
-- Uzumaki server authority
-- --------------------------------------------------------------------------

local function getBodyPartSnapshot(player)
    local snapshot = {}
    local bodyDamage = player and player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return snapshot end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local health = 100
        local bleed = 0
        pcall(function() health = part:getHealth() end)
        pcall(function() bleed = part:getBleedingTime() end)
        snapshot[i] = { health = health, bleed = bleed }
    end

    return snapshot
end

function Passives.captureUzumakiHealthState(player)
    if not isLivePlayer(player) then return end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local state = uzumakiHealthState[player] or {}
    pcall(function() state.generalHealth = bodyDamage:getHealth() end)
    state.parts = getBodyPartSnapshot(player)
    state.lastPassiveAt = NinjaLineages.Utils.Time.gameMinutes()
    uzumakiHealthState[player] = state
end

function Passives.refundUzumakiDamage(player)
    if not isLivePlayer(player) or not NinjaLineages.hasUzumaki(player) then return end

    local state = uzumakiHealthState[player]
    if not state then
        Passives.captureUzumakiHealthState(player)
        return
    end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local okGeneral, currentGeneral = pcall(function() return bodyDamage:getHealth() end)
    local damageRefunded = false
    local parts = bodyDamage:getBodyParts()

    if parts and state.parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local previous = state.parts[i]
            if part and previous then
                local okPart, currentPartHealth = pcall(function() return part:getHealth() end)
                if okPart and currentPartHealth and previous.health and currentPartHealth < previous.health then
                    local lost = previous.health - currentPartHealth
                    local refund = lost * consts.Uzumaki.Passive.DAMAGE_REFUND
                    if refund > 0 then
                        NinjaLineages.Utils.Healing.healPart(bodyDamage, part, { health = refund })
                        damageRefunded = true
                    end
                end
            end
        end
    end

    if not damageRefunded and okGeneral and state.generalHealth and currentGeneral and currentGeneral < state.generalHealth then
        pcall(function()
            bodyDamage:AddGeneralHealth((state.generalHealth - currentGeneral) * consts.Uzumaki.Passive.DAMAGE_REFUND)
        end)
    end

    Passives.captureUzumakiHealthState(player)
    NinjaLineages.transmitPlayerData(player)
end

function Passives.applyUzumakiBleedSlow(player)
    if not isLivePlayer(player) then return end

    if not NinjaLineages.hasUzumaki(player) then
        uzumakiHealthState[player] = nil
        return
    end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local state = uzumakiHealthState[player]
    if not state then
        Passives.captureUzumakiHealthState(player)
        return
    end

    if state.lastPassiveAt and now < state.lastPassiveAt + consts.Uzumaki.Passive.TICK_MINUTES then
        return
    end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local previous = state.parts and state.parts[i]
        if part and previous then
            local okBleed, currentBleed = pcall(function() return part:getBleedingTime() end)
            if okBleed and currentBleed and currentBleed > 0 and previous.bleed and currentBleed < previous.bleed then
                local restored = currentBleed + ((previous.bleed - currentBleed) * consts.Uzumaki.Passive.BLEED_REFUND)
                pcall(function() part:setBleedingTime(restored) end)
            end
        end
    end

    Passives.captureUzumakiHealthState(player)
    NinjaLineages.transmitPlayerData(player)
end

function Passives.updatePlayer(player)
    if not isLivePlayer(player) then return end
    Passives.applyByakugan(player)

    if NinjaLineages.hasUzumaki(player) and not uzumakiHealthState[player] then
        Passives.captureUzumakiHealthState(player)
    end
end

function Passives.everyMinute(player)
    if not isLivePlayer(player) then return end
    Passives.applyByakugan(player)
    Passives.applyUzumakiBleedSlow(player)
end

function Passives.onPlayerGetDamage(player, damageType, damage)
    if isLivePlayer(player) then
        Passives.refundUzumakiDamage(player)
    end
end

if Events and Events.OnPlayerGetDamage then
    NinjaLineages.addEventOnce(
        "server.passives.onPlayerGetDamage",
        Events.OnPlayerGetDamage,
        Passives.onPlayerGetDamage
    )
end
