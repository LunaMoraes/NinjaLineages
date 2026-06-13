require "NinjaLineages_Progression"
require "NinjaLineages_Balance"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.TreePassives = NinjaLineages.TreePassives or {}

local Progression = NinjaLineages.Progression
local Balance = NinjaLineages.Balance

local function rankValue(player, path)
    local rank = Progression.getCompletedRank(player, path)
    return rank and Balance.getMastery(rank) or 0
end

local function weaponPath(weapon)
    if not weapon or weapon:isRanged() then return nil end
    local script = weapon:getScriptItem()
    if not script then return nil end
    if script:containsWeaponCategory(WeaponCategory.LONG_BLADE)
            or script:containsWeaponCategory(WeaponCategory.SMALL_BLADE) then
        return "blade"
    end
    if script:containsWeaponCategory(WeaponCategory.BLUNT)
            or script:containsWeaponCategory(WeaponCategory.SMALL_BLUNT) then
        return "blunt"
    end
    if script:containsWeaponCategory(WeaponCategory.AXE)
            or script:containsWeaponCategory(WeaponCategory.SPEAR) then
        return "polearm"
    end
    return nil
end

local function weaponPerks(weapon)
    local path = weaponPath(weapon)
    if path == "blade" then return { Perks.LongBlade, Perks.SmallBlade } end
    if path == "blunt" then return { Perks.Blunt, Perks.SmallBlunt } end
    if path == "polearm" then return { Perks.Axe, Perks.Spear } end
    return {}
end

local function onWeaponHitXP(owner, weapon, hitObject, damage, hitCount)
    if not owner or hitCount <= 0 then return end
    local path = weaponPath(weapon)
    if not path then return end
    local bonus = rankValue(owner, path)
    if bonus <= 0 then return end
    local amount = math.max(0, damage) * bonus
    for _, perk in ipairs(weaponPerks(weapon)) do
        if weapon:getScriptItem():containsWeaponCategory(
                perk == Perks.LongBlade and WeaponCategory.LONG_BLADE
                or perk == Perks.SmallBlade and WeaponCategory.SMALL_BLADE
                or perk == Perks.Blunt and WeaponCategory.BLUNT
                or perk == Perks.SmallBlunt and WeaponCategory.SMALL_BLUNT
                or perk == Perks.Axe and WeaponCategory.AXE
                or WeaponCategory.SPEAR) then
            owner:getXp():AddXP(perk, amount)
        end
    end

    local maintenanceBonus = rankValue(owner, "maintenance")
    if maintenanceBonus > 0 then owner:getXp():AddXP(Perks.Maintenance, amount * maintenanceBonus) end

    local saveChance = rankValue(owner, "maintenance")
    if saveChance > 0 and weapon:getCondition() < weapon:getConditionMax()
            and ZombRand(Balance.Progression.ProbabilityMaximum)
                < saveChance * Balance.Progression.ProbabilityMaximum then
        weapon:setCondition(math.min(
            weapon:getConditionMax(),
            weapon:getCondition() + Balance.Progression.ConditionRestore
        ))
    end
end

local function onHitZombie(zombie, attacker, bodyPartType, weapon)
    if not attacker or not weapon or weapon:getType() ~= "BareHands" then return end
    local reliability = rankValue(attacker, "strength")
    if reliability > 0
            and ZombRand(Balance.Progression.ProbabilityMaximum)
                < reliability * Balance.Progression.ProbabilityMaximum then
        NinjaLineages.Utils.Combat.applyControlTier(zombie, Progression.getCompletedRank(attacker, "strength"))
    end
end

local function everyMinute(player, elapsedMinutes)
    local elapsed = elapsedMinutes or 1
    local stats = player:getStats()
    local strengthXP = rankValue(player, "strength")
    local fitnessXP = rankValue(player, "fitness")
    if strengthXP > 0 and player:getInventoryWeight() > player:getMaxWeight() then
        player:getXp():AddXP(Perks.Strength, strengthXP * elapsed)
    end
    if fitnessXP > 0 and stats:get(CharacterStat.ENDURANCE) < Balance.Progression.NormalizedMaximum then
        player:getXp():AddXP(Perks.Fitness, fitnessXP * elapsed)
    end

    local recovery = math.max(
        rankValue(player, "fitness"),
        rankValue(player, "combat_body")
    )
    if recovery > 0 then
        recovery = recovery * elapsed
        stats:set(CharacterStat.ENDURANCE, math.min(
            Balance.Progression.NormalizedMaximum,
            stats:get(CharacterStat.ENDURANCE) + recovery
        ))
        stats:set(CharacterStat.FATIGUE, math.max(0, stats:get(CharacterStat.FATIGUE) - recovery))
    end

    local painReduction = rankValue(player, "combat_body")
    if painReduction > 0 then
        painReduction = painReduction * elapsed
        local parts = player:getBodyDamage():getBodyParts()
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            pcall(function()
                part:setAdditionalPain(math.max(0, part:getAdditionalPain() - painReduction))
            end)
        end
    end
end

Events.OnWeaponHitXp.Add(onWeaponHitXP)
NinjaLineages.registerHitZombie("treePassives.hitZombie", onHitZombie)
NinjaLineages.registerEveryMinute("treePassives.everyMinute", everyMinute)
