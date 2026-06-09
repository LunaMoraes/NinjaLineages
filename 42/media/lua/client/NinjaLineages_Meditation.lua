require "TimedActions/ISBaseTimedAction"

NLMeditationAction = ISBaseTimedAction:derive("NLMeditationAction")

function NLMeditationAction:isValid()
    return self.character and not self.character:isDead()
end

function NLMeditationAction:start()
    local data = self.character:getModData().NinjaLineages
    if data then
        data.isMeditating = true
        if self.character.transmitModData then
            pcall(function() self.character:transmitModData() end)
        end
    end
    if not self.character:isSitOnGround() then
        self.character:reportEvent("EventSitOnGround")
    end
    self.lastXpTick = getTimestampMs()
    self.character:Say(getText("UI_NL_Meditating"))
end

function NLMeditationAction:update()
    local current = getTimestampMs()
    if not self.lastXpTick then self.lastXpTick = current end
    if current - self.lastXpTick >= 5000 then
        self.lastXpTick = current
        require "NinjaLineages_Skills"
        NinjaLineages.Skills.addChakraControlXP(self.character, 1.5)
    end
end

function NLMeditationAction:stop()
    local data = self.character:getModData().NinjaLineages
    if data then
        data.isMeditating = false
        if self.character.transmitModData then
            pcall(function() self.character:transmitModData() end)
        end
    end
    ISBaseTimedAction.stop(self)
end

function NLMeditationAction:perform()
    local data = self.character:getModData().NinjaLineages
    if data then
        data.isMeditating = false
        if self.character.transmitModData then
            pcall(function() self.character:transmitModData() end)
        end
    end
    self.character:Say(getText("UI_NL_MeditationComplete"))
    require "NinjaLineages_Skills"
    NinjaLineages.Skills.addChakraControlXP(self.character, 10.0)
    ISBaseTimedAction.perform(self)
end

function NLMeditationAction:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 3000 -- ~50 seconds in real life
    return o
end
