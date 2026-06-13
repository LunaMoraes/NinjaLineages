require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Hyuga = NinjaLineages.Hyuga or {}

local consts = NinjaLineages.Constants

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
                local inv = player:getInventory()
                if inv then
                    local item = inv:getItemFromType("Base.NL_ByakuganSight")
                    if not item then
                        item = inv:AddItem("Base.NL_ByakuganSight")
                    end
                    if item then
                        player:setWornItem(item:getBodyLocation(), item)
                    end
                end
            end
            if not player:hasTrait(CharacterTrait.EAGLE_EYED) then
                player:getCharacterTraits():add(CharacterTrait.EAGLE_EYED)
            end
            if not player:hasTrait(CharacterTrait.KEEN_HEARING) then
                player:getCharacterTraits():add(CharacterTrait.KEEN_HEARING)
            end
        else
            data.eyePowerActive = false
            local equipped = getWornByakuganSight(player)
            if equipped then
                player:setWornItem(equipped:getBodyLocation(), nil)
            end
            if player:hasTrait(CharacterTrait.EAGLE_EYED) then
                player:getCharacterTraits():remove(CharacterTrait.EAGLE_EYED)
            end
            if player:hasTrait(CharacterTrait.KEEN_HEARING) then
                player:getCharacterTraits():remove(CharacterTrait.KEEN_HEARING)
            end
            NinjaLineages.Utils.Inventory.removeInventoryItems(player, { "Base.NL_ByakuganSight" })
        end
    else
        local equipped = getWornByakuganSight(player)
        if equipped then
            player:setWornItem(equipped:getBodyLocation(), nil)
        end
        NinjaLineages.Utils.Inventory.removeInventoryItems(player, { "Base.NL_ByakuganSight" })
    end
end

function NinjaLineages.Hyuga.toggleByakugan(player)
    local data = NinjaLineages.getNLData(player)
    if data.eyePowerActive then
        data.eyePowerActive = false
        applyByakugan(player)
        player:Say(getText("UI_NL_Ability_Byakugan_Deactivated"))
        return true
    else
        if NinjaLineages.Chakra.getChakra(player) > 0 then
            data.eyePowerActive = true
            applyByakugan(player)
            pcall(function()
                player:playerVoiceSound(consts.Hyuga.Audio.ACTIVATION_VOICE)
            end)
            player:Say(getText("UI_NL_Ability_Byakugan_Cast"))
            return true
        else
            player:Say(getText("UI_NL_Error_NotEnoughChakra"))
            return false
        end
    end
end

-- Gentle Fist hit logic helpers
local function isBareHands(weapon)
    if not weapon then return false end
    local ok, weaponType = pcall(function() return weapon:getType() end)
    return ok and weaponType == "BareHands"
end

local function getAttackPosition(attacker, zombie)
    local ok, position = pcall(function() return zombie:testDotSide(attacker) end)
    if ok and position then return position end
    return "FRONT"
end

local function isZombieCharacter(zombie)
    local ok, result = pcall(function() return zombie:isZombie() end)
    if ok then return result == true end
    return instanceof(zombie, "IsoZombie")
end

local function byakuganPushHit(zombie, attacker, bodyPartType, handWeapon)
    if not zombie or not attacker or not handWeapon then return end
    if not instanceof(attacker, "IsoPlayer") then return end
    if not attacker:isLocalPlayer() then return end
    if not NinjaLineages.hasByakugan(attacker) then return end
    local data = NinjaLineages.getNLData(attacker)
    if not data.eyePowerActive then return end
    if not isBareHands(handWeapon) then return end
    if not isZombieCharacter(zombie) or zombie:isDead() then return end

    if not NinjaLineages.Chakra.spendChakra(attacker, NinjaLineages.Balance.getCost("TRIVIAL")) then return end

    pcall(function() zombie:setHitFromBehind(attacker:isBehind(zombie)) end)
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = true, position = getAttackPosition(attacker, zombie), force = 2.0 })

    NinjaLineages.Utils.Combat.applyZombieDamage(attacker, zombie, NinjaLineages.Balance.rollDamage("LIGHT"))
end

-- Modular eye drain implementation
function NinjaLineages.Hyuga.getEyePowerDrain(player, data)
    if data.eyePowerActive and NinjaLineages.hasByakugan(player) then
        return consts.Hyuga.ByakuganDrainPerMinute
    end
    return 0.0
end

function NinjaLineages.Hyuga.onEyePowerDeactivated(player)
    applyByakugan(player)
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "byakugan",
    lineage = "hyuga",
    name = "UI_NL_Ability_Byakugan_Name",
    descriptionKey = "UI_NL_Ability_Byakugan_Desc",
    texture = "media/ui/Traits/trait_byakugan.png",
    condition = function(player) return NinjaLineages.hasByakugan(player) end,
    action = NinjaLineages.Hyuga.toggleByakugan
})

NinjaLineages.registerPlayerUpdate("hyuga.applyByakugan", applyByakugan)
NinjaLineages.registerCreatePlayer("hyuga.applyByakuganInit", applyByakugan)
