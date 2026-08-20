NinjaLineages = NinjaLineages or {}
NinjaLineages.BijuuDefinitions = NinjaLineages.BijuuDefinitions or {}

local Definitions = NinjaLineages.BijuuDefinitions

Definitions.Order = {
    "shukaku",
    "matatabi",
    "isobu",
    "son_goku",
    "kokuo",
    "saiken",
    "chomei",
    "gyuki",
    "kurama",
}

Definitions.ById = {
    shukaku = {
        id = "shukaku",
        tails = 1,
        nativeSpawnType = "host",
        nameKey = "UI_NL_Bijuu_Shukaku",
    },

    matatabi = {
        id = "matatabi",
        tails = 2,
        nativeSpawnType = "host",
        nameKey = "UI_NL_Bijuu_Matatabi",
    },

    isobu = {
        id = "isobu",
        tails = 3,
        nativeSpawnType = "host",
        nameKey = "UI_NL_Bijuu_Isobu",
    },

    son_goku = {
        id = "son_goku",
        tails = 4,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_SonGoku",
    },

    kokuo = {
        id = "kokuo",
        tails = 5,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_Kokuo",
    },

    saiken = {
        id = "saiken",
        tails = 6,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_Saiken",
    },

    chomei = {
        id = "chomei",
        tails = 7,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_Chomei",
    },

    gyuki = {
        id = "gyuki",
        tails = 8,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_Gyuki",
    },

    kurama = {
        id = "kurama",
        tails = 9,
        nativeSpawnType = "wild",
        nameKey = "UI_NL_Bijuu_Kurama",
    },
}

function Definitions.get(id)
    if not id then return nil end
    return Definitions.ById[id]
end

function Definitions.isValidId(id)
    if not id then return false end
    return Definitions.ById[id] ~= nil
end

function Definitions.getAll()
    return Definitions.ById
end

function Definitions.getOrder()
    return Definitions.Order
end
