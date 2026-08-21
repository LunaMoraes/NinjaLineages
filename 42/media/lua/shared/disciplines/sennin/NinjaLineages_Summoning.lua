require "NinjaLineages_Traits"
require "NinjaLineages_Balance"
require "NinjaLineages_Constants"
require "NinjaLineages_Progression"
require "NinjaLineages_Chakra"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_Utils"
require "combat/NinjaLineages_Damage"
require "combat/NinjaLineages_Targeting"

NinjaLineages = NinjaLineages or {}
NinjaLineages.Summoning = NinjaLineages.Summoning or {}
NinjaLineages.AbilityExecution = NinjaLineages.AbilityExecution or {}
NinjaLineages.AbilityExecution.specializedExecutors = NinjaLineages.AbilityExecution.specializedExecutors or {}

local Summoning = NinjaLineages.Summoning
local Balance = NinjaLineages.Balance
local Authority = NinjaLineages.AbilityAuthority
local SummonBalance = Balance.Summoning

Summoning.activeSummons = Summoning.activeSummons or {}
Summoning.activeSummonIds = Summoning.activeSummonIds or {}
Summoning.activeSummonContracts = Summoning.activeSummonContracts or {}

function Summoning.isSummon(animal)
    if not animal then return false end
    if animal.getModData and animal:getModData().isNinjaSummon == true then
        return true
    end
    local animalId = animal.getAnimalID and animal:getAnimalID()
    if animalId and Summoning.activeSummonIds[animalId] then
        return true
    end
    return false
end

function Summoning.getSummonContract(animal)
    if not animal then return nil end
    if animal.getModData and animal:getModData().summonContract then
        return animal:getModData().summonContract
    end
    local animalId = animal.getAnimalID and animal:getAnimalID()
    if animalId and Summoning.activeSummonContracts[animalId] then
        return Summoning.activeSummonContracts[animalId]
    end
    if animalId then
        for _, summon in pairs(Summoning.activeSummons) do
            if summon.animalId == animalId then
                return summon.contract
            end
        end
    end
    return nil
end

function Summoning.getSummonDisplayName(animal)
    local contract = Summoning.getSummonContract(animal) or "toad"
    local fullKey = "UI_NL_Summon_" .. contract:gsub("^%l", string.upper) .. "_Full"
    local text = getText(fullKey)
    if text ~= fullKey then
        return text
    end
    local nameKey = "UI_NL_Summon_" .. contract:gsub("^%l", string.upper)
    return getText(nameKey)
end

local function getSummonKey(player)
    if not player then return "unknown" end
    if player.getOnlineID then
        local id = player:getOnlineID()
        if id and id >= 0 then return "online:" .. tostring(id) end
    end
    return tostring(player)
end

function Summoning.getAnimal(animalId)
    if not animalId then return nil end
    local cell = getCell()
    if not cell then return nil end
    local animals = cell:getAnimals()
    if animals then
        for i = 0, animals:size() - 1 do
            local a = animals:get(i)
            if a and a:getAnimalID() == animalId then
                return a
            end
        end
    end
    return nil
end

function Summoning.removeAnimal(animalOrId)
    local animal = type(animalOrId) == "number" and Summoning.getAnimal(animalOrId) or animalOrId
    local animalId = type(animalOrId) == "number" and animalOrId or (animal and animal.getAnimalID and animal:getAnimalID())
    if animalId then
        Summoning.activeSummonIds[animalId] = nil
        Summoning.activeSummonContracts[animalId] = nil
    end
    if animal and instanceof(animal, "IsoAnimal") then
        if animal.getModData then
            animal:getModData().isNinjaSummon = nil
            animal:getModData().summonContract = nil
            animal:getModData().summonName = nil
        end
        animal:removeFromWorld()
        animal:removeFromSquare()
        animal:setSquare(nil)
        pcall(function() animal:remove() end)
        return true
    end
    return false
end

function Summoning.hasActiveSummon(player)
    local key = getSummonKey(player)
    local summon = Summoning.activeSummons[key]
    return summon ~= nil
end

