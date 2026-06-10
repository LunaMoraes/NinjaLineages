require "NinjaLineages_Traits"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rinnegan = {}

local consts = NinjaLineages.Constants

local function applyShinraDamage(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local falloff = math.max(consts.Rinnegan.ShinraTensei.DAMAGE_MIN_FALLOFF, 1.0 - ((target.distance / consts.Rinnegan.ShinraTensei.RADIUS) * 0.15))
    local damage = NinjaLineages.Utils.Combat.randomDamage(consts.Rinnegan.ShinraTensei.DAMAGE_MIN, consts.Rinnegan.ShinraTensei.DAMAGE_MAX) * falloff
    NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
end

local function getKnockdownChance(distance)
    if distance <= consts.Rinnegan.ShinraTensei.GUARANTEED_KNOCKDOWN_RADIUS then return 100 end

    local outerRange = consts.Rinnegan.ShinraTensei.RADIUS - consts.Rinnegan.ShinraTensei.GUARANTEED_KNOCKDOWN_RADIUS
    if outerRange <= 0 then return 0 end

    local remaining = math.max(0, consts.Rinnegan.ShinraTensei.RADIUS - distance)
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

    local targets = NinjaLineages.Utils.Zombies.collectInRadius(player, consts.Rinnegan.ShinraTensei.RADIUS)
    local cost = math.min(
        consts.Rinnegan.ShinraTensei.COST_CAP,
        consts.Rinnegan.ShinraTensei.BASE_COST + (#targets * consts.Rinnegan.ShinraTensei.COST_PER_ZOMBIE)
    )
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say(getText("UI_NL_Error_NotEnoughChakra_ShinraTensei"))
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    for _, target in ipairs(targets) do
        applyShinraToZombie(player, target)
    end

    NinjaLineages.Cooldowns.set(player, "rinnegan.shinra_tensei", consts.Rinnegan.ShinraTensei.COOLDOWN_SECONDS)
    player:Say(getText("UI_NL_Ability_ShinraTensei_Cast"))
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "shinra_tensei",
    name = "UI_NL_Ability_ShinraTensei_Name",
    texture = "media/ui/Traits/trait_rinnegan.png",
    condition = function(player) return NinjaLineages.hasRinnegan(player) end,
    action = useShinraTensei
})
