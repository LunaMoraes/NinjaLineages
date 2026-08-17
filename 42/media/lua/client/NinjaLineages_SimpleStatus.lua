require "NinjaLineages_Chakra"
require "NinjaLineages_Balance"

if not getActivatedMods():contains("simpleStatus") then
    return
end

local loaded = pcall(require, "SimpleStatus")
if not loaded or not SimpleStatus or not SimpleStatus.addStat then
    return
end

local function round(value)
    return math.floor(value + 0.5)
end

local function getPercent(player)
    local maximum = NinjaLineages.Chakra.getMaxChakra(player)
    if maximum <= 0 then
        return 0
    end
    return math.max(0, math.min(1, NinjaLineages.Chakra.getChakra(player) / maximum))
end

local chakra = {
    name = "nl_chakra",
    type = "custom",
    shown = true,
}

chakra.valueFn = function(player)
    return NinjaLineages.Chakra.getChakra(player)
end

chakra.percentFn = getPercent

chakra.textFn = function(player)
    return tostring(round(NinjaLineages.Chakra.getChakra(player)))
        .. " / "
        .. tostring(round(NinjaLineages.Chakra.getMaxChakra(player)))
end

chakra.colorFn = function(player)
    local percent = getPercent(player)
    if percent < NinjaLineages.Balance.Chakra.CRITICAL_THRESHOLD then
        return { r = 1, g = 0, b = 0 }
    elseif percent < NinjaLineages.Balance.Chakra.LOW_THRESHOLD then
        return { r = 1, g = 0.55, b = 0 }
    end
    return { r = 0.15, g = 0.55, b = 1 }
end

SimpleStatus:addStat("nl_chakra", chakra)

local natureChakra = {
    name = "nl_nature_chakra",
    type = "custom",
    shown = true,
}

natureChakra.valueFn = function(player)
    return NinjaLineages.Chakra.getNatureChakra(player)
end

natureChakra.percentFn = function(player)
    return math.max(0, math.min(1, NinjaLineages.Chakra.getNatureChakra(player) / 100))
end

natureChakra.textFn = function(player)
    return tostring(round(NinjaLineages.Chakra.getNatureChakra(player))) .. " / 100"
end

natureChakra.colorFn = function(player)
    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if chosen == "toad" then
        return { r = 1.0, g = 0.55, b = 0.1 } -- Orange
    elseif chosen == "snake" then
        return { r = 0.7, g = 0.2, b = 0.9 } -- Purple
    elseif chosen == "snail" then
        return { r = 0.1, g = 0.85, b = 0.9 } -- Cyan
    end
    return { r = 0.3, g = 0.9, b = 0.4 } -- Nature green default
end

SimpleStatus:addStat("nl_nature_chakra", natureChakra)
