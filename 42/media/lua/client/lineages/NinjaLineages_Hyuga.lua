require "NinjaLineages_Traits"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Hyuga = NinjaLineages.Hyuga or {}

local function getWornByakuganSight(player)
    return NinjaLineages.Utils.Inventory.getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function applyByakugan(player)
    if not player then return end

    if NinjaLineages.hasByakugan(player) then
        local data = NinjaLineages.getNLData(player)
        local chakra = NinjaLineages.Chakra.getChakra(player)
        if data.eyePowerActive and chakra > 0 then
            local equipped = getWornByakuganSight(player)
            if not equipped then
                local inventory = player:getInventory()
                if inventory then
                    local item = inventory:getItemFromType("Base.NL_ByakuganSight")
                        or inventory:AddItem("Base.NL_ByakuganSight")
                    if item then player:setWornItem(item:getBodyLocation(), item) end
                end
            end
            if not player:hasTrait(CharacterTrait.EAGLE_EYED) then
                player:getCharacterTraits():add(CharacterTrait.EAGLE_EYED)
            end
            if not player:hasTrait(CharacterTrait.KEEN_HEARING) then
                player:getCharacterTraits():add(CharacterTrait.KEEN_HEARING)
            end
            return
        end
        data.eyePowerActive = false
    end

    local equipped = getWornByakuganSight(player)
    if equipped then player:setWornItem(equipped:getBodyLocation(), nil) end
    if player:hasTrait(CharacterTrait.EAGLE_EYED) then
        player:getCharacterTraits():remove(CharacterTrait.EAGLE_EYED)
    end
    if player:hasTrait(CharacterTrait.KEEN_HEARING) then
        player:getCharacterTraits():remove(CharacterTrait.KEEN_HEARING)
    end
    NinjaLineages.Utils.Inventory.removeInventoryItems(player, { "Base.NL_ByakuganSight" })
end

NinjaLineages.registerPlayerUpdate("hyuga.applyByakugan", applyByakugan)
NinjaLineages.registerCreatePlayer("hyuga.applyByakuganInit", applyByakugan)
