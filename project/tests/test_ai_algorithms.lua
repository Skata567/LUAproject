local function distance(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

-- Dummy Map
local MAP_WIDTH, MAP_HEIGHT = 20, 20
local map = {}
local TILE_WALL = 0
local TILE_FLOOR = 1
for y = 1, MAP_HEIGHT do
    map[y] = {}
    for x = 1, MAP_WIDTH do
        map[y][x] = TILE_FLOOR
    end
end

-- Put some walls
map[5][5] = TILE_WALL
map[5][6] = TILE_WALL
map[5][7] = TILE_WALL

-- Test Bresenham LoS
local function checkLineOfSight(x1, y1, x2, y2, map)
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

print("Testing Bresenham LoS...")
local los_clear = checkLineOfSight(1, 1, 10, 2, map)
assert(los_clear == true, "LoS should be clear")

local los_blocked = checkLineOfSight(5, 1, 5, 10, map)
assert(los_blocked == false, "LoS should be blocked by wall at 5,5")
print("Bresenham LoS PASS")

-- Test Circle Radius
print("Testing Circle Radius...")
local function getCircleTiles(cx, cy, radius)
    local tiles = {}
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            local dx = x - cx
            local dy = y - cy
            if dx*dx + dy*dy <= radius*radius then
                table.insert(tiles, {x=x, y=y})
            end
        end
    end
    return tiles
end

local tiles = getCircleTiles(10, 10, 3)
local inCircle = false
local outCircle = true
for _, t in ipairs(tiles) do
    if t.x == 10 and t.y == 13 then inCircle = true end
    if t.x == 13 and t.y == 13 then outCircle = false end -- 3^2 + 3^2 = 18 > 9
end
assert(inCircle == true, "10,13 should be inside radius 3")
assert(outCircle == true, "13,13 should be outside radius 3")
print("Circle Radius PASS")

print("All AI Algorithm Tests Passed!")
