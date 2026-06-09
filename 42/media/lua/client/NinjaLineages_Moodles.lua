pcall(require, "MF_ISMoodle")

NinjaLineages = NinjaLineages or {}
NinjaLineages.Moodles = NinjaLineages.Moodles or {}

local MOODLE_GOOD = 1
local MOODLE_BAD = 2

local MOODLE_TEXT = {
    NLChakra = {
        [MOODLE_BAD] = {
            [1] = { "Low Chakra", "Your chakra is low (<30%). Consider meditating." },
            [2] = { "Very Low Chakra", "Your chakra is critical (<10%). Sustained powers will fail soon." },
        },
    },
    NLSharinganTomoe = {
        [MOODLE_GOOD] = {
            [1] = { "Sharingan", "First Tomoe awakened. Dodge chance: 30%." },
            [2] = { "Sharingan", "Second Tomoe released. Dodge chance: 60%." },
            [3] = { "Sharingan", "Third Tomoe released. Dodge chance: 90%." },
            [4] = { "Mangekyo Sharingan", "Mangekyo Sharingan awakened. Kamui is available." },
        },
    },
    NLKamuiVision = {
        [MOODLE_BAD] = {
            [1] = { "Vision Impaired", "Kamui has strained your vision. Recovery: 1 in-game hour." },
            [2] = { "Vision Impaired", "Repeated Kamui use has damaged your vision. Recovery: 6 in-game hours." },
            [3] = { "Vision Impaired", "Kamui overuse has severely damaged your vision. Recovery: 1 full in-game day." },
            [4] = { "Vision Impaired", "Kamui overuse has severely damaged your vision. Recovery: 1 full in-game day." },
        },
    },
}

function NinjaLineages.Moodles.create(name)
    if MF and MF.createMoodle then
        pcall(function() MF.createMoodle(name) end)
    end
end

function NinjaLineages.Moodles.registerText(name, textTable)
    MOODLE_TEXT[name] = textTable
end

function NinjaLineages.Moodles.setValue(name, player, value)
    if not MF or not MF.getMoodle then return end
    local playerNum = player:getPlayerNum()
    local ok, moodle = pcall(function() return MF.getMoodle(name, playerNum) end)
    if ok and moodle then
        local text = MOODLE_TEXT[name]
        if text and not moodle.NinjaLineagesTextConfigured then
            for moodleType, levels in pairs(text) do
                for level, moodleText in pairs(levels) do
                    pcall(function() moodle:setTitle(moodleType, level, moodleText[1]) end)
                    pcall(function() moodle:setDescription(moodleType, level, moodleText[2]) end)
                end
            end
            moodle.NinjaLineagesTextConfigured = true
        end
        moodle:setValue(value)
    end
end

-- Initialize moodles automatically if MoodleFramework is loaded
if MF and MF.createMoodle then
    NinjaLineages.Moodles.create("NLChakra")
    NinjaLineages.Moodles.create("NLSharinganTomoe")
    NinjaLineages.Moodles.create("NLKamuiVision")
end
