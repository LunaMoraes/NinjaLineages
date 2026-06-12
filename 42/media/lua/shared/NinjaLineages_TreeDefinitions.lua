require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.TreeDefinitions = NinjaLineages.TreeDefinitions or {}

local Trees = NinjaLineages.TreeDefinitions

Trees.Disciplines = {
    genjutsu = {
        name = "UI_NL_Discipline_Genjutsu",
        description = "UI_NL_Discipline_Genjutsu_Desc",
        card = "media/ui/jutsuTree/cards/genjutsu.png",
    },
    ninjutsu = {
        name = "UI_NL_Discipline_Ninjutsu",
        description = "UI_NL_Discipline_Ninjutsu_Desc",
        card = "media/ui/jutsuTree/cards/ninjutsu.png",
    },
    taijutsu = {
        name = "UI_NL_Discipline_Taijutsu",
        description = "UI_NL_Discipline_Taijutsu_Desc",
        card = "media/ui/jutsuTree/cards/taijutsu.png",
    },
    kenjutsu = {
        name = "UI_NL_Discipline_Kenjutsu",
        description = "UI_NL_Discipline_Kenjutsu_Desc",
        card = "media/ui/jutsuTree/cards/kenjutsu.png",
    },
    medical = {
        name = "UI_NL_Discipline_Medical",
        description = "UI_NL_Discipline_Medical_Desc",
        card = "media/ui/jutsuTree/cards/medical.png",
    },
    fuinjutsu = {
        name = "UI_NL_Discipline_Fuinjutsu",
        description = "UI_NL_Discipline_Fuinjutsu_Desc",
        card = "media/ui/jutsuTree/cards/fuinjutsu.png",
    },
    chakra_transformation = {
        name = "UI_NL_Discipline_ChakraTransformation",
        description = "UI_NL_Discipline_ChakraTransformation_Desc",
        locked = true,
        card = "media/ui/jutsuTree/cards/chakra_transformation.png",
    },
}

local function node(id, discipline, tier, prerequisites, effectType)
    return {
        id = id,
        discipline = discipline,
        tier = tier,
        prerequisites = prerequisites or {},
        effectType = effectType or "ability",
        name = "UI_NL_Node_" .. id .. "_Name",
        description = "UI_NL_Node_" .. id .. "_Desc",
        icon = "media/ui/jutsuTree/nodes/" .. id .. ".png",
        trainingItem = "Base.NL_Training_" .. id,
    }
end

Trees.Nodes = {
    quiet_step = node("quiet_step", "genjutsu", "GENIN"),
    false_sound = node("false_sound", "genjutsu", "GENIN"),
    veil_presence = node("veil_presence", "genjutsu", "CHUNIN", { "quiet_step", "false_sound" }),
    killing_intent = node("killing_intent", "genjutsu", "JONIN", { "veil_presence" }),

    
    chakra_focus = node("chakra_focus", "ninjutsu", "GENIN"),
    chakra_grip = node("chakra_grip", "ninjutsu", "GENIN"),
    physical_reinforcement = node("physical_reinforcement", "ninjutsu", "GENIN"),
    
    chakra_burst = node("chakra_burst", "ninjutsu", "CHUNIN", { "physical_reinforcement", "chakra_grip" }),
    pressure_point_pulse = node("pressure_point_pulse", "ninjutsu", "CHUNIN", { "chakra_focus", "chakra_grip" }),
    shadow_close = node("shadow_close", "ninjutsu", "JONIN", { "chakra_burst", "pressure_point_pulse" }),

    body_flicker = node("body_flicker", "taijutsu", "GENIN"),
    strength_genin = node("strength_genin", "taijutsu", "GENIN", nil, "passive"),
    strength_chunin = node("strength_chunin", "taijutsu", "CHUNIN", { "strength_genin" }, "passive"),
    strength_jonin = node("strength_jonin", "taijutsu", "JONIN", { "strength_chunin" }, "passive"),
    fitness_genin = node("fitness_genin", "taijutsu", "GENIN", nil, "passive"),
    fitness_chunin = node("fitness_chunin", "taijutsu", "CHUNIN", { "fitness_genin" }, "passive"),
    fitness_jonin = node("fitness_jonin", "taijutsu", "JONIN", { "fitness_chunin" }, "passive"),
    combat_body_genin = node("combat_body_genin", "taijutsu", "GENIN", nil, "passive"),
    combat_body_chunin = node("combat_body_chunin", "taijutsu", "CHUNIN", { "combat_body_genin" }, "passive"),
    combat_body_jonin = node("combat_body_jonin", "taijutsu", "JONIN", { "combat_body_chunin" }, "passive"),

    blade_genin = node("blade_genin", "kenjutsu", "GENIN", nil, "passive"),
    blade_chunin = node("blade_chunin", "kenjutsu", "CHUNIN", { "blade_genin" }, "passive"),
    blade_jonin = node("blade_jonin", "kenjutsu", "JONIN", { "blade_chunin" }, "passive"),
    blunt_genin = node("blunt_genin", "kenjutsu", "GENIN", nil, "passive"),
    blunt_chunin = node("blunt_chunin", "kenjutsu", "CHUNIN", { "blunt_genin" }, "passive"),
    blunt_jonin = node("blunt_jonin", "kenjutsu", "JONIN", { "blunt_chunin" }, "passive"),
    polearm_genin = node("polearm_genin", "kenjutsu", "GENIN", nil, "passive"),
    polearm_chunin = node("polearm_chunin", "kenjutsu", "CHUNIN", { "polearm_genin" }, "passive"),
    polearm_jonin = node("polearm_jonin", "kenjutsu", "JONIN", { "polearm_chunin" }, "passive"),
    maintenance_genin = node("maintenance_genin", "kenjutsu", "GENIN", nil, "passive"),
    maintenance_chunin = node("maintenance_chunin", "kenjutsu", "CHUNIN", { "maintenance_genin" }, "passive"),
    maintenance_jonin = node("maintenance_jonin", "kenjutsu", "JONIN", { "maintenance_chunin" }, "passive"),

    minor_healing = node("minor_healing", "medical", "GENIN"),
    cell_stimulation = node("cell_stimulation", "medical", "GENIN"),
    chakra_needle = node("chakra_needle", "medical", "GENIN"),
    
    nervous_system_shock = node("nervous_system_shock", "medical", "CHUNIN", { "chakra_needle", "cell_stimulation" }),
    field_surgery = node("field_surgery", "medical", "CHUNIN", { "minor_healing", "cell_stimulation" }),
    bleeding_suppression = node("bleeding_suppression", "medical", "JONIN", { "nervous_system_shock", "field_surgery" }),

    alarm_seal = node("alarm_seal", "fuinjutsu", "GENIN", nil, "passive"),
    storage_seal = node("storage_seal", "fuinjutsu", "GENIN", nil, "passive"),
}

Trees.DisciplineOrder = {
    "genjutsu",
    "ninjutsu",
    "taijutsu",
    "kenjutsu",
    "medical",
    "fuinjutsu",
    "chakra_transformation",
}

function Trees.getNode(id)
    return Trees.Nodes[id]
end

function Trees.getNodesForDiscipline(disciplineId)
    local result = {}
    for _, definition in pairs(Trees.Nodes) do
        if definition.discipline == disciplineId then
            table.insert(result, definition)
        end
    end
    table.sort(result, function(a, b)
        if a.tier == b.tier then return a.id < b.id end
        local order = { GENIN = 1, CHUNIN = 2, JONIN = 3 }
        return order[a.tier] < order[b.tier]
    end)
    return result
end
