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
        -- Ensure the moodle object's player character reference is correct (can be stale in MP/respawn)
        if moodle.char ~= player then
            moodle.char = player
        end
        
        -- Safely initialize player's Moods modData if missing or overridden by server sync
        local modData = player:getModData()
        if modData then
            modData.Moodles = modData.Moodles or {}
            if modData.Moodles[name] == nil then
                modData.Moodles[name] = {
                    Level = 0,
                    GoodBadNeutral = 0,
                    Value = 0.5
                }
            end
        end

        pcall(function() moodle:setValue(value) end)
    end
end

-- Initialize moodles automatically if MoodleFramework is loaded
if MF and MF.createMoodle then
    NinjaLineages.Moodles.create("NLChakra")
    NinjaLineages.Moodles.create("NLSharinganTomoe")
    NinjaLineages.Moodles.create("NLKamuiVision")
end
