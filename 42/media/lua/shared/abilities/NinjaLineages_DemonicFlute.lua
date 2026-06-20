require "NinjaLineages_Constants"
require "NinjaLineages_Utils"

NinjaLineages = NinjaLineages or {}
NinjaLineages.DemonicFlute = NinjaLineages.DemonicFlute or {}

local DemonicFlute = NinjaLineages.DemonicFlute
local slowedRecords = DemonicFlute.slowedRecords
    or setmetatable({}, { __mode = "k" })
DemonicFlute.slowedRecords = slowedRecords

local SLOW_FACTOR = 0.70 -- 70% slower

local function applyCoordinateSlow(character, record)
    local currentX = character:getX()
    local currentY = character:getY()
    local lastX = record.lastX
    local lastY = record.lastY
    
    if lastX and lastY and (currentX ~= lastX or currentY ~= lastY) then
        local dx = currentX - lastX
        local dy = currentY - lastY
        
        -- Ignore teleports or fence hopps (distance > 0.5 per tick is huge)
        if (dx*dx + dy*dy) < 0.25 then
            local newX = currentX - (dx * SLOW_FACTOR)
            local newY = currentY - (dy * SLOW_FACTOR)
            
            character:setX(newX)
            character:setY(newY)
            record.lastX = newX
            record.lastY = newY
            return
        end
    end
    
    record.lastX = currentX
    record.lastY = currentY
end

function DemonicFlute.apply(character, expiresAt)
    if not character or not expiresAt then return false end
    if character.isDead and character:isDead() then return false end

    local record = slowedRecords[character]
    if record then
        record.expiresAt = math.max(record.expiresAt or 0, expiresAt)
        return true
    end

    slowedRecords[character] = {
        expiresAt = expiresAt,
        lastX = character:getX(),
        lastY = character:getY()
    }
    
    if instanceof(character, "IsoZombie") then
        character:setVariable("Speed", 0.3)
        character:setVariable("WalkSpeed", 0.3)
        character:setVariable("RunSpeed", 0.3)
    end
    
    return true
end

function DemonicFlute.updatePlayer(player)
    if not player then return end
    local record = slowedRecords[player]
    if not record then return end

    if player:isDead() or NinjaLineages.Utils.Time.gameMinutes() >= record.expiresAt then
        DemonicFlute.clear(player)
        return
    end
    
    player:setVariable("Speed", 0.3)
    player:setVariable("WalkSpeed", 0.3)
    player:setVariable("RunSpeed", 0.3)
    player:setForceSprint(false)
    player:setForceRun(false)
    
    applyCoordinateSlow(player, record)
end

function DemonicFlute.updateZombies()
    local now = NinjaLineages.Utils.Time.gameMinutes()
    for character, record in pairs(slowedRecords) do
        if instanceof(character, "IsoZombie") then
            if not character or character:isDead() or now >= record.expiresAt then
                DemonicFlute.clear(character)
            else
                character:setVariable("Speed", 0.3)
                character:setVariable("WalkSpeed", 0.3)
                character:setVariable("RunSpeed", 0.3)
                
                applyCoordinateSlow(character, record)
            end
        end
    end
end

function DemonicFlute.clear(character)
    if not character then return end
    slowedRecords[character] = nil
    
    if instanceof(character, "IsoZombie") or instanceof(character, "IsoPlayer") then
        character:setVariable("Speed", 1.0)
        character:setVariable("WalkSpeed", 1.0)
        character:setVariable("RunSpeed", 1.0)
    end
end
