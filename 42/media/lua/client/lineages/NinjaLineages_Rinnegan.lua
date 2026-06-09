require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rinnegan = {}

local consts = NinjaLineages.Constants

local function getTimestampSeconds()
    if getTimestamp then return getTimestamp() end
    return math.floor(getTimestampMs() / 1000)
end

local function collectShinraTargets(player)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return targets end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local distance = zombie:DistTo(player)
            if distance <= consts.SHINRA_RADIUS then
                table.insert(targets, { zombie = zombie, distance = distance })
            end
        end
    end
    return targets
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

local function applyShinraDamage(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local falloff = math.max(consts.SHINRA_MIN_DAMAGE_FALLOFF, 1.0 - ((target.distance / consts.SHINRA_RADIUS) * 0.15))
    local damage = getRandomDamage(consts.SHINRA_MIN_DAMAGE, consts.SHINRA_MAX_DAMAGE) * falloff
    applyZombieDamage(player, zombie, damage)
end

local function getKnockdownChance(distance)
    if distance <= consts.SHINRA_GUARANTEED_KNOCKDOWN_RADIUS then return 100 end

    local outerRange = consts.SHINRA_RADIUS - consts.SHINRA_GUARANTEED_KNOCKDOWN_RADIUS
    if outerRange <= 0 then return 0 end

    local remaining = math.max(0, consts.SHINRA_RADIUS - distance)
    return math.floor((remaining / outerRange) * 100)
end

local function applyShinraToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    zombie:setVariable("AttackOutcome", "fail")
    zombie:setStaggerBack(true)
    if ZombRand(1, 101) <= getKnockdownChance(target.distance) then
        zombie:setKnockedDown(true)
    end
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition("FRONT") end)
    pcall(function() zombie:setHitForce(math.max(2.0, 8.0 - target.distance)) end)
    pcall(function() zombie:reportEvent("wasHit") end)
    applyShinraDamage(player, target)
end

local function useShinraTensei(player)
    if not NinjaLineages.hasRinnegan(player) then
        player:Say("Rinnegan is required")
        return
    end

    local data = NinjaLineages.getNLData(player)
    local now = getTimestampSeconds()
    if data.shinraCooldownUntil and now < data.shinraCooldownUntil then
        player:Say("Shinra Tensei cooldown: " .. tostring(math.ceil(data.shinraCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats then return end

    local targets = collectShinraTargets(player)
    local cost = math.min(
        NinjaLineages.Chakra.SHINRA_COST_CAP,
        NinjaLineages.Chakra.SHINRA_BASE_COST + (#targets * NinjaLineages.Chakra.SHINRA_COST_PER_ZOMBIE)
    )
    if not NinjaLineages.Chakra.canAffordChakra(player, cost) then
        player:Say("Not enough chakra for Shinra Tensei")
        return
    end

    NinjaLineages.Chakra.spendChakra(player, cost)
    for _, target in ipairs(targets) do
        applyShinraToZombie(player, target)
    end

    data.shinraCooldownUntil = now + consts.SHINRA_COOLDOWN_SECONDS
    NinjaLineages.transmitPlayerData(player)
    player:Say("Shinra Tensei")
end

-- Dynamic Registration
NinjaLineages.registerAbility({
    id = "shinra_tensei",
    name = "Shinra Tensei",
    texture = "media/ui/Traits/trait_rinnegan.png",
    condition = function(player) return NinjaLineages.hasRinnegan(player) end,
    action = useShinraTensei
})
