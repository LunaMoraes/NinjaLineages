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

function Passives.updatePlayer(player)
    if not isLivePlayer(player) then return end
    NinjaLineages.runListeners(NinjaLineages.PlayerUpdates, "PlayerUpdateServer", player)
end

function Passives.everyMinute(player)
    if not isLivePlayer(player) then return end
    NinjaLineages.runListeners(NinjaLineages.EveryMinuteListeners, "EveryMinuteServer", player)
end
