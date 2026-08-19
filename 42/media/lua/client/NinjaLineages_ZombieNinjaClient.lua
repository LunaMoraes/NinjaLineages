require "npc/NinjaLineages_ZombieNinja"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_AbilityAuthority"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ZombieNinjaClient = NinjaLineages.ZombieNinjaClient or {}
local Client = NinjaLineages.ZombieNinjaClient
local ZombieNinja = NinjaLineages.ZombieNinja
local Balance = NinjaLineages.Balance

local activeDashes = {}
local activeSnares = {}
local pendingJutsuRequests = {}
local pendingSubstitutionTriggers = {}

local function getZombieIdKey(zombie)
    if not zombie then return nil end
    local onlineId = zombie.getOnlineID and zombie:getOnlineID() or nil
    if onlineId and onlineId >= 0 then
        return onlineId
    end
    return tostring(zombie)
end

function Client.startDash(zombie, dirX, dirY, travelDistance, duration)
    if not zombie or not dirX or not dirY or not travelDistance or travelDistance <= 0 then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local idKey = getZombieIdKey(zombie)

    pcall(function()
        zombie:addLineChatElement(getText("UI_NL_Zombie_Dash_Speech"))
    end)

    activeDashes[idKey] = {
        zombie = zombie,
        directionX = dirX,
        directionY = dirY,
        movement = {
            startedAt = now,
            endsAt = now + (duration or Balance.getDuration("BURST")),
            directionX = dirX,
            directionY = dirY,
            distance = travelDistance,
            travelled = 0,
        },
    }
end

function Client.startSnare(player, zombie, pullDistance, duration, runtimeId)
    if not player or not zombie or not pullDistance or pullDistance <= 0 then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local rId = runtimeId or ("snare_" .. tostring(now))

    local dx = zombie:getX() - player:getX()
    local dy = zombie:getY() - player:getY()
    local len = math.sqrt((dx * dx) + (dy * dy))
    local dirX = len > 0.0001 and (dx / len) or 0
    local dirY = len > 0.0001 and (dy / len) or 1

    pcall(function()
        zombie:addLineChatElement(getText("UI_NL_Zombie_Snare_Speech"))
    end)

    activeSnares[rId] = {
        runtimeId = rId,
        player = player,
        zombie = zombie,
        movement = {
            startedAt = now,
            endsAt = now + (duration or Balance.getDuration("BURST")),
            directionX = dirX,
            directionY = dirY,
            distance = pullDistance,
            travelled = 0,
        },
    }

    if NinjaLineages.VFX and NinjaLineages.VFX.addSnareTether then
        NinjaLineages.VFX.addSnareTether({
            runtimeId = rId,
            zombie = zombie,
            zombieId = zombie.getOnlineID and zombie:getOnlineID() or nil,
            targetPlayer = player,
            targetOnlineId = player.getOnlineID and player:getOnlineID() or nil,
            startedAtGameMinutes = now,
            durationGameMinutes = duration or Balance.getDuration("BURST"),
        })
    end
end

local function updateActiveDashes(now)
    local touchDist = Balance.getRadius("TOUCH")
    for idKey, dash in pairs(activeDashes) do
        local zombie = dash.zombie
        if not zombie or not ZombieNinja.canAct(zombie) then
            activeDashes[idKey] = nil
        else
            local target = zombie:getTarget()
            if not target or not ZombieNinja.isValidTarget(zombie, target) then
                activeDashes[idKey] = nil
            else
                local dx = target:getX() - zombie:getX()
                local dy = target:getY() - zombie:getY()
                local projectedGap = (dx * dash.directionX) + (dy * dash.directionY)

                if projectedGap <= touchDist then
                    activeDashes[idKey] = nil
                else
                    local maxStepAdvance = math.max(0, projectedGap - touchDist)
                    dash.movement.distance = math.min(
                        dash.movement.distance,
                        dash.movement.travelled + maxStepAdvance
                    )

                    local active, progress = NinjaLineages.Utils.Movement.updateDash(
                        zombie,
                        dash.movement,
                        now,
                        Balance.CommonJutsu.Dash.STEP_DISTANCE,
                        function() activeDashes[idKey] = nil end
                    )
                    if not active then
                        activeDashes[idKey] = nil
                    end
                end
            end
        end
    end
end

