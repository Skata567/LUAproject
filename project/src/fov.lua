local FOV = {}

-- Bresenham's line algorithm for Raycasting FOV
local function getLine(x0, y0, x1, y1)
    local points = {}
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy

    while true do
        table.insert(points, {x = x0, y = y0})
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end
        if x0 == x1 and y0 == y1 then
            table.insert(points, {x = x0, y = y0})
            break
        end
        if e2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
    return points
end

function FOV.calculate(px, py, radius, map, mapWidth, mapHeight, isOpaqueFunc, visibleMapOut)
    local visible = visibleMapOut or {}

    -- Initialize or clear only the required bounds
    for y = 1, mapHeight do
        visible[y] = visible[y] or {}
        for x = 1, mapWidth do
            visible[y][x] = false
        end
    end

    -- Always see yourself
    visible[py][px] = true

    -- Raycast to the perimeter of the bounding box
    local startX = math.max(1, px - radius)
    local endX = math.min(mapWidth, px + radius)
    local startY = math.max(1, py - radius)
    local endY = math.min(mapHeight, py + radius)

    local perimeter = {}
    for x = startX, endX do
        table.insert(perimeter, {x=x, y=startY})
        table.insert(perimeter, {x=x, y=endY})
    end
    for y = startY+1, endY-1 do
        table.insert(perimeter, {x=startX, y=y})
        table.insert(perimeter, {x=endX, y=y})
    end

    for _, p in ipairs(perimeter) do
        local line = getLine(px, py, p.x, p.y)
        for _, pt in ipairs(line) do
            -- Check distance
            local distSq = (pt.x - px)^2 + (pt.y - py)^2
            if distSq <= radius * radius then
                visible[pt.y][pt.x] = true
                if isOpaqueFunc(pt.x, pt.y) then
                    break -- Block vision
                end
            else
                break
            end
        end
    end

    return visible
end

return FOV
