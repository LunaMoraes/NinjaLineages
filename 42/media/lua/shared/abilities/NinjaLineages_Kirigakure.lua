require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Kirigakure = NinjaLineages.Kirigakure or {}

local Kirigakure = NinjaLineages.Kirigakure
local FOG_INTENSITY = ClimateManager.FLOAT_FOG_INTENSITY

Kirigakure.state = Kirigakure.state or nil

local function getFogVariable()
    local climate = getClimateManager and getClimateManager()
    return climate and climate:getClimateFloat(FOG_INTENSITY) or nil
end

local function restoreFog(state)
    local fog = getFogVariable()
    if not fog or not state then return false end

    local restored = pcall(function()
        fog:setAdminValue(state.adminValue)
        fog:setEnableAdmin(state.adminEnabled)
    end)
    return restored == true
end

local function setFullFog(fog)
    return pcall(function()
        fog:setEnableAdmin(true)
        fog:setAdminValue(1.0)
    end)
end

function Kirigakure.activate(duration)
    local fog = getFogVariable()
    if not fog then return false end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    if Kirigakure.state then
        if not setFullFog(fog) then return false end
        Kirigakure.state.expiresAt =
            math.max(now, Kirigakure.state.expiresAt) + duration
        return true
    end

    local state = {
        adminEnabled = fog:isEnableAdmin(),
        adminValue = fog:getAdminValue(),
        expiresAt = now + duration,
    }
    if not setFullFog(fog) then
        restoreFog(state)
        return false
    end

    Kirigakure.state = state
    return true
end

function Kirigakure.update()
    local state = Kirigakure.state
    if not state then return end
    if NinjaLineages.Utils.Time.gameMinutes() < state.expiresAt then return end

    if restoreFog(state) then
        Kirigakure.state = nil
    end
end
