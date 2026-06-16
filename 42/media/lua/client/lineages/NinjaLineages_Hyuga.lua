require "NinjaLineages_Traits"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Hyuga = NinjaLineages.Hyuga or {}

local function getWornByakuganSight(player)
    return NinjaLineages.Utils.Inventory.getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function applyByakugan(player)
    if not player then return end

    -- MP client: server owns gameplay mutations.
    -- The client will receive modData/item/trait sync and should only handle local UI elsewhere.
    if isClient and isClient() then return end

    local data = NinjaLineages.getNLData(player)
    local changed = false

    local active = NinjaLineages.hasByakugan(player)
        and data.eyePowerActive == true
        and NinjaLineages.Chakra.getChakra(player) > 0

    if active then
        local equipped = getWornByakuganSight(player)
        if not equipped then
            local inventory = player:getInventory()
            if inventory then
                local item = inventory:AddItem("Base.NL_ByakuganSight")
                if item then
                    NinjaLineages.Utils.Inventory.wearItem(player, item)
                    data.byakuganSightItemId = item:getID()
                    data.byakuganAddedSightItem = true
                    changed = true
                end
            end
        else
            NinjaLineages.Utils.Inventory.wearItem(player, equipped)
            if data.byakuganSightItemId ~= equipped:getID() then
                changed = true
            end
            data.byakuganSightItemId = equipped:getID()
        end

        if not player:hasTrait(CharacterTrait.EAGLE_EYED) then
            player:getCharacterTraits():add(CharacterTrait.EAGLE_EYED)
            data.byakuganAddedEagleEyed = true
            changed = true
        end

        if not player:hasTrait(CharacterTrait.KEEN_HEARING) then
            player:getCharacterTraits():add(CharacterTrait.KEEN_HEARING)
            data.byakuganAddedKeenHearing = true
            changed = true
        end

        if changed then NinjaLineages.transmitPlayerData(player) end
        return
    end

    if data.eyePowerActive and NinjaLineages.hasByakugan(player) then
        data.eyePowerActive = false
        changed = true
    end

    local equipped = getWornByakuganSight(player)
    if equipped then
        NinjaLineages.Utils.Inventory.removeWornItem(player, equipped)
        changed = true
    end

    local inventory = player:getInventory()
    if inventory and data.byakuganSightItemId then
        local item = inventory:getItemById(data.byakuganSightItemId)
        if item then
            inventory:Remove(item)
            pcall(function() sendRemoveItemFromContainer(inventory, item) end)
            changed = true
        end
    end
    data.byakuganSightItemId = nil
    data.byakuganAddedSightItem = nil

    if data.byakuganAddedEagleEyed and player:hasTrait(CharacterTrait.EAGLE_EYED) then
        player:getCharacterTraits():remove(CharacterTrait.EAGLE_EYED)
        changed = true
    end
    data.byakuganAddedEagleEyed = nil

    if data.byakuganAddedKeenHearing and player:hasTrait(CharacterTrait.KEEN_HEARING) then
        player:getCharacterTraits():remove(CharacterTrait.KEEN_HEARING)
        changed = true
    end
    data.byakuganAddedKeenHearing = nil

    if changed then NinjaLineages.transmitPlayerData(player) end
end

NinjaLineages.registerPlayerUpdate("hyuga.applyByakugan", applyByakugan)
NinjaLineages.registerCreatePlayer("hyuga.applyByakuganInit", applyByakugan)