local function updateActiveSnares(now)
    local touchDist = Balance.getRadius("TOUCH")
    for rId, snare in pairs(activeSnares) do
        local player = snare.player
        local zombie = snare.zombie
        if not player or player:isDead() or player:isGhostMode()
                or not zombie or not ZombieNinja.canAct(zombie) then
            if NinjaLineages.VFX and NinjaLineages.VFX.removeSnareTether then
                NinjaLineages.VFX.removeSnareTether(rId)
            end
            activeSnares[rId] = nil
        else
            local dist = player:DistTo(zombie)
            if dist <= touchDist then
                if NinjaLineages.VFX and NinjaLineages.VFX.removeSnareTether then
                    NinjaLineages.VFX.removeSnareTether(rId)
                end
                activeSnares[rId] = nil
            else
                local dx = zombie:getX() - player:getX()
                local dy = zombie:getY() - player:getY()
                local len = math.sqrt((dx * dx) + (dy * dy))
                if len > 0.0001 then
                    snare.movement.directionX = dx / len
                    snare.movement.directionY = dy / len
                end

                local active, progress = NinjaLineages.Utils.Movement.updateDash(
                    player,
                    snare.movement,
                    now,
                    Balance.CommonJutsu.Dash.STEP_DISTANCE,
                    function()
                        if NinjaLineages.VFX and NinjaLineages.VFX.removeSnareTether then
                            NinjaLineages.VFX.removeSnareTether(rId)
                        end
                        activeSnares[rId] = nil
                    end
                )
                if not active then
                    if NinjaLineages.VFX and NinjaLineages.VFX.removeSnareTether then
                        NinjaLineages.VFX.removeSnareTether(rId)
                    end
                    activeSnares[rId] = nil
                end
            end
        end
    end
end

local function executeSinglePlayerJutsu(zombie, player, jutsu, now)
    local cooldown = Balance.getCooldown("DASH")
    if jutsu == ZombieNinja.Jutsu.DASH then
        zombie:getModData().nextZombieJutsuAt = now + cooldown
        local geo = ZombieNinja.calculateDashGeometry(zombie, player)
        Client.startDash(zombie, geo.directionX, geo.directionY, geo.travelDistance, geo.duration)
    elseif jutsu == ZombieNinja.Jutsu.KILLING_INTENT then
        zombie:getModData().nextZombieJutsuAt = now + cooldown
        local panicAmount = ZombieNinja.calculateKillingIntentMagnitude()
        local stats = player:getStats()
        if stats and stats.add and CharacterStat and CharacterStat.PANIC then
            stats:add(CharacterStat.PANIC, panicAmount)
        elseif stats and stats.set and stats.get and CharacterStat and CharacterStat.PANIC then
            stats:set(CharacterStat.PANIC, stats:get(CharacterStat.PANIC) + panicAmount)
        end
        pcall(function()
            zombie:addLineChatElement(getText("UI_NL_Zombie_KillingIntent_Speech"))
        end)
        if NinjaLineages.VFX and NinjaLineages.VFX.addGenericPulse then
            NinjaLineages.VFX.addGenericPulse({
                abilityId = "killing_intent",
                zombie = zombie,
                x = zombie:getX(),
                y = zombie:getY(),
                z = math.floor(zombie:getZ()),
                startedAtGameMinutes = now,
            })
        end
    elseif jutsu == ZombieNinja.Jutsu.SUBSTITUTION then
        zombie:getModData().zombieNinjaSubstitutionArmed = true
    elseif jutsu == ZombieNinja.Jutsu.SNARE then
        zombie:getModData().nextZombieJutsuAt = now + cooldown
        local geo = ZombieNinja.calculateSnareGeometry(zombie, player)
        Client.startSnare(player, zombie, geo.pullDistance, geo.duration, nil)
    end
end

