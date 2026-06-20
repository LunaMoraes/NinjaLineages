require "NinjaLineages_Traits"

NinjaLineages = NinjaLineages or {}
NinjaLineages.UzumakiPassives = NinjaLineages.UzumakiPassives or {}

local UzumakiPassives = NinjaLineages.UzumakiPassives
local consts = NinjaLineages.Constants
local THICK_SKINNED_TRAIT_ID = "base:thickskinned"
local OWNED_THICK_SKINNED_KEY = "uzumakiAddedThickSkinned"

local function isLivePlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

function UzumakiPassives.ensureThickSkinned(player)
    if not isLivePlayer(player) then return end

    local data = NinjaLineages.getNLData(player)
    local thickSkinned = NinjaLineages.getTraitObject(THICK_SKINNED_TRAIT_ID)
    if not data or not thickSkinned then return end

    local changed = false
    if NinjaLineages.hasUzumaki(player) then
        if not player:hasTrait(thickSkinned) then
            player:getCharacterTraits():add(thickSkinned)
            data[OWNED_THICK_SKINNED_KEY] = true
            changed = true
        end
    elseif data[OWNED_THICK_SKINNED_KEY] == true then
        if player:hasTrait(thickSkinned) then
            player:getCharacterTraits():remove(thickSkinned)
        end
        data[OWNED_THICK_SKINNED_KEY] = nil
        changed = true
    end

    if changed then
        NinjaLineages.transmitPlayerData(player)
    end
end

function UzumakiPassives.applyRapidClotting(player)
    if not isLivePlayer(player) or not NinjaLineages.hasUzumaki(player) then return end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return end

    local remaining = consts.Uzumaki.Passive.BLEEDING_REMAINING_PER_MINUTE
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part then
            local bleedingTime = part:getBleedingTime()
            if bleedingTime and bleedingTime > 0 then
                part:setBleedingTime(bleedingTime * remaining)
            end
        end
    end
end

local function onPlayerUpdate(player)
    UzumakiPassives.ensureThickSkinned(player)
end

local function onEveryMinute(player)
    UzumakiPassives.ensureThickSkinned(player)
    UzumakiPassives.applyRapidClotting(player)
end

if NinjaLineages.isServer() or not NinjaLineages.isClient() then
    NinjaLineages.registerPlayerUpdate("uzumaki.ensureThickSkinned", onPlayerUpdate)
    NinjaLineages.registerEveryMinute("uzumaki.rapidClotting", onEveryMinute)
    NinjaLineages.registerCreatePlayer("uzumaki.init", UzumakiPassives.ensureThickSkinned)
end
