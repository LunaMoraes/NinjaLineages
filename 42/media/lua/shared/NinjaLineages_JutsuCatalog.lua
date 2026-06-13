require "NinjaLineages_Balance"

NinjaLineages = NinjaLineages or {}
NinjaLineages.JutsuCatalog = NinjaLineages.JutsuCatalog or {}

local Catalog = NinjaLineages.JutsuCatalog
local Balance = NinjaLineages.Balance

Catalog.Disciplines = {
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
        card = "media/ui/jutsuTree/cards/chakra_transformation.png",
        locked = true,
    },
}

Catalog.DisciplineOrder = {
    "genjutsu",
    "ninjutsu",
    "taijutsu",
    "kenjutsu",
    "medical",
    "fuinjutsu",
    "chakra_transformation",
}

local function node(id, discipline, rank, order, prerequisites, effectType)
    return {
        id = id,
        selectable = false,
        category = "common",
        node = {
            id = id,
            discipline = discipline,
            rank = rank,
            order = order,
            prerequisites = prerequisites or {},
            effectType = effectType or "passive",
        },
    }
end

Catalog.Definitions = {
    {
        id = "quietstep",
        cooldownKey = "common.quiet_step",
        category = "common",
        node = { id = "quiet_step", discipline = "genjutsu", rank = "GENIN", order = 10 },
        presentation = {
            nameKey = "UI_NL_Ability_QuietStep_Name",
            descriptionKey = "UI_NL_Ability_QuietStep_Desc",
            castMessageKey = "UI_NL_Ability_QuietStep_Cast",
        },
        casting = { handSigns = { "rat", "snake", "hare" } },
        balance = { cost = "BASIC", cooldown = "STANDARD", duration = "STANDARD_MS" },
        effect = { kind = "timed_state", stateField = "quietStepEndTime", durationScale = true },
    },
    {
        id = "false_sound",
        category = "common",
        node = { id = "false_sound", discipline = "genjutsu", rank = "GENIN", order = 20 },
        casting = { handSigns = { "rat", "hare", "snake" } },
        balance = { cost = "BASIC", cooldown = "SHORT", radius = "LARGE" },
        effect = { kind = "world_sound", projected = true },
    },
    {
        id = "veil_presence",
        category = "common",
        node = {
            id = "veil_presence", discipline = "genjutsu", rank = "CHUNIN", order = 10,
            prerequisites = { "quiet_step", "false_sound" },
        },
        casting = { handSigns = { "snake", "rat", "tiger" } },
        balance = {
            cost = "STANDARD", cooldown = "LONG", radius = "STANDARD",
            duration = "LONG_MS", indoorBonusDuration = "STANDARD_MS",
        },
        effect = { kind = "sound_timed_state", stateField = "veilPresenceEndTime" },
    },
    {
        id = "killing_intent",
        category = "common",
        node = {
            id = "killing_intent", discipline = "genjutsu", rank = "JONIN", order = 10,
            prerequisites = { "veil_presence" },
        },
        casting = { handSigns = { "tiger", "dragon", "tiger" } },
        balance = { cost = "MAJOR", cooldown = "VERY_LONG", radius = "STANDARD", control = "CHUNIN" },
        effect = { kind = "area_control" },
    },
    {
        id = "focus",
        cooldownKey = "common.chakra_focus",
        category = "common",
        node = { id = "chakra_focus", discipline = "ninjutsu", rank = "GENIN", order = 10 },
        presentation = {
            nameKey = "UI_NL_Ability_ChakraFocus_Name",
            descriptionKey = "UI_NL_Ability_ChakraFocus_Desc",
            castMessageKey = "UI_NL_Ability_ChakraFocus_Cast",
        },
        casting = { handSigns = { "ram", "dragon", "tiger" } },
        balance = { cost = "BASIC", cooldown = "STANDARD", mastery = "JONIN" },
        effect = { kind = "restore_focus" },
    },
    {
        id = "grip",
        cooldownKey = "common.chakra_grip",
        category = "common",
        node = { id = "chakra_grip", discipline = "ninjutsu", rank = "GENIN", order = 20 },
        presentation = {
            nameKey = "UI_NL_Ability_ChakraGrip_Name",
            descriptionKey = "UI_NL_Ability_ChakraGrip_Desc",
            castMessageKey = "UI_NL_Ability_ChakraGrip_Cast",
        },
        casting = { handSigns = { "dog", "ox", "horse" } },
        balance = { cost = "BASIC", cooldown = "SHORT", duration = "STANDARD_MS" },
        effect = { kind = "timed_state", stateField = "chakraGripEndTime", durationScale = true },
    },
    {
        id = "reinforcement",
        cooldownKey = "common.reinforcement",
        category = "common",
        node = { id = "physical_reinforcement", discipline = "ninjutsu", rank = "GENIN", order = 30 },
        presentation = {
            nameKey = "UI_NL_Ability_PhysicalReinforcement_Name",
            descriptionKey = "UI_NL_Ability_PhysicalReinforcement_Desc",
            castMessageKey = "UI_NL_Ability_PhysicalReinforcement_Cast",
        },
        casting = { handSigns = { "tiger", "horse", "ox" } },
        balance = { cost = "STANDARD", cooldown = "LONG", duration = "STANDARD_MS", recovery = "GENIN" },
        effect = { kind = "timed_state", stateField = "reinforcementEndTime", durationScale = true },
    },
    {
        id = "chakra_burst",
        category = "common",
        node = {
            id = "chakra_burst", discipline = "ninjutsu", rank = "CHUNIN", order = 10,
            prerequisites = { "physical_reinforcement", "chakra_grip" },
        },
        casting = { handSigns = { "ox", "tiger", "ram" } },
        balance = {
            cost = "ADVANCED", cooldown = "LONG", targeting = "NARROW",
            damage = "MODERATE", control = "JONIN",
        },
        effect = { kind = "target_damage" },
    },
    {
        id = "pressure_point_pulse",
        category = "common",
        node = {
            id = "pressure_point_pulse", discipline = "ninjutsu", rank = "CHUNIN", order = 20,
            prerequisites = { "chakra_focus", "chakra_grip" },
        },
        casting = { handSigns = { "ram", "ox", "snake" } },
        balance = {
            cost = "ADVANCED", cooldown = "LONG", targeting = "SMALL_CLUSTER",
            damage = "LIGHT", control = "CHUNIN",
        },
        effect = { kind = "cluster_damage" },
    },
    {
        id = "shadow_close",
        category = "common",
        node = {
            id = "shadow_close", discipline = "ninjutsu", rank = "JONIN", order = 10,
            prerequisites = { "chakra_burst", "pressure_point_pulse" },
        },
        casting = { handSigns = { "bird", "rat", "tiger" } },
        balance = {
            cost = "MAJOR", cooldown = "VERY_LONG", targeting = "STANDARD",
            distance = "STANDARD", decoyRadius = "STANDARD", control = "GENIN",
        },
        effect = { kind = "shadow_close" },
    },
    {
        id = "bodyflicker",
        cooldownKey = "common.body_flicker",
        category = "common",
        node = { id = "body_flicker", discipline = "taijutsu", rank = "GENIN", order = 10 },
        presentation = {
            nameKey = "UI_NL_Ability_Dash_Name",
            descriptionKey = "UI_NL_Ability_Dash_Desc",
            castMessageKey = "UI_NL_Ability_Dash_Cast",
        },
        casting = { handSigns = { "bird", "hare", "rat" } },
        balance = { cost = "ADVANCED", cooldown = "DASH", distance = "TOUCH", duration = "BURST_MS" },
        effect = { kind = "forward_movement" },
    },

    node("strength_genin", "taijutsu", "GENIN", 20),
    node("strength_chunin", "taijutsu", "CHUNIN", 10, { "strength_genin" }),
    node("strength_jonin", "taijutsu", "JONIN", 10, { "strength_chunin" }),
    node("fitness_genin", "taijutsu", "GENIN", 30),
    node("fitness_chunin", "taijutsu", "CHUNIN", 20, { "fitness_genin" }),
    node("fitness_jonin", "taijutsu", "JONIN", 20, { "fitness_chunin" }),
    node("combat_body_genin", "taijutsu", "GENIN", 40),
    node("combat_body_chunin", "taijutsu", "CHUNIN", 30, { "combat_body_genin" }),
    node("combat_body_jonin", "taijutsu", "JONIN", 30, { "combat_body_chunin" }),

    node("blade_genin", "kenjutsu", "GENIN", 10),
    node("blade_chunin", "kenjutsu", "CHUNIN", 10, { "blade_genin" }),
    node("blade_jonin", "kenjutsu", "JONIN", 10, { "blade_chunin" }),
    node("blunt_genin", "kenjutsu", "GENIN", 20),
    node("blunt_chunin", "kenjutsu", "CHUNIN", 20, { "blunt_genin" }),
    node("blunt_jonin", "kenjutsu", "JONIN", 20, { "blunt_chunin" }),
    node("polearm_genin", "kenjutsu", "GENIN", 30),
    node("polearm_chunin", "kenjutsu", "CHUNIN", 30, { "polearm_genin" }),
    node("polearm_jonin", "kenjutsu", "JONIN", 30, { "polearm_chunin" }),
    node("maintenance_genin", "kenjutsu", "GENIN", 40),
    node("maintenance_chunin", "kenjutsu", "CHUNIN", 40, { "maintenance_genin" }),
    node("maintenance_jonin", "kenjutsu", "JONIN", 40, { "maintenance_chunin" }),

    {
        id = "healing",
        cooldownKey = "common.healing",
        category = "common",
        node = { id = "minor_healing", discipline = "medical", rank = "GENIN", order = 10 },
        presentation = {
            nameKey = "UI_NL_Ability_Healing_Name",
            descriptionKey = "UI_NL_Ability_Healing_Desc",
            castMessageKey = "UI_NL_Ability_Healing_Cast",
        },
        casting = { handSigns = { "boar", "ram", "snake" } },
        balance = { cost = "STANDARD", cooldown = "STANDARD", healing = "LIGHT" },
        effect = { kind = "heal_most_damaged", fields = { "health", "scratch", "cut" } },
    },
    {
        id = "cell_stimulation",
        category = "common",
        node = { id = "cell_stimulation", discipline = "medical", rank = "GENIN", order = 20 },
        casting = { handSigns = { "boar", "ram", "tiger" } },
        balance = { cost = "STANDARD", cooldown = "LONG", healing = "MODERATE", duration = "LONG_MS" },
        effect = { kind = "cell_stimulation" },
    },
    {
        id = "chakra_needle",
        category = "common",
        node = { id = "chakra_needle", discipline = "medical", rank = "GENIN", order = 30 },
        casting = { handSigns = { "snake", "ram", "bird" } },
        balance = {
            cost = "STANDARD", cooldown = "SHORT", targeting = "NARROW",
            damage = "LIGHT", control = "GENIN",
        },
        effect = { kind = "target_damage" },
    },
    {
        id = "nervous_system_shock",
        category = "common",
        node = {
            id = "nervous_system_shock", discipline = "medical", rank = "CHUNIN", order = 10,
            prerequisites = { "chakra_needle", "cell_stimulation" },
        },
        casting = { handSigns = { "snake", "dragon", "ram" } },
        balance = {
            cost = "ADVANCED", cooldown = "LONG", targeting = "NARROW",
            damage = "LIGHT", control = "JONIN",
        },
        effect = { kind = "target_damage" },
    },
    {
        id = "field_surgery",
        category = "common",
        node = {
            id = "field_surgery", discipline = "medical", rank = "CHUNIN", order = 20,
            prerequisites = { "minor_healing", "cell_stimulation" },
        },
        casting = { handSigns = { "boar", "snake", "ram" } },
        balance = { cost = "MAJOR", cooldown = "VERY_LONG", healing = "DEVASTATING" },
        effect = {
            kind = "heal_most_damaged",
            fields = { "health", "bleeding", "scratch", "cut", "deepWound", "burn", "fracture" },
        },
    },
    {
        id = "bleeding_suppression",
        category = "common",
        node = {
            id = "bleeding_suppression", discipline = "medical", rank = "JONIN", order = 10,
            prerequisites = { "nervous_system_shock", "field_surgery" },
        },
        casting = { handSigns = { "ram", "boar", "dragon" } },
        balance = { cost = "MAJOR", cooldown = "VERY_LONG", healing = "HEAVY", duration = "VERY_LONG_MS" },
        effect = { kind = "timed_state", stateField = "bleedingSuppressionEndTime" },
    },

    node("alarm_seal", "fuinjutsu", "GENIN", 10, nil, "passive"),
    node("storage_seal", "fuinjutsu", "GENIN", 20, nil, "passive"),

    {
        id = "sharingan",
        category = "uchiha",
        presentation = {
            nameKey = "UI_NL_Ability_Sharingan_Name",
            descriptionKey = "UI_NL_Ability_Sharingan_Desc",
            castMessageKey = "UI_NL_Ability_Sharingan_Cast",
            icon = "media/ui/Traits/trait_sharingan.png",
        },
        casting = { sealFree = true },
        requirements = { { kind = "lineage", id = "uchiha" } },
        balance = {
            drainByStage = { value = { [1] = 8.5, [2] = 12.0, [3] = 16.3 } },
            mangekyoDrain = { value = 16.3 },
        },
        executor = "sharingan",
    },
    {
        id = "kamui",
        category = "uchiha",
        presentation = {
            nameKey = "UI_NL_Ability_Kamui_Name",
            descriptionKey = "UI_NL_Ability_Kamui_Desc",
            castMessageKey = "UI_NL_Ability_Kamui_Cast",
            icon = "media/ui/Traits/trait_sharingan.png",
        },
        casting = { sealFree = true },
        requirements = {
            { kind = "lineage", id = "uchiha" },
            { kind = "special", id = "mangekyo_unlocked" },
        },
        balance = {
            cost = "FREE", cooldown = "STANDARD", channelDrain = "HIGH",
            duration = { tier = "SHORT_MS", value = 10000 },
            minimumChakra = { value = 20 },
        },
        executor = "kamui",
    },
    {
        id = "byakugan",
        category = "hyuga",
        presentation = {
            nameKey = "UI_NL_Ability_Byakugan_Name",
            descriptionKey = "UI_NL_Ability_Byakugan_Desc",
            castMessageKey = "UI_NL_Ability_Byakugan_Cast",
            icon = "media/ui/Traits/trait_byakugan.png",
        },
        casting = { sealFree = true },
        requirements = { { kind = "lineage", id = "hyuga" } },
        balance = { sustainedDrain = { value = 12.0 } },
        executor = "byakugan",
    },
    {
        id = "binding_roots",
        category = "senju",
        presentation = {
            nameKey = "UI_NL_Ability_BindingRoots_Name",
            descriptionKey = "UI_NL_Ability_BindingRoots_Desc",
            castMessageKey = "UI_NL_Ability_BindingRoots_Cast",
            icon = "media/ui/Traits/trait_senju.png",
        },
        casting = { sealFree = true },
        requirements = { { kind = "lineage", id = "senju" } },
        balance = {
            cost = "MAJOR", cooldown = "STANDARD", radius = "LARGE", duration = "BRIEF_MS",
            innerRadius = { value = 6.0 },
            innerKnockdownChance = { value = 65 },
            outerKnockdownChance = { value = 35 },
        },
        executor = "binding_roots",
    },
    {
        id = "creation_rebirth",
        category = "senju",
        presentation = {
            nameKey = "UI_NL_Ability_CreationRebirth_Name",
            descriptionKey = "UI_NL_Ability_CreationRebirth_Desc",
            castMessageKey = "UI_NL_Ability_CreationRebirth_Cast",
            icon = "media/ui/Traits/trait_senju.png",
        },
        casting = { sealFree = true },
        requirements = {
            { kind = "lineage", id = "senju" },
            { kind = "special", id = "creation_rebirth_unlocked" },
        },
        balance = {
            costStep = "HARSH",
            duration = "SHORT_MS",
            tickInterval = { value = 250 },
            healingTick = {
                value = {
                    health = 3, bleeding = 4, scratch = 4, cut = 4,
                    deepWound = 3, burn = 2, fracture = 1,
                },
            },
        },
        executor = "creation_rebirth",
    },
    {
        id = "shinra_tensei",
        category = "rinnegan",
        presentation = {
            nameKey = "UI_NL_Ability_ShinraTensei_Name",
            descriptionKey = "UI_NL_Ability_ShinraTensei_Desc",
            castMessageKey = "UI_NL_Ability_ShinraTensei_Cast",
            icon = "media/ui/Traits/trait_rinnegan.png",
        },
        casting = { sealFree = true },
        requirements = { { kind = "lineage", id = "rinnegan" } },
        balance = {
            cost = "MAJOR", costStep = "SMALL", maximumCost = "ULTIMATE",
            cooldown = "STANDARD", radius = "STANDARD", damage = "HEAVY",
            guaranteedKnockdownRadius = { value = 3.5 },
        },
        executor = "shinra_tensei",
    },
}

