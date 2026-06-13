local MapGen = {}

local Constants = require("data.constants")
local Item = require("item")
local DropData = require("data.drop_tables")
local DROP_TABLE = DropData.DROP_TABLE

local TILE_SIZE = Constants.TILE_SIZE
local MAP_WIDTH = Constants.MAP_WIDTH
local MAP_HEIGHT = Constants.MAP_HEIGHT
local MAX_ROOMS = Constants.MAX_ROOMS
local MIN_ROOM_SIZE = Constants.MIN_ROOM_SIZE
local MAX_ROOM_SIZE = Constants.MAX_ROOM_SIZE
local MAX_ENEMIES_PER_ROOM = Constants.MAX_ENEMIES_PER_ROOM
local MAX_ITEMS_PER_ROOM = Constants.MAX_ITEMS_PER_ROOM

local TILE_WALL = Constants.TILE_WALL
local TILE_FLOOR = Constants.TILE_FLOOR
local TILE_STAIR_DOWN = Constants.TILE_STAIR_DOWN
local TILE_STAIR_UP = Constants.TILE_STAIR_UP
local TILE_WATER = Constants.TILE_WATER
local TILE_LAVA = Constants.TILE_LAVA
local TILE_GRASS = Constants.TILE_GRASS
local TILE_DIRT = Constants.TILE_DIRT

local COLOR_WALL = Constants.COLOR_WALL
local COLOR_FLOOR = Constants.COLOR_FLOOR
local COLOR_WATER = Constants.COLOR_WATER
local COLOR_LAVA = Constants.COLOR_LAVA
local COLOR_GRASS = Constants.COLOR_GRASS
local COLOR_DIRT = Constants.COLOR_DIRT
local COLOR_PLAYER = Constants.COLOR_PLAYER
local COLOR_STAIR = Constants.COLOR_STAIR

local map = {}
local rooms = {}
local visibleMap = {}
local exploredMap = {}
local currentBiome = nil
local floor = 1

local addMessage_cb = nil

function MapGen.init(callbacks)
    addMessage_cb = callbacks.addMessage
end

local function addMessage(text)
    if addMessage_cb then addMessage_cb(text) end
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end



local function carveRoomShape(room, shape)
    local x, y, w, h = room.x, room.y, room.w, room.h
    for ry = y, y + h - 1 do
        for rx = x, x + w - 1 do
            local carve = false
            if shape == "rect" then
                carve = true
            elseif shape == "cross" then
                carve = (math.abs(rx - room.cx) <= 1) or (math.abs(ry - room.cy) <= 1)
            elseif shape == "round" then
                local nx = (rx - room.cx) / math.max(1, w / 2)
                local ny = (ry - room.cy) / math.max(1, h / 2)
                carve = nx * nx + ny * ny <= 1.05
            elseif shape == "chamber" then
                carve = true
                if math.random() < 0.18 and not (rx == room.cx and ry == room.cy) then
                    carve = false
                end
            end

            if carve then
                map[ry][rx] = TILE_FLOOR
            end
        end
    end
    map[room.cy][room.cx] = TILE_FLOOR
end

local function carveCorridor(x1, y1, x2, y2)
    if math.random() < 0.5 then
        for cx = math.min(x1, x2), math.max(x1, x2) do
            map[y1][cx] = TILE_FLOOR
        end
        for cy = math.min(y1, y2), math.max(y1, y2) do
            map[cy][x2] = TILE_FLOOR
        end
    else
        for cy = math.min(y1, y2), math.max(y1, y2) do
            map[cy][x1] = TILE_FLOOR
        end
        for cx = math.min(x1, x2), math.max(x1, x2) do
            map[y2][cx] = TILE_FLOOR
        end
    end
end

