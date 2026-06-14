require "NinjaLineages_Traits"
require "NinjaLineages_Utils"
require "NinjaLineages_Progression"
require "NinjaLineages_AbilityAuthority"
require "NinjaLineages_JutsuCatalog"

NinjaLineages = NinjaLineages or {}
NinjaLineages.HandSigns = NinjaLineages.HandSigns or {}

local HandSigns = NinjaLineages.HandSigns
local classicInputs = {}
local activeSequences = {}

HandSigns.Definitions = {
    monkey = { nameKey = "UI_NL_HandSign_Monkey", emote = "nl_handseal_monkey" },
    dragon = { nameKey = "UI_NL_HandSign_Dragon", emote = "nl_handseal_dragon" },
    rat = { nameKey = "UI_NL_HandSign_Rat", emote = "nl_handseal_rat" },
    bird = { nameKey = "UI_NL_HandSign_Bird", emote = "nl_handseal_bird" },
    snake = { nameKey = "UI_NL_HandSign_Snake", emote = "nl_handseal_snake" },
    ox = { nameKey = "UI_NL_HandSign_Ox", emote = "nl_handseal_ox" },
    dog = { nameKey = "UI_NL_HandSign_Dog", emote = "nl_handseal_dog" },
    horse = { nameKey = "UI_NL_HandSign_Horse", emote = "nl_handseal_horse" },
    tiger = { nameKey = "UI_NL_HandSign_Tiger", emote = "nl_handseal_tiger" },
    boar = { nameKey = "UI_NL_HandSign_Boar", emote = "nl_handseal_boar" },
    ram = { nameKey = "UI_NL_HandSign_Ram", emote = "nl_handseal_ram" },
    hare = { nameKey = "UI_NL_HandSign_Hare", emote = "nl_handseal_hare" },
}

HandSigns.KeyMap = {
    [Keyboard.KEY_NUMPAD7] = "monkey",
    [Keyboard.KEY_NUMPAD8] = "dragon",
    [Keyboard.KEY_NUMPAD9] = "rat",
    [Keyboard.KEY_NUMPAD4] = "bird",
    [Keyboard.KEY_NUMPAD5] = "snake",
    [Keyboard.KEY_NUMPAD6] = "ox",
    [Keyboard.KEY_NUMPAD1] = "dog",
    [Keyboard.KEY_NUMPAD2] = "horse",
    [Keyboard.KEY_NUMPAD3] = "tiger",
    [Keyboard.KEY_NUMPAD0] = "boar",
    [Keyboard.KEY_DECIMAL] = "ram",
    [Keyboard.KEY_ADD] = "hare",
}

function HandSigns.isClassic()
    local options = SandboxVars and SandboxVars.NinjaLineages
    return options and options.HandSignBehaviour == 1
end

function HandSigns.isAvailable(player, ability)
    if not ability then return false end
    local definition = NinjaLineages.JutsuCatalog.get(ability.id)
    if definition then return NinjaLineages.JutsuCatalog.isAvailable(player, definition) end
    return not ability.condition or ability.condition(player)
end

function HandSigns.getAvailableAbilities(player)
    local abilities = {}
    for _, ability in ipairs(NinjaLineages.Abilities) do
        if HandSigns.isAvailable(player, ability) then
            table.insert(abilities, ability)
        end
    end
    return abilities
end

function HandSigns.formatSequence(ability)
    if not ability or ability.sealFree or not ability.handSigns then
        return getText("UI_NL_HandSigns_NoSigns")
    end
    local parts = {}
    for _, signId in ipairs(ability.handSigns) do
        local sign = HandSigns.Definitions[signId]
        if sign then
            table.insert(parts, getText(sign.nameKey))
        end
    end
    return table.concat(parts, " > ")
end

local function playSign(player, signId)
    local sign = HandSigns.Definitions[signId]
    if not sign then return end
    player:Say(getText(sign.nameKey))
end

