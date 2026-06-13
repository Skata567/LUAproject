local AI = {}

local STATE_IDLE = "IDLE"
local STATE_WANDER = "WANDER"
local STATE_CHASE = "CHASE"
local STATE_FLEE = "FLEE"

local TILE_WALL = 0

local function distance(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

function AI.initEnemy(enemy)
    enemy.state = STATE_IDLE
    enemy.stateTimer = 0
end

-- Bresenham's Line Algorithm (Line-of-Sight)
function AI.checkLineOfSight(x1, y1, x2, y2, map)
    local dx = math.abs(x2 - x1)
    local dy = -math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx + dy

    local cx, cy = x1, y1
    while true do
        if map[cy] and map[cy][cx] == TILE_WALL then
            return false
        end
        if cx == x2 and cy == y2 then break end
        local e2 = 2 * err
        if e2 >= dy then
            err = err + dy
            cx = cx + sx
        end
        if e2 <= dx then
            err = err + dx
            cy = cy + sy
        end
    end
    return true
end

-- A* Algorithm
function AI.findPathAStar(sx, sy, tx, ty, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
    local openSet = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    local function posToKey(x, y) return y * MAP_WIDTH + x end
    local startKey = posToKey(sx, sy)
    
    openSet[startKey] = {x=sx, y=sy}
    gScore[startKey] = 0
    fScore[startKey] = distance(sx, sy, tx, ty)
    
    local blockedMap = {}
    for _, e in ipairs(enemies) do
        if e.alive and (e.x ~= sx or e.y ~= sy) then
            blockedMap[posToKey(e.x, e.y)] = true
        end
    end
    if allies then
        for _, a in ipairs(allies) do
            if a.alive then
                blockedMap[posToKey(a.x, a.y)] = true
            end
        end
    end
    
    local iters = 0
    while next(openSet) do
        iters = iters + 1
        if iters > 200 then break end
        
        local currentKey, current = nil, nil
        local minF = math.huge
        for k, v in pairs(openSet) do
            if fScore[k] < minF then
                minF = fScore[k]
                currentKey = k
                current = v
            end
        end
        
        if current.x == tx and current.y == ty then
            local path = {}
            local currKey = currentKey
            while cameFrom[currKey] do
                table.insert(path, 1, cameFrom[currKey].pos)
                currKey = cameFrom[currKey].parent
            end
            if #path > 0 then return path[1].x, path[1].y end
            return sx, sy
        end
        
        openSet[currentKey] = nil
        
        local neighbors = { {0, -1}, {0, 1}, {-1, 0}, {1, 0} }
        for _, d in ipairs(neighbors) do
            local nx, ny = current.x + d[1], current.y + d[2]
            if nx >= 1 and nx <= MAP_WIDTH and ny >= 1 and ny <= MAP_HEIGHT then
                if (nx == tx and ny == ty) or (map[ny][nx] ~= TILE_WALL and not blockedMap[posToKey(nx, ny)]) then
                    local tentative_gScore = gScore[currentKey] + 1
                    local neighborKey = posToKey(nx, ny)
                    
                    if not gScore[neighborKey] or tentative_gScore < gScore[neighborKey] then
                        cameFrom[neighborKey] = {parent = currentKey, pos = {x=nx, y=ny}}
                        gScore[neighborKey] = tentative_gScore
                        fScore[neighborKey] = tentative_gScore + distance(nx, ny, tx, ty)
                        openSet[neighborKey] = {x=nx, y=ny}
                    end
                end
            end
        end
    end
    
    return nil, nil
end

local function wanderStep(x, y, map, MAP_WIDTH, MAP_HEIGHT)
    local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    for i = #dirs, 2, -1 do
        local j = math.random(i)
        dirs[i], dirs[j] = dirs[j], dirs[i]
    end
    for _, d in ipairs(dirs) do
        local nx, ny = x + d[1], y + d[2]
        if nx >= 1 and nx <= MAP_WIDTH and ny >= 1 and ny <= MAP_HEIGHT then
            if map[ny][nx] ~= TILE_WALL then
                return nx, ny
            end
        end
    end
    return x, y
end

function AI.process(enemy, map, MAP_WIDTH, MAP_HEIGHT, player, allies, enemies)
    if not enemy.alive then return end
    if not enemy.state then AI.initEnemy(enemy) end
    
    local distToPlayer = distance(enemy.x, enemy.y, player.x, player.y)
    local maxHp = enemy.maxHp or 10
    local hpRatio = enemy.hp / maxHp
    local aiType = enemy.aiType or "melee"
    
    local nextState = enemy.state
    
    local fleeThreshold = 0.2
    if aiType == "coward" then fleeThreshold = 0.5 end
    
    if hpRatio <= fleeThreshold then
        nextState = STATE_FLEE
    elseif distToPlayer <= 8 or enemy.hp < maxHp then
        nextState = STATE_CHASE
    else
        if enemy.state == STATE_CHASE then
            nextState = STATE_WANDER
        elseif enemy.state == STATE_IDLE then
            if math.random() < 0.2 then nextState = STATE_WANDER end
        elseif enemy.state == STATE_WANDER then
            if math.random() < 0.1 then nextState = STATE_IDLE end
        end
    end
    
    enemy.state = nextState
    
    local nx, ny = enemy.x, enemy.y
    local attemptAttack = false
    local spellAttackTarget = nil
    
    if enemy.state == STATE_IDLE then
        if enemy.hp < maxHp and math.random() < 0.1 then
            enemy.hp = enemy.hp + 1
        end
        return "WAIT"
        
    elseif enemy.state == STATE_CHASE then
        if aiType == "mage" then
            -- Mage AI logic
            if distToPlayer > 1 and distToPlayer <= 5 and AI.checkLineOfSight(enemy.x, enemy.y, player.x, player.y, map) then
                if math.random() < 0.4 then
                    spellAttackTarget = player
                end
            end
            if spellAttackTarget == nil then
                if distToPlayer <= 1 then
                    attemptAttack = true
                elseif distToPlayer <= 2 then
                    -- 너무 가까우면 거리 벌리기
                    local dx, dy = enemy.x - player.x, enemy.y - player.y
                    local tx = math.max(1, math.min(MAP_WIDTH, enemy.x + dx * 2))
                    local ty = math.max(1, math.min(MAP_HEIGHT, enemy.y + dy * 2))
                    local ax, ay = AI.findPathAStar(enemy.x, enemy.y, tx, ty, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
                    if ax and ay then nx, ny = ax, ay else nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT) end
                else
                    local ax, ay = AI.findPathAStar(enemy.x, enemy.y, player.x, player.y, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
                    if ax and ay then nx, ny = ax, ay else nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT) end
                end
            end
        elseif aiType == "assassin" then
            -- Assassin AI logic: target weakest
            local target = player
            local minTargetHp = player.hp / player.maxHp
            if allies then
                for _, a in ipairs(allies) do
                    if a.alive and (a.hp / a.maxHp) < minTargetHp then
                        target = a
                        minTargetHp = a.hp / a.maxHp
                    end
                end
            end
            local distToTarget = distance(enemy.x, enemy.y, target.x, target.y)
            if distToTarget <= 1 then
                attemptAttack = true
                spellAttackTarget = target -- Just for targetting, we return ATTACK
            else
                local ax, ay = AI.findPathAStar(enemy.x, enemy.y, target.x, target.y, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
                if ax and ay then nx, ny = ax, ay else nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT) end
            end
        else
            -- Melee & Coward (Chase phase)
            if distToPlayer <= 1 then
                attemptAttack = true
            else
                local ax, ay = AI.findPathAStar(enemy.x, enemy.y, player.x, player.y, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
                if ax and ay then
                    nx, ny = ax, ay
                else
                    nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT)
                end
            end
        end
        
    elseif enemy.state == STATE_WANDER then
        nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT)
        
    elseif enemy.state == STATE_FLEE then
        local dx = enemy.x - player.x
        local dy = enemy.y - player.y
        local tx = enemy.x + math.max(-5, math.min(5, dx * 5))
        local ty = enemy.y + math.max(-5, math.min(5, dy * 5))
        tx = math.max(1, math.min(MAP_WIDTH, tx))
        ty = math.max(1, math.min(MAP_HEIGHT, ty))
        
        local ax, ay = AI.findPathAStar(enemy.x, enemy.y, tx, ty, map, MAP_WIDTH, MAP_HEIGHT, enemies, allies)
        if ax and ay then
            nx, ny = ax, ay
        else
            nx, ny = wanderStep(enemy.x, enemy.y, map, MAP_WIDTH, MAP_HEIGHT)
        end
    end
    
    if spellAttackTarget and aiType == "mage" then
        return "SPELL", spellAttackTarget
    elseif attemptAttack then
        if aiType == "assassin" and spellAttackTarget then
            return "ATTACK", spellAttackTarget
        end
        return "ATTACK", player
    else
        if ny >= 1 and ny <= MAP_HEIGHT and nx >= 1 and nx <= MAP_WIDTH then
            if map[ny][nx] ~= TILE_WALL then
                local blocked = false
                if nx == player.x and ny == player.y then blocked = true end
                for _, other in ipairs(enemies) do
                    if other ~= enemy and other.alive and other.x == nx and other.y == ny then
                        blocked = true; break
                    end
                end
                if allies then
                    for _, a in ipairs(allies) do
                        if a.alive and a.x == nx and a.y == ny then
                            blocked = true; break
                        end
                    end
                end
                if not blocked then
                    enemy.x = nx
                    enemy.y = ny
                    return "MOVE"
                end
            end
        end
    end
    
    return "WAIT"
end

return AI
