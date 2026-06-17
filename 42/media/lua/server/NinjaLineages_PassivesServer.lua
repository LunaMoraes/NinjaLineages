require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Chakra"
require "lineages/NinjaLineages_UzumakiPassives"
require "lineages/NinjaLineages_ByakuganPassives"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ServerPassives = NinjaLineages.ServerPassives or {}

local Passives = NinjaLineages.ServerPassives

local function isLivePlayer(player)
    return player and instanceof(player, "IsoPlayer") and not player:isDead()
end

-- --------------------------------------------------------------------------
-- Byakugan server authority
-- --------------------------------------------------------------------------

function Passives.applyByakugan(player)
    NinjaLineages.ByakuganPassives.applyByakugan(player)
end

-- --------------------------------------------------------------------------
-- Uzumaki server authority
-- --------------------------------------------------------------------------

function Passives.captureUzumakiHealthState(player)
    NinjaLineages.UzumakiPassives.captureUzumakiHealthState(player)
end

function Passives.refundUzumakiDamage(player)
    NinjaLineages.UzumakiPassives.refundUzumakiDamage(player)
end

function Passives.applyUzumakiBleedSlow(player)
    NinjaLineages.UzumakiPassives.applyUzumakiBleedSlow(player)
end

function Passives.updatePlayer(player)
    if not isLivePlayer(player) then return end
    Passives.applyByakugan(player)

    if NinjaLineages.hasUzumaki(player) then
        Passives.captureUzumakiHealthState(player)
    end
end

function Passives.everyMinute(player)
    if not isLivePlayer(player) then return end
    Passives.applyByakugan(player)
    Passives.applyUzumakiBleedSlow(player)
end

function Passives.onPlayerGetDamage(player, damageType, damage)
    if isLivePlayer(player) then
        Passives.refundUzumakiDamage(player)
    end
end

if Events and Events.OnPlayerGetDamage then
    NinjaLineages.addEventOnce(
        "server.passives.onPlayerGetDamage",
        Events.OnPlayerGetDamage,
        Passives.onPlayerGetDamage
    )
end
