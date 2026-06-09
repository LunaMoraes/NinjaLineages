require "NinjaLineages_Chakra"

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
    local consts = NinjaLineages.Constants
    if percent < consts.Chakra.CRITICAL_THRESHOLD then
        return { r = 1, g = 0, b = 0 }
    elseif percent < consts.Chakra.LOW_THRESHOLD then
        return { r = 1, g = 0.55, b = 0 }
    end
    return { r = 0.15, g = 0.55, b = 1 }
end

SimpleStatus:addStat("nl_chakra", chakra)
