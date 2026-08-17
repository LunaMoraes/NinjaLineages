require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_AbilityExecution"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.SageMode = NinjaLineages.SageMode or {}

local SageMode = NinjaLineages.SageMode
local SageBalance = NinjaLineages.Balance.SageMode
local Balance = NinjaLineages.Balance
local Authority = NinjaLineages.AbilityAuthority

function SageMode.isActive(player)
    if not player then return false end
    local data = NinjaLineages.getNLData(player)
    return data and data.sageModeActive == true
end

function SageMode.toggle(player)
    if not player then return false end
    local data = NinjaLineages.getNLData(player)
    if not data then return false end

    if data.sageModeActive then
        data.sageModeActive = false
        NinjaLineages.transmitPlayerData(player)
        player:Say(getText("UI_NL_Ability_SageMode_Deactivated"))
        return true
    end

    local natureChakra = NinjaLineages.Chakra.getNatureChakra(player)
    if natureChakra <= 0 then
        player:Say(getText("UI_NL_Error_NoNatureChakra"))
        return false, "no_nature_chakra"
    end

    data.sageModeActive = true
    NinjaLineages.transmitPlayerData(player)
    player:Say(getText("UI_NL_Ability_SageMode_Activated"))

    local chosen = NinjaLineages.Progression.getChosenContract(player)
    local event = {
        kind = "sage_mode_aura",
        casterOnlineId = player:getOnlineID(),
        contract = chosen,
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "sageModeAuraBroadcast", event)
    end

    return true
end

function SageMode.deactivate(player)
    if not player then return end
    local data = NinjaLineages.getNLData(player)
    if data and data.sageModeActive then
        data.sageModeActive = false
        NinjaLineages.transmitPlayerData(player)
        player:Say(getText("UI_NL_SageMode_Depleted"))
    end
end

-- ============================================================================
-- Stat & Multiplier Queries (Grounded in Balance.lua and Specializations)
-- ============================================================================

function SageMode.getMeleeDamageMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "toad" then return SageBalance.TOAD_MELEE_DAMAGE_MULTIPLIER end
    return SageBalance.BASE_MELEE_DAMAGE_MULTIPLIER
end

function SageMode.getMeleeAttackSpeedMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "toad" then return SageBalance.TOAD_ATTACK_SPEED_MULTIPLIER end
    return SageBalance.BASE_ATTACK_SPEED_MULTIPLIER
end

function SageMode.getMovementSpeedMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    return SageBalance.MOVEMENT_SPEED_MULTIPLIER
end

function SageMode.getFirearmAccuracyBonus(player)
    if not SageMode.isActive(player) then return 0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snake" then return SageBalance.SNAKE_ACCURACY_BONUS end
    return SageBalance.BASE_ACCURACY_BONUS
end

function SageMode.getJutsuDamageMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snail" then return SageBalance.SNAIL_JUTSU_DAMAGE_MULTIPLIER end
    return SageBalance.BASE_JUTSU_DAMAGE_MULTIPLIER
end

function SageMode.getJutsuHealingMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snail" then return SageBalance.SNAIL_JUTSU_HEALING_MULTIPLIER end
    return SageBalance.BASE_JUTSU_HEALING_MULTIPLIER
end

-- ============================================================================
-- Action-based Drain Hooks (Sprinting, Hits, Jutsu casts; zero passive drain)
-- ============================================================================

function SageMode.onHit(player)
    if not SageMode.isActive(player) then return end
    local cost = Balance.getCost("BASIC")
    if not NinjaLineages.Chakra.spendNatureChakra(player, cost)
            or NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
        SageMode.deactivate(player)
    end
end

function SageMode.onCastJutsu(player)
    if not SageMode.isActive(player) then return end
    local cost = Balance.getCostStep("STANDARD")
    if not NinjaLineages.Chakra.spendNatureChakra(player, cost)
            or NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
        SageMode.deactivate(player)
    end
end

local sageSprintState = {}

function SageMode.update(player)
    if not player or player:isDead() then return end
    if not SageMode.isActive(player) then
        sageSprintState[player] = nil
        return
    end

    if player:isSprinting() then
        local now = NinjaLineages.Utils.Time.gameMinutes()
        local state = sageSprintState[player]
        if not state then
            state = { lastDrain = now }
            sageSprintState[player] = state
        end

        -- 1. Forward Superhuman Sprint Boost (Same collision stepping as Dash)
        local forward = player:getForwardDirection()
        if forward then
            local fx, fy = forward:getX(), forward:getY()
            if (fx * fx + fy * fy) > NinjaLineages.Constants.Geometry.DIRECTION_EPSILON then
                local stepDistance = NinjaLineages.Balance.CommonJutsu.Dash.STEP_DISTANCE
                local nextX = player:getX() + (fx * stepDistance)
                local nextY = player:getY() + (fy * stepDistance)
                local cell = getCell()
                local curSq = cell and cell:getGridSquare(player:getX(), player:getY(), player:getZ())
                local nextSq = cell and cell:getGridSquare(nextX, nextY, player:getZ())
                if curSq and nextSq and not nextSq:isBlockedTo(curSq) then
                    player:setX(nextX)
                    player:setY(nextY)
                end
            end
        end

        -- 2. Nature Chakra Drain (In-Game Clock: gameMinutes)
        local elapsed = math.max(0, now - state.lastDrain)
        state.lastDrain = now
        if elapsed > 0 then
            local drainRate = NinjaLineages.Balance.getSustainedDrain("HIGH")
            if not NinjaLineages.Chakra.spendNatureChakra(player, drainRate * elapsed)
                    or NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
                sageSprintState[player] = nil
                SageMode.deactivate(player)
            end
        end
    else
        sageSprintState[player] = nil
    end
end

-- Register Executor for Sage Mode
NinjaLineages = NinjaLineages or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.specializedExecutors = NinjaLineages.AbilityExecution.specializedExecutors or {}

NinjaLineages.AbilityExecution.specializedExecutors["sage_mode"] = function(player, definition, args)
    return SageMode.toggle(player)
end

if NinjaLineages.AbilityExecution.registerSpecializedExecutor then
    NinjaLineages.AbilityExecution.registerSpecializedExecutor("sage_mode", function(player, definition, args)
        return SageMode.toggle(player)
    end)
end

Authority.register("sage_mode", function(player, args)
    return SageMode.toggle(player)
end)
