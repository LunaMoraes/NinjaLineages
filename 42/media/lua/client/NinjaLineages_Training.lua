require "TimedActions/ISReadABook"
require "NinjaLineages_Progression"

NLJutsuTrainingAction = ISReadABook:derive("NLJutsuTrainingAction")

function NLJutsuTrainingAction:isBook(item)
    return true
end

function NLJutsuTrainingAction:complete()
    local completed = ISReadABook.complete(self)
    if completed ~= true then return completed end
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
