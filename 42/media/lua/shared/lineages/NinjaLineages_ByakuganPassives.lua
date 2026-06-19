require "NinjaLineages_Utils"
require "NinjaLineages_Traits"
require "NinjaLineages_Chakra"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ByakuganPassives = NinjaLineages.ByakuganPassives or {}

local ByakuganPassives = NinjaLineages.ByakuganPassives

local function isLivePlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

local function getWornByakuganSight(player)
    return NinjaLineages.Utils.Inventory.findWornItem(player, function(item)
        return item:getFullType() == "Base.NL_ByakuganSight"
    end)
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

    pcall(function() sendAddItemToContainer(inv, item) end)
    NinjaLineages.Utils.Inventory.wearItem(player, item)
    data.byakuganSightItemId = item:getID()
    data.byakuganAddedSightItem = true
    return true
end

function ByakuganPassives.applyByakugan(player)
    if not isLivePlayer(player) then return end
    if NinjaLineages.isClient() then return end

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
        changed = removeOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED) or changed
        changed = removeOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING) or changed
    end
    if changed then
        NinjaLineages.transmitPlayerData(player)
    end
end

if NinjaLineages.isServer() or not NinjaLineages.isClient() then
    NinjaLineages.registerPlayerUpdate("byakugan.update", ByakuganPassives.applyByakugan)
    NinjaLineages.registerEveryMinute("byakugan.everyMinute", ByakuganPassives.applyByakugan)
end