local rankOrder = { GENIN = 1, CHUNIN = 2, JONIN = 3 }
local handSigns = {
    monkey = true, dragon = true, rat = true, bird = true, snake = true, ox = true,
    dog = true, horse = true, tiger = true, boar = true, ram = true, hare = true,
}
local genericEffects = {
    timed_state = true,
    world_sound = true,
    sound_timed_state = true,
    area_control = true,
    restore_focus = true,
    target_damage = true,
    cluster_damage = true,
    shadow_close = true,
    forward_movement = true,
    heal_most_damaged = true,
    cell_stimulation = true,
}
local specializedExecutors = {
    sharingan = true,
    byakugan = true,
    kamui = true,
    binding_roots = true,
    creation_rebirth = true,
    shinra_tensei = true,
}
local specialRequirements = {
    mangekyo_unlocked = true,
    creation_rebirth_unlocked = true,
}
local lineageRequirements = {
    uchiha = true,
    hyuga = true,
    senju = true,
    rinnegan = true,
    uzumaki = true,
}
local balanceSchemas = {
    cost = { tiers = "ChakraCostTier", resolver = "getCost" },
    maximumCost = { tiers = "ChakraCostTier", resolver = "getCost" },
    costStep = { tiers = "ChakraCostStepTier", resolver = "getCostStep" },
    cooldown = { tiers = "CooldownTier", resolver = "getCooldown" },
    duration = { tiers = "DurationTier", resolver = "getDuration" },
    indoorBonusDuration = { tiers = "DurationTier", resolver = "getDuration" },
    radius = { tiers = "RadiusTier", resolver = "getRadius" },
    distance = { tiers = "RadiusTier", resolver = "getRadius" },
    decoyRadius = { tiers = "RadiusTier", resolver = "getRadius" },
    sustainedDrain = { tiers = "SustainedDrainTier", resolver = "getSustainedDrain" },
    channelDrain = { tiers = "ChannelDrainTier", resolver = "getChannelDrain" },
    targeting = { tiers = "TargetingTier", resolver = "getTargeting" },
    healing = { tiers = "HealingTier", resolver = "getHealing" },
    mastery = { tiers = "MasteryTier", resolver = "getMastery" },
    recovery = { tiers = "MasteryTier", resolver = "getMastery" },
}
local explicitBalanceFields = {
    minimumChakra = true,
    drainByStage = true,
    mangekyoDrain = true,
    innerRadius = true,
    innerKnockdownChance = true,
    outerKnockdownChance = true,
    tickInterval = true,
    healingTick = true,
    guaranteedKnockdownRadius = true,
}

