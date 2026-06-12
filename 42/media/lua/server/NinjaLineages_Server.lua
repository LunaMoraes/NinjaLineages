require "NinjaLineages_Traits"
require "NinjaLineages_Items"
require "NinjaLineages_RinneganMechanics"
require "NinjaLineages_ProgressionServer"

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if NinjaLineages.getSharinganStage(attacker) < 3 then return end

    local data = NinjaLineages.getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    NinjaLineages.transmitPlayerData(attacker)
end

Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)

local function rejectShinraTensei(player, reason, remaining)
    sendServerCommand(player, "NinjaLineages", "shinraTenseiRejected", {
        reason = reason,
        remaining = remaining,
    })
end

local function castShinraTensei(player)
    local executed, reason, remaining = NinjaLineages.RinneganMechanics.execute(player)
    if not executed then
        rejectShinraTensei(player, reason, remaining)
        return
    end

    sendServerCommand("NinjaLineages", "shinraTenseiPulse", {
        x = player:getX(),
        y = player:getY(),
        z = math.floor(player:getZ()),
        casterOnlineId = player:getOnlineID(),
    })
end

local function handleDamageZombie(player, args)
    local onlineId = args and args.zombieOnlineId
    local damage = tonumber(args and args.damage) or 0
    if not onlineId or damage <= 0 then return end
    local cell = getCell()
    local zombies = cell and cell:getZombieList()
    if not zombies then return end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombie:getOnlineID() == onlineId then
            NinjaLineages.Utils.Combat.applyZombieDamage(player, zombie, damage)
            break
        end
    end
end

local function handleAddWorldSound(player, args)
    local x = tonumber(args and args.x) or 0
    local y = tonumber(args and args.y) or 0
    local z = tonumber(args and args.z) or 0
    local radius = tonumber(args and args.radius) or 0
    local volume = tonumber(args and args.volume) or 0
    if radius <= 0 or volume <= 0 then return end
    addSound(player, x, y, z, radius, volume)
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "shinraTensei" then
        castShinraTensei(player)
    elseif command == "damageZombie" then
        handleDamageZombie(player, args)
    elseif command == "addWorldSound" then
        handleAddWorldSound(player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(NinjaLineages.RinneganMechanics.update)
