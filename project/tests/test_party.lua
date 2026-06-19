local Party = require("systems.party")

local function assert_eq(a, b, msg)
    if a ~= b then
        error("Assertion failed: " .. tostring(msg) .. " (Expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
    end
end

function test_companion_movement()
    print("Testing Companion Movement...")
    
    local map = {}
    for y=1, 20 do
        map[y] = {}
        for x=1, 20 do
            map[y][x] = 1 -- 1=floor (TILE_FLOOR)
        end
    end
    
    local player = {x=10, y=10}
    local comp = {x=2, y=2, hp=10, alive=true, name="TestComp"}
    local party = {comp}
    local enemies = {}
    
    -- Mock context
    local ctx = {
        map = map,
        player = player,
        party = party,
        enemies = enemies,
        TILE_WALL = 0,
        addMessage = function() end
    }
    
    Party.init(ctx)
    
    -- 플레이어와 떨어져 있으면 따라간다 (stopDist = 1)
    Party.takeTurns()
    
    -- 원래 2, 2 였고 10, 10으로 가야하니 x나 y가 1 증가해야 함
    local moved = (comp.x == 3 and comp.y == 2) or (comp.x == 2 and comp.y == 3)
    if not moved then
        error("Companion failed to move towards player. Current pos: " .. comp.x .. ", " .. comp.y)
    end
    
    print("Companion Movement tests passed successfully.")
end

function test_companion_attack()
    print("Testing Companion Attack Targeting...")
    
    local map = {}
    for y=1, 20 do
        map[y] = {}
        for x=1, 20 do
            map[y][x] = 1 -- 1=floor
        end
    end
    
    local player = {x=10, y=10}
    local comp = {x=10, y=11, hp=10, alive=true, name="TestComp", baseAtk=5, str=2}
    local party = {comp}
    
    local enemy1 = {x=10, y=12, hp=10, alive=true, name="E1"}
    local enemy2 = {x=10, y=13, hp=10, alive=true, name="E2"}
    local enemies = {enemy1, enemy2}
    
    local attackedEnemy = nil
    
    local ctx = {
        map = map,
        player = player,
        party = party,
        enemies = enemies,
        TILE_WALL = 0,
        addMessage = function() end,
        lastAttackedEnemy = enemy1, -- 플레이어가 E1을 때렸음
        dealCompanionAttack = function(c, target)
            attackedEnemy = target
        end
    }
    
    Party.init(ctx)
    
    Party.takeTurns()
    
    -- 거리가 3이내(comp=10,11 / E1=10,13 => dist=2)이고 lastAttackedEnemy이므로 E1을 최우선 타겟으로 공격해야 함
    assert_eq(attackedEnemy, enemy1, "Companion should prioritize lastAttackedEnemy")
    
    print("Companion Attack Targeting tests passed successfully.")
end

function test_recruit_and_equip()
    print("Testing Companion Recruit and Equip...")
    
    local RacesData = require("data.races")
    local ClassesData = require("data.classes")
    local Item = require("item")
    
    local ctx = {
        RacesData = RacesData,
        ClassesData = ClassesData,
        Inventory = require("inventory"),
        Equipment = require("equipment"),
        Item = require("item"),
        party = {},
        player = {x=5, y=5}
    }
    Party.init(ctx)
    
    local merc = {
        name = "TestMerc",
        level = 1,
        race = RacesData.PLAYER_RACES[1], -- human
        class = ClassesData.PLAYER_CLASSES[1], -- fighter
        cost = 100
    }
    
    local success, msg = Party.recruit(merc)
    assert_eq(success, true, "Recruit should succeed")
    assert_eq(#ctx.party, 1, "Party should have 1 member")
    
    local comp = ctx.party[1]
    assert_eq(comp.x, 5, "Companion should spawn at player x")
    assert_eq(comp.y, 5, "Companion should spawn at player y")
    
    -- Test Equip
    local sword = Item.new("iron_sword")
    comp.inv:autoPlace(sword)
    local eqSuccess = comp.equip:equip(sword, comp.inv)
    assert_eq(type(eqSuccess), "table", "Equip should succeed (return table)")
    
    print("Companion Recruit and Equip tests passed successfully.")
end

return { 
    test_companion_movement = test_companion_movement,
    test_companion_attack = test_companion_attack,
    test_recruit_and_equip = test_recruit_and_equip
}