local function onZombieUpdate(zombie)
    if not zombie or zombie:isDead() then return end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()

    -- 1. Mutation Roll Check
    local modData = zombie:getModData()
    if not modData.zombieNinjaRolled then
        local target = zombie:getTarget()
        if target and instanceof(target, "IsoPlayer") and target:isLocalPlayer() then
            if NinjaLineages.isClient() then
                local zombieId = zombie.getOnlineID and zombie:getOnlineID() or nil
                if zombieId and zombieId >= 0 then
                    sendClientCommand(target, "NinjaLineages", ZombieNinja.Commands.ROLL_MUTATION, { zombieId = zombieId })
                end
            else
                ZombieNinja.rollMutation(zombie)
            end
        end
    end

    -- 2. Living Combat Processing
    if ZombieNinja.isZombieNinja(zombie) then
        local target = zombie:getTarget()
        if target and instanceof(target, "IsoPlayer") and target:isLocalPlayer() then
            local zombieId = zombie.getOnlineID and zombie:getOnlineID() or nil
            local idKey = getZombieIdKey(zombie)

            if pendingJutsuRequests[idKey] and (nowMs - pendingJutsuRequests[idKey] > NinjaLineages.AbilityAuthority.REQUEST_TIMEOUT_MS) then
                pendingJutsuRequests[idKey] = nil
            end

            if NinjaLineages.isClient() then
                if zombieId and zombieId >= 0 and not pendingJutsuRequests[idKey] then
                    local eligible = ZombieNinja.getEligibleJutsus(zombie, target, now)
                    if #eligible > 0 then
                        pendingJutsuRequests[idKey] = nowMs
                        sendClientCommand(target, "NinjaLineages", ZombieNinja.Commands.REQUEST_JUTSU, {
                            zombieId = zombieId,
                        })
                    end
                end
            else
                local eligible = ZombieNinja.getEligibleJutsus(zombie, target, now)
                if #eligible > 0 then
                    local selected = ZombieNinja.selectRandomJutsu(eligible)
                    if selected then
                        executeSinglePlayerJutsu(zombie, target, selected, now)
                    end
                end
            end
        end
    end

    -- 3. Update active movements
    updateActiveDashes(now)
    updateActiveSnares(now)
end

local function executeSinglePlayerSubstitution(zombie, attacker, destination)
    local now = NinjaLineages.Utils.Time.gameMinutes()
    zombie:getModData().zombieNinjaSubstitutionArmed = false
    zombie:getModData().nextZombieJutsuAt = now + Balance.getCooldown("DASH")

    local oldX, oldY, oldZ = zombie:getX(), zombie:getY(), math.floor(zombie:getZ())

    if destination then
        NinjaLineages.Utils.Movement.placeEntity(zombie, destination.x, destination.y, destination.z)
    end

    if NinjaLineages.VFX and NinjaLineages.VFX.addSummonPoof then
        NinjaLineages.VFX.addSummonPoof({
            x = oldX,
            y = oldY,
            z = oldZ,
            startedAtGameMinutes = now,
        })
    end

    pcall(function()
        zombie:addLineChatElement(getText("UI_NL_Zombie_Substitution_Speech"))
    end)
end