function Summoning.dismissSummon(player)
    local key = getSummonKey(player)
    local summon = Summoning.activeSummons[key]
    if summon then
        Summoning.activeSummons[key] = nil
        if player and not player:isDead() then
            player:Say(getText("UI_NL_Summon_Despawn"))
        end

        local actor = summon.actor or Summoning.getAnimal(summon.animalId)
        local posX = actor and actor:getX() or player:getX()
        local posY = actor and actor:getY() or player:getY()
        local posZ = actor and actor:getZ() or player:getZ()

        Summoning.removeAnimal(summon.animalId)

        local event = {
            kind = "summon_poof",
            animalId = summon.animalId,
            x = posX,
            y = posY,
            z = posZ,
            startedAtGameMinutes = NinjaLineages.Utils.Time.gameMinutes(),
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", event)
        elseif NinjaLineages.isClient() then
            sendClientCommand(player, "NinjaLineages", "summonPoofBroadcast", event)
        else
            if NinjaLineages.VFX and NinjaLineages.VFX.removeSummonMarker then
                NinjaLineages.VFX.removeSummonMarker(event)
            end
        end
    end
end

function Summoning.cast(player, definition, resolved, args)
    if not player or player:isDead() then return false, "dead" end
    if not NinjaLineages.Progression.isCompleted(player, "summoning") then
        return false, "node_not_completed"
    end

    local chosen = NinjaLineages.Progression.getChosenContract(player)
    if not chosen then
        player:Say(getText("UI_NL_Error_NoContractForSummon"))
        return false, "no_contract"
    end

    -- Dismiss previous summon if active
    if Summoning.hasActiveSummon(player) then
        Summoning.dismissSummon(player)
    end

    local cell = getCell()
    if not cell then return false, "no_cell" end
    local px, py, pz = player:getX(), player:getY(), player:getZ()

    local breed = AnimalDefinitions.getDef("rat"):getBreedByName("grey")
    local animal = addAnimal(cell, px, py, pz, "rat", breed)
    if not animal then
        return false, "spawn_failed"
    end

    animal:setWild(false)
    animal:setIsInvincible(true)
    animal:setInvisible(true)
    animal:setAlphaAndTarget(0.0)

    local summonNameKey = "UI_NL_Summon_" .. chosen:gsub("^%l", string.upper)
    local summonName = getText(summonNameKey)
    pcall(function() animal:setCustomName(summonName) end)

    if animal.getModData then
        animal:getModData().isNinjaSummon = true
        animal:getModData().summonContract = chosen
        animal:getModData().summonName = summonName
    end
    animal:addToWorld()

    local animalId = animal:getAnimalID()
    Summoning.activeSummonIds[animalId] = true
    Summoning.activeSummonContracts[animalId] = chosen
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local lifetime = SummonBalance.LIFETIME_GAME_MINUTES or 180
    local key = getSummonKey(player)

    Summoning.activeSummons[key] = {
        owner = player,
        animalId = animalId,
        actor = animal,
        contract = chosen,
        createdAtGameMinutes = now,
        expiresAtGameMinutes = now + lifetime,
        nextActionGameMinutes = now,
    }

    local summonNameKey = "UI_NL_Summon_" .. chosen:gsub("^%l", string.upper)
    player:Say(getText("UI_NL_Summon_Cast") .. " — " .. getText(summonNameKey))

    local event = {
        kind = "summon_spawn",
        animalId = animalId,
        contract = chosen,
        x = px,
        y = py,
        z = pz,
        startedAtGameMinutes = now,
    }
    if NinjaLineages.isServer() then
        sendServerCommand("NinjaLineages", "abilityEvent", event)
    elseif NinjaLineages.isClient() then
        sendClientCommand(player, "NinjaLineages", "summonSpawnBroadcast", event)
    else
        if NinjaLineages.VFX and NinjaLineages.VFX.addSummonMarker then
            NinjaLineages.VFX.addSummonMarker(event)
        end
    end

    return true
end

-- ============================================================================
-- Summon Companion AI Loop
-- ============================================================================

local function updateToadCompanion(summon, player, actor, now)
    local tuning = SummonBalance.Toad
    while now >= summon.nextActionGameMinutes do
        local targetRadius = Balance.getRadius(tuning.TARGET_RADIUS_TIER)
        local splashRadius = Balance.getRadius(tuning.SPLASH_RADIUS_TIER)
        local targets = NinjaLineages.Utils.Zombies.collectInRadius(actor, targetRadius)

        if #targets > 0 then
            local closest = targets[1].zombie
            local slamX, slamY = closest:getX(), closest:getY()
            local pz = math.floor(actor:getZ())

            local splash = NinjaLineages.Utils.Zombies.collectInRadius(closest, splashRadius)
            for _, entry in ipairs(splash) do
                local zed = entry.zombie
                NinjaLineages.Utils.Combat.staggerZombie(zed, { knockdown = true, position = "FRONT" })
                local dmg = Balance.rollDamage(tuning.DAMAGE_TIER)
                if NinjaLineages.CombatModifiers then
                    dmg = NinjaLineages.CombatModifiers.applyJutsuDamage(player, dmg)
                end
                NinjaLineages.Damage.applyZombieDamage(player, zed, dmg)
            end

            local event = {
                kind = "toad_slam",
                x = slamX,
                y = slamY,
                z = pz,
                radius = splashRadius,
                startedAtGameMinutes = now,
            }
            if NinjaLineages.isServer() then
                sendServerCommand("NinjaLineages", "abilityEvent", event)
            elseif NinjaLineages.isClient() then
                sendClientCommand(player, "NinjaLineages", "toadSlamBroadcast", event)
            else
                if NinjaLineages.VFX and NinjaLineages.VFX.addToadSlam then
                    NinjaLineages.VFX.addToadSlam(event)
                end
            end
        end

        summon.nextActionGameMinutes = summon.nextActionGameMinutes + tuning.ACTION_INTERVAL_GAME_MINUTES
    end
end

local function updateSnakeCompanion(summon, player, actor, now)
    local tuning = SummonBalance.Snake
    while now >= summon.nextActionGameMinutes do
        local targetRadius = Balance.getRadius(tuning.TARGET_RADIUS_TIER)
        local targets = NinjaLineages.Utils.Zombies.collectInRadius(actor, targetRadius)

        if #targets > 0 then
            local target = targets[1].zombie
            local tx, ty = target:getX(), target:getY()
            local originX, originY = actor:getX(), actor:getY()
            local pz = math.floor(actor:getZ())

            NinjaLineages.Utils.Combat.staggerZombie(target, { knockdown = false, position = "BEHIND" })
            local dmg = Balance.rollDamage(tuning.DAMAGE_TIER)
            if NinjaLineages.CombatModifiers then
                dmg = NinjaLineages.CombatModifiers.applyJutsuDamage(player, dmg)
            end
            NinjaLineages.Damage.applyZombieDamage(player, target, dmg)

            local event = {
                kind = "snake_strike",
                originX = originX,
                originY = originY,
                targetX = tx,
                targetY = ty,
                z = pz,
                startedAtGameMinutes = now,
            }
            if NinjaLineages.isServer() then
                sendServerCommand("NinjaLineages", "abilityEvent", event)
            elseif NinjaLineages.isClient() then
                sendClientCommand(player, "NinjaLineages", "snakeStrikeBroadcast", event)
            else
                if NinjaLineages.VFX and NinjaLineages.VFX.addSnakeStrike then
                    NinjaLineages.VFX.addSnakeStrike(event)
                end
            end
        end

        summon.nextActionGameMinutes = summon.nextActionGameMinutes + tuning.ACTION_INTERVAL_GAME_MINUTES
    end
end

local function updateSnailCompanion(summon, player, actor, now)
    local tuning = SummonBalance.Snail
    while now >= summon.nextActionGameMinutes do
        local healConfig = Balance.getHealing(tuning.HEALING_TIER)
        local healAmount = healConfig.health
        if NinjaLineages.CombatModifiers then
            healAmount = NinjaLineages.CombatModifiers.applyJutsuHealing(player, healAmount)
        end
        local radius = Balance.getRadius(tuning.RADIUS_TIER)
        local ax, ay, az = actor:getX(), actor:getY(), math.floor(actor:getZ())

        local bodyDamage = player:getBodyDamage()
        if bodyDamage and bodyDamage:getOverallBodyHealth() < 100 then
            local currentHealth = bodyDamage:getOverallBodyHealth()
            bodyDamage:setOverallBodyHealth(math.min(100, currentHealth + healAmount))

            local data = NinjaLineages.getNLData(player)
            if data and data.sageTrial then
                data.sageTrial.healthHealed = (data.sageTrial.healthHealed or 0) + healAmount
                NinjaLineages.transmitPlayerData(player)
                NinjaLineages.Progression.checkAndNotifySageTrial(player)
            end
        end

        -- Heal nearby players in radius around actor
        for _, entry in ipairs(NinjaLineages.Utils.Players.collectInRadius(player, radius)) do
            local otherPlayer = entry.player
            if otherPlayer and otherPlayer ~= player and not otherPlayer:isDead() then
                local otherBd = otherPlayer:getBodyDamage()
                if otherBd and otherBd:getOverallBodyHealth() < 100 then
                    local current = otherBd:getOverallBodyHealth()
                    otherBd:setOverallBodyHealth(math.min(100, current + healAmount))
                end
            end
        end

        local event = {
            kind = "katsuyu_heal_wave",
            x = ax,
            y = ay,
            z = az,
            radius = radius,
            startedAtGameMinutes = now,
        }
        if NinjaLineages.isServer() then
            sendServerCommand("NinjaLineages", "abilityEvent", event)
        elseif NinjaLineages.isClient() then
            sendClientCommand(player, "NinjaLineages", "katsuyuHealWaveBroadcast", event)
        else
            if NinjaLineages.VFX and NinjaLineages.VFX.addKatsuyuHealWave then
                NinjaLineages.VFX.addKatsuyuHealWave(event)
            end
        end

        summon.nextActionGameMinutes = summon.nextActionGameMinutes + tuning.ACTION_INTERVAL_GAME_MINUTES
    end
end

function Summoning.updateWorld()
    local now = NinjaLineages.Utils.Time.gameMinutes()

    for key, summon in pairs(Summoning.activeSummons) do
        local player = summon.owner
        local actor = summon.actor
        if not actor or not actor:isExistInTheWorld() then
            actor = Summoning.getAnimal(summon.animalId)
            summon.actor = actor
        end

        if not player or player:isDead() or not actor or now >= summon.expiresAtGameMinutes then
            Summoning.activeSummons[key] = nil
            if player and not player:isDead() then
                player:Say(getText("UI_NL_Summon_Expired"))
            end

            local posX = actor and actor:getX() or (player and player:getX() or 0)
            local posY = actor and actor:getY() or (player and player:getY() or 0)
            local posZ = actor and actor:getZ() or (player and player:getZ() or 0)

            Summoning.removeAnimal(summon.animalId)

            local event = {
                kind = "summon_poof",
                animalId = summon.animalId,
                x = posX,
                y = posY,
                z = posZ,
                startedAtGameMinutes = now,
            }
            if NinjaLineages.isServer() then
                sendServerCommand("NinjaLineages", "abilityEvent", event)
            elseif NinjaLineages.isClient() then
                sendClientCommand(player, "NinjaLineages", "summonPoofBroadcast", event)
            else
                if NinjaLineages.VFX and NinjaLineages.VFX.removeSummonMarker then
                    NinjaLineages.VFX.removeSummonMarker(event)
                end
            end
        else
            -- Navigation: Command animal to path toward owner
            if actor:DistTo(player) > 20 then
                actor:setX(player:getX())
                actor:setY(player:getY())
                actor:setZ(player:getZ())
            else
                pcall(function() actor:pathToCharacter(player) end)
            end

            if summon.contract == "toad" then
                updateToadCompanion(summon, player, actor, now)
            elseif summon.contract == "snake" then
                updateSnakeCompanion(summon, player, actor, now)
            elseif summon.contract == "snail" then
                updateSnailCompanion(summon, player, actor, now)
            end
        end
    end
end

-- Register Summoning update tick
NinjaLineages.addEventOnce("shared.summoning.update", Events.OnTick, function()
    Summoning.updateWorld()
end)

-- ============================================================================
-- Summon Interaction Interception (Allow Pet, Block Pick Up, Kill, Yields)
-- ============================================================================

local function hookSummonInteractions()
    if AnimalContextMenu and not AnimalContextMenu._nlSummonHooked then
        AnimalContextMenu._nlSummonHooked = true

        local originalDoMenu = AnimalContextMenu.doMenu
        AnimalContextMenu.doMenu = function(player, context, animal, test)
            if animal and Summoning.isSummon(animal) then
                -- Allow ONLY pet animal; suppress pick up, slaughter/kill, attach, shear, milk, etc.
                if animal:canBePet() then
                    local playerObj = getSpecificPlayer(player)
                    local text = Summoning.getSummonDisplayName(animal)
                    local animalOption = context:addOption(text, nil, nil)
                    animalOption.iconTexture = getTexture("media/ui/jutsuTree/nodes/sennin.png")
                    local animalSubMenu = ISContextMenu:getNew(context)
                    context:addSubMenu(animalOption, animalSubMenu)

                    local petOption = animalSubMenu:addOption(
                        getText("ContextMenu_PetAnimal"),
                        animal,
                        AnimalContextMenu.onPetAnimal,
                        playerObj
                    )
                    petOption.iconTexture = getTexture("media/ui/AnimalActions_Pet.png")
                end
                return
            end
            return originalDoMenu(player, context, animal, test)
        end

        local originalGetAnimal = AnimalContextMenu.getAnimalToInteractWith
        AnimalContextMenu.getAnimalToInteractWith = function(playerObj)
            local animal = originalGetAnimal(playerObj)
            if animal and Summoning.isSummon(animal) then
                return nil
            end
            return animal
        end

        local originalShowRadialMenu = AnimalContextMenu.showRadialMenu
        AnimalContextMenu.showRadialMenu = function(playerObj)
            local animal = originalGetAnimal(playerObj)
            if animal and Summoning.isSummon(animal) then
                local playerIndex = playerObj:getPlayerNum()
                local menu = getPlayerRadialMenu(playerIndex)
                if menu:isReallyVisible() then
                    if menu.joyfocus then setJoypadFocus(playerIndex, nil) end
                    menu:undisplay()
                    return
                end
                menu:clear()
                if animal:canBePet() then
                    menu:addSlice(
                        getText("ContextMenu_PetAnimal"),
                        getTexture("media/ui/AnimalActions_Pet.png"),
                        AnimalContextMenu.onPetAnimal,
                        animal,
                        playerObj
                    )
                end
                if menu:isEmpty() then return end
                menu:setX(getPlayerScreenLeft(playerIndex) + getPlayerScreenWidth(playerIndex) / 2 - menu:getWidth() / 2)
                menu:setY(getPlayerScreenTop(playerIndex) + getPlayerScreenHeight(playerIndex) / 2 - menu:getHeight() / 2)
                menu:addToUIManager()
                if getJoypadData(playerIndex) then
                    menu:setHideWhenButtonReleased(Joypad.DPadUp)
                    setJoypadFocus(playerIndex, menu)
                    playerObj:setJoypadIgnoreAimUntilCentered(true)
                end
                return
            end
            return originalShowRadialMenu(playerObj)
        end
    end

    if ISPickupAnimal and not ISPickupAnimal._nlSummonHooked then
        ISPickupAnimal._nlSummonHooked = true
        local originalPickupIsValid = ISPickupAnimal.isValid
        function ISPickupAnimal:isValid()
            if self.animal and Summoning.isSummon(self.animal) then
                return false
            end
            return originalPickupIsValid(self)
        end
    end

    if ISKillAnimal and not ISKillAnimal._nlSummonHooked then
        ISKillAnimal._nlSummonHooked = true
        local originalCanKill = ISKillAnimal.canKillAnimal
        function ISKillAnimal:canKillAnimal()
            if self.animal and Summoning.isSummon(self.animal) then
                return false
            end
            return originalCanKill(self)
        end
    end
end

hookSummonInteractions()
Events.OnGameStart.Add(hookSummonInteractions)

-- Network event registration for clients to track active summons
if Events and Events.OnServerCommand then
    NinjaLineages.AbilityAuthority.registerEventHandler("summon_spawn", function(args)
        if args and args.animalId then
            Summoning.activeSummonIds[args.animalId] = true
            if args.contract then
                Summoning.activeSummonContracts[args.animalId] = args.contract
            end
            local animal = Summoning.getAnimal(args.animalId)
            if animal and animal.getModData then
                animal:getModData().isNinjaSummon = true
                if args.contract then
                    animal:getModData().summonContract = args.contract
                    local summonNameKey = "UI_NL_Summon_" .. args.contract:gsub("^%l", string.upper)
                    local sName = getText(summonNameKey)
                    animal:getModData().summonName = sName
                    pcall(function() animal:setCustomName(sName) end)
                end
            end
        end
    end)

    NinjaLineages.AbilityAuthority.registerEventHandler("summon_poof", function(args)
        if args and args.animalId then
            Summoning.activeSummonIds[args.animalId] = nil
            Summoning.activeSummonContracts[args.animalId] = nil
        end
    end)
end

