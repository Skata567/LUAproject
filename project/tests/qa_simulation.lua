local M = {}

function M.test_qa_simulation()
    local RacesData = require("data.races")
    local ClassesData = require("data.classes")
    local Item = require("item")
    local Equipment = require("equipment")
    local Inventory = require("inventory")
    local Party = require("systems.party")
    local Combat = require("systems.combat")
    
    local map = {}
    local MAP_WIDTH, MAP_HEIGHT = 20, 20
    for y=1, MAP_HEIGHT do
        map[y] = {}
        for x=1, MAP_WIDTH do
            map[y][x] = 1 -- floor
        end
    end
    
    local player = {x=5, y=5, hp=30, maxHp=30, alive=true, name="Player", char="@", baseAtk=5, str=10, dex=10, con=10, int=10, lck=10, exp=0, nextExp=20, level=1}
    local party = {}
    local enemies = {}
    local groundItems = {}
    
    local ctx = {
        player = player,
        party = party,
        enemies = enemies,
        map = map,
        addMessage = function(msg) end,
        Inventory = Inventory,
        Equipment = Equipment,
        Item = Item,
        checkLevelUp = function() end,
        dealCompanionAttack = Combat.dealCompanionAttack,
        lastAttackedEnemy = nil,
        getGroundItems = function() return groundItems end,
        TILE_WALL = 0
    }
    
    Party.init(ctx)
    Combat.init({
        player = player,
        party = party,
        enemies = enemies,
        map = map,
        addMessage = ctx.addMessage,
        getPlayerAtk = function() return 10 end,
        getPlayerDef = function() return 5 end,
        getPlayerEvasion = function() return 5 end,
        getPlayerCrit = function() return 5 end,
        getPlayerElement = function() return "physical" end,
        Inventory = Inventory,
        Equipment = Equipment,
        Item = Item
    })
    
    -- 1. 영입 테스트
    local merc = { name="QAMerc", level=1, race=RacesData.PLAYER_RACES[1], class=ClassesData.PLAYER_CLASSES[1], cost=10 }
    Party.recruit(merc)
    assert(#party == 1, "Companion was not recruited!")
    
    local comp = party[1]
    
    -- 2. 아이템 루팅 AI 테스트
    player.x = 10
    player.y = 10
    comp.x = 10
    comp.y = 11
    
    table.insert(groundItems, {x=10, y=13, item=Item.new("iron_sword"), picked=false})
    
    -- 턴 진행
    for turn=1, 5 do
        Party.takeTurns()
    end
    assert(comp.x == 10 and comp.y == 13, "Companion did not move to item!")
    
    -- 아이템 줍기 시뮬레이션
    local isStepped = false
    for _, gi in ipairs(groundItems) do
        if not gi.picked and comp.x == gi.x and comp.y == gi.y then
            isStepped = true
            gi.picked = true
            comp.inv:autoPlace(gi.item)
        end
    end
    assert(isStepped, "Companion failed to pick up item.")
    
    -- 3. 전투 AI 테스트
    table.insert(enemies, {x=10, y=14, hp=20, maxHp=20, alive=true, name="QAEnemy", char="E", def=0, ev=0, exp=10})
    
    -- 무기 장착
    comp.equip:equip(comp.inv.items[1], comp.inv)
    
    for turn=1, 3 do
        Party.takeTurns()
    end
    
    assert(enemies[1].hp < 20, "Companion did not deal damage!")
    
    -- 4. 미행 AI 테스트
    enemies[1].alive = false -- 적 사망 처리
    player.x = 15
    player.y = 15
    
    for turn=1, 10 do
        Party.takeTurns()
    end
    local dist = math.abs(comp.x - player.x) + math.abs(comp.y - player.y)
    assert(dist == 1, "Companion did not follow player properly!")
end

return M
