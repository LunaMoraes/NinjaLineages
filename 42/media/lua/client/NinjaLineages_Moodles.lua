pcall(require, "MF_ISMoodle")

NinjaLineages = NinjaLineages or {}
NinjaLineages.Moodles = NinjaLineages.Moodles or {}

local MOODLE_GOOD = 1
local MOODLE_BAD = 2

local MOODLE_TEXT = {
    NLChakra = {
        [MOODLE_BAD] = {
            [1] = {
                titleKey = "UI_NL_Moodle_Chakra_Low_Title",
                descKey = "UI_NL_Moodle_Chakra_Low_Desc",
            },
            [2] = {
                titleKey = "UI_NL_Moodle_Chakra_Critical_Title",
                descKey = "UI_NL_Moodle_Chakra_Critical_Desc",
            },
        },
    },
    NLSharinganTomoe = {
        [MOODLE_GOOD] = {
            [1] = {
                titleKey = "UI_NL_Moodle_Sharingan_Tomoe1_Title",
                descKey = "UI_NL_Moodle_Sharingan_Tomoe1_Desc",
            },
            [2] = {
                titleKey = "UI_NL_Moodle_Sharingan_Tomoe2_Title",
                descKey = "UI_NL_Moodle_Sharingan_Tomoe2_Desc",
            },
            [3] = {
                titleKey = "UI_NL_Moodle_Sharingan_Tomoe3_Title",
                descKey = "UI_NL_Moodle_Sharingan_Tomoe3_Desc",
            },
            [4] = {
                titleKey = "UI_NL_Moodle_Mangekyo_Title",
                descKey = "UI_NL_Moodle_Mangekyo_Desc",
            },
        },
    },
    NLKamuiVision = {
        [MOODLE_BAD] = {
            [1] = {
                titleKey = "UI_NL_Moodle_KamuiVision_L1_Title",
                descKey = "UI_NL_Moodle_KamuiVision_L1_Desc",
            },
            [2] = {
                titleKey = "UI_NL_Moodle_KamuiVision_L2_Title",
                descKey = "UI_NL_Moodle_KamuiVision_L2_Desc",
            },
            [3] = {
                titleKey = "UI_NL_Moodle_KamuiVision_L3_Title",
                descKey = "UI_NL_Moodle_KamuiVision_L3_Desc",
            },
            [4] = {
                titleKey = "UI_NL_Moodle_KamuiVision_L4_Title",
                descKey = "UI_NL_Moodle_KamuiVision_L4_Desc",
            },
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
                    local title = moodleText.titleKey and getText(moodleText.titleKey) or moodleText[1]
                    local desc = moodleText.descKey and getText(moodleText.descKey) or moodleText[2]
                    pcall(function() moodle:setTitle(moodleType, level, title) end)
                    pcall(function() moodle:setDescription(moodleType, level, desc) end)
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
