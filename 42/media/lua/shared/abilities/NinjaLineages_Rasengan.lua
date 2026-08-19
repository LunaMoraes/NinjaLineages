require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Damage"
require "combat/NinjaLineages_Collision"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Rasengan = NinjaLineages.Rasengan or {}

local Rasengan = NinjaLineages.Rasengan
local Balance = NinjaLineages.Balance
local activeRuntimes = {}

local function distancePointToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = (dx * dx) + (dy * dy)
    if l2 <= 0.00001 then
        local sx, sy = px - ax, py - ay
        return math.sqrt((sx * sx) + (sy * sy))
    end
    local t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
    local projX, projY = ax + (t * dx), ay + (t * dy)
    local ex, ey = px - projX, py - projY
    return math.sqrt((ex * ex) + (ey * ey))
end

local function getTuning()
    local t = Balance.JutsuRuntime.Rasengan or {}
    local contactRange = (t.CONTACT_RANGE_TIER and Balance.getRadius(t.CONTACT_RANGE_TIER))
        or t.CONTACT_RANGE
        or Balance.getRadius("TOUCH")
    local catchRadius = (t.CATCH_RADIUS_FACTOR and (contactRange * t.CATCH_RADIUS_FACTOR))
        or t.CATCH_RADIUS
        or (contactRange * 0.5)
    local tickInterval = (t.TICK_INTERVAL_TIER and Balance.getDuration(t.TICK_INTERVAL_TIER))
        or t.TICK_INTERVAL_GAME_MINUTES
        or Balance.getDuration("RAPID_TICK")
    local damageTier = t.TICK_DAMAGE_TIER or "LIGHT"
    local pushSpeed = t.PUSH_SPEED or 8.0

    return {
        contactRange = contactRange,
        catchRadius = catchRadius,
        tickInterval = tickInterval,
        damageTier = damageTier,
        pushSpeed = pushSpeed,
    }
end

function Rasengan.findLeadTarget(player)
    if not player or player:isDead() then return nil end
    local tuning = getTuning()
    local maxRange = tuning.contactRange
    local playerZ = math.floor(player:getZ())
    local forward = player:getForwardDirection()
    if not forward then return nil end

    local closestZombie = nil
    local closestDist = maxRange + 1.0

    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return nil end

    for i = 0, zombies:size() - 1 do
        local zed = zombies:get(i)
        if zed and not zed:isDead() and math.floor(zed:getZ()) == playerZ then
            local dist = zed:DistTo(player)
            if dist <= maxRange then
                local dx = zed:getX() - player:getX()
                local dy = zed:getY() - player:getY()
                local len = math.sqrt((dx * dx) + (dy * dy))
                if len > 0.0001 then
                    local dot = ((dx / len) * forward:getX()) + ((dy / len) * forward:getY())
                    if dot >= 0.40 and dist < closestDist then
                        closestDist = dist
                        closestZombie = zed
                    end
                end
            end
        end
    end

    return closestZombie
end

function Rasengan.cast(player, definition, resolved, args)
    if not player or player:isDead() then return false, "dead" end
    local leadZombie = Rasengan.findLeadTarget(player)
    if not leadZombie then
        return false, "no_target"
    end

    local forward = player:getForwardDirection()
    local dirX = forward and forward:getX() or 0
    local dirY = forward and forward:getY() or 1
    local len = math.sqrt((dirX * dirX) + (dirY * dirY))
    if len > 0.0001 then
        dirX, dirY = dirX / len, dirY / len
    else
        dirX, dirY = 0, 1
    end

    local nowGameMinutes = NinjaLineages.Utils.Time.gameMinutes()
    local tuning = getTuning()
    local runtimeId = "rasengan_" .. tostring(player:getOnlineID() or 0) .. "_" .. tostring(math.floor(nowGameMinutes * 1000))

    activeRuntimes[runtimeId] = {
        id = runtimeId,
        player = player,
        leadZombie = leadZombie,
        leadZombieOnlineId = leadZombie:getOnlineID(),
        caughtZombies = {},
        caughtIds = {},
        dirX = dirX,
        dirY = dirY,
        lastLeadX = leadZombie:getX(),
        lastLeadY = leadZombie:getY(),
        lastUpdateGameMinutes = nowGameMinutes,
        nextDamageGameMinutes = nowGameMinutes + tuning.tickInterval,
        terminated = false,
    }

    local event = {
        kind = "rasengan_started",
        runtimeId = runtimeId,
        leadZombieOnlineId = leadZombie:getOnlineID(),
        leadZombie = leadZombie,
        dirX = dirX,
        dirY = dirY,
        startedAtGameMinutes = nowGameMinutes,
    }

    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "rasenganStartedBroadcast", event)
    else
        if NinjaLineages.VFX and NinjaLineages.VFX.addRasengan then
            NinjaLineages.VFX.addRasengan(event)
        end
    end

    return true
end

