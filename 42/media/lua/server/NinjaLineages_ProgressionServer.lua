require "NinjaLineages_Progression"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.ProgressionServer = NinjaLineages.ProgressionServer or {}

local function sendState(player, command, payload)
    sendServerCommand(player, "NinjaLineages", command, payload or {})
end

local function handleAward(player, args)
    local source = args and args.source
    local amount = tonumber(args and args.amount) or 0
    if source ~= "chakra" and source ~= "meditation" then return end
    local maximum = NinjaLineages.Balance.Progression.NinjaXP
    if source == "chakra" then
        amount = math.min(amount, maximum.CHAKRA_DAILY_CAP)
    else
        amount = math.min(amount, maximum.MEDITATION_REWARD)
    end
    NinjaLineages.Progression.awardXP(player, source, amount, true)
    sendState(player, "progressionUpdated")
end

local function handleUnlock(player, args)
    local ok, reason = NinjaLineages.Progression.unlockNode(player, args and args.nodeId)
    sendState(player, "unlockResult", { ok = ok == true, reason = reason, nodeId = args and args.nodeId })
end

local function handleCompleteTraining(player, args)
    local nodeId = args and args.nodeId
    local itemId = tonumber(args and args.itemId) or -1
    local item = player:getInventory():getItemById(itemId)
    local ok, reason = NinjaLineages.Progression.completeTraining(player, nodeId, item)
    sendState(player, "trainingResult", { ok = ok == true, reason = reason, nodeId = nodeId })
end

local function onClientCommand(module, command, player, args)
    if module ~= "NinjaLineages" then return end
    if command == "awardNinjaXP" then
        handleAward(player, args)
    elseif command == "unlockNode" then
        handleUnlock(player, args)
    elseif command == "completeTraining" then
        handleCompleteTraining(player, args)
    end
end

local function onZombieDead(zombie)
    local attacker = zombie and zombie:getAttackedBy()
    if attacker and instanceof(attacker, "IsoPlayer") then
        local reward = NinjaLineages.Balance.Progression.NinjaXP.KILL
        NinjaLineages.Progression.awardXP(attacker, "kill", reward, true)
        sendState(attacker, "progressionUpdated")
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnZombieDead.Add(onZombieDead)