local function onWeaponSwing(player, weapon)
    if not player or not player:isLocalPlayer() or player:isDead() then return end
    if not weapon or not instanceof(weapon, "HandWeapon") then return end

    local cell = getCell()
    if not cell then return end
    local zombieList = cell:getZombieList()
    if not zombieList or zombieList:size() == 0 then return end

    local forward = player:getForwardDirection()
    local fX = forward and forward:getX() or 0
    local fY = forward and forward:getY() or 1
    local fLen = math.sqrt(fX * fX + fY * fY)
    if fLen > 0.0001 then
        fX, fY = fX / fLen, fY / fLen
    else
        fX, fY = 0, 1
    end

    local maxRange = (weapon.getMaxRange and weapon:getMaxRange(player)) or 2.0
    local minRange = (weapon.getMinRange and weapon:getMinRange()) or 0
    local effectiveMaxRange = maxRange + 0.35

    local px, py, pz = player:getX(), player:getY(), math.floor(player:getZ())

    for i = 0, zombieList:size() - 1 do
        local zombie = zombieList:get(i)
        if zombie and not zombie:isDead() and ZombieNinja.isZombieNinja(zombie) and ZombieNinja.isSubstitutionArmed(zombie) then
            if math.floor(zombie:getZ()) == pz then
                local dx = zombie:getX() - px
                local dy = zombie:getY() - py
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist >= minRange and dist <= effectiveMaxRange then
                    local dirX = dx / (dist > 0.0001 and dist or 1)
                    local dirY = dy / (dist > 0.0001 and dist or 1)
                    local dot = (dirX * fX) + (dirY * fY)

                    -- Within ~60 degree half-cone
                    if dot >= 0.50 then
                        local hit = NinjaLineages.Collision.traceSegment(
                            px, py, pz,
                            zombie:getX(), zombie:getY(), pz,
                            NinjaLineages.Collision.Masks.jutsu_projectile
                        )
                        if hit == nil then
                            local destination = ZombieNinja.findSubstitutionDestination(zombie, player)
                            if destination then
                                if NinjaLineages.isClient() then
                                    local zombieId = zombie.getOnlineID and zombie:getOnlineID() or nil
                                    local idKey = getZombieIdKey(zombie)
                                    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()
                                    if zombieId and zombieId >= 0 and (not pendingSubstitutionTriggers[idKey] or (nowMs - pendingSubstitutionTriggers[idKey] > 1000)) then
                                        pendingSubstitutionTriggers[idKey] = nowMs
                                        sendClientCommand(player, "NinjaLineages", ZombieNinja.Commands.SUBSTITUTION_TRIGGER, {
                                            zombieId = zombieId,
                                            destination = destination,
                                        })
                                    end
                                else
                                    executeSinglePlayerSubstitution(zombie, player, destination)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= "NinjaLineages" or not args then return end

    if command == ZombieNinja.Commands.SYNC_STATE then
        local zombieId = args.zombieId
        if zombieId then
            local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
            if zombie then
                local modData = zombie:getModData()
                modData.zombieNinjaRolled = true
                modData.isZombieNinja = (args.isZombieNinja == true)
            end
        end
    elseif command == ZombieNinja.Commands.JUTSU_ACK then
        local zombieId = args.zombieId
        if zombieId then
            pendingJutsuRequests[zombieId] = nil
            local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
            if zombie and args.nextZombieJutsuAt then
                zombie:getModData().nextZombieJutsuAt = args.nextZombieJutsuAt
            end
        end
    elseif command == ZombieNinja.Commands.EXECUTE_JUTSU then
        local zombieId = args.zombieId
        local jutsu = args.jutsu
        if zombieId then
            pendingJutsuRequests[zombieId] = nil
            local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
            if zombie then
                if args.nextZombieJutsuAt then
                    zombie:getModData().nextZombieJutsuAt = args.nextZombieJutsuAt
                end

                if jutsu == ZombieNinja.Jutsu.DASH then
                    Client.startDash(
                        zombie,
                        args.directionX,
                        args.directionY,
                        args.travelDistance,
                        args.durationGameMinutes
                    )
                elseif jutsu == ZombieNinja.Jutsu.KILLING_INTENT then
                    pcall(function()
                        zombie:addLineChatElement(getText("UI_NL_Zombie_KillingIntent_Speech"))
                    end)
                elseif jutsu == ZombieNinja.Jutsu.SUBSTITUTION then
                    zombie:getModData().zombieNinjaSubstitutionArmed = true
                elseif jutsu == ZombieNinja.Jutsu.SNARE then
                    local player = args.targetOnlineId and getPlayerByOnlineID and getPlayerByOnlineID(args.targetOnlineId)
                    if not player then
                        local localP = getPlayer()
                        if localP and localP.getOnlineID and localP:getOnlineID() == args.targetOnlineId then
                            player = localP
                        end
                    end
                    if player and player:isLocalPlayer() then
                        Client.startSnare(
                            player,
                            zombie,
                            args.pullDistance,
                            args.durationGameMinutes,
                            args.runtimeId
                        )
                    end
                end
            end
        end
    elseif command == ZombieNinja.Commands.SUBSTITUTION_TRIGGER then
        local zombieId = args.zombieId
        if zombieId then
            pendingSubstitutionTriggers[zombieId] = nil
            local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
            if zombie then
                zombie:getModData().zombieNinjaSubstitutionArmed = false
                if args.nextZombieJutsuAt then
                    zombie:getModData().nextZombieJutsuAt = args.nextZombieJutsuAt
                end

                if args.destX and args.destY and args.destZ then
                    NinjaLineages.Utils.Movement.placeEntity(zombie, args.destX, args.destY, args.destZ)
                end

                local now = NinjaLineages.Utils.Time.gameMinutes()
                if NinjaLineages.VFX and NinjaLineages.VFX.addSummonPoof then
                    NinjaLineages.VFX.addSummonPoof({
                        x = args.oldX or zombie:getX(),
                        y = args.oldY or zombie:getY(),
                        z = args.oldZ or math.floor(zombie:getZ()),
                        startedAtGameMinutes = now,
                    })
                end

                pcall(function()
                    zombie:addLineChatElement(getText("UI_NL_Zombie_Substitution_Speech"))
                end)
            end
        end
    end
end

NinjaLineages.registerZombieUpdate(onZombieUpdate)

if Events and Events.OnWeaponSwing then
    NinjaLineages.addEventOnce("client.zombieNinja.onWeaponSwing", Events.OnWeaponSwing, onWeaponSwing)
end

if Events and Events.OnServerCommand then
    NinjaLineages.addEventOnce("client.zombieNinja.onServerCommand", Events.OnServerCommand, onServerCommand)
end
