require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Damage"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls or {}
NinjaLineages.AbilityExecution.boundZombies = NinjaLineages.AbilityExecution.boundZombies or {}
NinjaLineages.AbilityExecution.restrainedPlayers =
    NinjaLineages.AbilityExecution.restrainedPlayers or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}
NinjaLineages.AbilityExecution.pvpDodgeHits =
    NinjaLineages.AbilityExecution.pvpDodgeHits or {}

local sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls
local boundZombies = NinjaLineages.AbilityExecution.boundZombies
local restrainedPlayers = NinjaLineages.AbilityExecution.restrainedPlayers
local active = NinjaLineages.AbilityExecution.active
local pvpDodgeHits = NinjaLineages.AbilityExecution.pvpDodgeHits
local PVP_DODGE_DEDUP_MS = NinjaLineages.Constants.Uchiha.PVP_DODGE_DEDUP_MS
local Balance = NinjaLineages.Balance

function NinjaLineages.AbilityAuthority.bindZombie(zombie, expiresAtGameMinutes, options)
    if not zombie or zombie:isDead() then return false end
    local existing = boundZombies[zombie]
    local existingExpiry = type(existing) == "table"
        and existing.expiresAtGameMinutes or tonumber(existing) or 0
    boundZombies[zombie] = {
        expiresAtGameMinutes = math.max(existingExpiry,
            tonumber(expiresAtGameMinutes) or 0),
        suppressMovement = options and options.suppressMovement == true,
        suppressAttacks = not options or options.suppressAttacks ~= false,
    }
    return true
end

function NinjaLineages.AbilityAuthority.restrainPlayer(player, expiresAtGameMinutes)
    if not player or (player.isDead and player:isDead()) then return false end
    local state = restrainedPlayers[player] or {}
    state.expiresAtGameMinutes = math.max(state.expiresAtGameMinutes or 0,
        tonumber(expiresAtGameMinutes) or 0)
    restrainedPlayers[player] = state
    return true
end

local function playerIdentity(player)
    if not player then return "unknown" end
    if player.getOnlineID then
        local ok, id = pcall(function() return player:getOnlineID() end)
        if ok and id and id >= 0 then return tostring(id) end
    end
    return tostring(player)
end

local function isPvPMeleeHit(player, attacker, weapon)
    if not player or not attacker or attacker == player then return false end
    if not instanceof(attacker, "IsoPlayer") then return false end
    if not weapon or not instanceof(weapon, "HandWeapon") then return false end
    local melee = false
    pcall(function() melee = weapon:isMelee() and not weapon:isRanged() end)
    return melee
end

local function broadcastSharinganEvade(player)
    local event = {
        kind = "sharingan_evade",
        casterOnlineId = player:getOnlineID(),
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "sharinganEvadeBroadcast", event)
    else
        NinjaLineages.AbilityAuthority.handleEvent(event)
    end
end

local function sharinganPvPMeleeEvade(attacker, player, weapon, damage)
    if not player or not instanceof(player, "IsoPlayer") or player:isDead() then return end
    if not isPvPMeleeHit(player, attacker, weapon) then return end
    local allowed = NinjaLineages.Targeting.canDamagePlayer(attacker, player)
    if not allowed then return end

    local data = NinjaLineages.getNLData(player)
    if not NinjaLineages.hasSharingan(player) or not data.eyePowerActive then return end

    local key = playerIdentity(attacker) .. ">" .. playerIdentity(player)
    local now = NinjaLineages.Utils.Time.realMilliseconds()
    if pvpDodgeHits[key] and now - pvpDodgeHits[key] < PVP_DODGE_DEDUP_MS then return end
    pvpDodgeHits[key] = now

    local kamuiActive = active[player] and active[player].kamuiUntil
    local stage = NinjaLineages.getSharinganStage(player)
    local baseChance = NinjaLineages.Balance.Lineages.Uchiha.SharinganDodgeChance[stage] or 0
    local multiplier = NinjaLineages.getEyePowerMultiplier(player, "sharingan")
    local chance = math.floor(baseChance * multiplier)
    local dodged = kamuiActive or ZombRand(1, 101) <= chance
    if dodged then
        player:setAvoidDamage(true)
        broadcastSharinganEvade(player)
    end
end

local function gentleFist(zombie, attacker, bodyPartType, weapon)
    if not attacker or not zombie or not instanceof(attacker, "IsoPlayer") then return end
    if not NinjaLineages.hasByakugan(attacker) then return end
    if not NinjaLineages.getNLData(attacker).eyePowerActive then return end
    if not weapon or weapon:getType() ~= "BareHands" or zombie:isDead() then return end
    local cost = Balance.getCost("TRIVIAL")
    if not NinjaLineages.Chakra.spendChakra(attacker, cost, {
            jutsuSpend = true,
            abilityId = "gentle_fist",
        }) then return end
    local multiplier = NinjaLineages.getEyePowerMultiplier(attacker, "byakugan")
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = true, position = "FRONT" })
    NinjaLineages.Damage.applyZombieDamage(attacker, zombie, Balance.rollDamage("LIGHT") * multiplier)
end

