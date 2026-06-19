require "NinjaLineages_Balance"
require "NinjaLineages_Utils"
require "NinjaLineages_RareScrolls"

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
    sennin_mode = {
        name = "UI_NL_Discipline_SenninMode",
        description = "UI_NL_Discipline_SenninMode_Desc",
        card = "media/ui/jutsuTree/cards/sennin_mode.png",
        locked = true,
    },
    kinjutsu = {
        name = "UI_NL_Discipline_Kinjutsu",
        description = "UI_NL_Discipline_Kinjutsu_Desc",
        card = "media/ui/jutsuTree/cards/kinjutsu.png",
        locked = true,
        hidden = true,
    },
    puppet_master = {
        name = "UI_NL_Discipline_PuppetMaster",
        description = "UI_NL_Discipline_PuppetMaster_Desc",
        card = "media/ui/jutsuTree/cards/puppet_master.png",
        locked = true,
        hidden = true,
    },
    gene_experimentation = {
        name = "UI_NL_Discipline_GeneExperimentation",
        description = "UI_NL_Discipline_GeneExperimentation_Desc",
        card = "media/ui/jutsuTree/cards/gene_experimentation.png",
        locked = true,
        hidden = true,
    },
    jinchuuriki = {
        name = "UI_NL_Discipline_Jinchuuriki",
        description = "UI_NL_Discipline_Jinchuuriki_Desc",
        card = "media/ui/jutsuTree/cards/jinchuriki.png",
        locked = true,
        hidden = true,
    },
}

Catalog.DisciplineOrder = {
    "genjutsu",
    "ninjutsu",
    "taijutsu",
    "kenjutsu",
    "medical",
    "fuinjutsu",
    "sennin_mode",
    "kinjutsu",
    "puppet_master",
    "gene_experimentation",
    "jinchuuriki",
}

