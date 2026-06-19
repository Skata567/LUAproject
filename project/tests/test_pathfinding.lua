local AI = require("systems.ai")

local M = {}

function M.test_astar()
    -- Create dummy map
    local map = {}
    for y = 1, 20 do
        map[y] = {}
        for x = 1, 20 do
            map[y][x] = 1 -- floor
        end
    end
    
    -- Clear path
    local path1 = AI.findPathAStar(1, 1, 10, 10, map, 20, 20, {}, {})
    assert(path1 ~= nil, "A* should find a clear path")
    
    -- Obstacles
    map[5][5] = 0
    map[5][6] = 0
    map[5][7] = 0
    local path2 = AI.findPathAStar(5, 4, 5, 8, map, 20, 20, {}, {})
    assert(path2 ~= nil, "A* should navigate around obstacles")
    
    -- Unreachable
    map[14][15] = 0
    map[15][14] = 0
    map[16][15] = 0
    map[15][16] = 0
    local path3 = AI.findPathAStar(1, 1, 15, 15, map, 20, 20, {}, {})
    assert(path3 == nil or #path3 == 0, "A* should return empty for unreachable destination")
end

return M
