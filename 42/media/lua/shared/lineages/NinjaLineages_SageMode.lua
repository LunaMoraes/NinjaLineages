require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.SageMode = NinjaLineages.SageMode or {}

local SageMode = NinjaLineages.SageMode
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
    if chosen == "toad" then return 1.40 end -- Toad specialization: +40% melee damage
    return 1.20 -- Base: +20% melee damage
end

function SageMode.getMeleeAttackSpeedMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "toad" then return 1.35 end -- Toad specialization: +35% attack speed
    return 1.20 -- Base: +20% attack speed
end

function SageMode.getMovementSpeedMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    return 1.15 -- Base: +15% movement speed for all sages
end

function SageMode.getFirearmAccuracyBonus(player)
    if not SageMode.isActive(player) then return 0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snake" then return 35 end -- Snake specialization: +35% accuracy
    return 15 -- Base: +15% accuracy
end

function SageMode.getJutsuDamageMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snail" then return 1.40 end -- Snail specialization: +40% jutsu damage
    return 1.20 -- Base: +20% jutsu damage
end

function SageMode.getJutsuHealingMultiplier(player)
    if not SageMode.isActive(player) then return 1.0 end
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "snail" then return 1.40 end -- Snail specialization: +40% jutsu healing
    return 1.20 -- Base: +20% jutsu healing
end

-- ============================================================================
-- Action-based Drain Hooks (Sprinting, Hits, Jutsu casts; zero passive drain)
-- ============================================================================

function SageMode.onHit(player)
    if not SageMode.isActive(player) then return end
    local cost = Balance.getCost("TRIVIAL")
    NinjaLineages.Chakra.spendNatureChakra(player, cost)
    if NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
        SageMode.deactivate(player)
    end
end

function SageMode.onCastJutsu(player)
    if not SageMode.isActive(player) then return end
    local cost = Balance.getCostStep("STANDARD")
    NinjaLineages.Chakra.spendNatureChakra(player, cost)
    if NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
        SageMode.deactivate(player)
    end
end

local lastSprintUpdateAt = {}

local function updateSageModeSprintDrain(player)
    if not player or player:isDead() then return end
    if not SageMode.isActive(player) then return end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local last = lastSprintUpdateAt[player] or now
    lastSprintUpdateAt[player] = now
    local elapsed = math.max(0, now - last)

    if elapsed > 0 and player:isSprinting() then
        local drain = Balance.getSustainedDrain("LOW") * elapsed
        NinjaLineages.Chakra.spendNatureChakra(player, drain)
        if NinjaLineages.Chakra.getNatureChakra(player) <= 0 then
            SageMode.deactivate(player)
        end
    end
end

-- Register Sprint drain loop
NinjaLineages.registerPlayerUpdate("sageMode.sprintDrain", updateSageModeSprintDrain)

-- Register Executor for Sage Mode
NinjaLineages.AbilityExecution.registerSpecializedExecutor("sage_mode", function(player, definition, args)
    return SageMode.toggle(player)
end)

Authority.register("sage_mode", function(player, args)
    return SageMode.toggle(player)
end)
