NinjaLineages = NinjaLineages or {}
NinjaLineages.CorpseUtils = NinjaLineages.CorpseUtils or {}

local CorpseUtils = NinjaLineages.CorpseUtils

function CorpseUtils.getCorpseIdentifier(corpse)
    local x = corpse:getX()
    local y = corpse:getY()
    local z = corpse:getZ()
    local sq = corpse:getSquare()
    local index = -1
    if sq then
        local deadBodies = sq:getDeadBodys()
        if deadBodies then
            for i = 0, deadBodies:size() - 1 do
                if deadBodies:get(i) == corpse then
                    index = i
                    break
                end
            end
        end
    end
    local isZombie = instanceof(corpse, "IsoZombie")
    local zombieId = isZombie and corpse:getOnlineID() or nil
    return { x = x, y = y, z = z, index = index, zombieId = zombieId, isZombie = isZombie }
end

function CorpseUtils.getCorpseFromIdentifier(args)
    if not args then return nil end
    if args.isZombie and args.zombieId then
        local zombies = getCell() and getCell():getZombieList()
        if zombies then
            for i = 0, zombies:size() - 1 do
                local z = zombies:get(i)
                if z and z:getOnlineID() == args.zombieId then
                    return z
                end
            end
        end
        return nil
    end
    local sq = getCell():getGridSquare(args.x, args.y, args.z)
    if not sq then return nil end
    local deadBodies = sq:getDeadBodys()
    if deadBodies and args.index >= 0 and args.index < deadBodies:size() then
        return deadBodies:get(args.index)
    end
    return nil
end
