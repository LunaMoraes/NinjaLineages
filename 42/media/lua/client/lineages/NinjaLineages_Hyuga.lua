require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Hyuga = {}

local consts = NinjaLineages.Constants

local function getWornItemByType(player, itemTypes)
    local wornItems = player:getWornItems()
    if not wornItems then return nil end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem then
            local fullType = wornItem:getFullType()
            local typeName = wornItem:getType()
            for _, itemType in ipairs(itemTypes) do
                if fullType == itemType or typeName == itemType:gsub("^Base%.", "") then
                    return wornItem
                end
            end
        end
    end
    return nil
end

local function getWornByakuganSight(player)
    return getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function removeInventoryItems(player, itemTypes)
    local inv = player:getInventory()
    if not inv then return end
    for _, itemType in ipairs(itemTypes) do
        local item = inv:getItemFromType(itemType)
        while item do
            inv:Remove(item)
            item = inv:getItemFromType(itemType)
        end
    end
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
            removeInventoryItems(player, { "Base.NL_ByakuganSight" })
        end
    else
        local equipped = getWornByakuganSight(player)
        if equipped then
            player:setWornItem(equipped:getBodyLocation(), nil)
        end
        removeInventoryItems(player, { "Base.NL_ByakuganSight" })
    end
end

function NinjaLineages.Hyuga.toggleByakugan(player)
    local data = NinjaLineages.getNLData(player)
    if data.eyePowerActive then
        data.eyePowerActive = false
        applyByakugan(player)
        player:Say("Byakugan Deactivated")
    else
        if NinjaLineages.Chakra.getChakra(player) > 0 then
            data.eyePowerActive = true
            applyByakugan(player)
            player:Say("Byakugan Activated")
        else
            player:Say("Not enough chakra!")
        end
    end
end

-- Gentle Fist hit logic
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

local function applyZombieDamage(player, zombie, damage)
    if not zombie or zombie:isDead() then return end

    pcall(function() zombie:setAttackedBy(player) end)
    local ok, health = pcall(function() return zombie:getHealth() end)
    if ok and health then
        local newHealth = math.max(0, health - damage)
        pcall(function() zombie:setHealth(newHealth) end)
        if newHealth <= 0 then
            pcall(function() zombie:Kill(player) end)
        end
    end
end

local function getRandomDamage(minDamage, maxDamage)
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
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

    if not NinjaLineages.Chakra.spendChakra(attacker, 2.0) then return end

    pcall(function() zombie:setHitFromBehind(attacker:isBehind(zombie)) end)
    pcall(function() zombie:setKnockedDown(true) end)
    pcall(function() zombie:setStaggerBack(true) end)
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition(getAttackPosition(attacker, zombie)) end)
    pcall(function() zombie:setHitForce(2.0) end)
    pcall(function() zombie:reportEvent("wasHit") end)

    applyZombieDamage(attacker, zombie, getRandomDamage(consts.BYAKUGAN_PUSH_MIN_DAMAGE, consts.BYAKUGAN_PUSH_MAX_DAMAGE))
end

-- Modular eye drain implementation
function NinjaLineages.Hyuga.getEyePowerDrain(player, data)
    if data.eyePowerActive and NinjaLineages.hasByakugan(player) then
        return consts.BYAKUGAN_DRAIN_PER_MINUTE
    end
    return 0.0
end

function NinjaLineages.Hyuga.onEyePowerDeactivated(player)
    applyByakugan(player)
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "byakugan",
    name = "Toggle Byakugan",
    texture = "media/ui/Traits/trait_byakugan.png",
    condition = function(player) return NinjaLineages.hasByakugan(player) end,
    action = NinjaLineages.Hyuga.toggleByakugan
})

NinjaLineages.registerPlayerUpdate(applyByakugan)
NinjaLineages.registerHitZombie(byakuganPushHit)
NinjaLineages.registerCreatePlayer(applyByakugan)
