require "NinjaLineages_Balance"
require "NinjaLineages_Social"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Missions = NinjaLineages.Missions or {}

local Missions = NinjaLineages.Missions

Missions.RANKS = { "D", "C", "B", "A", "S" }
Missions.STATUSES = {
    available = true,
    posted = true,
    active = true,
    completed = true,
    failed = true,
    cancelled = true,
    expired = true,
}
Missions.MAX_TITLE_LENGTH = 64
Missions.MAX_DESCRIPTION_LENGTH = 500

Missions._snapshot = Missions._snapshot or {
    myMission = nil,
    villageMissions = {},
    availableMissions = {},
    managedTeams = {},
    unlockedRanks = {},
    canAcceptPosted = false,
}

function Missions.isValidRank(rank)
    for _, allowed in ipairs(Missions.RANKS) do
        if rank == allowed then return true end
    end
    return false
end

function Missions.validateText(value, maximum)
    local trimmed = NinjaLineages.Social.trim(value)
    if #trimmed < 1 or #trimmed > maximum then return nil end
    return trimmed
end

function Missions.getBalance(rank)
    if not Missions.isValidRank(rank) then return nil, nil end
    local balance = NinjaLineages.Balance.Missions or {}
    return balance.NinjaXP and balance.NinjaXP[rank],
        balance.VillageXP and balance.VillageXP[rank]
end

function Missions.setSnapshot(snapshot)
    if type(snapshot) ~= "table" then return false end
    snapshot.villageMissions = snapshot.villageMissions or {}
    snapshot.availableMissions = snapshot.availableMissions or {}
    snapshot.managedTeams = snapshot.managedTeams or {}
    snapshot.unlockedRanks = snapshot.unlockedRanks or {}
    snapshot.canAcceptPosted = snapshot.canAcceptPosted == true
    Missions._snapshot = snapshot
    return true
end

function Missions.getSnapshot()
    return Missions._snapshot
end

function Missions.request(player, command, args)
    if not player or not command then return false end
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", command, args or {})
        return true
    end
    if NinjaLineages.MissionServer and NinjaLineages.MissionServer.handleCommand then
        NinjaLineages.MissionServer.handleCommand(command, player, args or {})
        return true
    end
    return false
end
