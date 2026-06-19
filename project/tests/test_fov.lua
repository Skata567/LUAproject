local FOV = require("fov")

local M = {}

function M.test_fov_raycast()
    local map = {}
    for y = 1, 20 do
        map[y] = {}
        for x = 1, 20 do
            map[y][x] = 1 -- 1=floor, 0=wall
        end
    end
    
    -- Place a wall blocking sight
    map[12][10] = 0
    map[12][9] = 0
    map[12][11] = 0

    local isOpaque = function(x, y)
        if not map[y] or not map[y][x] then return true end
        return map[y][x] == 0
    end
    
    local visible = FOV.calculate(10, 10, 5, map, 20, 20, isOpaque)
    
    -- Check if empty floor is visible
    local function isVisible(vx, vy)
        return visible[vy] and visible[vy][vx]
    end
    
    assert(isVisible(10, 11), "Clear space should be visible")
    assert(not isVisible(10, 13), "Blocked space should not be visible")
end

return M
