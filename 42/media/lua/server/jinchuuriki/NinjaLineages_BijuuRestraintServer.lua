require "NinjaLineages_Balance"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Targeting"
require "combat/NinjaLineages_CombatModifiers"
require "disciplines/jinchuuriki/NinjaLineages_BijuuBoss"
require "jinchuuriki/NinjaLineages_BijuuBossServer"
require "jinchuuriki/NinjaLineages_BijuuSealingServer"
require "jinchuuriki/NinjaLineages_BijuuServerSupport"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuRestraintServer = NinjaLineages.BijuuRestraintServer or {}

local Server = NinjaLineages.BijuuRestraintServer
local Balance = NinjaLineages.Balance
local Boss = NinjaLineages.BijuuBoss
local BossServer = NinjaLineages.BijuuBossServer
local SealingServer = NinjaLineages.BijuuSealingServer
local Support = NinjaLineages.BijuuServerSupport

local function distance(player, target)
    local dx, dy = player:getX() - target.x, player:getY() - target.y
    return math.sqrt(dx * dx + dy * dy)
end

local function nearestZombieByClass(player, range, zombieNinja)
    local nearest, nearestDistance = nil, range + 1
    for _, entry in ipairs(NinjaLineages.Utils.Zombies.collectInRadius(player, range)) do
        local zombie = entry.zombie
        local modData = zombie and zombie.getModData and zombie:getModData() or nil
        if zombie and not zombie:isDead() and not Boss.isBossProxy(zombie)
                and (modData and modData.isZombieNinja == true) == zombieNinja
                and entry.distance < nearestDistance then
            nearest = {
                kind = "zombie",
                object = zombie,
                onlineId = zombie.getOnlineID and zombie:getOnlineID() or nil,
                x = zombie:getX(), y = zombie:getY(), z = zombie:getZ(),
                distance = entry.distance,
            }
            nearestDistance = entry.distance
        end
    end
    return nearest
end

function Server.selectChainsTarget(player, range)
    local boss, bossDistance = BossServer.findNearestActiveBoss(player, range)
    if boss then
        boss.kind = "bijuu"
        boss.distance = bossDistance
        return boss
    end

    local hostilePlayers = NinjaLineages.Targeting.collectHostilePlayers(player, {
        range = range,
        maxTargets = 1,
    })
    if hostilePlayers[1] then return hostilePlayers[1] end

    return nearestZombieByClass(player, range, true)
        or nearestZombieByClass(player, range, false)
end

local function chainsEvent(player, target, expiresAt)
    return {
        kind = "adamantine_chains",
        casterOnlineId = player.getOnlineID and player:getOnlineID() or nil,
        targetKind = target.kind,
        targetOnlineId = target.onlineId,
        bijuuId = target.bijuuId,
        runtimeId = target.runtimeId,
        fromX = player:getX(), fromY = player:getY(), fromZ = player:getZ(),
        toX = target.x, toY = target.y, toZ = target.z,
        startedAtGameMinutes = NinjaLineages.Utils.Time.gameMinutes(),
        endsAtGameMinutes = expiresAt,
    }
end

function Server.executeAdamantineChains(player, resolved)
    local target = Server.selectChainsTarget(player, resolved.radius)
    if not target then return false, "no_target" end
    local expiresAt = NinjaLineages.Utils.Time.gameMinutes() + resolved.duration

    if target.kind == "bijuu" then
        local config = Balance.Jinchuuriki.Restraints.AdamantineChains
        local applied, reason = SealingServer.applyBossRestraint(
            player, target, "adamantine_sealing_chains", {
                sealingPower = config.SEALING_POWER,
                expiresAtGameMinutes = expiresAt,
                suppressMovement = true,
                suppressAttacks = true,
            })
        if not applied then return false, reason end
    elseif target.kind == "player" or target.kind == "hostile_player" then
        local hostile, reason = NinjaLineages.Targeting.canDamagePlayer(player, target.object)
        if not hostile then return false, reason end
        NinjaLineages.AbilityAuthority.restrainPlayer(target.object, expiresAt)
    else
        NinjaLineages.AbilityAuthority.bindZombie(target.object, expiresAt, {
            suppressMovement = true,
            suppressAttacks = true,
        })
    end

    return true, nil, nil, { event = chainsEvent(player, target, expiresAt) }
end

function Server.applyBindingRootsToBijuu(player, resolved)
    local config = Balance.Jinchuuriki.Restraints.BindingRoots
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local expiresAt = now + resolved.duration * config.BIJUU_DURATION_MULTIPLIER
    local damage = config.BIJUU_BASE_DAMAGE * config.BIJUU_DAMAGE_MULTIPLIER
    if NinjaLineages.CombatModifiers then
        damage = NinjaLineages.CombatModifiers.applyJutsuDamage(player, damage)
    end
    local applied = 0
    for _, target in ipairs(BossServer.getActiveBossSnapshots()) do
        if math.abs(player:getZ() - target.z) < 2 and distance(player, target) <= resolved.radius then
            local ok = SealingServer.applyBossRestraint(
                player, target, "binding_roots", {
                    sealingPower = config.SEALING_POWER,
                    expiresAtGameMinutes = expiresAt,
                    suppressMovement = true,
                    suppressAttacks = true,
                    damage = damage,
                })
            if ok then applied = applied + 1 end
        end
    end
    return applied
end

function Server.debugApplyChains(player)
    local definition = NinjaLineages.JutsuCatalog.get("adamantine_sealing_chains")
    local resolved = definition and NinjaLineages.JutsuCatalog.resolveBalance(definition)
    if not resolved then return false, "unavailable" end
    local ok, reason, _, state = Server.executeAdamantineChains(player, resolved)
    if ok and state and state.event then Support.emit(state.event.kind, state.event) end
    return ok, reason
end

function Server.debugApplyRoots(player)
    local definition = NinjaLineages.JutsuCatalog.get("binding_roots")
    local resolved = definition and NinjaLineages.JutsuCatalog.resolveBalance(definition)
    if not resolved then return false, "unavailable" end
    local count = Server.applyBindingRootsToBijuu(player, resolved)
    return count > 0, count > 0 and "ok" or "no_bijuu_nearby", { count = count }
end

function Server.debugSuppressionState(player)
    local target = BossServer.findNearestActiveBoss(player,
        Balance.getRadius("HUGE"))
    if not target then return false, "no_bijuu_nearby" end
    local state = BossServer.getSuppressionSnapshot(target.bijuuId, target.runtimeId)
    print("[NL-BIJUU-SUPPRESSION] bijuu=" .. tostring(target.bijuuId)
        .. " runtime=" .. tostring(target.runtimeId)
        .. " movement=" .. tostring(state and state.movement)
        .. " attacks=" .. tostring(state and state.attacks)
        .. " contributions=" .. tostring(state and state.contributions))
    return true, "ok", state
end

Support.registerDebugAction("apply_adamantine_chains", Server.debugApplyChains)
Support.registerDebugAction("apply_binding_roots", Server.debugApplyRoots)
Support.registerDebugAction("print_bijuu_suppression", Server.debugSuppressionState)

return Server
