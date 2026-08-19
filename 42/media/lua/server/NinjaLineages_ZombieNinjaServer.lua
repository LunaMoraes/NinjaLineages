require "npc/NinjaLineages_ZombieNinja"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "combat/NinjaLineages_Collision"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ZombieNinjaServer = NinjaLineages.ZombieNinjaServer or {}
local Server = NinjaLineages.ZombieNinjaServer
local ZombieNinja = NinjaLineages.ZombieNinja
local Balance = NinjaLineages.Balance
local Collision = NinjaLineages.Collision

local function handleRollZombieNinja(player, args)
    local zombieId = args and args.zombieId
    if not zombieId then return end
    local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
    if zombie then
        local isNinja = ZombieNinja.rollMutation(zombie)
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.SYNC_STATE, {
            zombieId = zombieId,
            isZombieNinja = isNinja,
        })
    end
end

local function handleJutsuRequest(player, args)
    local zombieId = args and args.zombieId
    if not zombieId or not player then return end

    local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
    local now = NinjaLineages.Utils.Time.gameMinutes()

    if not zombie or not ZombieNinja.canAct(zombie) or not ZombieNinja.isValidTarget(zombie, player) then
        sendServerCommand(player, "NinjaLineages", ZombieNinja.Commands.JUTSU_ACK, {
            zombieId = zombieId,
            nextZombieJutsuAt = zombie and zombie:getModData().nextZombieJutsuAt or now,
        })
        return
    end

    local eligible = ZombieNinja.getEligibleJutsus(zombie, player, now)
    if #eligible == 0 then
        sendServerCommand(player, "NinjaLineages", ZombieNinja.Commands.JUTSU_ACK, {
            zombieId = zombieId,
            nextZombieJutsuAt = zombie:getModData().nextZombieJutsuAt or now,
        })
        return
    end

    local selected = ZombieNinja.selectRandomJutsu(eligible)
    local cooldown = Balance.getCooldown("DASH")
    local nextAt = now + cooldown

    if selected == ZombieNinja.Jutsu.DASH then
        zombie:getModData().nextZombieJutsuAt = nextAt
        local geo = ZombieNinja.calculateDashGeometry(zombie, player)
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.EXECUTE_JUTSU, {
            zombieId = zombieId,
            jutsu = ZombieNinja.Jutsu.DASH,
            directionX = geo.directionX,
            directionY = geo.directionY,
            travelDistance = geo.travelDistance,
            durationGameMinutes = geo.duration,
            nextZombieJutsuAt = nextAt,
        })
    elseif selected == ZombieNinja.Jutsu.KILLING_INTENT then
        zombie:getModData().nextZombieJutsuAt = nextAt
        local panicAmount = ZombieNinja.calculateKillingIntentMagnitude()
        local stats = player:getStats()
        if stats and stats.add and CharacterStat and CharacterStat.PANIC then
            stats:add(CharacterStat.PANIC, panicAmount)
        elseif stats and stats.set and stats.get and CharacterStat and CharacterStat.PANIC then
            stats:set(CharacterStat.PANIC, stats:get(CharacterStat.PANIC) + panicAmount)
        end

        sendServerCommand("NinjaLineages", "abilityEvent", {
            kind = "generic_ability_pulse",
            abilityId = "killing_intent",
            zombieOnlineId = zombieId,
            x = zombie:getX(),
            y = zombie:getY(),
            z = math.floor(zombie:getZ()),
            startedAtGameMinutes = now,
        })

        sendServerCommand("NinjaLineages", ZombieNinja.Commands.EXECUTE_JUTSU, {
            zombieId = zombieId,
            jutsu = ZombieNinja.Jutsu.KILLING_INTENT,
            nextZombieJutsuAt = nextAt,
        })
    elseif selected == ZombieNinja.Jutsu.SUBSTITUTION then
        zombie:getModData().zombieNinjaSubstitutionArmed = true
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.EXECUTE_JUTSU, {
            zombieId = zombieId,
            jutsu = ZombieNinja.Jutsu.SUBSTITUTION,
        })
    elseif selected == ZombieNinja.Jutsu.SNARE then
        zombie:getModData().nextZombieJutsuAt = nextAt
        local geo = ZombieNinja.calculateSnareGeometry(zombie, player)
        local runtimeId = "snare_" .. tostring(zombieId) .. "_" .. tostring(now)
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.EXECUTE_JUTSU, {
            zombieId = zombieId,
            jutsu = ZombieNinja.Jutsu.SNARE,
            targetOnlineId = player:getOnlineID(),
            pullDistance = geo.pullDistance,
            durationGameMinutes = geo.duration,
            runtimeId = runtimeId,
            nextZombieJutsuAt = nextAt,
        })
    end
end

local function handleSubstitutionTrigger(player, args)
    local zombieId = args and args.zombieId
    if not zombieId or not player then return end

    local zombie = NinjaLineages.Utils.Zombies.getByOnlineID(zombieId)
    if not zombie or not zombie:getModData().zombieNinjaSubstitutionArmed then return end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    zombie:getModData().zombieNinjaSubstitutionArmed = false
    local nextAt = now + Balance.getCooldown("DASH")
    zombie:getModData().nextZombieJutsuAt = nextAt

    local oldX, oldY, oldZ = zombie:getX(), zombie:getY(), math.floor(zombie:getZ())
    local dest = nil

    if args.destination and args.destination.x and args.destination.y then
        local cell = getCell()
        local sq = cell and cell:getGridSquare(args.destination.x, args.destination.y, args.destination.z or oldZ)
        if sq and not sq:isSolid() and not sq:isSolidTrans() and sq:isFree(false) then
            local hit = Collision.traceSegment(
                oldX, oldY, oldZ,
                args.destination.x, args.destination.y, args.destination.z or oldZ,
                Collision.Masks.jutsu_projectile
            )
            if hit == nil then
                dest = args.destination
            end
        end
    end

    if not dest then
        dest = ZombieNinja.findSubstitutionDestination(zombie, player)
    end

    if dest then
        NinjaLineages.Utils.Movement.placeEntity(zombie, dest.x, dest.y, dest.z)
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.SUBSTITUTION_TRIGGER, {
            zombieId = zombieId,
            destX = dest.x,
            destY = dest.y,
            destZ = dest.z,
            oldX = oldX,
            oldY = oldY,
            oldZ = oldZ,
            nextZombieJutsuAt = nextAt,
        })
    else
        -- Reconciliation when no destination is free: leave in place, perform poof & speech
        sendServerCommand("NinjaLineages", ZombieNinja.Commands.SUBSTITUTION_TRIGGER, {
            zombieId = zombieId,
            oldX = oldX,
            oldY = oldY,
            oldZ = oldZ,
            nextZombieJutsuAt = nextAt,
        })
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end

    if command == ZombieNinja.Commands.ROLL_MUTATION then
        handleRollZombieNinja(player, args)
    elseif command == ZombieNinja.Commands.REQUEST_JUTSU then
        handleJutsuRequest(player, args)
    elseif command == ZombieNinja.Commands.SUBSTITUTION_TRIGGER then
        handleSubstitutionTrigger(player, args)
    end
end

if Events and Events.OnClientCommand then
    NinjaLineages.addEventOnce("server.zombieNinja.onClientCommand", Events.OnClientCommand, onClientCommand)
end
