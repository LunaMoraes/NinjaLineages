require "NinjaLineages_Traits"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.EarthWall = NinjaLineages.EarthWall or {}

local EarthWall = NinjaLineages.EarthWall
local DATA_KEY = "NinjaLineagesEarthWalls"
local LOG_PREFIX = "[DEBUG-NL-EARTH-WALL] "
local HEALTH = 250
local DURATION_GAME_MINUTES = 12
local WEST_WALL_SPRITE = "fencing_01_35"
local NORTH_WALL_SPRITE = "fencing_01_33"

local function log(message)
    if SandboxVars
            and SandboxVars.NinjaLineages
            and SandboxVars.NinjaLineages.DebugMode == true then
        print(LOG_PREFIX .. message)
    end
end

local function records()
    return ModData.getOrCreate(DATA_KEY)
end

local function transmitRecords()
    if ModData.transmit then ModData.transmit(DATA_KEY) end
end

local function wallId(owner, x, y, z, north, createdAt)
    return table.concat({
        tostring(owner or ""),
        tostring(x),
        tostring(y),
        tostring(z),
        north and "N" or "W",
        string.format("%.6f", createdAt),
    }, ":")
end

local function getSpecialObjects(square)
    return square and square:getSpecialObjects() or nil
end

local function findWallOnSquare(square, id)
    local objects = getSpecialObjects(square)
    if not objects then return nil end
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        if object and object.hasModData and object:hasModData() then
            local data = object:getModData()
            if data.earthWall == true and (not id or data.earthWallId == id) then
                return object
            end
        end
    end
    return nil
end

local function facingPlacement(player)
    local square = player and player:getSquare()
    local forward = player and player:getForwardDirection()
    local cell = getCell()
    if not square or not forward or not cell then return nil end

    local dx, dy = forward:getX(), forward:getY()
    local stepX, stepY = 0, 0
    if math.abs(dx) >= math.abs(dy) then
        stepX = dx >= 0 and 1 or -1
    else
        stepY = dy >= 0 and 1 or -1
    end

    local targetSquare = cell:getGridSquare(
        square:getX() + stepX,
        square:getY() + stepY,
        square:getZ()
    )
    if not targetSquare then return nil end

    return {
        fromSquare = square,
        objectSquare = targetSquare,
        north = math.abs(stepY) > 0,
    }
end

function EarthWall.validatePlacement(player)
    local placement = facingPlacement(player)
    if not placement then return nil, "invalid_target" end
    local square = placement.objectSquare

    if not square:TreatAsSolidFloor()
            or not square:isFree(true)
            or square:isVehicleIntersecting()
            or square:getMovingObjects():size() > 0 then
        return nil, "blocked_placement"
    end

    local objects = getSpecialObjects(square)
    if objects then
        for index = 0, objects:size() - 1 do
            local object = objects:get(index)
            if object and object.hasModData and object:hasModData()
                    and object:getModData().earthWall == true then
                return nil, "blocked_placement"
            end
        end
    end
    return placement
end

function EarthWall.spawn(player, placement, duration)
    placement = placement or EarthWall.validatePlacement(player)
    if not placement then return nil end

    local square = placement.objectSquare
    local createdAt = NinjaLineages.Utils.Time.gameMinutes()
    local owner = player.getUsername and player:getUsername() or ""
    local id = wallId(
        owner,
        square:getX(),
        square:getY(),
        square:getZ(),
        placement.north,
        createdAt
    )
    local expiresAt = createdAt + (tonumber(duration) or DURATION_GAME_MINUTES)
    local sprite = placement.north and NORTH_WALL_SPRITE or WEST_WALL_SPRITE
    local wall = IsoThumpable.new(getCell(), square, sprite, placement.north, {})
    wall:setName("Doton: Doryuheki")
    wall:setCanBarricade(false)
    wall:setBlockAllTheSquare(true)
    wall:setCanPassThrough(false)
    wall:setIsHoppable(false)
    wall:setHoppable(false)
    wall:setIsThumpable(true)
    wall:setIsDismantable(false)
    wall:setMaxHealth(HEALTH)
    wall:setHealth(HEALTH)
    wall:setThumpDmg(1)
    wall:setBreakSound("BreakObject")

    local data = wall:getModData()
    data.earthWall = true
    data.earthWallId = id
    data.ownerPlayerId = owner
    data.abilityId = "earth_wall"
    data.createdAtGameMinutes = createdAt
    data.expiresAtGameMinutes = expiresAt

    square:AddSpecialObject(wall)
    square:RecalcAllWithNeighbours(true)
    wall:transmitCompleteItemToClients()

    records()[id] = {
        wallId = id,
        ownerPlayerId = owner,
        abilityId = "earth_wall",
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
        north = placement.north,
        createdAtGameMinutes = createdAt,
        expiresAtGameMinutes = expiresAt,
    }
    transmitRecords()
    log(string.format(
        "PLACED id=%s square=(%d,%d,%d) north=%s health=%d expiresAt=%.6f",
        id,
        square:getX(),
        square:getY(),
        square:getZ(),
        tostring(placement.north),
        HEALTH,
        expiresAt
    ))
    return wall
end

local function removeWall(record, reason)
    local cell = getCell()
    local square = cell and cell:getGridSquare(record.x, record.y, record.z) or nil
    if not square then return false end

    local wall = findWallOnSquare(square, record.wallId)
    if wall then
        square:transmitRemoveItemFromSquare(wall)
        square:RecalcAllWithNeighbours(true)
    end
    log(string.format(
        "REMOVED id=%s reason=%s found=%s",
        tostring(record.wallId),
        tostring(reason),
        tostring(wall ~= nil)
    ))
    return true
end

function EarthWall.update()
    if NinjaLineages.isClient() and not NinjaLineages.isServer() then return end
    local now = NinjaLineages.Utils.Time.gameMinutes()
    local changed = false

    for id, record in pairs(records()) do
        local cell = getCell()
        local square = cell and cell:getGridSquare(record.x, record.y, record.z) or nil
        if square then
            local wall = findWallOnSquare(square, id)
            if not wall then
                records()[id] = nil
                changed = true
                log("MISSING id=" .. tostring(id) .. " removing registry entry")
            elseif now >= (tonumber(record.expiresAtGameMinutes) or 0)
                    and removeWall(record, "expired") then
                records()[id] = nil
                changed = true
            end
        end
    end

    if changed then transmitRecords() end
end

function EarthWall.init()
    records()
    log("REGISTRY_READY")
end

function EarthWall.onDestroyIsoThumpable(object)
    if not object or not object.hasModData or not object:hasModData() then return end
    local data = object:getModData()
    if data.earthWall ~= true or not data.earthWallId then return end

    local registry = records()
    if registry[data.earthWallId] then
        registry[data.earthWallId] = nil
        transmitRecords()
    end
    log(string.format(
        "DESTROYED id=%s health=%s",
        tostring(data.earthWallId),
        tostring(object.getHealth and object:getHealth() or "unavailable")
    ))
end

if not NinjaLineages.isClient() and Events then
    if Events.OnInitGlobalModData then
        NinjaLineages.addEventOnce(
            "shared.earthWall.onInitGlobalModData",
            Events.OnInitGlobalModData,
            EarthWall.init
        )
    end
    if Events.OnDestroyIsoThumpable then
        NinjaLineages.addEventOnce(
            "shared.earthWall.onDestroyIsoThumpable",
            Events.OnDestroyIsoThumpable,
            EarthWall.onDestroyIsoThumpable
        )
    end
end
