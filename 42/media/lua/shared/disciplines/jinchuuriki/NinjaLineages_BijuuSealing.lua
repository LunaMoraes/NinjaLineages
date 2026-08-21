require "NinjaLineages_Balance"
require "NinjaLineages_Progression"

NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuSealing = NinjaLineages.BijuuSealing or {}

local Sealing = NinjaLineages.BijuuSealing

local vesselDefinitions = {
    ["Base.NL_BasicSealingVessel"] = {
        power = NinjaLineages.Balance.Jinchuuriki.Sealing.BASIC_VESSEL_POWER,
    },
}

function Sealing.getVesselDefinition(item)
    if not item or not item.getFullType then return nil end
    return vesselDefinitions[item:getFullType()]
end

function Sealing.isVessel(item)
    return Sealing.getVesselDefinition(item) ~= nil
end

function Sealing.isEmptyVessel(item)
    if not Sealing.isVessel(item) then return false end
    local modData = item.getModData and item:getModData() or nil
    return not (modData and modData.bijuuSeal)
end

function Sealing.getVesselPower(item)
    local definition = Sealing.getVesselDefinition(item)
    return definition and definition.power or nil
end

function Sealing.getVesselItemId(item)
    return item and item.getID and item:getID() or nil
end

function Sealing.getTailResistance(tails, config)
    config = config or NinjaLineages.Balance.Jinchuuriki.Sealing
    local canonicalTails = math.max(1, math.min(9, tonumber(tails) or 1))
    local perTail = math.max(0, tonumber(config.TAIL_RESISTANCE_PER_ADDITIONAL_TAIL) or 0)
    return 1 + (canonicalTails - 1) * perTail
end

function Sealing.getProgressionMultiplier(player, config)
    config = config or NinjaLineages.Balance.Jinchuuriki.Sealing
    local multiplier = 1.0
    local progression = NinjaLineages.Progression
    if player and progression and progression.isCompleted then
        if progression.isCompleted(player, "containment_technique") then
            multiplier = multiplier * math.max(1,
                tonumber(config.CONTAINMENT_MULTIPLIER) or 1)
        end
        if progression.isCompleted(player, "seal_reinforcement") then
            multiplier = multiplier * math.max(1,
                tonumber(config.SEAL_REINFORCEMENT_MULTIPLIER) or 1)
        end
    end
    return multiplier
end

function Sealing.calculateProgressRate(values, config)
    values = values or {}
    config = config or NinjaLineages.Balance.Jinchuuriki.Sealing

    local maximumHealth = math.max(0, tonumber(values.maximumHealth) or 0)
    local currentHealth = math.max(0, tonumber(values.currentHealth) or 0)
    local healthRatio = maximumHealth > 0
        and math.max(0, math.min(1, currentHealth / maximumHealth)) or 1
    local healthPressure = 1 - healthRatio
    local restraintPressure = math.max(0, tonumber(values.restraintStrength) or 0)
    local vesselPower = math.max(0, tonumber(values.vesselPower) or 0)
    local progressionMultiplier = math.max(1,
        tonumber(values.progressionMultiplier) or 1)
    local tailResistance = Sealing.getTailResistance(values.tails, config)
    local baseRate = math.max(0, tonumber(config.BASE_PROGRESS_PER_GAME_MINUTE) or 0)

    return baseRate * (healthPressure + restraintPressure)
        * vesselPower * progressionMultiplier / tailResistance, {
            healthRatio = healthRatio,
            healthPressure = healthPressure,
            restraintPressure = restraintPressure,
            vesselPower = vesselPower,
            progressionMultiplier = progressionMultiplier,
            tailResistance = tailResistance,
        }
end

function Sealing.advanceProgress(progress, elapsedGameMinutes, values, config)
    local current = math.max(0, math.min(100, tonumber(progress) or 0))
    local elapsed = math.max(0, tonumber(elapsedGameMinutes) or 0)
    local rate, details = Sealing.calculateProgressRate(values, config)
    return math.max(current, math.min(100, current + rate * elapsed)), rate, details
end

return Sealing
