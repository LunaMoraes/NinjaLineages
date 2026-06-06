require "NinjaLineages_Traits"

local PlayerHitReactionState = PlayerHitReactionState or (zombie and zombie.ai and zombie.ai.states and zombie.ai.states.PlayerHitReactionState)
local PlayerHitReactionPVPState = PlayerHitReactionPVPState or (zombie and zombie.ai and zombie.ai.states and zombie.ai.states.PlayerHitReactionPVPState)

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

local function tableContains(t, e)
    for _, value in pairs(t) do
        if value == e then
            return true
        end
    end
    return false
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

local function sharinganEvade(player, damageType, damage)
    if not player then return end
    if not instanceof(player, "IsoPlayer") then return end
    
    local sharinganTrait = getSharinganTrait()
    if not sharinganTrait then return end
    if not player:hasTrait(sharinganTrait) then return end

    local modData = player:getModData()
    if not modData.NL_SharinganInjuredBodyList then
        modData.NL_SharinganInjuredBodyList = {}
    end

    local list = modData.NL_SharinganInjuredBodyList
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local wasInfected = modData.NL_SharinganPlayerInfected or false
    local infected = bodyDamage:isInfected()

    -- Check if player is in a hit reaction state (meaning they just took a physical hit)
    local isHitReaction = false
    if PlayerHitReactionState and player:getCurrentState() == PlayerHitReactionState.instance() then
        isHitReaction = true
    elseif PlayerHitReactionPVPState and player:getCurrentState() == PlayerHitReactionPVPState.instance() then
        isHitReaction = true
    end

    if isHitReaction then
        for i = 0, bodyDamage:getBodyParts():size() - 1 do
            local bodypart = bodyDamage:getBodyParts():get(i)
            if bodypart:HasInjury() == true and tableContains(list, i) == false then
                -- 95% evasion chance
                if ZombRand(1, 101) <= 95 then
                    -- Play sound / display text
                    player:Say("Sharingan!")
                    player:setHitReaction("EvasiveBlocked")

                    -- Clean up wound
                    if bodypart:IsInfected() and wasInfected == false and infected == true then
                        bodypart:SetInfected(false)
                        bodyDamage:setInfected(false)
                        bodyDamage:setInfectionMortalityDuration(-1)
                        bodyDamage:setInfectionTime(-1)
                        bodyDamage:setInfectionLevel(0)
                        bodyDamage:setInfectionGrowthRate(0)
                    end
                    bodypart:setBleedingTime(0)
                    bodypart:setBleeding(false)
                    if bodypart:scratched() then
                        bodypart:setScratchTime(0)
                        bodypart:setScratched(false, false)
                    end
                    if bodypart:isCut() then
                        bodypart:setCutTime(0)
                        bodypart:setCut(false, false)
                    end
                    if bodypart:bitten() then
                        bodypart:RestoreToFullHealth()
                    end
                else
                    table.insert(list, i)
                    if bodypart:IsInfected() and wasInfected == false and infected == true then
                        modData.NL_SharinganPlayerInfected = true
                    end
                end
            end
        end
    end
end

local function applySenjuEndurance(player)
    if not player then return end
    
    local senjuTrait = getSenjuTrait()
    if not senjuTrait then return end
    if not player:hasTrait(senjuTrait) then return end

    local stats = player:getStats()
    if not stats then return end

    -- Bounded endurance recovery
    local current = stats:getEndurance()
    local boosted = math.min(1.0, current + 0.02)
    stats:setEndurance(boosted)

    -- Keep warnings suppressed
    stats:setEndurancewarn(0.0)
    stats:setEndurancedanger(0.0)
end

-- Clear Sharingan injury tracking list for fully healed body parts
local function cleanSharinganList(player)
    if not player then return end
    local modData = player:getModData()
    if not modData.NL_SharinganInjuredBodyList then return end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    for idx = #modData.NL_SharinganInjuredBodyList, 1, -1 do
        local partIdx = modData.NL_SharinganInjuredBodyList[idx]
        local bodypart = bodyDamage:getBodyParts():get(partIdx)
        if bodypart and bodypart:HasInjury() == false then
            table.remove(modData.NL_SharinganInjuredBodyList, idx)
        end
    end
end

-- Combined update handler for player ticks
local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    applyByakugan(player)
    applySenjuEndurance(player)
    cleanSharinganList(player)
end

-- Trigger on player creation or loading
Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        applyByakugan(player)
    end
end)

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPlayerGetDamage.Add(sharinganEvade)