Catalog.ById = {}
Catalog.ByNodeId = {}

local function presentation(definition)
    local value = definition.presentation or {}
    local sourceId = definition.node and definition.node.id or definition.id
    return {
        nameKey = value.nameKey or ("UI_NL_Node_" .. sourceId .. "_Name"),
        descriptionKey = value.descriptionKey or ("UI_NL_Node_" .. sourceId .. "_Desc"),
        nameFallback = value.nameFallback or definition.id,
        descriptionFallback = value.descriptionFallback or "",
        icon = value.icon or (definition.node
            and ("media/ui/jutsuTree/nodes/" .. definition.node.id .. ".png")
            or "media/ui/NLJutsu.png"),
    }
end

local function resolveValue(key, reference)
    if reference == nil then return nil end
    if type(reference) == "table" and reference.value ~= nil then return reference.value end
    local tier = type(reference) == "table" and reference.tier or reference
    if key == "damage" then
        local minimum, maximum = Balance.getDamageRange(tier)
        return { tier = tier, min = minimum, max = maximum }
    end
    if key == "control" then
        return { tier = tier, value = Balance.getMastery(tier) }
    end
    if explicitBalanceFields[key] then return tier end
    local schema = balanceSchemas[key]
    return schema and Balance[schema.resolver](tier) or tier
