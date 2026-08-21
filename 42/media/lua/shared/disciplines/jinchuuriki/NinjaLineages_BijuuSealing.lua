require "NinjaLineages_Balance"

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

return Sealing
