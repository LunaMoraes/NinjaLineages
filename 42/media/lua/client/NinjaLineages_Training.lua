require "TimedActions/ISReadABook"
require "NinjaLineages_Progression"

NLJutsuTrainingAction = ISReadABook:derive("NLJutsuTrainingAction")

function NLJutsuTrainingAction:isBook(item)
    return true
end

function NLJutsuTrainingAction:update()
    ISReadABook.update(self)
    local readPages = self.item:getAlreadyReadPages()
    local data = NinjaLineages.getNLData(self.character)
    data.trainingProgress = data.trainingProgress or {}
    data.trainingProgress[self.nodeId] = readPages
end

function NLJutsuTrainingAction:stop()
    ISReadABook.stop(self)
    local readPages = self.item:getAlreadyReadPages()
    local data = NinjaLineages.getNLData(self.character)
    data.trainingProgress = data.trainingProgress or {}
    data.trainingProgress[self.nodeId] = readPages
    NinjaLineages.Progression.requestTrainingProgress(self.character, self.nodeId, readPages)
end

function NLJutsuTrainingAction:complete()
    local completed = ISReadABook.complete(self)
    if completed ~= true then return completed end
    
    local required = NinjaLineages.Progression.getTrainingPages(self.character, self.nodeId)
    local data = NinjaLineages.getNLData(self.character)
    data.trainingProgress = data.trainingProgress or {}
    data.trainingProgress[self.nodeId] = required

    NinjaLineages.Progression.requestTrainingProgress(self.character, self.nodeId, required)
    NinjaLineages.Progression.requestCompleteTraining(self.character, self.nodeId, self.item)
    return true
end

function NLJutsuTrainingAction:new(character, nodeId)
    local item = NinjaLineages.Progression.getOrCreateTrainingItem(character, nodeId)
    if not item then return nil end
    local o = ISReadABook.new(self, character, item)
    o.nodeId = nodeId
    return o
end

local function onTrainingServerCommand(module, command, args)
    if module ~= "NinjaLineages" then return end
    if command ~= "trainingResult" and command ~= "trainingProgressResult" then return end
    if not args or not args.nodeId then return end

    local player = getPlayer()
    if not player then return end
    local data = NinjaLineages.getNLData(player)
    data.trainingProgress = data.trainingProgress or {}

    if command == "trainingResult" and args.ok == true then
        data.trainingProgress[args.nodeId] = nil
    elseif args.pages ~= nil then
        data.trainingProgress[args.nodeId] = args.pages
    end

    local isDebug = (isDebugEnabled and isDebugEnabled())
        or (SandboxVars and SandboxVars.NinjaLineages and SandboxVars.NinjaLineages.DebugMode == true)

    if args.ok ~= true then
        local reason = args.reason or "unknown"
        player:Say("Training failed: " .. tostring(reason))
        if isDebug then
            print("[DEBUG-NL-TRAINING] client result node=" .. tostring(args.nodeId)
                .. " ok=false reason=" .. tostring(reason)
                .. " pages=" .. tostring(args.pages))
        end
    else
        if isDebug then
            print("[DEBUG-NL-TRAINING] client result node=" .. tostring(args.nodeId)
                .. " command=" .. tostring(command)
                .. " pages=" .. tostring(args.pages))
        end
    end
end

NinjaLineages.addEventOnce("client.training.onServerCommand", Events.OnServerCommand, onTrainingServerCommand)