end

function Catalog.get(id)
    return Catalog.ById[id]
end

function Catalog.getByNodeId(nodeId)
    return Catalog.ByNodeId[nodeId]
end

function Catalog.getAll()
    return Catalog.Definitions
end

function Catalog.getSelectable()
    local result = {}
    for _, definition in ipairs(Catalog.Definitions) do
        if definition.selectable ~= false then table.insert(result, definition) end
    end
    return result
end

function Catalog.getNodesForDiscipline(disciplineId)
    local result = {}
    for _, definition in ipairs(Catalog.Definitions) do
        if definition.node and definition.node.discipline == disciplineId then
            table.insert(result, definition)
        end
    end
    table.sort(result, function(a, b)
        if a.node.rank ~= b.node.rank then
            return rankOrder[a.node.rank] < rankOrder[b.node.rank]
        end
        if (a.node.order or 0) ~= (b.node.order or 0) then
            return (a.node.order or 0) < (b.node.order or 0)
        end
        return a.node.id < b.node.id
    end)
    return result
end

function Catalog.resolveBalance(id)
    local definition = type(id) == "table" and id or Catalog.get(id)
    if not definition then return nil end
    local resolved = {}
    for key, reference in pairs(definition.balance or {}) do
        resolved[key] = resolveValue(key, reference)
    end
    return resolved
