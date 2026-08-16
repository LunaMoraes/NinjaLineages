require "NinjaLineages_Utils"
require "NinjaLineages_Traits"
require "NinjaLineages_Chakra"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ByakuganPassives = NinjaLineages.ByakuganPassives or {}

local ByakuganPassives = NinjaLineages.ByakuganPassives

local function isLivePlayer(player)
    return NinjaLineages.Utils.isLivePlayer(player)
end

local function getWornByakuganSight(player)
    return NinjaLineages.Utils.Inventory.findWornItem(player, function(item)
        local fullType = item and item:getFullType()
        return fullType == "Base.NL_ByakuganSight" or fullType == "Base.NL_ByakuganSight_Half"
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
    local inv = player:getInventory()

    local equipped = getWornByakuganSight(player)
    if equipped then
        NinjaLineages.Utils.Inventory.removeWornItem(player, equipped)
        if inv then
            inv:Remove(equipped)
            pcall(function() sendRemoveItemFromContainer(inv, equipped) end)
        end
        changed = true
    end

    if inv and data.byakuganSightItemId then
        local item = inv:getItemById(data.byakuganSightItemId)
        if item and item ~= equipped then
            NinjaLineages.Utils.Inventory.removeWornItem(player, item)
            inv:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inv, item) end)
            changed = true
        end
    end

    data.byakuganSightItemId = nil
    data.byakuganAddedSightItem = nil
    return changed
end

local function ensureByakuganSight(player, data, eyeCount)
    local desiredType = (eyeCount >= 2) and "Base.NL_ByakuganSight" or "Base.NL_ByakuganSight_Half"
    local equipped = getWornByakuganSight(player)

    if equipped and equipped:getFullType() == desiredType then
        NinjaLineages.Utils.Inventory.wearItem(player, equipped)
        local hadId = data.byakuganSightItemId
        data.byakuganSightItemId = equipped:getID()
        return hadId ~= data.byakuganSightItemId
    end

    if equipped then
        removeTrackedByakuganSight(player, data)
    end

    local inv = player:getInventory()
    if not inv then return false end

    local item = inv:AddItem(desiredType)
    if not item then return false end

    pcall(function() sendAddItemToContainer(inv, item) end)
    NinjaLineages.Utils.Inventory.wearItem(player, item)
    data.byakuganSightItemId = item:getID()
    data.byakuganAddedSightItem = true
    return true
end

function ByakuganPassives.applyByakugan(player)
    if not isLivePlayer(player) then return end

    local data = NinjaLineages.getNLData(player)
    if not data then return end

    local eyeCount = NinjaLineages.getInstalledEyeCount(player, "byakugan")
    local active = (eyeCount > 0)
        and data.eyePowerActive == true
        and NinjaLineages.Chakra.getChakra(player) > 0

    if NinjaLineages.isServer() then
        local lastSyncedActive = data.byakuganSyncedActive
        local lastSyncedCount = data.byakuganSyncedCount
        if lastSyncedActive ~= active or lastSyncedCount ~= eyeCount then
            data.byakuganSyncedActive = active
            data.byakuganSyncedCount = eyeCount
            sendServerCommand(player, "NinjaLineages", "abilityEvent", {
                kind = "byakuganSync",
                active = active,
                eyeCount = eyeCount,
                casterOnlineId = player:getOnlineID(),
            })
            NinjaLineages.transmitPlayerData(player)
        end
    elseif not NinjaLineages.isClient() then
        -- Singleplayer fallback
        local changed = false
        if active then
            changed = ensureByakuganSight(player, data, eyeCount) or changed
            changed = addOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED) or changed
            if eyeCount >= 2 then
                changed = addOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING) or changed
            else
                changed = removeOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING) or changed
            end
        else
            if data.eyePowerActive and eyeCount > 0 then
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
end

if NinjaLineages.isServer() or not NinjaLineages.isClient() then
    NinjaLineages.registerPlayerUpdate("byakugan.update", ByakuganPassives.applyByakugan)
    NinjaLineages.registerEveryMinute("byakugan.everyMinute", ByakuganPassives.applyByakugan)
end

if NinjaLineages.isClient() then
    require "NinjaLineages_AbilityAuthority"

    NinjaLineages.AbilityAuthority.registerEventHandler("byakuganSync", function(args)
        local player = NinjaLineages.AbilityAuthority.findLocalPlayer(args.casterOnlineId)
        if player then
            local data = NinjaLineages.getNLData(player)
            local count = args.eyeCount or 2
            if args.active then
                ensureByakuganSight(player, data, count)
                addOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED)
                if count >= 2 then
                    addOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING)
                else
                    removeOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING)
                end
            else
                removeTrackedByakuganSight(player, data)
                removeOwnedTrait(player, data, "byakuganAddedEagleEyed", CharacterTrait.EAGLE_EYED)
                removeOwnedTrait(player, data, "byakuganAddedKeenHearing", CharacterTrait.KEEN_HEARING)
            end
        end
    end)
end
