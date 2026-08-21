require "disciplines/sennin/NinjaLineages_SageMode"
require "disciplines/jinchuuriki/NinjaLineages_ChakraCloak"

NinjaLineages = NinjaLineages or {}
NinjaLineages.CombatModifiers = NinjaLineages.CombatModifiers or {}

local Modifiers = NinjaLineages.CombatModifiers
local runtimeState = setmetatable({}, { __mode = "k" })

local function multiplicative(player, method)
    local value = 1.0
    local sage = NinjaLineages.SageMode
    if sage and sage[method] then value = value * sage[method](player) end
    local cloak = NinjaLineages.ChakraCloak
    if cloak and cloak[method] then value = value * cloak[method](player) end
    return value
end

function Modifiers.getMeleeDamageMultiplier(player)
    return multiplicative(player, "getMeleeDamageMultiplier")
end

function Modifiers.getMeleeAttackSpeedMultiplier(player)
    return multiplicative(player, "getMeleeAttackSpeedMultiplier")
end

function Modifiers.getMovementSpeedMultiplier(player)
    return multiplicative(player, "getMovementSpeedMultiplier")
end

function Modifiers.getFirearmAccuracyBonus(player)
    local value = 0
    local sage = NinjaLineages.SageMode
    if sage and sage.getFirearmAccuracyBonus then
        value = value + sage.getFirearmAccuracyBonus(player)
    end
    local cloak = NinjaLineages.ChakraCloak
    if cloak and cloak.getFirearmAccuracyBonus then
        value = value + cloak.getFirearmAccuracyBonus(player)
    end
    return value
end

function Modifiers.getJutsuDamageMultiplier(player)
    return multiplicative(player, "getJutsuDamageMultiplier")
end

function Modifiers.getJutsuHealingMultiplier(player)
    return multiplicative(player, "getJutsuHealingMultiplier")
end

function Modifiers.applyJutsuDamage(player, amount)
    return math.max(0, tonumber(amount) or 0) * Modifiers.getJutsuDamageMultiplier(player)
end

function Modifiers.applyJutsuHealing(player, amount)
    return math.max(0, tonumber(amount) or 0) * Modifiers.getJutsuHealingMultiplier(player)
end

local function updateFloatModifier(player, state, key, multiplier, getter, setter)
    local ok, current = pcall(getter)
    if not ok or type(current) ~= "number" then return end
    local lastApplied = state[key .. "Applied"]
    if not lastApplied or math.abs(current - lastApplied) > 0.0001 then
        state[key .. "Base"] = current
    end
    local base = state[key .. "Base"] or current
    if multiplier == 1.0 then
        if lastApplied then pcall(function() setter(base) end) end
        state[key .. "Base"] = nil
        state[key .. "Applied"] = nil
        return
    end
    local applied = base * multiplier
    pcall(function() setter(applied) end)
    state[key .. "Applied"] = applied
end

local function restoreWeaponAccuracy(state)
    local weapon = state.accuracyWeapon
    if weapon and state.accuracyBase ~= nil and weapon.setHitChance then
        pcall(function() weapon:setHitChance(state.accuracyBase) end)
    end
    state.accuracyWeapon = nil
    state.accuracyBase = nil
    state.accuracyApplied = nil
end

local function updateWeaponAccuracy(player, state)
    local weapon = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    local ranged = false
    if weapon and instanceof(weapon, "HandWeapon") then
        pcall(function() ranged = weapon:isRanged() end)
    end
    local bonus = ranged and Modifiers.getFirearmAccuracyBonus(player) or 0
    if weapon ~= state.accuracyWeapon then restoreWeaponAccuracy(state) end
    if not ranged or bonus <= 0 or not weapon.getHitChance or not weapon.setHitChance then return end

    local ok, current = pcall(function() return weapon:getHitChance() end)
    if not ok or type(current) ~= "number" then return end
    if state.accuracyApplied == nil or current ~= state.accuracyApplied then
        state.accuracyBase = current
    end
    state.accuracyWeapon = weapon
    state.accuracyApplied = math.max(0, math.min(100,
        (state.accuracyBase or current) + bonus))
    pcall(function() weapon:setHitChance(state.accuracyApplied) end)
end

function Modifiers.updatePlayer(player)
    if not player then return end
    local state = runtimeState[player] or {}
    runtimeState[player] = state

    updateFloatModifier(player, state, "movement",
        Modifiers.getMovementSpeedMultiplier(player),
        function() return player:getMoveSpeed() end,
        function(value) player:setMoveSpeed(value) end)

    local weapon = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
    local ranged = false
    if weapon and instanceof(weapon, "HandWeapon") then
        pcall(function() ranged = weapon:isRanged() end)
    end
    local attackMultiplier = ranged and 1.0
        or Modifiers.getMeleeAttackSpeedMultiplier(player)
    updateFloatModifier(player, state, "combat", attackMultiplier,
        function() return player:getCombatSpeed() end,
        function(value) player:setCombatSpeed(value) end)

    updateWeaponAccuracy(player, state)
end

return Modifiers