end

local function checkLineage(player, id)
    local checks = {
        uchiha = NinjaLineages.hasSharingan,
        hyuga = NinjaLineages.hasByakugan,
        senju = NinjaLineages.hasSenju,
        rinnegan = NinjaLineages.hasRinnegan,
        uzumaki = NinjaLineages.hasUzumaki,
    }
    return checks[id] and checks[id](player) == true
end

function Catalog.checkRequirements(player, definition)
    definition = type(definition) == "table" and definition or Catalog.get(definition)
    if not player or not definition then return false, "invalid_player" end
    if definition.node
            and NinjaLineages.Progression
            and not NinjaLineages.Progression.isCompleted(player, definition.node.id) then
        return false, "not_learned"
    end
    for _, requirement in ipairs(definition.requirements or {}) do
        if requirement.kind == "lineage" and not checkLineage(player, requirement.id) then
            return false, "lineage"
        elseif requirement.kind == "special" then
            if requirement.id == "mangekyo_unlocked"
                    and not NinjaLineages.getNLData(player).mangekyoUnlocked then
                return false, "locked"
            elseif requirement.id == "creation_rebirth_unlocked"
                    and (not NinjaLineages.CreationRebirth
                        or not NinjaLineages.CreationRebirth.isUnlocked(player)) then
                return false, "locked"
            end
        end
    end
    return true
