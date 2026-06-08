require "NinjaLineages_Traits"
require "NinjaLineages_Items"

pcall(require, "MF_ISMoodle")
pcall(require, "ISUI/ISContextMenu")
pcall(require, "ISUI/ISRadialMenu")
pcall(require, "TimedActions/ISBaseTimedAction")
pcall(require, "TimedActions/ISTimedActionQueue")

if MF and MF.createMoodle then
    MF.createMoodle("NLSharinganTomoe")
    MF.createMoodle("NLKamuiVision")
end

local SENJU_ENDURANCE_RECOVERY_PER_SECOND = 0.01
local SHARINGAN_STAGE_1_KILLS = 1
local SHARINGAN_STAGE_2_KILLS = 100
local SHARINGAN_STAGE_3_KILLS = 500
local KAMUI_DURATION_MS = 10000
local KAMUI_ENDURANCE_MIN = 0.20
local KAMUI_ENDURANCE_DRAIN_PER_SECOND = 0.08
local KAMUI_COOLDOWN_SECONDS = 15
local SHINRA_COOLDOWN_SECONDS = 15
local SHINRA_RADIUS = 7.0
local SHINRA_GUARANTEED_KNOCKDOWN_RADIUS = 3.5
local SHINRA_BASE_ENDURANCE_COST = 0.35
local SHINRA_ENDURANCE_COST_PER_ZOMBIE = 0.03
local SHINRA_ENDURANCE_COST_CAP = 0.75
local SHINRA_MIN_DAMAGE = 0.75
local SHINRA_MAX_DAMAGE = 1.10
local SHINRA_MIN_DAMAGE_FALLOFF = 0.85
local WOOD_ROOTS_RADIUS = 10.0
local WOOD_ROOTS_INNER_RADIUS = 6.0
local WOOD_ROOTS_COOLDOWN_SECONDS = 45
local WOOD_ROOTS_ENDURANCE_COST = 0.35
local WOOD_ROOTS_BIND_MS = 3500
local CREATION_REBIRTH_DURATION_MS = 8000
local CREATION_REBIRTH_TICK_MS = 250
local CREATION_REBIRTH_ENDURANCE_PER_PART = 0.015
local UZUMAKI_DAMAGE_REFUND = 0.33
local UZUMAKI_BLEED_REFUND = 0.75
local UZUMAKI_PASSIVE_TICK_MS = 1000
local ALARM_SEAL_RADIUS = 2.0
local ALARM_SEAL_SCAN_MS = 500
local ALARM_SEAL_DISCOVERY_MS = 5000
local BYAKUGAN_PUSH_MIN_DAMAGE = 0.18
local BYAKUGAN_PUSH_MAX_DAMAGE = 0.75
local VISION_RECOVERY_HOURS = { 1, 6, 24 }
local VISION_ITEMS = {
    "Base.NL_KamuiVision_L1",
    "Base.NL_KamuiVision_L2",
    "Base.NL_KamuiVision_L3",
}
local MOODLE_GOOD = 1
local MOODLE_BAD = 2
local MOODLE_TEXT = {
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

local sharinganAttackRolls = {}
local senjuLastRecoveryAt = {}
local kamuiState = {}
local boundZombies = {}
local creationRebirthState = {}
local uzumakiHealthState = {}
local alarmSeals = {}
local nextAlarmScanAt = 0
local nextAlarmDiscoveryAt = 0

local function getByakuganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.BYAKUGAN
end

local function getSharinganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SHARINGAN
end

local function getSenjuTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.SENJU
end

local function getRinneganTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.RINNEGAN
end

local function getUzumakiTrait()
    return NinjaLineages.CharacterTrait
        and NinjaLineages.CharacterTrait.UZUMAKI
end

local function getFastHealerTrait()
    local ok, trait = pcall(function()
        return CharacterTrait.get(ResourceLocation.of("base:fasthealer"))
    end)
    if ok then return trait end
    return nil
end

local function getNLData(player)
    local modData = player:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    return modData.NinjaLineages
end

local function transmitPlayerData(player)
    if player and player.transmitModData then
        pcall(function() player:transmitModData() end)
    end
end

local function getTimestampSeconds()
    if getTimestamp then return getTimestamp() end
    return math.floor(getTimestampMs() / 1000)
end

local function getWorldAgeHours()
    local gameTime = getGameTime()
    if gameTime and gameTime.getWorldAgeHours then
        return gameTime:getWorldAgeHours()
    end
    return 0
end

local function hasTrait(player, trait)
    return player and trait and player:hasTrait(trait)
end

local function hasSharingan(player)
    return hasTrait(player, getSharinganTrait())
end

local function hasByakugan(player)
    return hasTrait(player, getByakuganTrait())
end

local function hasRinnegan(player)
    return hasTrait(player, getRinneganTrait())
end

local function hasSenju(player)
    return hasTrait(player, getSenjuTrait())
end

local function hasUzumaki(player)
    return hasTrait(player, getUzumakiTrait())
end

local function getSharinganStage(player)
    if not hasSharingan(player) then return 0 end
    local kills = player:getZombieKills() or 0
    if kills >= SHARINGAN_STAGE_3_KILLS then return 3 end
    if kills >= SHARINGAN_STAGE_2_KILLS then return 2 end
    if kills >= SHARINGAN_STAGE_1_KILLS then return 1 end
    return 0
end

local function getSharinganDodgeChance(player)
    local stage = getSharinganStage(player)
    if stage == 1 then return 30 end
    if stage == 2 then return 60 end
    if stage == 3 then return 90 end
    return 0
end

local function setMoodleValue(name, player, value)
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

local function updateSharinganMoodle(player)
    local data = getNLData(player)
    if not hasSharingan(player) then
        setMoodleValue("NLSharinganTomoe", player, 0.5)
        data.lastSharinganStage = nil
        return
    end

    local stage = getSharinganStage(player)
    if data.mangekyoUnlocked then
        setMoodleValue("NLSharinganTomoe", player, 0.9)
    elseif stage == 3 then
        setMoodleValue("NLSharinganTomoe", player, 0.8)
    elseif stage == 2 then
        setMoodleValue("NLSharinganTomoe", player, 0.7)
    elseif stage == 1 then
        setMoodleValue("NLSharinganTomoe", player, 0.6)
    else
        setMoodleValue("NLSharinganTomoe", player, 0.5)
    end

    local lastStage = data.lastSharinganStage or 0
    if stage > lastStage then
        if stage == 1 then
            player:Say("Sharingan unlocked")
        elseif stage == 2 then
            player:Say("Second Tomoe released")
        elseif stage == 3 then
            player:Say("Third Tomoe released")
        end
        data.lastSharinganStage = stage
        transmitPlayerData(player)
    elseif stage < lastStage then
        data.lastSharinganStage = stage
        transmitPlayerData(player)
    end
end

local function getWornItemByType(player, itemTypes)
    local wornItems = player:getWornItems()
    if not wornItems then return nil end
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:getItemByIndex(i)
        if wornItem then
            local fullType = wornItem:getFullType()
            local typeName = wornItem:getType()
            for _, itemType in ipairs(itemTypes) do
                if fullType == itemType or typeName == itemType:gsub("^Base%.", "") then
                    return wornItem
                end
            end
        end
    end
    return nil
end

local function getWornByakuganSight(player)
    return getWornItemByType(player, { "Base.NL_ByakuganSight" })
end

local function removeInventoryItems(player, itemTypes)
    local inv = player:getInventory()
    if not inv then return end
    for _, itemType in ipairs(itemTypes) do
        local item = inv:getItemFromType(itemType)
        while item do
            inv:Remove(item)
            item = inv:getItemFromType(itemType)
        end
    end
end

local function applyByakugan(player)
    if not player then return end
    local byakuganTrait = getByakuganTrait()
    if not byakuganTrait then return end

    if player:hasTrait(byakuganTrait) then
        local equipped = getWornByakuganSight(player)
        if not equipped then
            local inv = player:getInventory()
            if inv then
                local item = inv:getItemFromType("Base.NL_ByakuganSight")
                if not item then
                    item = inv:AddItem("Base.NL_ByakuganSight")
                end
                if item then
                    player:setWornItem(item:getBodyLocation(), item)
                end
            end
        end
        if not player:hasTrait(CharacterTrait.EAGLE_EYED) then
            player:getCharacterTraits():add(CharacterTrait.EAGLE_EYED)
        end
        if not player:hasTrait(CharacterTrait.KEEN_HEARING) then
            player:getCharacterTraits():add(CharacterTrait.KEEN_HEARING)
        end
    else
        local equipped = getWornByakuganSight(player)
        if equipped then
            player:setWornItem(equipped:getBodyLocation(), nil)
        end
        removeInventoryItems(player, { "Base.NL_ByakuganSight" })
    end
end

local function applyKamuiVisionItem(player)
    local data = getNLData(player)
    local level = data.kamuiVisionLevel or 0
    local equipped = getWornItemByType(player, VISION_ITEMS)
    local desiredType = level > 0 and VISION_ITEMS[level] or nil
    if equipped and desiredType and equipped:getFullType() == desiredType then
        if level == 1 then
            setMoodleValue("NLKamuiVision", player, 0.4)
        elseif level == 2 then
            setMoodleValue("NLKamuiVision", player, 0.3)
        else
            setMoodleValue("NLKamuiVision", player, 0.2)
        end
        return
    end

    if equipped then
        player:setWornItem(equipped:getBodyLocation(), nil)
    end

    if level <= 0 then
        removeInventoryItems(player, VISION_ITEMS)
        setMoodleValue("NLKamuiVision", player, 0.5)
        return
    end

    removeInventoryItems(player, VISION_ITEMS)
    local inv = player:getInventory()
    if not inv then return end
    local item = inv:AddItem(desiredType)
    if item then
        player:setWornItem(item:getBodyLocation(), item)
    end

    if level == 1 then
        setMoodleValue("NLKamuiVision", player, 0.4)
    elseif level == 2 then
        setMoodleValue("NLKamuiVision", player, 0.3)
    else
        setMoodleValue("NLKamuiVision", player, 0.2)
    end
end

local function recoverKamuiVision(player)
    local data = getNLData(player)
    local level = data.kamuiVisionLevel or 0
    if level <= 0 then
        data.kamuiVisionLevel = 0
        data.kamuiVisionRecoverAt = nil
        applyKamuiVisionItem(player)
        return
    end

    local now = getWorldAgeHours()
    if data.kamuiVisionRecoverAt and now >= data.kamuiVisionRecoverAt then
        level = math.max(0, level - 1)
        data.kamuiVisionLevel = level
        if level > 0 then
            data.kamuiVisionRecoverAt = now + VISION_RECOVERY_HOURS[level]
        else
            data.kamuiVisionRecoverAt = nil
        end
        transmitPlayerData(player)
    end
    applyKamuiVisionItem(player)
end

local function addKamuiVisionPenalty(player)
    local data = getNLData(player)
    local now = getWorldAgeHours()
    local level = math.min(3, (data.kamuiVisionLevel or 0) + 1)
    data.kamuiVisionLevel = level
    data.kamuiVisionRecoverAt = now + VISION_RECOVERY_HOURS[level]
    applyKamuiVisionItem(player)
    transmitPlayerData(player)
end

local function applySenjuEndurance(player)
    if not player then return end

    local senjuTrait = getSenjuTrait()
    if not senjuTrait then return end
    local data = getNLData(player)
    local fastHealer = getFastHealerTrait()
    if not player:hasTrait(senjuTrait) then
        senjuLastRecoveryAt[player] = nil
        if data.senjuAddedFastHealer and fastHealer then
            pcall(function() player:getCharacterTraits():remove(fastHealer:getType()) end)
            pcall(function() player:getCharacterTraits():remove(fastHealer) end)
            data.senjuAddedFastHealer = nil
            transmitPlayerData(player)
        end
        return
    end

    if fastHealer and not player:hasTrait(fastHealer) then
        pcall(function() player:getCharacterTraits():add(fastHealer:getType()) end)
        pcall(function()
            if not player:hasTrait(fastHealer) then
                player:getCharacterTraits():add(fastHealer)
            end
        end)
        data.senjuAddedFastHealer = true
        transmitPlayerData(player)
    end

    local currentTime = getTimestampMs()
    local lastRecovery = senjuLastRecoveryAt[player]
    if lastRecovery and currentTime < lastRecovery + 1000 then return end
    senjuLastRecoveryAt[player] = currentTime

    local stats = player:getStats()
    if not stats then return end

    local current = stats:get(CharacterStat.ENDURANCE)
    local boosted = math.min(1.0, current + SENJU_ENDURANCE_RECOVERY_PER_SECOND)
    stats:set(CharacterStat.ENDURANCE, boosted)
end

local function safeGetBool(player, getterName)
    local ok, value = pcall(function()
        if getterName == "isGhostMode" then return player:isGhostMode() end
        if getterName == "isGodMod" then return player:isGodMod() end
        if getterName == "isNoClip" then return player:isNoClip() end
        return false
    end)
    return ok and value == true
end

local function safeSetBool(player, setterName, value)
    pcall(function()
        if setterName == "setGhostMode" then
            player:setGhostMode(value)
        elseif setterName == "setGodMod" then
            player:setGodMod(value)
        end
    end)
end

local function safeSetNoClip(player, value)
    pcall(function() player:setNoClip(value, true) end)
    pcall(function() player:setNoClip(value) end)
end

local function stopKamui(player, applyPenalty)
    local state = kamuiState[player]
    if not state then return end

    safeSetBool(player, "setGhostMode", state.wasGhostMode)
    safeSetBool(player, "setGodMod", state.wasGodMod)
    safeSetNoClip(player, state.wasNoClip)
    kamuiState[player] = nil

    if applyPenalty then
        addKamuiVisionPenalty(player)
    end
end

local function failNearbyZombieAttacks(player)
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() and zombie:DistTo(player) <= 3.0 then
            local target = zombie:getTarget()
            if target == player then
                zombie:setVariable("AttackOutcome", "fail")
            end
        end
    end
end

local function updateKamui(player)
    local state = kamuiState[player]
    if not state then return end

    local nowMs = getTimestampMs()
    local stats = player:getStats()
    if not stats then
        stopKamui(player, true)
        return
    end

    local elapsedMs = nowMs - state.startedAt
    local deltaSeconds = math.max(0, (nowMs - state.lastTick) / 1000)
    state.lastTick = nowMs

    local endurance = stats:get(CharacterStat.ENDURANCE)
    endurance = math.max(0, endurance - (KAMUI_ENDURANCE_DRAIN_PER_SECOND * deltaSeconds))
    stats:set(CharacterStat.ENDURANCE, endurance)

    failNearbyZombieAttacks(player)

    if elapsedMs >= KAMUI_DURATION_MS or endurance <= 0 then
        stopKamui(player, true)
    end
end

local function canUseKamui(player)
    local data = getNLData(player)
    return hasSharingan(player) and data.mangekyoUnlocked == true
end

local function startKamui(player)
    local data = getNLData(player)
    if not canUseKamui(player) then
        player:Say("Mangekyo Sharingan is not unlocked")
        return
    end

    if kamuiState[player] then
        stopKamui(player, false)
        player:Say("Kamui cancelled")
        return
    end

    local now = getTimestampSeconds()
    if data.kamuiCooldownUntil and now < data.kamuiCooldownUntil then
        player:Say("Kamui cooldown: " .. tostring(math.ceil(data.kamuiCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats or stats:get(CharacterStat.ENDURANCE) < KAMUI_ENDURANCE_MIN then
        player:Say("Too exhausted for Kamui")
        return
    end

    local nowMs = getTimestampMs()
    kamuiState[player] = {
        startedAt = nowMs,
        lastTick = nowMs,
        wasGhostMode = safeGetBool(player, "isGhostMode"),
        wasGodMod = safeGetBool(player, "isGodMod"),
        wasNoClip = safeGetBool(player, "isNoClip"),
    }

    safeSetBool(player, "setGhostMode", true)
    safeSetBool(player, "setGodMod", true)
    safeSetNoClip(player, true)

    data.kamuiCooldownUntil = now + KAMUI_COOLDOWN_SECONDS
    transmitPlayerData(player)
    player:Say("Kamui")
end

local function collectShinraTargets(player)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return targets end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local distance = zombie:DistTo(player)
            if distance <= SHINRA_RADIUS then
                table.insert(targets, { zombie = zombie, distance = distance })
            end
        end
    end
    return targets
end

local function applyZombieDamage(player, zombie, damage)
    if not zombie or zombie:isDead() then return end

    pcall(function() zombie:setAttackedBy(player) end)
    local ok, health = pcall(function() return zombie:getHealth() end)
    if ok and health then
        local newHealth = math.max(0, health - damage)
        pcall(function() zombie:setHealth(newHealth) end)
        if newHealth <= 0 then
            pcall(function() zombie:Kill(player) end)
        end
    end
end

local function getRandomDamage(minDamage, maxDamage)
    local damageRoll = ZombRand(0, 1001) / 1000
    return minDamage + (damageRoll * (maxDamage - minDamage))
end

local function applyShinraDamage(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    local falloff = math.max(SHINRA_MIN_DAMAGE_FALLOFF, 1.0 - ((target.distance / SHINRA_RADIUS) * 0.15))
    local damage = getRandomDamage(SHINRA_MIN_DAMAGE, SHINRA_MAX_DAMAGE) * falloff
    applyZombieDamage(player, zombie, damage)
end

local function getKnockdownChance(distance)
    if distance <= SHINRA_GUARANTEED_KNOCKDOWN_RADIUS then return 100 end

    local outerRange = SHINRA_RADIUS - SHINRA_GUARANTEED_KNOCKDOWN_RADIUS
    if outerRange <= 0 then return 0 end

    local remaining = math.max(0, SHINRA_RADIUS - distance)
    return math.floor((remaining / outerRange) * 100)
end

local function applyShinraToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    zombie:setVariable("AttackOutcome", "fail")
    zombie:setStaggerBack(true)
    if ZombRand(1, 101) <= getKnockdownChance(target.distance) then
        zombie:setKnockedDown(true)
    end
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition("FRONT") end)
    pcall(function() zombie:setHitForce(math.max(2.0, 8.0 - target.distance)) end)
    pcall(function() zombie:reportEvent("wasHit") end)
    applyShinraDamage(player, target)
end

local function useShinraTensei(player)
    if not hasRinnegan(player) then
        player:Say("Rinnegan is required")
        return
    end

    local data = getNLData(player)
    local now = getTimestampSeconds()
    if data.shinraCooldownUntil and now < data.shinraCooldownUntil then
        player:Say("Shinra Tensei cooldown: " .. tostring(math.ceil(data.shinraCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats then return end

    local targets = collectShinraTargets(player)
    local cost = math.min(
        SHINRA_ENDURANCE_COST_CAP,
        SHINRA_BASE_ENDURANCE_COST + (#targets * SHINRA_ENDURANCE_COST_PER_ZOMBIE)
    )
    local endurance = stats:get(CharacterStat.ENDURANCE)
    if endurance < cost then
        player:Say("Too exhausted for Shinra Tensei")
        return
    end

    stats:set(CharacterStat.ENDURANCE, math.max(0, endurance - cost))
    for _, target in ipairs(targets) do
        applyShinraToZombie(player, target)
    end

    data.shinraCooldownUntil = now + SHINRA_COOLDOWN_SECONDS
    transmitPlayerData(player)
    player:Say("Shinra Tensei")
end

local function collectZombieTargets(player, radius)
    local targets = {}
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return targets end
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local distance = zombie:DistTo(player)
            if distance <= radius then
                table.insert(targets, { zombie = zombie, distance = distance })
            end
        end
    end
    return targets
end

local function applyBindingRootsToZombie(player, target)
    local zombie = target.zombie
    if not zombie or zombie:isDead() then return end

    zombie:setVariable("AttackOutcome", "fail")
    zombie:setStaggerBack(true)
    local knockdownChance = target.distance <= WOOD_ROOTS_INNER_RADIUS and 65 or 35
    if ZombRand(1, 101) <= knockdownChance then
        zombie:setKnockedDown(true)
    end
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition("FRONT") end)
    pcall(function() zombie:setHitForce(2.0) end)
    pcall(function() zombie:reportEvent("wasHit") end)
    boundZombies[zombie] = getTimestampMs() + WOOD_ROOTS_BIND_MS
end

local function useBindingRoots(player)
    if not hasSenju(player) then
        player:Say("Senju lineage is required")
        return
    end

    local data = getNLData(player)
    local now = getTimestampSeconds()
    if data.bindingRootsCooldownUntil and now < data.bindingRootsCooldownUntil then
        player:Say("Binding Roots cooldown: " .. tostring(math.ceil(data.bindingRootsCooldownUntil - now)) .. "s")
        return
    end

    local stats = player:getStats()
    if not stats then return end
    local endurance = stats:get(CharacterStat.ENDURANCE)
    if endurance < WOOD_ROOTS_ENDURANCE_COST then
        player:Say("Too exhausted for Binding Roots")
        return
    end

    stats:set(CharacterStat.ENDURANCE, math.max(0, endurance - WOOD_ROOTS_ENDURANCE_COST))
    for _, target in ipairs(collectZombieTargets(player, WOOD_ROOTS_RADIUS)) do
        applyBindingRootsToZombie(player, target)
    end

    data.bindingRootsCooldownUntil = now + WOOD_ROOTS_COOLDOWN_SECONDS
    transmitPlayerData(player)
    player:Say("Mokuton")
end

local function reducePartTimer(bodypart, getter, setter, amount)
    local ok, value = pcall(function()
        if getter == "getBleedingTime" then return bodypart:getBleedingTime() end
        if getter == "getScratchTime" then return bodypart:getScratchTime() end
        if getter == "getCutTime" then return bodypart:getCutTime() end
        if getter == "getDeepWoundTime" then return bodypart:getDeepWoundTime() end
        if getter == "getBurnTime" then return bodypart:getBurnTime() end
        if getter == "getFractureTime" then return bodypart:getFractureTime() end
        return 0
    end)
    if not ok or not value or value <= 0 then return false end
    local nextValue = math.max(0, value - amount)
    pcall(function()
        if setter == "setBleedingTime" then bodypart:setBleedingTime(nextValue) end
        if setter == "setScratchTime" then bodypart:setScratchTime(nextValue) end
        if setter == "setCutTime" then bodypart:setCutTime(nextValue) end
        if setter == "setDeepWoundTime" then bodypart:setDeepWoundTime(nextValue) end
        if setter == "setBurnTime" then bodypart:setBurnTime(nextValue) end
        if setter == "setFractureTime" then bodypart:setFractureTime(nextValue) end
    end)
    return nextValue < value
end

local function restoreBodyPartHealth(bodyDamage, bodypart, amount)
    local changed = false
    local ok, health = pcall(function() return bodypart:getHealth() end)
    if ok and health and health < 100 then
        pcall(function() bodypart:setHealth(math.min(100, health + amount)) end)
        changed = true
    end
    if changed then
        pcall(function() bodyDamage:AddGeneralHealth(amount * 0.25) end)
    end
    return changed
end

local function healBodyPartForCreationRebirth(bodyDamage, bodypart)
    if not bodypart then return false end
    local changed = false

    changed = reducePartTimer(bodypart, "getBleedingTime", "setBleedingTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getScratchTime", "setScratchTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getCutTime", "setCutTime", 4.0) or changed
    changed = reducePartTimer(bodypart, "getDeepWoundTime", "setDeepWoundTime", 3.0) or changed
    changed = reducePartTimer(bodypart, "getBurnTime", "setBurnTime", 2.0) or changed
    changed = reducePartTimer(bodypart, "getFractureTime", "setFractureTime", 1.0) or changed
    if changed then
        pcall(function()
            if bodypart:getBleedingTime() <= 0 then
                bodypart:setBleeding(false)
            end
        end)
    end

    changed = restoreBodyPartHealth(bodyDamage, bodypart, 3.0) or changed
    return changed
end

local function stopCreationRebirth(player)
    creationRebirthState[player] = nil
end

local function updateCreationRebirth(player)
    local state = creationRebirthState[player]
    if not state then return end

    local nowMs = getTimestampMs()
    if nowMs >= state.endsAt then
        stopCreationRebirth(player)
        return
    end
    if nowMs < state.nextTickAt then return end
    state.nextTickAt = nowMs + CREATION_REBIRTH_TICK_MS

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if not stats or not bodyDamage then
        stopCreationRebirth(player)
        return
    end

    local parts = bodyDamage:getBodyParts()
    if not parts then return end
    local endurance = stats:get(CharacterStat.ENDURANCE)
    for i = 0, parts:size() - 1 do
        if endurance <= 0 then
            stats:set(CharacterStat.ENDURANCE, 0)
            stopCreationRebirth(player)
            return
        end

        local bodypart = parts:get(i)
        if bodypart and healBodyPartForCreationRebirth(bodyDamage, bodypart) then
            endurance = math.max(0, endurance - CREATION_REBIRTH_ENDURANCE_PER_PART)
            stats:set(CharacterStat.ENDURANCE, endurance)
        end
    end
end

local function useCreationRebirth(player)
    if not hasSenju(player) then
        player:Say("Senju lineage is required")
        return
    end
    local stats = player:getStats()
    if not stats or stats:get(CharacterStat.ENDURANCE) <= 0 then
        player:Say("Too exhausted for Creation Rebirth")
        return
    end
    local nowMs = getTimestampMs()
    creationRebirthState[player] = {
        endsAt = nowMs + CREATION_REBIRTH_DURATION_MS,
        nextTickAt = nowMs,
    }
    player:Say("Creation Rebirth")
end

local function getBodyPartSnapshot(player)
    local snapshot = {}
    local bodyDamage = player and player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return snapshot end
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        local health = 100
        local bleed = 0
        pcall(function() health = part:getHealth() end)
        pcall(function() bleed = part:getBleedingTime() end)
        snapshot[i] = { health = health, bleed = bleed }
    end
    return snapshot
end

local function captureUzumakiHealthState(player)
    local bodyDamage = player and player:getBodyDamage()
    if not bodyDamage then return end
    local data = uzumakiHealthState[player] or {}
    pcall(function() data.generalHealth = bodyDamage:getHealth() end)
    data.parts = getBodyPartSnapshot(player)
    data.lastPassiveAt = getTimestampMs()
    uzumakiHealthState[player] = data
end

local function refundUzumakiDamage(player)
    if not hasUzumaki(player) then return end
    local data = uzumakiHealthState[player]
    if not data then
        captureUzumakiHealthState(player)
        return
    end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not bodyDamage or not parts then return end

    local ok, currentGeneral = pcall(function() return bodyDamage:getHealth() end)
    if ok and data.generalHealth and currentGeneral and currentGeneral < data.generalHealth then
        pcall(function() bodyDamage:AddGeneralHealth((data.generalHealth - currentGeneral) * UZUMAKI_DAMAGE_REFUND) end)
    end

    for i = 0, parts:size() - 1 do
        local previous = data.parts and data.parts[i]
        local part = parts:get(i)
        if previous and part then
            local okHealth, currentHealth = pcall(function() return part:getHealth() end)
            if okHealth and currentHealth and currentHealth < previous.health then
                local refund = (previous.health - currentHealth) * UZUMAKI_DAMAGE_REFUND
                pcall(function() part:setHealth(math.min(100, currentHealth + refund)) end)
            end
        end
    end
    captureUzumakiHealthState(player)
end

local function applyUzumakiBleedSlow(player)
    if not hasUzumaki(player) then
        uzumakiHealthState[player] = nil
        return
    end

    local nowMs = getTimestampMs()
    local data = uzumakiHealthState[player]
    if not data then
        captureUzumakiHealthState(player)
        return
    end
    if data.lastPassiveAt and nowMs < data.lastPassiveAt + UZUMAKI_PASSIVE_TICK_MS then return end

    local bodyDamage = player:getBodyDamage()
    local parts = bodyDamage and bodyDamage:getBodyParts()
    if not parts then return end

    for i = 0, parts:size() - 1 do
        local previous = data.parts and data.parts[i]
        local part = parts:get(i)
        if previous and part then
            local okBleed, currentBleed = pcall(function() return part:getBleedingTime() end)
            if okBleed and currentBleed and currentBleed > 0 and previous.bleed and currentBleed < previous.bleed then
                local restored = currentBleed + ((previous.bleed - currentBleed) * UZUMAKI_BLEED_REFUND)
                pcall(function() part:setBleedingTime(restored) end)
            end
        end
    end
    captureUzumakiHealthState(player)
end

local function getActualInventoryItem(item)
    if not item then return nil end
    if item.items and item.items[1] then return item.items[1] end
    return item
end

local function getFirstInventoryItem(player, fullType)
    local inv = player and player:getInventory()
    if not inv then return nil end
    return inv:getItemFromType(fullType)
end

local function consumeInventoryItem(player, item)
    local inv = player and player:getInventory()
    if not inv or not item then return false end
    inv:Remove(item)
    pcall(function() sendRemoveItemFromContainer(inv, item) end)
    return true
end

local function getSquareKey(square)
    if not square then return nil end
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

local function registerAlarmSeal(square, player)
    if not square then return end
    local owner = ""
    pcall(function() owner = player and player:getUsername() or "" end)
    local modData = square:getModData()
    modData.NinjaLineages = modData.NinjaLineages or {}
    modData.NinjaLineages.alarmSeal = {
        owner = owner,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    }
    pcall(function() square:transmitModData() end)
    alarmSeals[getSquareKey(square)] = square
end

local function removeAlarmSeal(square)
    if not square then return end
    local modData = square:getModData()
    if modData.NinjaLineages then
        modData.NinjaLineages.alarmSeal = nil
    end
    pcall(function() square:transmitModData() end)
    alarmSeals[getSquareKey(square)] = nil
end

local function placeAlarmSeal(player, square)
    if not hasUzumaki(player) then
        player:Say("Uzumaki lineage is required")
        return
    end
    local seal = getFirstInventoryItem(player, "Base.NL_AlarmSeal")
    if not seal then
        player:Say("No Alarm Seal")
        return
    end
    if not square then square = player:getSquare() end
    registerAlarmSeal(square, player)
    consumeInventoryItem(player, seal)
    player:Say("Alarm Seal placed")
end

local function discoverAlarmSealsNearPlayer(player)
    if not player or not player:getSquare() then return end
    local cell = getCell()
    if not cell then return end
    local px = player:getX()
    local py = player:getY()
    local z = player:getZ()
    for x = math.floor(px - 25), math.floor(px + 25) do
        for y = math.floor(py - 25), math.floor(py + 25) do
            local square = cell:getGridSquare(x, y, z)
            local modData = square and square:getModData()
            if modData and modData.NinjaLineages and modData.NinjaLineages.alarmSeal then
                alarmSeals[getSquareKey(square)] = square
            end
        end
    end
end

local function triggerAlarmSeal(player, square)
    removeAlarmSeal(square)
    if player and not player:isDead() then
        player:Say("Alarm Seal triggered!")
    end
end

local function updateAlarmSeals(player)
    local nowMs = getTimestampMs()
    if nowMs >= nextAlarmDiscoveryAt then
        nextAlarmDiscoveryAt = nowMs + ALARM_SEAL_DISCOVERY_MS
        discoverAlarmSealsNearPlayer(player)
    end
    if nowMs < nextAlarmScanAt then return end
    nextAlarmScanAt = nowMs + ALARM_SEAL_SCAN_MS

    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    for key, square in pairs(alarmSeals) do
        if not square then
            alarmSeals[key] = nil
        else
            for i = 0, zombies:size() - 1 do
                local zombie = zombies:get(i)
                local dx = zombie and (zombie:getX() - (square:getX() + 0.5)) or 999
                local dy = zombie and (zombie:getY() - (square:getY() + 0.5)) or 999
                if zombie and not zombie:isDead() and ((dx * dx) + (dy * dy)) <= (ALARM_SEAL_RADIUS * ALARM_SEAL_RADIUS) then
                    triggerAlarmSeal(player, square)
                    break
                end
            end
        end
    end
end

local function isSealedScrollItem(item)
    local ok, fullType = pcall(function() return item and item:getFullType() end)
    return ok and fullType == "Base.NL_SealedScroll"
end

local function isBackpackContainer(item)
    if not item or isSealedScrollItem(item) then return false end
    local okContainer, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if not okContainer or not isContainer then return false end

    local okEquip, equipLocation = pcall(function() return item:canBeEquipped() end)
    if okEquip and equipLocation and tostring(equipLocation) ~= "" then return true end

    local okCategory, category = pcall(function() return item:getDisplayCategory() end)
    if okCategory and tostring(category) == "Bag" then return true end

    return false
end

local function getScrollInventory(scroll)
    local ok, inv = pcall(function() return scroll and scroll:getInventory() end)
    if ok then return inv end
    return nil
end

local function getContainedBackpack(scroll)
    local inv = getScrollInventory(scroll)
    if not inv or inv:getItems():size() == 0 then return nil end
    return inv:getItems():get(0)
end

local function moveItemBetweenContainers(item, srcContainer, destContainer)
    if not item or not destContainer then return false end
    if srcContainer then
        srcContainer:Remove(item)
        pcall(function() sendRemoveItemFromContainer(srcContainer, item) end)
    end
    destContainer:AddItem(item)
    pcall(function() sendAddItemToContainer(destContainer, item) end)
    pcall(function() destContainer:setDrawDirty(true) end)
    return true
end

local function sealBackpackInScroll(player, backpack, scroll)
    if not hasUzumaki(player) then
        player:Say("Uzumaki lineage is required")
        return
    end
    if not isBackpackContainer(backpack) then return end
    local scrollInv = getScrollInventory(scroll)
    if not scrollInv or scrollInv:getItems():size() > 0 then
        player:Say("Scroll already contains a seal")
        return
    end
    moveItemBetweenContainers(backpack, backpack:getContainer(), scrollInv)
    player:Say("Storage Seal")
end

NLUnsealScrollAction = ISBaseTimedAction and ISBaseTimedAction:derive("NLUnsealScrollAction") or {}

function NLUnsealScrollAction:isValid()
    return self.scroll and getContainedBackpack(self.scroll) ~= nil
end

function NLUnsealScrollAction:perform()
    local backpack = getContainedBackpack(self.scroll)
    if backpack then
        moveItemBetweenContainers(backpack, getScrollInventory(self.scroll), self.character:getInventory())
        self.character:Say("Unsealed")
    end
    if ISBaseTimedAction then
        ISBaseTimedAction.perform(self)
    end
end

function NLUnsealScrollAction:new(character, scroll)
    local o = ISBaseTimedAction and ISBaseTimedAction.new(self, character) or {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.scroll = scroll
    o.maxTime = character:isTimedActionInstant() and 1 or 80
    return o
end

local function unsealScroll(player, scroll)
    if not hasUzumaki(player) then
        player:Say("Uzumaki lineage is required")
        return
    end
    if ISTimedActionQueue and ISBaseTimedAction then
        ISTimedActionQueue.add(NLUnsealScrollAction:new(player, scroll))
    else
        local backpack = getContainedBackpack(scroll)
        if backpack then
            moveItemBetweenContainers(backpack, getScrollInventory(scroll), player:getInventory())
        end
    end
end

local function isSinglePlayerGame()
    if isClient and isClient() then return false end
    if isServer and isServer() then return false end
    return true
end

local function canUseKamuiTestUnlock(player)
    if not isSinglePlayerGame() then return false end
    if not hasSharingan(player) then return false end
    if getSharinganStage(player) < 3 then return false end
    return getNLData(player).mangekyoUnlocked ~= true
end

local function unlockKamuiForSinglePlayerTest(player)
    if not canUseKamuiTestUnlock(player) then
        player:Say("Third Tomoe is required")
        return
    end

    local data = getNLData(player)
    data.mangekyoUnlocked = true
    transmitPlayerData(player)
    updateSharinganMoodle(player)
    player:Say("Mangekyo Sharingan awakened")
end

local function unlockMangekyoIfEligible(victim)
    if not victim or not instanceof(victim, "IsoPlayer") then return end
    local attacker = victim:getAttackedBy()
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    if not attacker:isLocalPlayer() then return end
    if not hasSharingan(attacker) or getSharinganStage(attacker) < 3 then return end

    local data = getNLData(attacker)
    if data.mangekyoUnlocked then return end
    data.mangekyoUnlocked = true
    transmitPlayerData(attacker)
    attacker:Say("Mangekyo Sharingan awakened")
    updateSharinganMoodle(attacker)
end

local function sharinganEvade(zombie)
    if not zombie or zombie:isDead() then return end

    local attackOutcome = zombie:getVariableString("AttackOutcome")
    if attackOutcome ~= "success" then
        sharinganAttackRolls[zombie] = nil
        return
    end

    if sharinganAttackRolls[zombie] then return end

    local player = zombie:getTarget()
    if not player or not instanceof(player, "IsoPlayer") then return end
    if player:isDead() or player:isZombie() then return end
    if not player:isLocalPlayer() then return end

    if kamuiState[player] then
        sharinganAttackRolls[zombie] = true
        zombie:setVariable("AttackOutcome", "fail")
        return
    end

    local dodgeChance = getSharinganDodgeChance(player)
    if dodgeChance <= 0 then return end

    sharinganAttackRolls[zombie] = true
    if ZombRand(1, 101) <= dodgeChance then
        zombie:setVariable("AttackOutcome", "fail")
        player:setHitReaction("EvasiveBlocked")
        player:Say("Sharingan!")
    end
end

local function enforceBindingRoots(zombie)
    local bindUntil = boundZombies[zombie]
    if not bindUntil then return end
    if not zombie or zombie:isDead() or getTimestampMs() > bindUntil then
        boundZombies[zombie] = nil
        return
    end
    zombie:setVariable("AttackOutcome", "fail")
    pcall(function() zombie:setStaggerBack(true) end)
end

local function onZombieUpdate(zombie)
    enforceBindingRoots(zombie)
    sharinganEvade(zombie)
end

local function isBareHands(weapon)
    if not weapon then return false end
    local ok, weaponType = pcall(function() return weapon:getType() end)
    return ok and weaponType == "BareHands"
end

local function getAttackPosition(attacker, zombie)
    local ok, position = pcall(function() return zombie:testDotSide(attacker) end)
    if ok and position then return position end
    return "FRONT"
end

local function isZombieCharacter(zombie)
    local ok, result = pcall(function() return zombie:isZombie() end)
    if ok then return result == true end
    return instanceof(zombie, "IsoZombie")
end

local function byakuganPushHit(zombie, attacker, bodyPartType, handWeapon)
    if not zombie or not attacker or not handWeapon then return end
    if not instanceof(attacker, "IsoPlayer") then return end
    if not attacker:isLocalPlayer() then return end
    if not hasByakugan(attacker) then return end
    if not isBareHands(handWeapon) then return end
    if not isZombieCharacter(zombie) or zombie:isDead() then return end

    pcall(function() zombie:setHitFromBehind(attacker:isBehind(zombie)) end)
    pcall(function() zombie:setKnockedDown(true) end)
    pcall(function() zombie:setStaggerBack(true) end)
    pcall(function() zombie:setHitReaction("") end)
    pcall(function() zombie:setPlayerAttackPosition(getAttackPosition(attacker, zombie)) end)
    pcall(function() zombie:setHitForce(2.0) end)
    pcall(function() zombie:reportEvent("wasHit") end)

    applyZombieDamage(attacker, zombie, getRandomDamage(BYAKUGAN_PUSH_MIN_DAMAGE, BYAKUGAN_PUSH_MAX_DAMAGE))
end

local function getAvailableAbilities(player)
    local abilities = {}
    if canUseKamui(player) then
        table.insert(abilities, { id = "kamui", name = "Kamui", action = startKamui, texture = "media/ui/Traits/trait_sharingan.png" })
    end
    if hasRinnegan(player) then
        table.insert(abilities, { id = "shinra_tensei", name = "Shinra Tensei", action = useShinraTensei, texture = "media/ui/Traits/trait_rinnegan.png" })
    end
    if hasSenju(player) then
        table.insert(abilities, { id = "binding_roots", name = "Wood Release - Binding Roots", action = useBindingRoots, texture = "media/ui/Traits/trait_senju.png" })
        table.insert(abilities, { id = "creation_rebirth", name = "Creation Rebirth", action = useCreationRebirth, texture = "media/ui/Traits/trait_senju.png" })
    end
    return abilities
end

local function getSelectedAbility(player, abilities)
    local data = getNLData(player)
    for _, ability in ipairs(abilities) do
        if data.selectedAbilityId == ability.id then
            return ability
        end
    end
    local fallback = abilities[1]
    if fallback and data.selectedAbilityId ~= fallback.id then
        data.selectedAbilityId = fallback.id
        transmitPlayerData(player)
    end
    return fallback
end

local function selectAbility(player, ability)
    if not ability then return end
    local data = getNLData(player)
    data.selectedAbilityId = ability.id
    transmitPlayerData(player)
    player:Say(ability.name .. " selected")
end

local function useSelectedAbility(player)
    local abilities = getAvailableAbilities(player)
    if #abilities == 0 then
        player:Say("No ninja ability available")
        return
    end
    local ability = getSelectedAbility(player, abilities)
    if ability and ability.action then
        ability.action(player)
    end
end

local function addAbilityContextMenu(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    local abilities = getAvailableAbilities(player)
    local canTestUnlock = canUseKamuiTestUnlock(player)
    local alarmSeal = getFirstInventoryItem(player, "Base.NL_AlarmSeal")
    if #abilities == 0 and not canTestUnlock and not alarmSeal then return end
    if test then return true end

    local option = context:addOption("Ninja Lineages")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    if canTestUnlock then
        subMenu:addOption("Kamui Test: Unlock Mangekyo", player, unlockKamuiForSinglePlayerTest)
    end
    for _, ability in ipairs(abilities) do
        subMenu:addOption(ability.name, player, ability.action)
    end
    if alarmSeal then
        local square = player:getSquare()
        for _, worldObject in ipairs(worldObjects or {}) do
            if worldObject and worldObject.getSquare and worldObject:getSquare() then
                square = worldObject:getSquare()
                break
            end
        end
        subMenu:addOption("Place Alarm Seal", player, placeAlarmSeal, square)
    end
end

local function collectEmptyScrolls(player)
    local scrolls = {}
    local inv = player and player:getInventory()
    if not inv then return scrolls end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if isSealedScrollItem(item) then
            local scrollInv = getScrollInventory(item)
            if scrollInv and scrollInv:getItems():size() == 0 then
                table.insert(scrolls, item)
            end
        end
    end
    return scrolls
end

local function addStorageSealContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player or player:isDead() then return end
    if not hasUzumaki(player) then return end

    local selected = nil
    if items then
        selected = getActualInventoryItem(items[1])
    end
    if not selected then return end

    if isSealedScrollItem(selected) then
        if getContainedBackpack(selected) then
            context:addOption("Unseal Backpack", player, unsealScroll, selected)
        end
        return
    end

    if not isBackpackContainer(selected) then return end
    local scrolls = collectEmptyScrolls(player)
    if #scrolls == 0 then return end

    local option = context:addOption("Seal Backpack")
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, scroll in ipairs(scrolls) do
        subMenu:addOption(scroll:getName(), player, sealBackpackInScroll, selected, scroll)
    end
end

local function showAbilityRadial(player)
    local abilities = getAvailableAbilities(player)
    if #abilities < 2 then return false end

    local menu = getPlayerRadialMenu(player:getPlayerNum())
    menu:clear()
    if menu:isReallyVisible() then
        if menu.joyfocus then
            setJoypadFocus(player:getPlayerNum(), nil)
        end
        menu:undisplay()
        return true
    end

    menu:setX(getPlayerScreenLeft(player:getPlayerNum()) + getPlayerScreenWidth(player:getPlayerNum()) / 2 - menu:getWidth() / 2)
    menu:setY(getPlayerScreenTop(player:getPlayerNum()) + getPlayerScreenHeight(player:getPlayerNum()) / 2 - menu:getHeight() / 2)
    for _, ability in ipairs(abilities) do
        menu:addSlice(ability.name, getTexture(ability.texture), selectAbility, player, ability)
    end
    menu:addToUIManager()
    getSoundManager():playUISound("UIVehicleMenuOpen")
    menu.sounds.undisplay = "UIVehicleMenuClose"
    return true
end

local function onKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end

    if getCore():isKey("Ninja Ability", key) then
        useSelectedAbility(player)
        return
    end

    if getCore():isKey("Ninja Ability Radial", key) then
        showAbilityRadial(player)
    end
end

local function initKeybinds()
    table.insert(keyBinding, { value = "[Ninja Lineages]" })
    table.insert(keyBinding, { value = "Ninja Ability", key = Keyboard.KEY_NONE })
    table.insert(keyBinding, { value = "Ninja Ability Radial", key = Keyboard.KEY_NONE })
end

local function onPlayerUpdate(player)
    if not player then return end
    if not player:isLocalPlayer() then return end

    applyByakugan(player)
    applySenjuEndurance(player)
    applyUzumakiBleedSlow(player)
    updateSharinganMoodle(player)
    recoverKamuiVision(player)
    updateKamui(player)
    updateCreationRebirth(player)
    updateAlarmSeals(player)
end

local function onPlayerGetDamage(player, damageType, damage)
    if not player or not instanceof(player, "IsoPlayer") then return end
    if not player:isLocalPlayer() then return end
    refundUzumakiDamage(player)
end

Events.OnCreatePlayer.Add(function(playerIndex, player)
    if player then
        applyByakugan(player)
        applySenjuEndurance(player)
        captureUzumakiHealthState(player)
        recoverKamuiVision(player)
        updateSharinganMoodle(player)
    end
end)

Events.OnGameBoot.Add(initKeybinds)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnZombieUpdate.Add(onZombieUpdate)
Events.OnHitZombie.Add(byakuganPushHit)
Events.OnCharacterDeath.Add(unlockMangekyoIfEligible)
Events.OnFillWorldObjectContextMenu.Add(addAbilityContextMenu)
Events.OnFillInventoryObjectContextMenu.Add(addStorageSealContextMenu)
Events.OnKeyStartPressed.Add(onKeyStartPressed)
Events.OnPlayerGetDamage.Add(onPlayerGetDamage)
