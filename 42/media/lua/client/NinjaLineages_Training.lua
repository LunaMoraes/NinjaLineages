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
    NinjaLineages.transmitPlayerData(self.character)
end

function NLJutsuTrainingAction:complete()
    local completed = ISReadABook.complete(self)
    if completed ~= true then return completed end
    
    local required = NinjaLineages.Progression.getTrainingPages(self.character, self.nodeId)
    local data = NinjaLineages.getNLData(self.character)
    data.trainingProgress = data.trainingProgress or {}
    data.trainingProgress[self.nodeId] = required
    
    NinjaLineages.Progression.requestCompleteTraining(self.character, self.nodeId, self.item)
    
    local inventory = self.character:getInventory()
    inventory:Remove(self.item)
    return true
end

function NLJutsuTrainingAction:new(character, nodeId)
    local item = NinjaLineages.Progression.getOrCreateTrainingItem(character, nodeId)
    if not item then return nil end
    local o = ISReadABook.new(self, character, item)
    o.nodeId = nodeId
    return o
end
