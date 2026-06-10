pcall(require, "MF_ISMoodle")

NinjaLineages = NinjaLineages or {}
NinjaLineages.Moodles = NinjaLineages.Moodles or {}

function NinjaLineages.Moodles.create(name)
    if MF and MF.createMoodle then
        pcall(function() MF.createMoodle(name) end)
    end
end

function NinjaLineages.Moodles.setValue(name, player, value)
    if not MF or not MF.getMoodle then return end
    local playerNum = player:getPlayerNum()
    local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
    if ok and moodle then
        moodle:setValue(value)
    end
end

-- Initialize moodles automatically if MoodleFramework is loaded
if MF and MF.createMoodle then
    NinjaLineages.Moodles.create("NLChakra")
    NinjaLineages.Moodles.create("NLSharinganTomoe")
    NinjaLineages.Moodles.create("NLKamuiVision")
end
