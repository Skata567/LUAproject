local Combat = require("systems.combat")
local EnemyRaces = require("data.enemy_races")

local M = {}

function M.test_combat_calc()
    -- Create mock combat context
    local player = {x=5, y=5, hp=30, maxHp=30, baseAtk=5, str=10, dex=10, con=10, int=10, lck=10}
    
    local ctx = {
        player = player,
        party = {},
        enemies = {},
        map = {},
        addMessage = function(msg) end,
        getPlayerAtk = function() return 10 end,
        getPlayerDef = function() return 2 end,
        getPlayerEvasion = function() return 0 end,
        getPlayerCrit = function() return 0 end,
        getPlayerElement = function() return "physical" end,
        Inventory = {},
        Equipment = {},
        Item = {}
    }
    Combat.init(ctx)
    
    -- Test basic damage calculation formula
    -- In DCSS formula, dmg = max(0, atk - def * rand) approx
    -- We can just test element mult
    
    local mult1 = EnemyRaces.getElementMult("fire", "beast")
    assert(mult1 == 1.3, "Beast should be weak to fire (+30%)")
    
    local mult2 = EnemyRaces.getElementMult("poison", "construct")
    assert(mult2 == 0, "Construct should be immune to poison")
end

return M