local function sageCombatHook(zombie, attacker, bodyPartType, weapon)
    if not attacker or not zombie or not instanceof(attacker, "IsoPlayer") then return end

    local sageActive = NinjaLineages.SageMode
        and NinjaLineages.SageMode.isActive(attacker)
    local cloakActive = NinjaLineages.ChakraCloak
        and NinjaLineages.ChakraCloak.isActive(attacker)
    if sageActive or cloakActive then
        if sageActive then NinjaLineages.SageMode.onHit(attacker) end
        if weapon and not weapon:isRanged() then
            local mult = NinjaLineages.CombatModifiers
                and NinjaLineages.CombatModifiers.getMeleeDamageMultiplier(attacker)
                or NinjaLineages.SageMode.getMeleeDamageMultiplier(attacker)
            if mult > 1.0 then
                local bonus = (mult - 1.0) * (weapon:getMaxDamage() or 1.0)
                NinjaLineages.Damage.applyZombieDamage(attacker, zombie, bonus)
            end
        end
    end
end

if Events and Events.OnHitZombie then
    NinjaLineages.addEventOnce("shared.abilityExecution.onHitZombie", Events.OnHitZombie, gentleFist)
    NinjaLineages.addEventOnce("shared.abilityExecution.onHitZombie.sage", Events.OnHitZombie, sageCombatHook)
end

local function sharinganEvade(zombie)
    if not zombie or zombie:isDead() then return end
    if zombie:getVariableString("AttackOutcome") ~= "success" then
        sharinganRolls[zombie] = nil
        return
    end
    if sharinganRolls[zombie] then return end
    local player = zombie:getTarget()
    if not player or not instanceof(player, "IsoPlayer") or player:isDead() then return end
    local data = NinjaLineages.getNLData(player)
    if not NinjaLineages.hasSharingan(player) or not data.eyePowerActive then return end
    sharinganRolls[zombie] = true
    if active[player] and active[player].kamuiUntil then
        zombie:setVariable("AttackOutcome", "fail")
        return
    end
    local stage = NinjaLineages.getSharinganStage(player)
    local baseChance = NinjaLineages.Balance.Lineages.Uchiha.SharinganDodgeChance[stage] or 0
    local multiplier = NinjaLineages.getEyePowerMultiplier(player, "sharingan")
    local chance = math.floor(baseChance * multiplier)
    if ZombRand(1, 101) <= chance then
        zombie:setVariable("AttackOutcome", "fail")
        broadcastSharinganEvade(player)
    end
end

if Events and Events.OnZombieUpdate then
    NinjaLineages.addEventOnce("shared.abilityExecution.onZombieUpdate", Events.OnZombieUpdate, sharinganEvade)
end

if Events and Events.OnWeaponHitCharacter then
    NinjaLineages.addEventOnce(
        "shared.abilityExecution.onWeaponHitCharacter.sharinganPvp",
        Events.OnWeaponHitCharacter,
        sharinganPvPMeleeEvade
    )
end

function NinjaLineages.AbilityAuthority.updateRestraints()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    for zombie, binding in pairs(boundZombies) do
        local bindUntil = type(binding) == "table"
            and binding.expiresAtGameMinutes or tonumber(binding) or 0
        if not zombie or zombie:isDead() or now >= bindUntil then
            if zombie and type(binding) == "table" and binding.suppressMovement then
                pcall(function() zombie:setCanWalk(true) end)
            end
            boundZombies[zombie] = nil
        else
            if type(binding) ~= "table" or binding.suppressAttacks then
                zombie:setVariable("AttackOutcome", "fail")
                pcall(function() zombie:setStaggerBack(true) end)
            end
            if type(binding) == "table" and binding.suppressMovement then
                pcall(function()
                    zombie:setCanWalk(false)
                    zombie:setTarget(nil)
                    if zombie.setPath2 then zombie:setPath2(nil) end
                end)
            end
        end
    end
    for player, restraint in pairs(restrainedPlayers) do
        if not player or player:isDead() or now >= restraint.expiresAtGameMinutes then
            if player then
                pcall(function() player:setBlockMovement(false) end)
                pcall(function() player:setBannedAttacking(false) end)
            end
            restrainedPlayers[player] = nil
        else
            pcall(function() player:setBlockMovement(true) end)
            pcall(function() player:setBannedAttacking(true) end)
            pcall(function() player:StopAllActionQueueAiming() end)
        end
    end
end

function NinjaLineages.AbilityAuthority.updateWorld()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    NinjaLineages.AbilityAuthority.updateRestraints()
    for zombie, _ in pairs(sharinganRolls) do
        if not zombie or zombie:isDead() then
            sharinganRolls[zombie] = nil
        end
    end
    for key, seenAt in pairs(pvpDodgeHits) do
        if nowMs - seenAt >= PVP_DODGE_DEDUP_MS then
            pvpDodgeHits[key] = nil
        end
    end
    if NinjaLineages.BringerOfDarkness then
        NinjaLineages.BringerOfDarkness.updateZombies()
    end
    if NinjaLineages.DemonicFlute then
        NinjaLineages.DemonicFlute.updateZombies()
    end
    if NinjaLineages.Kirigakure then
        NinjaLineages.Kirigakure.update()
    end
end
