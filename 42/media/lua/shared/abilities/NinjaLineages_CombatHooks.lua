require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls or {}
NinjaLineages.AbilityExecution.boundZombies = NinjaLineages.AbilityExecution.boundZombies or {}
NinjaLineages.AbilityExecution.active = NinjaLineages.AbilityExecution.active or {}

local sharinganRolls = NinjaLineages.AbilityExecution.sharinganRolls
local boundZombies = NinjaLineages.AbilityExecution.boundZombies
local active = NinjaLineages.AbilityExecution.active
local Balance = NinjaLineages.Balance

local function gentleFist(zombie, attacker, bodyPartType, weapon)
    if not attacker or not zombie or not instanceof(attacker, "IsoPlayer") then return end
    if not NinjaLineages.hasByakugan(attacker) then return end
    if not NinjaLineages.getNLData(attacker).eyePowerActive then return end
    if not weapon or weapon:getType() ~= "BareHands" or zombie:isDead() then return end
    local cost = Balance.getCost("TRIVIAL")
    if not NinjaLineages.Chakra.spendChakra(attacker, cost) then return end
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = true, position = "FRONT" })
    NinjaLineages.Utils.Combat.applyZombieDamage(attacker, zombie, Balance.rollDamage("LIGHT"))
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
        sendServerCommand(player, "NinjaLineages", "abilityEvent", {
            kind = "sharingan_evade",
            casterOnlineId = player:getOnlineID(),
        })
    end
end

if not NinjaLineages.isClient() and Events and Events.OnZombieUpdate then
    NinjaLineages.addEventOnce("shared.abilityExecution.onZombieUpdate", Events.OnZombieUpdate, sharinganEvade)
end

function NinjaLineages.AbilityAuthority.updateWorld()
    local now = NinjaLineages.Utils.Time.gameMinutes()
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
end