end

function Catalog.isAvailable(player, definition)
    local ok = Catalog.checkRequirements(player, definition)
    return ok == true
end

function Catalog.toAbility(definition)
    local view = presentation(definition)
    local casting = definition.casting or {}
    local balance = definition.balance or {}
    return {
        id = definition.id,
        lineage = definition.category,
        nodeId = definition.node and definition.node.id or nil,
        name = view.nameKey,
        nameFallback = view.nameFallback,
        descriptionKey = view.descriptionKey,
        descriptionFallback = view.descriptionFallback,
        texture = view.icon,
        fallbackTexture = "media/ui/NLJutsu.png",
        handSigns = casting.handSigns,
        sealFree = casting.sealFree == true or definition.category ~= "common",
        costTier = type(balance.cost) == "table" and balance.cost.tier or balance.cost,
        cooldownTier = type(balance.cooldown) == "table" and balance.cooldown.tier or balance.cooldown,
        condition = function(player) return Catalog.isAvailable(player, definition) end,
        action = function(player)
            return NinjaLineages.AbilityAuthority.request(player, definition.id, {})
        end,
    }
end

function Catalog.registerSelectableAbilities()
    for _, definition in ipairs(Catalog.getSelectable()) do
        NinjaLineages.registerAbility(Catalog.toAbility(definition))
    end
