require "NinjaLineages_Utils"
require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.UzumakiPassives = NinjaLineages.UzumakiPassives or {}

local UzumakiPassives = NinjaLineages.UzumakiPassives
local consts = NinjaLineages.Constants
local uzumakiHealthState = setmetatable({}, { __mode = "k" })

local function isLivePlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

local function getBodyPartSnapshot(player)
    local snapshot = {}
    local bodyDamage = player and player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return snapshot end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local health = 100
        local bleed = 0
        pcall(function() health = part:getHealth() end)
        pcall(function() bleed = part:getBleedingTime() end)
        snapshot[i] = { health = health, bleed = bleed }
    end

    return snapshot
end

function UzumakiPassives.captureUzumakiHealthState(player)
    if not isLivePlayer(player) then return end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local state = uzumakiHealthState[player] or {}
    pcall(function() state.generalHealth = bodyDamage:getHealth() end)
    state.parts = getBodyPartSnapshot(player)
    state.lastPassiveAt = NinjaLineages.Utils.Time.gameMinutes()
    uzumakiHealthState[player] = state
end

function UzumakiPassives.refundUzumakiDamage(player)
    if not isLivePlayer(player) or not NinjaLineages.hasUzumaki(player) then return end

    local state = uzumakiHealthState[player]
    if not state then
        UzumakiPassives.captureUzumakiHealthState(player)
        return
    end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end

    local okGeneral, currentGeneral = pcall(function() return bodyDamage:getHealth() end)
    local damageRefunded = false
    local parts = bodyDamage:getBodyParts()

    if parts and state.parts then
        for i = 0, parts:size() - 1 do
            local part = parts:get(i)
            local previous = state.parts[i]
            if part and previous then
                local okPart, currentPartHealth = pcall(function() return part:getHealth() end)
                if okPart and currentPartHealth and previous.health and currentPartHealth < previous.health then
                    local lost = previous.health - currentPartHealth
                    local refund = lost * consts.Uzumaki.Passive.DAMAGE_REFUND
                    if refund > 0 then
                        NinjaLineages.Utils.Healing.healPart(bodyDamage, part, { health = refund })
                        damageRefunded = true
                    end
                end
            end
        end
    end

    if not damageRefunded and okGeneral and state.generalHealth and currentGeneral and currentGeneral < state.generalHealth then
        pcall(function()
            bodyDamage:AddGeneralHealth((state.generalHealth - currentGeneral) * consts.Uzumaki.Passive.DAMAGE_REFUND)
        end)
    end

    UzumakiPassives.captureUzumakiHealthState(player)
    NinjaLineages.transmitPlayerData(player)
end

function UzumakiPassives.applyUzumakiBleedSlow(player)
    if not isLivePlayer(player) then return end

    if not NinjaLineages.hasUzumaki(player) then
        uzumakiHealthState[player] = nil
        return
    end

    local now = NinjaLineages.Utils.Time.gameMinutes()
    local state = uzumakiHealthState[player]
    if not state then
        UzumakiPassives.captureUzumakiHealthState(player)
        return
    end

    if state.lastPassiveAt and now < state.lastPassiveAt + consts.Uzumaki.Passive.TICK_MINUTES then
        return
    end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return end

    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local previous = state.parts and state.parts[i]
        if part and previous then
            local okBleed, currentBleed = pcall(function() return part:getBleedingTime() end)
            if okBleed and currentBleed and currentBleed > 0 and previous.bleed and currentBleed < previous.bleed then
                local restored = currentBleed + ((previous.bleed - currentBleed) * consts.Uzumaki.Passive.BLEED_REFUND)
                pcall(function() part:setBleedingTime(restored) end)
            end
        end
    end

    UzumakiPassives.captureUzumakiHealthState(player)
    NinjaLineages.transmitPlayerData(player)
end

local function onPlayerUpdate(player)
    if NinjaLineages.hasUzumaki(player) then
        UzumakiPassives.captureUzumakiHealthState(player)
    end
end

local function onEveryMinute(player)
    UzumakiPassives.applyUzumakiBleedSlow(player)
end

local function onPlayerGetDamage(player, damageType, damage)
    UzumakiPassives.refundUzumakiDamage(player)
end

if NinjaLineages.isServer() or not NinjaLineages.isClient() then
    NinjaLineages.registerPlayerUpdate("uzumaki.update", onPlayerUpdate)
    NinjaLineages.registerEveryMinute("uzumaki.everyMinute", onEveryMinute)
    NinjaLineages.registerPlayerGetDamage("uzumaki.getDamage", onPlayerGetDamage)
end