function Rasengan.updateAll()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local tuning = getTuning()
    local toRemove = {}

    for id, runtime in pairs(activeRuntimes) do
        local lead = runtime.leadZombie
        local player = runtime.player

        if not lead or lead:isDead() or runtime.terminated then
            table.insert(toRemove, id)
        else
            local dt = now - runtime.lastUpdateGameMinutes
            if dt > 0 then
                local dist = tuning.pushSpeed * dt
                local prevX, prevY = runtime.lastLeadX, runtime.lastLeadY
                local proposedX = prevX + (runtime.dirX * dist)
                local proposedY = prevY + (runtime.dirY * dist)
                local z = math.floor(lead:getZ())

                local hit = NinjaLineages.Collision.traceSegment(
                    prevX, prevY, z,
                    proposedX, proposedY, z,
                    { world = true }
                )

                if hit and (hit.kind == "world" or hit.kind == "object") then
                    -- Wall Resolution: instant kill on lead and all caught zombies
                    local impactX = hit.x or proposedX
                    local impactY = hit.y or proposedY

                    NinjaLineages.Damage.applyZombieDamage(player, lead, 9999)
                    for _, caught in ipairs(runtime.caughtZombies) do
                        if caught and not caught:isDead() then
                            NinjaLineages.Damage.applyZombieDamage(player, caught, 9999)
                        end
                    end

                    local impactEvent = {
                        kind = "rasengan_wall_impact",
                        runtimeId = runtime.id,
                        x = impactX,
                        y = impactY,
                        z = z,
                    }
                    if NinjaLineages.isServer() then
                        sendServerCommand("NinjaLineages", "abilityEvent", impactEvent)
                    elseif NinjaLineages.isClient() then
                        sendClientCommand(player, "NinjaLineages", "rasenganWallImpactBroadcast", impactEvent)
                    else
                        if NinjaLineages.VFX and NinjaLineages.VFX.addRasenganWallImpact then
                            NinjaLineages.VFX.addRasenganWallImpact(impactEvent)
                        end
                    end

                    runtime.terminated = true
                    table.insert(toRemove, id)

                elseif hit and hit.kind == "unloaded" then
                    -- Unloaded square: safely terminate without kill reward
                    local endEvent = { kind = "rasengan_ended", runtimeId = runtime.id, reason = "unloaded" }
                    if NinjaLineages.isServer() then
                        sendServerCommand("NinjaLineages", "abilityEvent", endEvent)
                    elseif NinjaLineages.isClient() then
                        sendClientCommand(player, "NinjaLineages", "rasenganEndedBroadcast", endEvent)
                    else
                        if NinjaLineages.VFX and NinjaLineages.VFX.removeRasengan then
                            NinjaLineages.VFX.removeRasengan(runtime.id)
                        end
                    end
                    runtime.terminated = true
                    table.insert(toRemove, id)

                else
                    -- Clear path: update positions
                    local deltaX = proposedX - prevX
                    local deltaY = proposedY - prevY

                    lead:setX(proposedX)
                    lead:setY(proposedY)

                    for _, caught in ipairs(runtime.caughtZombies) do
                        if caught and not caught:isDead() then
                            caught:setX(caught:getX() + deltaX)
                            caught:setY(caught:getY() + deltaY)
                        end
                    end

                    -- Sweep path for new zombies along travelled segment
                    local cellZombies = getCell() and getCell():getZombieList()
                    if cellZombies then
                        for i = 0, cellZombies:size() - 1 do
                            local zed = cellZombies:get(i)
                            if zed and not zed:isDead() and zed ~= lead and math.floor(zed:getZ()) == z then
                                local zedId = zed:getOnlineID() or tostring(zed)
                                if not runtime.caughtIds[zedId] then
                                    local segDist = distancePointToSegment(zed:getX(), zed:getY(), prevX, prevY, proposedX, proposedY)
                                    if segDist <= tuning.catchRadius then
                                        runtime.caughtIds[zedId] = true
                                        table.insert(runtime.caughtZombies, zed)
                                    end
                                end
                            end
                        end
                    end

                    runtime.lastLeadX = proposedX
                    runtime.lastLeadY = proposedY
                    runtime.lastUpdateGameMinutes = now

                    -- Periodic DoT processing (no drift)
                    while now >= runtime.nextDamageGameMinutes do
                        local tickDamage = Balance.rollDamage(tuning.damageTier)
                        NinjaLineages.Damage.applyZombieDamage(player, lead, tickDamage)

                        for _, caught in ipairs(runtime.caughtZombies) do
                            if caught and not caught:isDead() then
                                NinjaLineages.Damage.applyZombieDamage(player, caught, tickDamage)
                            end
                        end

                        runtime.nextDamageGameMinutes = runtime.nextDamageGameMinutes + tuning.tickInterval

                        if lead:isDead() then
                            -- Normal Resolution: lead died from DoT
                            runtime.terminated = true
                            local endEvent = { kind = "rasengan_ended", runtimeId = runtime.id, reason = "death" }
                            if NinjaLineages.isServer() then
                                sendServerCommand("NinjaLineages", "abilityEvent", endEvent)
                            elseif NinjaLineages.isClient() then
                                sendClientCommand(player, "NinjaLineages", "rasenganEndedBroadcast", endEvent)
                            else
                                if NinjaLineages.VFX and NinjaLineages.VFX.removeRasengan then
                                    NinjaLineages.VFX.removeRasengan(runtime.id)
                                end
                            end
                            table.insert(toRemove, id)
                            break
                        end
                    end
                end
            end
        end
    end

    for _, id in ipairs(toRemove) do
        activeRuntimes[id] = nil
    end
end

Events.OnTick.Add(Rasengan.updateAll)
