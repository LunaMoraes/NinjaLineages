require "NinjaLineages_Traits"

local SHARINGAN_DODGE_CHANCE = 95
local SENJU_ENDURANCE_RECOVERY_PER_SECOND = 0.01
local sharinganAttackRolls = {}
local senjuLastRecoveryAt = {}

local function getByakuganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.BYAKUGAN
end

local function getSharinganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SHARINGAN
end

local function getSenjuTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SENJU
end

-- Helper to find equipped Byakugan sight
local function getWornByakuganSight(player)
    local wornItems = player:getWornItems()
    if not wornItems then return nil end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem and wornItem:getType() == "NL_ByakuganSight" then
            return wornItem
        end
    end
    return nil
end

local function applyByakugan(player)
    if not player then return end
    local byakuganTrait = getByakuganTrait()
    if not byakuganTrait then return end

    if player:hasTrait(byakuganTrait) then
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
        local equipped = getWornByakuganSight(player)
        if equipped then
            player:setWornItem(equipped:getBodyLocation(), nil)
        end
        local inv = player:getInventory()
        if inv then
            local item = inv:getItemFromType("Base.NL_ByakuganSight")
            if item then
                inv:Remove(item)
            end
        end
    end
end

local function sharinganEvade(zombie)
    if not zombie or zombie:isDead() then return end

    local attackOutcome = zombie:getVariableString("AttackOutcome")
    if attackOutcome ~= "success" then
        sharinganAttackRolls[zombie] = nil
        return
    end

    -- AttackCollisionCheck happens after the attack enters "success".
    -- Handle each success once and turn dodged attacks into misses first.
    if sharinganAttackRolls[zombie] then return end

    local player = zombie:getTarget()
    if not player or not instanceof(player, "IsoPlayer") then return end
    if player:isDead() or player:isZombie() then return end
    if not player:isLocalPlayer() then return end

    local sharinganTrait = getSharinganTrait()
    if not sharinganTrait then return end
    if not player:hasTrait(sharinganTrait) then return end

    sharinganAttackRolls[zombie] = true
    if ZombRand(1, 101) <= SHARINGAN_DODGE_CHANCE then
        zombie:setVariable("AttackOutcome", "fail")
        player:setHitReaction("EvasiveBlocked")
        player:Say("Sharingan!")
    end
end

local function applySenjuEndurance(player)
    if not player then return end
    
    local senjuTrait = getSenjuTrait()
    if not senjuTrait then return end
    if not player:hasTrait(senjuTrait) then
        senjuLastRecoveryAt[player] = nil
        return
    end

    local currentTime = getTimestampMs()
    local lastRecovery = senjuLastRecoveryAt[player]
    if lastRecovery and currentTime < lastRecovery + 1000 then return end
    senjuLastRecoveryAt[player] = currentTime

    local stats = player:getStats()
    if not stats then return end

    local current = stats:get(CharacterStat.ENDURANCE)
    local boosted = math.min(1.0, current + SENJU_ENDURANCE_RECOVERY_PER_SECOND)
    stats:set(CharacterStat.ENDURANCE, boosted)
end

-- Combined update handler for player ticks
local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    applyByakugan(player)
    applySenjuEndurance(player)
end

-- Trigger on player creation or loading
Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        applyByakugan(player)
    end
end)

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnZombieUpdate.Add(sharinganEvade)
