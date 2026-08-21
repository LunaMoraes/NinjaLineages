require "NinjaLineages_Balance"
require "NinjaLineages_Chakra"
require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ChakraCloak = NinjaLineages.ChakraCloak or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.specializedExecutors =
    NinjaLineages.AbilityExecution.specializedExecutors or {}

local Cloak = NinjaLineages.ChakraCloak
local Progression = NinjaLineages.Progression
local Balance = NinjaLineages.Balance.Jinchuuriki.ChakraCloak

local function hostedBijuuId(player)
    local jinchuuriki = player and Progression.getJinchuurikiData(player) or nil
    local hosted = jinchuuriki and jinchuuriki.hostedBijuuIds or {}
    return hosted[1]
end

function Cloak.getHostedBijuuId(player)
    return hostedBijuuId(player)
end

function Cloak.isActive(player)
    local data = player and NinjaLineages.getNLData(player) or nil
    return data ~= nil and data.chakraCloakActive == true
end

function Cloak.canActivate(player)
    if not player or (player.isDead and player:isDead()) then return false, "invalid_player" end
    if not Progression.isCompleted(player, "chakra_cloak") then return false, "not_learned" end
    if not hostedBijuuId(player) then return false, "no_hosted_bijuu" end
    if NinjaLineages.Chakra.getChakra(player) <= 0 then return false, "chakra" end
    return true
end

function Cloak.deactivate(player, reason)
    local data = player and NinjaLineages.getNLData(player) or nil
    if not data or data.chakraCloakActive ~= true then return false end
    data.chakraCloakActive = false
    data.chakraCloakBijuuId = nil
    NinjaLineages.transmitPlayerData(player)
    if reason == "depleted" and player.Say then
        player:Say(getText("UI_NL_ChakraCloak_Depleted"))
    elseif reason == "host_lost" and player.Say then
        player:Say(getText("UI_NL_ChakraCloak_HostLost"))
    end
    return true
end

function Cloak.activate(player)
    local valid, reason = Cloak.canActivate(player)
    if not valid then return false, reason end
    local data = NinjaLineages.getNLData(player)
    data.chakraCloakActive = true
    data.chakraCloakBijuuId = hostedBijuuId(player)
    NinjaLineages.transmitPlayerData(player)
    return true
end

function Cloak.toggle(player)
    if Cloak.isActive(player) then
        Cloak.deactivate(player, "manual")
        return true
    end
    return Cloak.activate(player)
end

function Cloak.update(player, elapsedGameMinutes)
    if not Cloak.isActive(player) then return end
    if NinjaLineages.isClient and NinjaLineages.isClient() then return end
    local currentHosted = hostedBijuuId(player)
    local data = NinjaLineages.getNLData(player)
    if not currentHosted or data.chakraCloakBijuuId ~= currentHosted
            or (player.isDead and player:isDead()) then
        Cloak.deactivate(player, "host_lost")
        return
    end
    local elapsed = math.max(0, tonumber(elapsedGameMinutes) or 0)
    if elapsed <= 0 then return end
    local drain = NinjaLineages.Balance.getSustainedDrain(Balance.SUSTAINED_DRAIN_TIER)
        * elapsed
    local chakra = NinjaLineages.Chakra.getChakra(player)
    if chakra <= drain then
        NinjaLineages.Chakra.setChakra(player, 0)
        Cloak.deactivate(player, "depleted")
        return
    end
    NinjaLineages.Chakra.setChakra(player, chakra - drain)
end

function Cloak.getMeleeDamageMultiplier(player)
    return Cloak.isActive(player) and Balance.MELEE_DAMAGE_MULTIPLIER or 1.0
end

function Cloak.getMeleeAttackSpeedMultiplier(player)
    return Cloak.isActive(player) and Balance.MELEE_ATTACK_SPEED_MULTIPLIER or 1.0
end

function Cloak.getMovementSpeedMultiplier(player)
    return Cloak.isActive(player) and Balance.MOVEMENT_SPEED_MULTIPLIER or 1.0
end

function Cloak.getFirearmAccuracyBonus(player)
    return Cloak.isActive(player) and Balance.FIREARM_ACCURACY_BONUS or 0
end

function Cloak.getJutsuDamageMultiplier(player)
    return Cloak.isActive(player) and Balance.JUTSU_DAMAGE_MULTIPLIER or 1.0
end

function Cloak.getJutsuHealingMultiplier(player)
    return Cloak.isActive(player) and Balance.JUTSU_HEALING_MULTIPLIER or 1.0
end

NinjaLineages.AbilityExecution.specializedExecutors.chakra_cloak = function(player)
    local wasActive = Cloak.isActive(player)
    local ok, reason = Cloak.toggle(player)
    return ok, reason, nil, wasActive and {
        messageKey = "UI_NL_ChakraCloak_Deactivated",
    } or nil
end

return Cloak
