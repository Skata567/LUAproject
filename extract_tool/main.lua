function love.load()
    local file = io.open("project/src/main.lua", "r")
    local content = file:read("*a")
    file:close()

    local function extract_and_remove(text, start_pattern, end_pattern)
        local s = text:find(start_pattern, 1, true)
        if not s then print("Failed to find start pattern") return text, nil end
        local e = text:find(end_pattern, s, true)
        if not e then print("Failed to find end pattern") return text, nil end
        e = e - 1
        
        local extracted = text:sub(s, e)
        local before = text:sub(1, s - 1)
        local after = text:sub(e + 1)
        return before .. after, extracted
    end

    local content, combat_ext = extract_and_remove(content, "local getBuffStatBonus\n\n---", "local function pickupItem()")

    if not combat_ext then
        print("Combat Extraction Failed")
        love.event.quit()
        return
    end

    -- Process combat_ext
    -- We want to export functions: local function NAME -> function Combat.NAME
    combat_ext = combat_ext:gsub("local function (%w+)", "function Combat.%1")

    -- Replace dependencies with ctx.
    combat_ext = " " .. combat_ext .. " "
    combat_ext = combat_ext:gsub("([^%w_])player([^%w_])", "%1ctx.player%2")
    combat_ext = combat_ext:gsub("([^%w_])enemies([^%w_])", "%1ctx.enemies%2")
    combat_ext = combat_ext:gsub("([^%w_])equip([^%w_])", "%1ctx.equip%2")
    combat_ext = combat_ext:gsub("([^%w_])addMessage([^%w_])", "%1ctx.addMessage%2")
    -- Also `messages`? The combat code doesn't access `messages` directly, it calls `addMessage`.
    -- Wait, `messages` array might be used? Let's check if it uses `messages`.
    -- `messages` is modified by `addMessage`. `combat.lua` only calls `addMessage`. So it's fine.

    combat_ext = combat_ext:sub(2, -2)

    -- Write systems/combat.lua
    local f = io.open("project/src/systems/combat.lua", "w")
    f:write([[
local Combat = {}

local ctx = {}
function Combat.init(context)
    ctx = context
end

]])
    f:write(combat_ext)
    f:write("\nreturn Combat\n")
    f:close()

    -- Inject requires and local bindings in main.lua
    -- We need to list the exported functions to bind them locally.
    local exports = {}
    for funcName in combat_ext:gmatch("function Combat%.(%w+)") do
        table.insert(exports, "local " .. funcName .. " = Combat." .. funcName)
    end
    local exports_str = table.concat(exports, "\n")

    local injection = [[
local Combat = require("systems.combat")

-- Update Context helper for main.lua to call when player/enemies change
local function updateCombatContext()
    Combat.init({
        player = player,
        enemies = enemies,
        equip = equip,
        addMessage = addMessage
    })
end

]] .. exports_str

    -- Insert injection where combat used to be
    local inject_pos = content:find("local function pickupItem()")
    if inject_pos then
        content = content:sub(1, inject_pos-1) .. injection .. "\n\n" .. content:sub(inject_pos)
    else
        print("Failed to find injection point for combat")
    end

    -- We must also call `updateCombatContext()` whenever `player`, `enemies`, or `equip` is initialized.
    -- `initPlayer` creates `player = {}`.
    content = content:gsub("unlockedSkills = %{%},  %-%- %{ skill_id = true %}\n        %}", "unlockedSkills = {},  -- { skill_id = true }\n        }\n        updateCombatContext()")
    
    -- `createMap` (now replaced by MapGen.generate) does `enemies = gen.enemies`.
    content = content:gsub("groundItems = gen%.groundItems", "groundItems = gen.groundItems\n    updateCombatContext()")

    -- `love.load` creates `equip = Equipment.new()`
    content = content:gsub("equip = Equipment%.new%(%)", "equip = Equipment.new()\n    updateCombatContext()")

    local out = io.open("project/src/main.lua", "w")
    out:write(content)
    out:close()

    print("Combat Extraction complete")
    love.event.quit()
end
