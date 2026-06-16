require "NinjaLineages_Traits"
require "NinjaLineages_Skills"
require "NinjaLineages_Balance"
require "NinjaLineages_TreeDefinitions"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Progression = NinjaLineages.Progression or {}

local Progression = NinjaLineages.Progression
local Balance = NinjaLineages.Balance
local Trees = NinjaLineages.TreeDefinitions

local function getState(player)
    local data = NinjaLineages.getNLData(player)
    data.progression = data.progression or {}
    local state = data.progression
    state.ninjaXP = state.ninjaXP or 0
    state.nodes = state.nodes or {}
    state.dailyXP = state.dailyXP or {}
    return state
end

function Progression.getState(player)
    return getState(player)
end

function Progression.getNinjaXP(player)
    return getState(player).ninjaXP or 0
end

function Progression.setNinjaXP(player, amount)
    if isClient and isClient() then return end
    local state = getState(player)
    state.ninjaXP = math.max(0, amount or 0)
    NinjaLineages.transmitPlayerData(player)
end

function Progression.requestDebugAddXP(player, amount)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then return false end
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "debugAddNinjaXP", { amount = amount })
        return true
    end
    Progression.setNinjaXP(player, Progression.getNinjaXP(player) + amount)
    return true
end

function Progression.requestDebugToggleBypass(player)
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "debugToggleBypass", {})
        return true
    end
    local data = NinjaLineages.getNLData(player)
    data.bypassTraining = data.bypassTraining ~= true
    NinjaLineages.transmitPlayerData(player)
    return data.bypassTraining
end

function Progression.requestDebugSetAllVisible(player)
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "debugToggleAllVisible", {})
        return true
    end
    local data = NinjaLineages.getNLData(player)
    data.allDisciplinesVisible = data.allDisciplinesVisible ~= true
    NinjaLineages.transmitPlayerData(player)
    return data.allDisciplinesVisible
end

function Progression.requestDebugSetAllUnlocked(player)
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "debugToggleAllUnlocked", {})
        return true
    end
    local data = NinjaLineages.getNLData(player)
    data.allDisciplinesUnlocked = data.allDisciplinesUnlocked ~= true
    NinjaLineages.transmitPlayerData(player)
    return data.allDisciplinesUnlocked
end

function Progression.isDisciplineVisible(player, disciplineId)
    local definition = NinjaLineages.TreeDefinitions.Disciplines[disciplineId]
    if not definition then return false end
    if not definition.hidden then return true end

    local data = NinjaLineages.getNLData(player)
    if data.visibleDisciplines and data.visibleDisciplines[disciplineId] then
        return true
    end
    if data.allDisciplinesVisible then
        return true
    end
    return false
end

function Progression.isDisciplineLocked(player, disciplineId)
    local definition = NinjaLineages.TreeDefinitions.Disciplines[disciplineId]
    if not definition then return true end
    
    local data = NinjaLineages.getNLData(player)
    if data.allDisciplinesUnlocked then
        return false
    end
    if data.unlockedDisciplines and data.unlockedDisciplines[disciplineId] then
        return false
    end
    return definition.locked == true
end

local function currentDay()
    local minutes = NinjaLineages.Utils and NinjaLineages.Utils.Time.gameMinutes() or 0
    return math.floor(minutes / (24 * 60))
end

local function resetDailyIfNeeded(state)
    local day = currentDay()
    if state.dailyXP.day ~= day then
        state.dailyXP = { day = day, chakra = 0, meditation = 0 }
    end
    return state.dailyXP
end

function Progression.awardXP(player, source, rawAmount, authoritative)
    if not player or rawAmount <= 0 then return 0 end
    if isClient and isClient() and authoritative ~= true then
        sendClientCommand(player, "NinjaLineages", "awardNinjaXP", {
            source = source,
            amount = rawAmount,
        })
        return 0
    end
    local state = getState(player)
    local daily = resetDailyIfNeeded(state)
    local xpRules = Balance.Progression.NinjaXP
    local amount = Balance.scaleNinjaXP(rawAmount)

    if source == "chakra" then
        local cap = Balance.scaleNinjaXP(xpRules.CHAKRA_DAILY_CAP)
        amount = math.min(amount, math.max(0, cap - (daily.chakra or 0)))
        daily.chakra = (daily.chakra or 0) + amount
    elseif source == "meditation" then
        local cap = Balance.scaleNinjaXP(xpRules.MEDITATION_DAILY_CAP)
        amount = math.min(amount, math.max(0, cap - (daily.meditation or 0)))
        daily.meditation = (daily.meditation or 0) + amount
    end

    if amount <= 0 then return 0 end
    state.ninjaXP = (state.ninjaXP or 0) + amount
    NinjaLineages.transmitPlayerData(player)
    return amount
end

function Progression.requestUnlock(player, nodeId)
    local data = NinjaLineages.getNLData(player)
    local bypass = (data and data.bypassTraining == true)
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "unlockNode", { nodeId = nodeId, bypass = bypass })
        return true
    end
    return Progression.unlockNode(player, nodeId, bypass)
end

function Progression.requestCompleteTraining(player, nodeId, item)
    if isClient and isClient() then
        sendClientCommand(player, "NinjaLineages", "completeTraining", {
            nodeId = nodeId,
            itemId = item and item:getID() or -1,
        })
        return true
    end
    return Progression.completeTraining(player, nodeId, item)
end

