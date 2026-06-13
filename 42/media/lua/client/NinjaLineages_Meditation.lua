require "TimedActions/ISBaseTimedAction"
require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Balance"
require "NinjaLineages_Progression"

NLMeditationAction = ISBaseTimedAction:derive("NLMeditationAction")

function NLMeditationAction:isValid()
    return self.character and not self.character:isDead()
end

function NLMeditationAction:start()
    local data = NinjaLineages.getNLData(self.character)
    if data then
        data.isMeditating = true
        NinjaLineages.transmitPlayerData(self.character)
    end
    if not self.character:isSitOnGround() then
        self.character:reportEvent("EventSitOnGround")
    end
    self.lastXpTick = NinjaLineages.Utils.Time.gameMinutes()
    self.lastNinjaXpTick = self.lastXpTick
    self.character:Say(getText("UI_NL_Meditating"))
end

function NLMeditationAction:update()
    local current = NinjaLineages.Utils.Time.gameMinutes()
    if not self.lastXpTick then self.lastXpTick = current end
    local chakraInterval = NinjaLineages.Balance.Meditation.CHAKRA_CONTROL_TICK_MINUTES
    local chakraTicks = math.floor((current - self.lastXpTick) / chakraInterval)
    if chakraTicks > 0 then
        self.lastXpTick = self.lastXpTick + (chakraTicks * chakraInterval)
        require "NinjaLineages_Skills"
        NinjaLineages.Skills.addChakraControlXP(
            self.character,
            chakraTicks * NinjaLineages.Balance.Meditation.CHAKRA_CONTROL_TICK_XP
        )
    end
    local interval = NinjaLineages.Balance.Progression.NinjaXP.MEDITATION_INTERVAL_MINUTES
    local ninjaXpTicks = math.floor((current - self.lastNinjaXpTick) / interval)
    if ninjaXpTicks > 0 then
        self.lastNinjaXpTick = self.lastNinjaXpTick + (ninjaXpTicks * interval)
        NinjaLineages.Progression.awardXP(
            self.character,
            "meditation",
            ninjaXpTicks * NinjaLineages.Balance.Progression.NinjaXP.MEDITATION_REWARD
        )
    end
end

function NLMeditationAction:stop()
    local data = NinjaLineages.getNLData(self.character)
    if data then
        data.isMeditating = false
        NinjaLineages.transmitPlayerData(self.character)
    end
    ISBaseTimedAction.stop(self)
end

function NLMeditationAction:perform()
    local data = NinjaLineages.getNLData(self.character)
    if data then
        data.isMeditating = false
        NinjaLineages.transmitPlayerData(self.character)
    end
    self.character:Say(getText("UI_NL_MeditationComplete"))
    require "NinjaLineages_Skills"
    NinjaLineages.Skills.addChakraControlXP(
        self.character,
        NinjaLineages.Balance.Meditation.CHAKRA_CONTROL_COMPLETION_XP
    )
    ISBaseTimedAction.perform(self)
end

function NLMeditationAction:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = NinjaLineages.Balance.Meditation.ACTION_TICKS
    return o
end