function HandSigns.playSeal(player, signId)
    if not player or player:isDead() or player:getVehicle() then return false end
    local sign = HandSigns.Definitions[signId or "tiger"]
    if not sign or not sign.emote then return false end
    local ok = pcall(function() player:playEmote(sign.emote) end)
    return ok
end

function HandSigns.startSequence(player, signs)
    if not player then return false end
    local sequence = signs
    if type(sequence) ~= "table" or #sequence == 0 then sequence = { "tiger" } end

    activeSequences[player] = nil
    if not HandSigns.playSeal(player, sequence[1]) then return false end
    if #sequence > 1 then
        activeSequences[player] = {
            signs = sequence,
            nextIndex = 2,
            nextAt = NinjaLineages.Utils.Time.realMilliseconds() + 400,
        }
    end
    return true
end

function HandSigns.playAbilitySeal(player, actionId)
    local definition = NinjaLineages.JutsuCatalog.get(actionId)
    if definition and definition.category == "common" and definition.handSigns then
        return HandSigns.startSequence(player, definition.handSigns)
    end
    return HandSigns.startSequence(player, { "tiger" })
end

function HandSigns.update(player)
    local sequence = activeSequences[player]
    if not sequence then return end
    if not player or player:isDead() or player:getVehicle() then
        activeSequences[player] = nil
        return
    end

    local now = NinjaLineages.Utils.Time.realMilliseconds()
    if now < sequence.nextAt then return end
    HandSigns.playSeal(player, sequence.signs[sequence.nextIndex])
    sequence.nextIndex = sequence.nextIndex + 1
    if sequence.nextIndex > #sequence.signs then
        activeSequences[player] = nil
    else
        sequence.nextAt = now + 400
    end
end

function HandSigns.activateAbility(player, ability)
    if not ability then return false end
    if HandSigns.isClassic() and not ability.sealFree then
        player:Say(getText("UI_NL_HandSigns_ClassicDisabled"))
        return false
    end
    return NinjaLineages.AbilityAuthority.request(player, ability.id, {})
end

local function sequenceEquals(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function isPrefix(input, sequence)
    if #input > #sequence then return false end
    for i = 1, #input do
        if input[i] ~= sequence[i] then return false end
    end
    return true
end

local function getClassicAbilities(player)
    local abilities = {}
    for _, ability in ipairs(HandSigns.getAvailableAbilities(player)) do
        if not ability.sealFree and ability.handSigns then table.insert(abilities, ability) end
    end
    return abilities
end

local function retainLongestValidSuffix(input, abilities)
    for startIndex = 1, #input do
        local suffix = {}
        for i = startIndex, #input do table.insert(suffix, input[i]) end
        for _, ability in ipairs(abilities) do
            if isPrefix(suffix, ability.handSigns) then return suffix end
        end
    end
    return {}
end

function HandSigns.handleClassicSign(player, signId)
    if not HandSigns.isClassic() then return false end
    if not player or player:isDead() or player:getVehicle() then
        if player then player:Say(getText("UI_NL_HandSigns_Busy")) end
        return true
    end
    local abilities = getClassicAbilities(player)
    if #abilities == 0 then return false end

    local state = classicInputs[player] or { signs = {} }
    table.insert(state.signs, signId)
    playSign(player, signId)
    HandSigns.playSeal(player, signId)

    for _, ability in ipairs(abilities) do
        if sequenceEquals(state.signs, ability.handSigns) then
            state.signs = {}
            classicInputs[player] = state
            NinjaLineages.AbilityAuthority.request(player, ability.id, {}, { skipSeal = true })
            return true
        end
    end

    state.signs = retainLongestValidSuffix(state.signs, abilities)
    classicInputs[player] = state
    return true
end

function HandSigns.handleKey(player, key)
    local signId = HandSigns.KeyMap[key]
    if not signId then return false end
    return HandSigns.handleClassicSign(player, signId)
end
