pcall(require, "MF_ISMoodle")

NinjaLineages = NinjaLineages or {}
NinjaLineages.Moodles = NinjaLineages.Moodles or {}

local registeredMoodles = {
    "NLChakra",
    "NLSharinganTomoe",
    "NLKamuiVision",
}

local function ensureMoodleData(player, name)
    if not player then return nil end
    local modData = player:getModData()
    if not modData then return nil end

    if type(modData.Moodles) ~= "table" then
        modData.Moodles = {}
    end
    if type(modData.Moodles[name]) ~= "table" then
        modData.Moodles[name] = {}
    end

    local moodleData = modData.Moodles[name]
    if moodleData.Level == nil then moodleData.Level = 0 end
    if moodleData.GoodBadNeutral == nil then moodleData.GoodBadNeutral = 0 end
    if moodleData.Value == nil then moodleData.Value = 0.5 end
    return moodleData
end

function NinjaLineages.Moodles.create(name)
    if MF and MF.createMoodle then
        pcall(function() MF.createMoodle(name) end)
    end
end

function NinjaLineages.Moodles.ensurePlayer(player)
    if not player then return end
    local playerNum = player:getPlayerNum()

    for _, name in ipairs(registeredMoodles) do
        ensureMoodleData(player, name)
        if MF and MF.getMoodle then
            local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
            if ok and moodle and moodle.char ~= player then
                moodle.char = player
            end
        end
    end
end

function NinjaLineages.Moodles.setValue(name, player, value)
    if not MF or not MF.getMoodle then return end
    ensureMoodleData(player, name)
    local playerNum = player:getPlayerNum()
    local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
    if ok and moodle then
        if moodle.char ~= player then
            moodle.char = player
        end

        pcall(function() moodle:setValue(value) end)
    end
end

-- Initialize moodles automatically if MoodleFramework is loaded
if MF and MF.createMoodle then
    for _, name in ipairs(registeredMoodles) do
        NinjaLineages.Moodles.create(name)
    end
end

NinjaLineages.registerCreatePlayer("moodles.init", NinjaLineages.Moodles.ensurePlayer)
NinjaLineages.registerPlayerUpdate("moodles.repair", NinjaLineages.Moodles.ensurePlayer)
