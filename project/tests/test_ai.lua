local AI = require("systems.ai")

local function assert_eq(a, b, msg)
    if a ~= b then
        error("Assertion failed: " .. tostring(msg) .. " (Expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
    end
end

function test_ai_state_transitions()
    print("Testing AI State Transitions (FSM)...")
    
    local map = {}
    for y=1, 20 do
        map[y] = {}
        for x=1, 20 do
            map[y][x] = 1 -- 1=floor (TILE_FLOOR)
        end
    end
    
    local player = {x=20, y=20}
    local enemy = {x=2, y=2, hp=10, maxHp=10, alive=true}
    local enemies = {enemy}
    local party = {}
    
    -- 초기 상태는 WANDER여야 함 (플레이어와 거리가 8 초과)
    AI.process(enemy, map, 20, 20, player, party, enemies)
    assert_eq(enemy.state, "IDLE", "Initial state should be IDLE")
    
    -- 플레이어가 가까이 오면 CHASE로 변함
    player.x = 4
    player.y = 4
    AI.process(enemy, map, 20, 20, player, party, enemies)
    assert_eq(enemy.state, "CHASE", "State should transition to CHASE when player is near")
    
    -- 체력이 20% 이하로 떨어지면 FLEE로 변함
    enemy.hp = 1
    AI.process(enemy, map, 20, 20, player, party, enemies)
    assert_eq(enemy.state, "FLEE", "State should transition to FLEE when HP is low")
    
    print("AI FSM tests passed successfully.")
end

return { test_ai_state_transitions = test_ai_state_transitions }