function Progression.isUnlocked(player, nodeId)
    local value = getState(player).nodes[nodeId]
    return value == "unlocked" or value == "completed"
end

function Progression.isCompleted(player, nodeId)
    return getState(player).nodes[nodeId] == "completed"
end

function Progression.arePrerequisitesComplete(player, definition)
    for _, prerequisite in ipairs(definition.prerequisites or {}) do
        if not Progression.isCompleted(player, prerequisite) then return false end
    end
    return true
end

function Progression.getNodeState(player, nodeId)
    local definition = Trees.getNode(nodeId)
    if not definition then return "invalid" end
    local stored = getState(player).nodes[nodeId]
    if stored then return stored end
    if Progression.arePrerequisitesComplete(player, definition) then return "available" end
    return "locked"
end

function Progression.getNodeCost(player, nodeId)
    local definition = Trees.getNode(nodeId)
    if not definition then return 0 end
    return Balance.getNodeCost(definition.tier, player, definition.discipline)
end

function Progression.getTrainingPages(player, nodeId)
    local definition = Trees.getNode(nodeId)
    if not definition then return 0 end
    return Balance.getTrainingPages(definition.tier)
end

function Progression.getTrainingPagesRead(player, nodeId)
    local definition = Trees.getNode(nodeId)
    if not definition or not player then return 0 end
    return math.max(0, player:getAlreadyReadPages(definition.trainingItem) or 0)
end

function Progression.getOrCreateTrainingItem(player, nodeId)
    local definition = Trees.getNode(nodeId)
    if not definition or Progression.getNodeState(player, nodeId) ~= "unlocked" then return nil end
    local inventory = player:getInventory()
    local item = inventory:FindAndReturn(definition.trainingItem)
    if not item then
        item = instanceItem(definition.trainingItem)
        if not item then return nil end
        inventory:AddItem(item)
    end
    item:setNumberOfPages(Progression.getTrainingPages(player, nodeId))
    item:setAlreadyReadPages(Progression.getTrainingPagesRead(player, nodeId))
    return item
end

function Progression.unlockNode(player, nodeId, bypass)
    if isClient and isClient() then return false, "client_unauthorized" end
    local definition = Trees.getNode(nodeId)
    if not definition then return false, "invalid" end
    if Progression.getNodeState(player, nodeId) ~= "available" then return false, "unavailable" end
    local cost = Progression.getNodeCost(player, nodeId)
    if Progression.getNinjaXP(player) < cost then return false, "xp" end

    local isBypass = false
    if bypass and SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true then
        isBypass = true
    end

    local state = getState(player)
    state.ninjaXP = state.ninjaXP - cost
    if isBypass then
        state.nodes[nodeId] = "completed"
    else
        state.nodes[nodeId] = "unlocked"
    end
    NinjaLineages.transmitPlayerData(player)
    return true
end

function Progression.completeTraining(player, nodeId, item)
    if isClient and isClient() then return false, "client_unauthorized" end
    if Progression.getNodeState(player, nodeId) ~= "unlocked" then return false, "unavailable" end
    local definition = Trees.getNode(nodeId)
    if not item or item:getFullType() ~= definition.trainingItem then return false, "invalid_item" end
    local required = Progression.getTrainingPages(player, nodeId)
    if item:getAlreadyReadPages() < required then return false, "incomplete" end
    local state = getState(player)
    state.nodes[nodeId] = "completed"
    NinjaLineages.transmitPlayerData(player)
    return true
end

function Progression.getCompletedRank(player, prefix)
    if Progression.isCompleted(player, prefix .. "_jonin") then return "JONIN" end
    if Progression.isCompleted(player, prefix .. "_chunin") then return "CHUNIN" end
    if Progression.isCompleted(player, prefix .. "_genin") then return "GENIN" end
    return nil
end

function Progression.getNinjaScore(player)
    local score = 0
    for id, definition in pairs(Trees.Nodes) do
        if Progression.isCompleted(player, id) then
            score = score + (Balance.Progression.RankNodeWeight[definition.tier] or 0)
        end
    end

    local lineageChecks = {
        NinjaLineages.hasByakugan,
        NinjaLineages.hasSharingan,
        NinjaLineages.hasSenju,
        NinjaLineages.hasRinnegan,
        NinjaLineages.hasUzumaki,
    }
    for _, check in ipairs(lineageChecks) do
        if check and check(player) then
            score = score + Balance.Progression.RankNodeWeight.LINEAGE
        end
    end

    local data = NinjaLineages.getNLData(player)
    local rareFlags = { "creationRebirthUnlocked", "mangekyoUnlocked" }
    for _, flag in ipairs(rareFlags) do
        if data[flag] then score = score + Balance.Progression.RankNodeWeight.RARE end
    end

    local skills = NinjaLineages.Skills.getChakraControlLevel(player)
        + NinjaLineages.Skills.getJutsuProwessLevel(player)
    score = score + math.floor(skills / Balance.Progression.SkillScoreDivisor)
    return score
end

function Progression.getNinjaRank(player)
    local score = Progression.getNinjaScore(player)
    local thresholds = Balance.Progression.RankThreshold
    if score >= thresholds.KAGE then return "KAGE" end
    if score >= thresholds.JONIN then return "JONIN" end
    if score >= thresholds.CHUNIN then return "CHUNIN" end
    if score >= thresholds.GENIN then return "GENIN" end
    return "NONE"
end
