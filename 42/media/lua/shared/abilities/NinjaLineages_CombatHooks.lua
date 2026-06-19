require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Damage"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls or {}
NinjaLineages.AbilityExecution.boundZombies = NinjaLineages.AbilityExecution.boundZombies or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}
NinjaLineages.AbilityExecution.pvpDodgeHits =
    NinjaLineages.AbilityExecution.pvpDodgeHits or {}

local sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls
local boundZombies = NinjaLineages.AbilityExecution.boundZombies
local active = NinjaLineages.AbilityExecution.active
local pvpDodgeHits = NinjaLineages.AbilityExecution.pvpDodgeHits
local Balance = NinjaLineages.Balance
local PVP_DODGE_DEDUP_MS = 300

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
    local chance = NinjaLineages.Constants.Uchiha.SharinganDodgeChance[stage] or 0
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
    if not NinjaLineages.Chakra.spendChakra(attacker, cost) then return end
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = true, position = "FRONT" })
    NinjaLineages.Damage.applyZombieDamage(attacker, zombie, Balance.rollDamage("LIGHT"))
end

if not NinjaLineages.isClient() and Events and Events.OnHitZombie then
    NinjaLineages.addEventOnce("shared.abilityExecution.onHitZombie", Events.OnHitZombie, gentleFist)
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
    local chance = NinjaLineages.Constants.Uchiha.SharinganDodgeChance[stage] or 0
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

function NinjaLineages.AbilityAuthority.updateWorld()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
    for zombie, bindUntil in pairs(boundZombies) do
        if not zombie or zombie:isDead() or now >= bindUntil then
            boundZombies[zombie] = nil
        else
            zombie:setVariable("AttackOutcome", "fail")
            pcall(function() zombie:setStaggerBack(true) end)
        end
    end
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
    if NinjaLineages.Kirigakure then
        NinjaLineages.Kirigakure.update()
    end
end
