require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Damage"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Summoning = NinjaLineages.Summoning or {}

local Summoning = NinjaLineages.Summoning
local Balance = NinjaLineages.Balance
local Authority = NinjaLineages.AbilityAuthority

Summoning.activeSummons = Summoning.activeSummons or {}

local function getSummonKey(player)
    if not player then return "unknown" end
    if player.getOnlineID then
        local id = player:getOnlineID()
        if id and id >= 0 then return "online:" .. tostring(id) end
    end
    return tostring(player)
end

function Summoning.hasActiveSummon(player)
    local key = getSummonKey(player)
    local summon = Summoning.activeSummons[key]
    return summon ~= nil
end

function Summoning.dismissSummon(player)
    local key = getSummonKey(player)
    local summon = Summoning.activeSummons[key]
    if summon then
        Summoning.activeSummons[key] = nil
        player:Say(getText("UI_NL_Summon_Despawn"))
        local event = {
            kind = "summon_poof",
            x = summon.x,
            y = summon.y,
            z = summon.z,
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", event)
        elseif NinjaLineages.isClient() then
            sendClientCommand(player, "NinjaLineages", "summonPoofBroadcast", event)
        end
    end
end

function Summoning.cast(player, args)
    if not player or player:isDead() then return false end
    if not NinjaLineages.Progression.isCompleted(player, "summoning") then
        return false, "node_not_completed"
    end

    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if not chosen then
        player:Say(getText("UI_NL_Error_NoContractForSummon"))
        return false, "no_contract"
    end

    local cost = Balance.getCost("MAJOR")
    if not NinjaLineages.Chakra.spendChakra(player, cost) then
        return false, "chakra"
    end

    -- Dismiss previous summon if active
    if Summoning.hasActiveSummon(player) then
        Summoning.dismissSummon(player)
    end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local duration = Balance.getDuration("LONG")
    local key = getSummonKey(player)

    Summoning.activeSummons[key] = {
        owner = player,
        contract = chosen,
        createdAt = now,
        expiresAt = now + duration,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
        lastActionTick = NinjaLineages.Utils.Time.realMilliseconds(),
    }

    local summonNameKey = "UI_NL_Summon_" .. chosen:gsub("^%l", string.upper)
    player:Say(getText("UI_NL_Summon_Cast") .. " — " .. getText(summonNameKey))

    -- Trigger poof effect
    local event = {
        kind = "summon_spawn",
        casterOnlineId = player:getOnlineID(),
        contract = chosen,
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "summonSpawnBroadcast", event)
    end

    return true
end

-- ============================================================================
-- Summon Companion AI Loop
-- ============================================================================

local function updateToadCompanion(summon, player, nowMs)
    if nowMs - summon.lastActionTick < 2500 then return end
    summon.lastActionTick = nowMs

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local targets = NinjaLineages.Targeting.getZombiesInRadius(px, py, pz, 7)
    if #targets > 0 then
        -- Toad attacks closest zombies with heavy ground slam
        local closest = targets[1]
        local slamX, slamY = closest:getX(), closest:getY()
        summon.x = slamX
        summon.y = slamY
        summon.z = pz

        local splash = NinjaLineages.Targeting.getZombiesInRadius(slamX, slamY, pz, 3.5)
        for _, zed in ipairs(splash) do
            NinjaLineages.Utils.Combat.staggerZombie(zed, { knockdown = true, position = "FRONT" })
            local dmg = Balance.rollDamage("HEAVY")
            NinjaLineages.Damage.applyZombieDamage(player, zed, dmg)
        end

        local event = {
            kind = "toad_slam",
            x = slamX,
            y = slamY,
            z = pz,
            radius = 3.5,
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", event)
        end
    else
        summon.x = px
        summon.y = py
        summon.z = pz
    end
end

local function updateSnakeCompanion(summon, player, nowMs)
    if nowMs - summon.lastActionTick < 1500 then return end
    summon.lastActionTick = nowMs

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local targets = NinjaLineages.Targeting.getZombiesInRadius(px, py, pz, 9)
    if #targets > 0 then
        local target = targets[1]
        local tx, ty = target:getX(), target:getY()
        summon.x = tx
        summon.y = ty
        summon.z = pz

        NinjaLineages.Utils.Combat.staggerZombie(target, { knockdown = false, position = "BEHIND" })
        local dmg = Balance.rollDamage("STANDARD")
        NinjaLineages.Damage.applyZombieDamage(player, target, dmg)

        local event = {
            kind = "snake_strike",
            x = tx,
            y = ty,
            z = pz,
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", event)
        end
    else
        summon.x = px
        summon.y = py
        summon.z = pz
    end
end

local function updateSnailCompanion(summon, player, nowMs)
    if nowMs - summon.lastActionTick < 4000 then return end
    summon.lastActionTick = nowMs

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    summon.x = px
    summon.y = py
    summon.z = pz

    -- Radiant healing wave in 6-tile radius
    local healAmount = Balance.getHealing("STANDARD")
    local bodyDamage = player:getBodyDamage()
    if bodyDamage and bodyDamage:getOverallBodyHealth() < 100 then
        local currentHealth = bodyDamage:getOverallBodyHealth()
        bodyDamage:setOverallBodyHealth(math.min(100, currentHealth + healAmount))
        
        -- Progress Snail trial if active
        local data = NinjaLineages.getNLData(player)
        if data and data.sageTrial then
            data.sageTrial.healthHealed = (data.sageTrial.healthHealed or 0) + healAmount
            NinjaLineages.transmitPlayerData(player)
        end
    end

    -- Heal nearby allies/players in multiplayer
    if isClient() or isServer() then
        local players = NinjaLineages.Targeting.getPlayersInRadius(px, py, pz, 6)
        for _, otherPlayer in ipairs(players) do
            if otherPlayer ~= player and not otherPlayer:isDead() then
                local otherBd = otherPlayer:getBodyDamage()
                if otherBd and otherBd:getOverallBodyHealth() < 100 then
                    local current = otherBd:getOverallBodyHealth()
                    otherBd:setOverallBodyHealth(math.min(100, current + healAmount))
                end
            end
        end
    end

    local event = {
        kind = "katsuyu_heal_wave",
        x = px,
        y = py,
        z = pz,
        radius = 6.0,
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    end
end

function Summoning.updateWorld()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local nowMs = NinjaLineages.Utils.Time.realMilliseconds()

    for key, summon in pairs(Summoning.activeSummons) do
        local player = summon.owner
        if not player or player:isDead() or now >= summon.expiresAt then
            Summoning.activeSummons[key] = nil
            if player and not player:isDead() then
                player:Say(getText("UI_NL_Summon_Expired"))
            end
            local event = {
                kind = "summon_poof",
                x = summon.x,
                y = summon.y,
                z = summon.z,
            }
            if NinjaLineages.isServer() then
                sendServerCommand("NinjaLineages", "abilityEvent", event)
            end
        else
            if summon.contract == "toad" then
                updateToadCompanion(summon, player, nowMs)
            elseif summon.contract == "snake" then
                updateSnakeCompanion(summon, player, nowMs)
            elseif summon.contract == "snail" then
                updateSnailCompanion(summon, player, nowMs)
            end
        end
    end
end

-- Register Summoning update tick
NinjaLineages.addEventOnce("shared.summoning.update", Events.OnTick, function()
    Summoning.updateWorld()
end)

-- Register Executor for Summoning Jutsu
NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.specializedExecutors = NinjaLineages.AbilityExecution.specializedExecutors or {}

NinjaLineages.AbilityExecution.specializedExecutors["summoning_jutsu"] = function(player, definition, args)
    return Summoning.cast(player, args)
end

if NinjaLineages.AbilityExecution.registerSpecializedExecutor then
    NinjaLineages.AbilityExecution.registerSpecializedExecutor("summoning_jutsu", function(player, definition, args)
        return Summoning.cast(player, args)
    end)
end

Authority.register("summoning_jutsu", function(player, args)
    return Summoning.cast(player, args)
end)