end

local function validateBalance(definition)
    for key, reference in pairs(definition.balance or {}) do
        local schema = balanceSchemas[key]
        if key ~= "damage" and key ~= "control" and not explicitBalanceFields[key] and not schema then
            error("[JutsuCatalog] Unknown balance field '" .. tostring(key) .. "' on " .. definition.id)
        end
        if type(reference) == "table" and reference.value ~= nil then
            if reference.tier and schema and not Balance[schema.tiers][reference.tier] then
                error("[JutsuCatalog] Unknown " .. key .. " tier '" .. tostring(reference.tier) .. "' on " .. definition.id)
            end
        else
            local tier = type(reference) == "table" and reference.tier or reference
            local tiers = key == "damage" and Balance.DamageTier
                or key == "control" and Balance.MasteryTier
                or schema and Balance[schema.tiers]
            if not explicitBalanceFields[key] and (not tiers or tiers[tier] == nil) then
                error("[JutsuCatalog] Unknown " .. key .. " tier '" .. tostring(tier) .. "' on " .. definition.id)
            end
        end
    end
end

function Catalog.validate()
    local ids, nodeIds = {}, {}
    for _, definition in ipairs(Catalog.Definitions) do
        if type(definition.id) ~= "string" or definition.id == "" or ids[definition.id] then
            error("[JutsuCatalog] Invalid or duplicate id '" .. tostring(definition.id) .. "'")
        end
        ids[definition.id] = true
        Catalog.ById[definition.id] = definition

        if definition.node then
            local value = definition.node
            value.prerequisites = value.prerequisites or {}
            value.effectType = value.effectType or (definition.selectable == false and "passive" or "ability")
            if nodeIds[value.id] then error("[JutsuCatalog] Duplicate node id '" .. value.id .. "'") end
            if not Catalog.Disciplines[value.discipline] then
                error("[JutsuCatalog] Unknown discipline '" .. tostring(value.discipline) .. "' on " .. definition.id)
            end
            if not rankOrder[value.rank] then
                error("[JutsuCatalog] Unknown rank '" .. tostring(value.rank) .. "' on " .. definition.id)
            end
            nodeIds[value.id] = true
            Catalog.ByNodeId[value.id] = definition
        end

        for _, sign in ipairs((definition.casting and definition.casting.handSigns) or {}) do
            if not handSigns[sign] then error("[JutsuCatalog] Unknown hand sign '" .. tostring(sign) .. "'") end
        end
        for _, requirement in ipairs(definition.requirements or {}) do
            if requirement.kind == "lineage" and not lineageRequirements[requirement.id] then
                error("[JutsuCatalog] Unknown lineage requirement '" .. tostring(requirement.id) .. "'")
            elseif requirement.kind == "special" and not specialRequirements[requirement.id] then
                error("[JutsuCatalog] Unknown special requirement '" .. tostring(requirement.id) .. "'")
            elseif requirement.kind ~= "lineage" and requirement.kind ~= "special" then
                error("[JutsuCatalog] Unknown requirement kind '" .. tostring(requirement.kind) .. "'")
            end
        end
        if definition.selectable ~= false then
            if definition.effect and not genericEffects[definition.effect.kind] then
                error("[JutsuCatalog] Unknown effect kind '" .. tostring(definition.effect.kind) .. "'")
            end
            if definition.executor and not specializedExecutors[definition.executor] then
                error("[JutsuCatalog] Unknown executor '" .. tostring(definition.executor) .. "'")
            end
            if not definition.effect and not definition.executor then
                error("[JutsuCatalog] Selectable ability '" .. definition.id .. "' has no execution")
            end
        end
        validateBalance(definition)
    end

    for _, definition in ipairs(Catalog.Definitions) do
        for _, prerequisite in ipairs((definition.node and definition.node.prerequisites) or {}) do
            if not nodeIds[prerequisite] then
                error("[JutsuCatalog] Unknown prerequisite '" .. prerequisite .. "' on " .. definition.id)
            end
        end
    end
    return true
end

Catalog.validate()
