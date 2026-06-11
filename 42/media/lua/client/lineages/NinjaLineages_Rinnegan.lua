require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rinnegan = NinjaLineages.Rinnegan or {}

local consts = NinjaLineages.Constants

local function applyShinraDamage(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local radius = NinjaLineages.Balance.getRadius("STANDARD")
    local falloff = math.max(consts.Rinnegan.ShinraTensei.DAMAGE_MIN_FALLOFF, 1.0 - ((target.distance / radius) * 0.15))
    local damage = NinjaLineages.Balance.rollDamage("HEAVY") * falloff
    NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
end

local function getKnockdownChance(distance)
    local radius = NinjaLineages.Balance.getRadius("STANDARD")
    if distance <= consts.Rinnegan.ShinraTensei.GUARANTEED_KNOCKDOWN_RADIUS then return 100 end

    local outerRange = radius - consts.Rinnegan.ShinraTensei.GUARANTEED_KNOCKDOWN_RADIUS
    if outerRange <= 0 then return 0 end

    local remaining = math.max(0, radius - distance)
    return math.floor((remaining / outerRange) * 100)
end

local function applyShinraToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local knockdown = ZombRand(1, 101) <= getKnockdownChance(target.distance)
    local force = math.max(2.0, 8.0 - target.distance)
    NinjaLineages.Utils.Combat.staggerZombie(zombie, { knockdown = knockdown, position = "FRONT", force = force })
    applyShinraDamage(player, target)
end

local function useShinraTensei(player)
    if not NinjaLineages.hasRinnegan(player) then
        player:Say(getText("UI_NL_Error_LineageRequired", "Rinnegan"))
        return
    end

    local data = NinjaLineages.getNLData(player)
    local onCd, remaining = NinjaLineages.Cooldowns.isOnCooldown(player, "rinnegan.shinra_tensei")
    if onCd then
        player:Say(getText("UI_NL_Error_AbilityOnCooldown", getText("UI_NL_Ability_ShinraTensei_Name"), tostring(remaining)))
        return
    end

    local stats = player:getStats()
    if not stats then return end

    local radius = NinjaLineages.Balance.getRadius("STANDARD")
    local targets = NinjaLineages.Utils.Zombies.collectInRadius(player, radius)
    local baseCost = NinjaLineages.Balance.getCost("MAJOR")
    local stepCost = NinjaLineages.Balance.getCostStep("SMALL")
    local capCost = NinjaLineages.Balance.getCost("ULTIMATE")
    local cost = math.min(
        capCost,
        baseCost + (#targets * stepCost)
    )
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_ShinraTensei"))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    for _, target in ipairs(targets) do
        applyShinraToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(player, "rinnegan.shinra_tensei", NinjaLineages.Balance.getCooldown("STANDARD"))
    player:Say(getText("UI_NL_Ability_ShinraTensei_Cast"))
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "shinra_tensei",
    lineage = "rinnegan",
    name = "UI_NL_Ability_ShinraTensei_Name",
    descriptionKey = "UI_NL_Ability_ShinraTensei_Desc",
    texture = "media/ui/Traits/trait_rinnegan.png",
    condition = function(player) return NinjaLineages.hasRinnegan(player) end,
    costTier = "MAJOR",
    cooldownTier = "STANDARD",
    radiusTier = "STANDARD",
    damageTier = "HEAVY",
    action = useShinraTensei
})