local function generateSpecialTerrain()
    local terrainTypes = {}
    if floor <= 2 then
        terrainTypes = {TILE_GRASS, TILE_DIRT, TILE_WATER}
    elseif floor <= 4 then
        terrainTypes = {TILE_DIRT, TILE_WATER, TILE_LAVA}
    else
        terrainTypes = {TILE_LAVA, TILE_DIRT}
    end

    local tempMap = {}
    for y = 1, MAP_HEIGHT do
        tempMap[y] = {}
        for x = 1, MAP_WIDTH do
            tempMap[y][x] = map[y][x]
            if map[y][x] == TILE_FLOOR and math.random() < 0.08 then
                tempMap[y][x] = terrainTypes[math.random(1, #terrainTypes)]
            end
        end
    end

    for iter = 1, 3 do
        local nextMap = {}
        for y = 1, MAP_HEIGHT do
            nextMap[y] = {}
            for x = 1, MAP_WIDTH do
                nextMap[y][x] = tempMap[y][x]
                if tempMap[y][x] ~= TILE_WALL and tempMap[y][x] ~= TILE_STAIR_UP and tempMap[y][x] ~= TILE_STAIR_DOWN then
                    local counts = {}
                    local maxCount = 0
                    local dominantTile = tempMap[y][x]
                    
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            local ny, nx = y + dy, x + dx
                            if ny > 0 and ny <= MAP_HEIGHT and nx > 0 and nx <= MAP_WIDTH then
                                local t = tempMap[ny][nx]
                                if t ~= TILE_WALL then
                                    counts[t] = (counts[t] or 0) + 1
                                    if counts[t] > maxCount then
                                        maxCount = counts[t]
                                        dominantTile = t
                                    end
                                end
                            end
                        end
                    end
                    nextMap[y][x] = dominantTile
                end
            end
        end
        tempMap = nextMap
    end

    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            if map[y][x] == TILE_FLOOR and tempMap[y][x] ~= TILE_FLOOR then
                map[y][x] = tempMap[y][x]
            end
        end
    end
end

local function createMap()
    map = {}
    visibleMap = {}
    exploredMap = {}
    rooms = {}

    local biomes = {"dungeon", "forest", "ice_cave", "volcano"}
    currentBiome = biomes[math.random(1, #biomes)]

    if currentBiome == "forest" then
        COLOR_WALL = {0.2, 0.4, 0.2}
        COLOR_FLOOR = {0.3, 0.5, 0.3}
    elseif currentBiome == "ice_cave" then
        COLOR_WALL = {0.6, 0.8, 0.9}
        COLOR_FLOOR = {0.8, 0.9, 1.0}
    elseif currentBiome == "volcano" then
        COLOR_WALL = {0.3, 0.1, 0.1}
        COLOR_FLOOR = {0.4, 0.2, 0.1}
    else
        COLOR_WALL = {0.3, 0.3, 0.4}
        COLOR_FLOOR = {0.6, 0.6, 0.5}
    end
    -- 타일셋 색상만 반환하고 렌더링은 main.lua에서 수행

    for y = 1, MAP_HEIGHT do
        map[y] = {}
        visibleMap[y] = {}
        exploredMap[y] = {}
        for x = 1, MAP_WIDTH do
            map[y][x] = TILE_WALL
            visibleMap[y][x] = false
            exploredMap[y][x] = false
        end
    end

    local roomAttempts = MAX_ROOMS + math.random(0, 4)
    for i = 1, roomAttempts do
        local w = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local h = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local x = math.random(2, MAP_WIDTH - w - 1)
        local y = math.random(2, MAP_HEIGHT - h - 1)

        local overlap = false
        for _, room in ipairs(rooms) do
            if x <= room.x + room.w + 1 and x + w + 1 >= room.x and
               y <= room.y + room.h + 1 and y + h + 1 >= room.y then
                overlap = true
                break
            end
        end

        if not overlap then
            local room = {x = x, y = y, w = w, h = h,
                          cx = math.floor(x + w / 2),
                          cy = math.floor(y + h / 2)}
            local shapes = {"rect", "rect", "cross", "round", "chamber"}
            carveRoomShape(room, shapes[math.random(1, #shapes)])
            table.insert(rooms, room)

            if #rooms > 1 then
                local prev = rooms[#rooms - 1]
                carveCorridor(prev.cx, prev.cy, room.cx, room.cy)
            end
        end
    end

    -- 가끔 떨어진 방끼리 추가 연결해 순환 구조를 만든다.
    for _ = 1, math.random(1, 3) do
        if #rooms >= 3 then
            local a = rooms[math.random(1, #rooms)]
            local b = rooms[math.random(1, #rooms)]
            if a ~= b then
                carveCorridor(a.cx, a.cy, b.cx, b.cy)
            end
        end
    end

    generateSpecialTerrain()

    local stairUpX, stairUpY, stairDownX, stairDownY
    if #rooms > 1 then
        local firstRoom = rooms[1]
        local lastRoom = rooms[#rooms]
        if floor > 1 then
            map[firstRoom.cy][firstRoom.cx] = TILE_STAIR_UP
            stairUpX = firstRoom.cx
            stairUpY = firstRoom.cy
        end
        map[lastRoom.cy][lastRoom.cx] = TILE_STAIR_DOWN
        stairDownX = lastRoom.cx
        stairDownY = lastRoom.cy
    end
    
    -- Spawn Altars
    local altarTypes = {Constants.TILE_ALTAR_WAR, Constants.TILE_ALTAR_SHADOW, Constants.TILE_ALTAR_MAGIC}
    if math.random() < 0.4 and #rooms > 2 then
        local altarRoom = rooms[math.random(2, #rooms - 1)]
        local ax, ay = getRandomFloorInRoom(altarRoom)
        local altarType = altarTypes[math.random(1, #altarTypes)]
        map[ay][ax] = altarType
    end

    return stairUpX, stairUpY, stairDownX, stairDownY
end

local function getRandomFloorInRoom(room)
    for _ = 1, 30 do
        local x = math.random(room.x + 1, room.x + room.w - 2)
        local y = math.random(room.y + 1, room.y + room.h - 2)
        if map[y] and map[y][x] ~= TILE_WALL and map[y][x] ~= TILE_LAVA and map[y][x] ~= TILE_STAIR_UP and map[y][x] ~= TILE_STAIR_DOWN then
            return x, y
        end
    end
    return room.cx, room.cy
end



-- ===== 플레이어 초기화 =====

function MapGen.generate(currentFloor)
    floor = currentFloor
    local upX, upY, downX, downY = createMap()
    return {
        map = map,
        visibleMap = visibleMap,
        exploredMap = exploredMap,
        rooms = rooms,
        colorWall = COLOR_WALL,
        colorFloor = COLOR_FLOOR,
        stairUpX = upX,
        stairUpY = upY,
        stairDownX = downX,
        stairDownY = downY
    }
end

return MapGen