local function node(id, discipline, rank, order, prerequisites, effectType)
    return {
        id = id,
        selectable = false,
        category = "common",
        node = {
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
        id = "smoke_bomb",
        category = "common",
        node = { discipline = "genjutsu", rank = "GENIN", order = 10 },
        handSigns = { "rat", "snake", "hare" },
        balance = { cost = "BASIC", cooldown = "STANDARD" },
        executor = "smoke_bomb",
    },
    {
        id = "false_sound",
        category = "common",
        node = { discipline = "genjutsu", rank = "GENIN", order = 20 },
        handSigns = { "rat", "hare", "snake" },
        balance = { cost = "BASIC", cooldown = "SHORT", radius = "LARGE" },
        effect = { kind = "world_sound", projected = true },
    },
    {
        id = "bringer_of_darkness",
        category = "common",
        node = {
            discipline = "genjutsu", rank = "CHUNIN", order = 10,
            prerequisites = { "smoke_bomb", "false_sound" },
        },
        handSigns = { "snake", "rat", "tiger" },
        balance = {
            cost = "STANDARD", cooldown = "LONG", radius = "LARGE",
            duration = "LONG",
        },
        executor = "bringer_of_darkness",
    },
    {
        id = "killing_intent",
        category = "common",
        node = {
            discipline = "genjutsu", rank = "JONIN", order = 10,
            prerequisites = { "bringer_of_darkness" },
        },
        handSigns = { "tiger", "dragon", "tiger" },
        balance = { cost = "MAJOR", cooldown = "VERY_LONG", radius = "STANDARD", control = "CHUNIN" },
        effect = { kind = "area_control" },
    },
    {
        id = "kirigakure",
        category = "common",
        discipline = "genjutsu",
        requirements = {
            { kind = "rare_unlock", id = "kirigakure" },
        },
        handSigns = { "snake", "rat", "dragon", "tiger" },
        balance = {
            cost = "ULTIMATE",
            cooldown = "VERY_LONG",
            duration = "WORLD_HOUR",
        },
        executor = "kirigakure",
    },
    {
        id = "chakra_focus",
        category = "common",
        node = { discipline = "ninjutsu", rank = "GENIN", order = 30 },
        handSigns = { "ram", "dragon", "tiger" },
        balance = { cost = "BASIC", cooldown = "STANDARD", mastery = "JONIN" },
        effect = { kind = "restore_focus" },
    },
    {
        id = "calorie_control",
        category = "common",
        presentation = {
            icon = "media/ui/jutsuTree/nodes/calorie_control.png",
        },
        node = { discipline = "ninjutsu", rank = "GENIN", order = 20 },
        handSigns = { "dog", "ox", "horse" },
        balance = {
            cost = "BASIC",
            cooldown = "LONG",
            duration = "SHORT",
            tickInterval = "RAPID_TICK",
            costStep = "STANDARD",
        },
        executor = "calorie_control",
    },
    {
        id = "physical_reinforcement",
        category = "common",
        node = { discipline = "ninjutsu", rank = "GENIN", order = 10 },
        handSigns = { "tiger", "horse", "ox" },
        balance = {
            cost = "STANDARD",
            cooldown = "LONG",
            duration = "STANDARD",
            tickInterval = "RAPID_TICK",
            costStep = "STANDARD",
        },
        executor = "physical_reinforcement",
    },
    {
        id = "katon",
        category = "common",
        presentation = {
            icon = "media/ui/jutsuTree/nodes/katon.png",
        },
        node = {
            discipline = "ninjutsu", rank = "CHUNIN", order = 10,
            prerequisites = { "physical_reinforcement", "calorie_control" },
        },
        handSigns = { "ox", "tiger", "ram" },
        balance = {
            cost = "ADVANCED", cooldown = "LONG",
            radius = "SMALL", targeting = "NARROW",
            damage = "MODERATE", control = "JONIN",
        },
        executor = "katon",
    },
    {
        id = "earth_wall",
        category = "common",
        presentation = {
            icon = "media/ui/jutsuTree/nodes/earth_wall.png",
        },
        node = {
            discipline = "ninjutsu", rank = "CHUNIN", order = 20,
            prerequisites = { "chakra_focus", "calorie_control" },
        },
        handSigns = { "ram", "ox", "snake" },
        balance = {
            cost = "ADVANCED", cooldown = "LONG", duration = "LONG",
        },
        executor = "earth_wall",
    },
    {
        id = "shadow_close",
        category = "common",
        node = {
            discipline = "ninjutsu", rank = "JONIN", order = 10,
            prerequisites = { "katon", "earth_wall" },
        },
        handSigns = { "bird", "rat", "tiger" },
        balance = {
            cost = "MAJOR", cooldown = "VERY_LONG", targeting = "STANDARD",
            distance = "STANDARD", decoyRadius = "STANDARD", control = "GENIN",
        },
        effect = { kind = "shadow_close" },
    },
    {
        id = "dash",
        category = "common",
        node = { discipline = "taijutsu", rank = "GENIN", order = 10 },
        handSigns = { "bird", "hare", "rat" },
        balance = { cost = "ADVANCED", cooldown = "DASH", distance = "STANDARD", duration = "BURST" },
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
        id = "minor_healing",
        category = "common",
        node = { discipline = "medical", rank = "GENIN", order = 30 },
        handSigns = { "boar", "ram", "snake" },
        balance = { cost = "STANDARD", cooldown = "STANDARD", healing = "LIGHT" },
        effect = { kind = "heal_most_damaged", fields = { "health", "scratch", "cut" } },
    },
    {
        id = "cell_stimulation",
        category = "common",
        node = { discipline = "medical", rank = "GENIN", order = 20 },
        handSigns = { "boar", "ram", "tiger" },
        balance = { cost = "STANDARD", cooldown = "LONG", healing = "MODERATE", duration = "LONG" },
        effect = { kind = "cell_stimulation" },
    },
    {
        id = "chakra_needle",
        category = "common",
        presentation = {
            icon = "media/ui/jutsuTree/nodes/chakra_needle.png",
        },
        node = { discipline = "medical", rank = "GENIN", order = 10 },
        handSigns = { "snake", "ram", "bird" },
        balance = {
            cost = "STANDARD", cooldown = "SHORT", targeting = "STANDARD",
            damage = "LIGHT", control = "GENIN",
        },
        executor = "chakra_needle",
        projectile = {
            trackingType = "homing",
            visual = "chakra_needle_line",
            collisionMask = "jutsu_projectile",
            targetPriority = "zombie_then_hostile_player",
        },
    },
    {
        id = "nervous_system_shock",
        category = "common",
        presentation = {
            icon = "media/ui/jutsuTree/nodes/chakra_needle.png",
        },
        node = {
            discipline = "medical", rank = "CHUNIN", order = 10,
            prerequisites = { "chakra_needle", "cell_stimulation" },
        },
        handSigns = { "snake", "dragon", "ram" },
        balance = {
            cost = "ADVANCED", cooldown = "LONG", targeting = "SMALL_CLUSTER",
            damage = "MODERATE", control = "JONIN",
        },
        executor = "nervous_system_shock",
    },
    {
        id = "field_surgery",
        category = "common",
        node = {
            discipline = "medical", rank = "CHUNIN", order = 20,
            prerequisites = { "minor_healing", "cell_stimulation" },
        },
        handSigns = { "boar", "snake", "ram" },
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
            discipline = "medical", rank = "JONIN", order = 10,
            prerequisites = { "nervous_system_shock", "field_surgery" },
        },
        handSigns = { "ram", "boar", "dragon" },
        balance = { cost = "MAJOR", cooldown = "VERY_LONG", healing = "HEAVY", duration = "VERY_LONG" },
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
        requirements = { { kind = "lineage", id = "uchiha" } },
        balance = {
            sustainedDrains = { "MODERATE", "HIGH", "EXTREME" },
            evolvedDrain = "EXTREME",
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
        requirements = {
            { kind = "lineage", id = "uchiha" },
            { kind = "special", id = "mangekyo_unlocked" },
        },
        balance = {
            cost = "FREE", cooldown = "STANDARD", channelDrain = "HIGH",
            duration = "COMBAT",
            minimumChakra = "COMMITTED",
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
        requirements = { { kind = "lineage", id = "hyuga" } },
        balance = { sustainedDrain = "HIGH" },
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
        requirements = { { kind = "lineage", id = "senju" } },
        balance = {
            cost = "MAJOR", cooldown = "STANDARD", radius = "LARGE", duration = "BRIEF",
            innerRadius = "MEDIUM",
            innerKnockdownChance = 65,
            outerKnockdownChance = 35,
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
        requirements = {
            { kind = "lineage", id = "senju" },
            { kind = "rare_unlock", id = "creation_rebirth" },
        },
        balance = {
            costStep = "HARSH",
            duration = "SHORT",
            tickInterval = "RAPID_TICK",
            healing = "CREATION_REBIRTH",
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
        requirements = { { kind = "lineage", id = "rinnegan" } },
        balance = {
            cost = "MAJOR", costStep = "SMALL", maximumCost = "ULTIMATE",
            cooldown = "STANDARD", radius = "STANDARD", damage = "HEAVY",
            guaranteedKnockdownRadius = "SMALL",
        },
        executor = "shinra_tensei",
    },
    {
        id = "corpse_odor_conditioning",
        category = "common",
        node = { discipline = "gene_experimentation", rank = "GENIN", order = 10 },
        balance = { sustainedDrain = "TRACE" },
        executor = "corpse_odor_conditioning",
    },
    node("blood_extraction", "gene_experimentation", "GENIN", 20),
    node("ocular_extraction", "gene_experimentation", "CHUNIN", 10, { "blood_extraction" }),
    node("gene_extraction", "gene_experimentation", "JONIN", 10, { "ocular_extraction" }),
}

local rankOrder = { GENIN = 1, CHUNIN = 2, JONIN = 3 }
local handSigns = {
    monkey = true, dragon = true, rat = true, bird = true, snake = true, ox = true,
    dog = true, horse = true, tiger = true, boar = true, ram = true, hare = true,
}
Catalog.genericEffects = {
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
local specialRequirements = {
    mangekyo_unlocked = true,
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
    minimumChakra = { tiers = "ChakraCostTier", resolver = "getCost" },
    sustainedDrains = {
        tiers = "SustainedDrainTier",
        resolver = "getSustainedDrain",
        list = true,
    },
    evolvedDrain = { tiers = "SustainedDrainTier", resolver = "getSustainedDrain" },
    innerRadius = { tiers = "RadiusTier", resolver = "getRadius" },
    tickInterval = { tiers = "DurationTier", resolver = "getDuration" },
    guaranteedKnockdownRadius = { tiers = "RadiusTier", resolver = "getRadius" },
}
local mechanicFields = {
    innerKnockdownChance = true,
    outerKnockdownChance = true,
}

Catalog.ById = {}
Catalog.ByNodeId = {}

local function presentation(definition)
    local value = definition.presentation or {}
    local sourceId = definition.id
    return {
        nameKey = value.nameKey or ("UI_NL_Node_" .. sourceId .. "_Name"),
        descriptionKey = value.descriptionKey or ("UI_NL_Node_" .. sourceId .. "_Desc"),
        nameFallback = value.nameFallback or definition.id,
        descriptionFallback = value.descriptionFallback or "",
        icon = value.icon or (definition.node
            and ("media/ui/jutsuTree/nodes/" .. definition.node.discipline .. ".png")
            or "media/ui/NLJutsu.png"),
    }
end

local function resolveValue(key, reference)
    if reference == nil then return nil end
    local schema = balanceSchemas[key]
    if schema and schema.list then
        local resolved = {}
        for index, tier in ipairs(reference) do
            resolved[index] = Balance[schema.resolver](tier)
        end
        return resolved
    end
    if mechanicFields[key] then return reference end
    local tier = reference
    if key == "damage" then
        local minimum, maximum = Balance.getDamageRange(tier)
        return { tier = tier, min = minimum, max = maximum }
    end
    if key == "control" then
        return { tier = tier, value = Balance.getMastery(tier) }
    end
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
        return a.id < b.id
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

function Catalog.getCooldownKey(definition)
    definition = type(definition) == "table" and definition or Catalog.get(definition)
    return definition and (definition.category .. "." .. definition.id) or nil
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
            and not NinjaLineages.Progression.isCompleted(player, definition.id) then
        return false, "not_learned"
    end
    for _, requirement in ipairs(definition.requirements or {}) do
        if requirement.kind == "lineage" and not checkLineage(player, requirement.id) then
            return false, "lineage"
        elseif requirement.kind == "rare_unlock" then
            if not NinjaLineages.RareScrolls.isUnlocked(player, requirement.id) then
                return false, "locked"
            end
        elseif requirement.kind == "special" then
            if requirement.id == "mangekyo_unlocked"
                    and not NinjaLineages.getNLData(player).mangekyoUnlocked then
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
    local balance = definition.balance or {}

    local function buildTargetArgs(player)
        if definition.executor ~= "chakra_needle"
                and definition.executor ~= "nervous_system_shock" then
            return {}
        end

        local resolved = Catalog.resolveBalance(definition)
        local targeting = resolved and resolved.targeting
        if not targeting then return {} end

        local targets = NinjaLineages.Utils.Zombies.collectClosestVisible(
            player,
            targeting.range,
            targeting.maxTargets
        )
        local args = { targetIds = {} }
        if not (NinjaLineages.isClient and NinjaLineages.isClient()) then
            args.targetZombies = {}
        end

        for _, entry in ipairs(targets) do
            local zombie = entry.zombie
            if zombie and zombie.getOnlineID then
                table.insert(args.targetIds, zombie:getOnlineID())
                if args.targetZombies then table.insert(args.targetZombies, zombie) end
            end
        end
        return args
    end

    return {
        id = definition.id,
        lineage = definition.category,
        discipline = definition.discipline or (definition.node and definition.node.discipline),
        nodeId = definition.node and definition.id or nil,
        name = view.nameKey,
        nameFallback = view.nameFallback,
        descriptionKey = view.descriptionKey,
        descriptionFallback = view.descriptionFallback,
        texture = view.icon,
        fallbackTexture = "media/ui/NLJutsu.png",
        handSigns = definition.handSigns,
        sealFree = not definition.handSigns,
        costTier = type(balance.cost) == "table" and balance.cost.tier or balance.cost,
        cooldownTier = type(balance.cooldown) == "table" and balance.cooldown.tier or balance.cooldown,
        condition = function(player) return Catalog.isAvailable(player, definition) end,
        action = function(player, presentation)
            return NinjaLineages.AbilityAuthority.request(
                player,
                definition.id,
                buildTargetArgs(player),
                presentation
            )
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
        if key ~= "damage" and key ~= "control" and not schema and not mechanicFields[key] then
            error("[JutsuCatalog] Unknown balance field '" .. tostring(key) .. "' on " .. definition.id)
        end
        if schema and schema.list then
            if type(reference) ~= "table" or #reference == 0 then
                error("[JutsuCatalog] Balance field '" .. key .. "' must be a tier list on " .. definition.id)
            end
            for _, tier in ipairs(reference) do
                if Balance[schema.tiers][tier] == nil then
                    error("[JutsuCatalog] Unknown " .. key .. " tier '" .. tostring(tier) .. "' on " .. definition.id)
                end
            end
        elseif not mechanicFields[key] then
            local tier = reference
            local tiers = key == "damage" and Balance.DamageTier
                or key == "control" and Balance.MasteryTier
                or schema and Balance[schema.tiers]
            if not tiers or tiers[tier] == nil then
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
            value.id = definition.id
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
        if definition.discipline and not Catalog.Disciplines[definition.discipline] then
            error("[JutsuCatalog] Unknown discipline '" .. tostring(definition.discipline) .. "' on " .. definition.id)
        end

        for _, sign in ipairs(definition.handSigns or {}) do
            if not handSigns[sign] then error("[JutsuCatalog] Unknown hand sign '" .. tostring(sign) .. "'") end
        end
        for _, requirement in ipairs(definition.requirements or {}) do
            if requirement.kind == "lineage" and not lineageRequirements[requirement.id] then
                error("[JutsuCatalog] Unknown lineage requirement '" .. tostring(requirement.id) .. "'")
            elseif requirement.kind == "special" and not specialRequirements[requirement.id] then
                error("[JutsuCatalog] Unknown special requirement '" .. tostring(requirement.id) .. "'")
            elseif requirement.kind == "rare_unlock"
                    and not NinjaLineages.RareScrolls.get(requirement.id) then
                error("[JutsuCatalog] Unknown rare unlock requirement '" .. tostring(requirement.id) .. "'")
            elseif requirement.kind ~= "lineage"
                    and requirement.kind ~= "special"
                    and requirement.kind ~= "rare_unlock" then
                error("[JutsuCatalog] Unknown requirement kind '" .. tostring(requirement.kind) .. "'")
            end
        end
        if definition.selectable ~= false then
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

function Catalog.validateExecutors()
    local specializedExecutors = NinjaLineages.AbilityExecution.specializedExecutors or {}
    local genericEffects = NinjaLineages.AbilityExecution.genericEffects or {}

    for _, definition in ipairs(Catalog.Definitions) do
        if definition.selectable ~= false then
            if definition.executor and not specializedExecutors[definition.executor] then
                error("[JutsuCatalog] Missing specialized executor '" .. tostring(definition.executor) .. "' for ability " .. definition.id)
            end
            if definition.effect and not Catalog.genericEffects[definition.effect.kind] and not genericEffects[definition.effect.kind] then
                error("[JutsuCatalog] Missing generic effect kind '" .. tostring(definition.effect.kind) .. "' for ability " .. definition.id)
            end
        end
    end
    return true
end

Catalog.validate()
