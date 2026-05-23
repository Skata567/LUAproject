-- Roguelike + Extraction RPG Inventory (LÖVE2D)
-- 기존 로그라이크 던전 + 그리드 기반 인벤토리 + 장비 시스템

local Item = require("item")
local Inventory = require("inventory")
local Equipment = require("equipment")

-- ===== 설정 =====
local TILE_SIZE = 16
local MAP_WIDTH = 50
local MAP_HEIGHT = 35
local MAX_ROOMS = 10
local MIN_ROOM_SIZE = 4
local MAX_ROOM_SIZE = 10
local MAX_ENEMIES_PER_ROOM = 3
local MAX_ITEMS_PER_ROOM = 2

-- 타일 종류
local TILE_WALL = 0
local TILE_FLOOR = 1
local TILE_STAIR = 2

-- 색상
local COLOR_WALL     = {0.3, 0.3, 0.4}
local COLOR_FLOOR    = {0.6, 0.6, 0.5}
local COLOR_PLAYER   = {1, 1, 0}
local COLOR_STAIR    = {1, 0.8, 0}
local COLOR_HUD_BG   = {0.1, 0.1, 0.15, 0.9}
local COLOR_HP_BAR   = {0.8, 0.1, 0.1}
local COLOR_HP_BG    = {0.3, 0.1, 0.1}
local COLOR_WHITE    = {1, 1, 1}
local COLOR_GRAY     = {0.5, 0.5, 0.5}
local COLOR_GOLD     = {1, 0.85, 0}

-- 게임 상태
local gameState = "playing" -- playing, inventory, gameover, win
local map = {}
local rooms = {}
local player = {}
local enemies = {}
local groundItems = {}  -- 바닥에 있는 아이템
local messages = {}
local turn = 0
local floor = 1
local font = nil
local messageScroll = 0
local MAX_VISIBLE_MESSAGES = 8

-- 인벤토리 & 장비
local inv = nil
local equip = nil

-- 드래그 상태
local drag = {
    item = nil,
    fromInv = nil,
    fromSlot = nil,
}
local hoverItem = nil

-- 바닥 아이템 드롭 테이블 (층별 가중치)
local DROP_TABLE = {
    {id = "health_potion", weight = 30, minFloor = 1},
    {id = "large_potion",  weight = 10, minFloor = 2},
    {id = "gold_coin",     weight = 25, minFloor = 1},
    {id = "short_sword",   weight = 15, minFloor = 1},
    {id = "long_sword",    weight = 8,  minFloor = 2},
    {id = "battle_axe",    weight = 5,  minFloor = 3},
    {id = "leather_armor", weight = 12, minFloor = 1},
    {id = "chain_mail",    weight = 6,  minFloor = 2},
    {id = "iron_helmet",   weight = 10, minFloor = 1},
    {id = "leather_boots", weight = 10, minFloor = 1},
    {id = "swift_boots",   weight = 4,  minFloor = 3},
    {id = "copper_ring",   weight = 8,  minFloor = 1},
    {id = "ruby_ring",     weight = 3,  minFloor = 4},
    {id = "silver_amulet", weight = 6,  minFloor = 2},
    {id = "royal_crown",   weight = 2,  minFloor = 4},
    {id = "dragon_scale",  weight = 1,  minFloor = 5},
    {id = "dragon_blade",  weight = 1,  minFloor = 5},
    {id = "dragon_armor",  weight = 1,  minFloor = 5},
}

-- ===== 유틸리티 =====
local function addMessage(text)
    table.insert(messages, 1, text)
    messageScroll = 0
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

--- 드롭 테이블에서 랜덤 아이템 생성
local function rollDrop()
    local available = {}
    local totalWeight = 0
    for _, entry in ipairs(DROP_TABLE) do
        if floor >= entry.minFloor then
            table.insert(available, entry)
            totalWeight = totalWeight + entry.weight
        end
    end
    if #available == 0 then return nil end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(available) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            local item = Item.create(entry.id)
            if item and item.stackable then
                if item.id == "gold_coin" then
                    item.count = math.random(5, 15 + floor * 5)
                elseif item.id == "health_potion" then
                    item.count = math.random(1, 2)
                end
            end
            return item
        end
    end
    return nil
end

-- ===== 맵 생성 =====
local function createMap()
    map = {}
    rooms = {}
    enemies = {}
    groundItems = {}

    for y = 1, MAP_HEIGHT do
        map[y] = {}
        for x = 1, MAP_WIDTH do
            map[y][x] = TILE_WALL
        end
    end

    for i = 1, MAX_ROOMS do
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
            for ry = y, y + h - 1 do
                for rx = x, x + w - 1 do
                    map[ry][rx] = TILE_FLOOR
                end
            end

            local room = {x = x, y = y, w = w, h = h,
                          cx = math.floor(x + w / 2),
                          cy = math.floor(y + h / 2)}
            table.insert(rooms, room)

            if #rooms > 1 then
                local prev = rooms[#rooms - 1]
                local sx = math.min(prev.cx, room.cx)
                local ex = math.max(prev.cx, room.cx)
                for cx = sx, ex do
                    if map[prev.cy] then
                        map[prev.cy][cx] = TILE_FLOOR
                    end
                end
                local sy = math.min(prev.cy, room.cy)
                local ey = math.max(prev.cy, room.cy)
                for cy = sy, ey do
                    if map[cy] then
                        map[cy][room.cx] = TILE_FLOOR
                    end
                end
            end
        end
    end

    if #rooms > 1 then
        local lastRoom = rooms[#rooms]
        map[lastRoom.cy][lastRoom.cx] = TILE_STAIR
    end
end

-- ===== 적 생성 =====
local function spawnEnemies()
    local enemyTypes = {
        {name = "고블린",  char = "g", hp = 3,  atk = 1, exp = 5,  color = {0, 0.8, 0}},
        {name = "오크",    char = "o", hp = 6,  atk = 2, exp = 10, color = {0.5, 0.8, 0.2}},
        {name = "트롤",    char = "T", hp = 10, atk = 3, exp = 20, color = {0.3, 0.6, 0.3}},
        {name = "드래곤",  char = "D", hp = 20, atk = 5, exp = 50, color = {1, 0.2, 0}},
    }

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(1, MAX_ENEMIES_PER_ROOM)
        for j = 1, count do
            local ex = math.random(room.x + 1, room.x + room.w - 2)
            local ey = math.random(room.y + 1, room.y + room.h - 2)

            local maxType = math.min(#enemyTypes, floor + 1)
            local typeIdx = math.random(1, maxType)
            local etype = enemyTypes[typeIdx]

            local hpBonus = (floor - 1) * 2
            local atkBonus = math.floor((floor - 1) / 2)

            table.insert(enemies, {
                x = ex, y = ey,
                name = etype.name,
                char = etype.char,
                hp = etype.hp + hpBonus,
                maxHp = etype.hp + hpBonus,
                atk = etype.atk + atkBonus,
                exp = etype.exp,
                color = etype.color,
                alive = true
            })
        end
    end
end

-- ===== 바닥 아이템 생성 =====
local function spawnGroundItems()
    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(0, MAX_ITEMS_PER_ROOM)
        for j = 1, count do
            local ix = math.random(room.x + 1, room.x + room.w - 2)
            local iy = math.random(room.y + 1, room.y + room.h - 2)
            local item = rollDrop()
            if item then
                table.insert(groundItems, {
                    x = ix, y = iy,
                    item = item,
                    picked = false,
                })
            end
        end
    end
end

-- ===== 플레이어 초기화 =====
local function initPlayer(keepStats)
    local startRoom = rooms[1]
    if keepStats then
        player.x = startRoom.cx
        player.y = startRoom.cy
    else
        player = {
            x = startRoom.cx,
            y = startRoom.cy,
            char = "@",
            hp = 30,
            maxHp = 30,
            baseAtk = 3,
            baseDef = 0,
            exp = 0,
            nextExp = 20,
            level = 1,
            gold = 0,
        }
    end
end

--- 장비 스탯 포함 최종 스탯 계산
local function getPlayerAtk()
    local bonus = equip and equip:getTotalStats().atk or 0
    return player.baseAtk + bonus
end

local function getPlayerDef()
    local bonus = equip and equip:getTotalStats().def or 0
    return player.baseDef + bonus
end

-- ===== 레벨업 =====
local function checkLevelUp()
    while player.exp >= player.nextExp do
        player.exp = player.exp - player.nextExp
        player.level = player.level + 1
        player.maxHp = player.maxHp + 5
        player.hp = player.maxHp
        player.baseAtk = player.baseAtk + 1
        player.nextExp = math.floor(player.nextExp * 1.5)
        addMessage("** 레벨 업! Lv." .. player.level .. " **")
    end
end

-- ===== 전투 =====
local function attackEnemy(enemy)
    local atk = getPlayerAtk()
    local dmg = math.max(1, atk - math.floor(math.random() * 2))
    enemy.hp = enemy.hp - dmg
    addMessage(enemy.name .. "에게 " .. dmg .. " 데미지!")

    if enemy.hp <= 0 then
        enemy.alive = false
        player.exp = player.exp + enemy.exp
        addMessage(enemy.name .. " 처치! (+" .. enemy.exp .. " 경험치)")

        -- 적 처치 시 아이템 드롭 (50% 확률)
        if math.random() < 0.5 then
            local drop = rollDrop()
            if drop then
                table.insert(groundItems, {
                    x = enemy.x, y = enemy.y,
                    item = drop,
                    picked = false,
                })
                addMessage("  → " .. drop.name .. " 드롭!")
            end
        end

        checkLevelUp()
    end
end

local function enemyAttack(enemy)
    local def = getPlayerDef()
    local dmg = math.max(1, enemy.atk - def)
    player.hp = player.hp - dmg
    addMessage(enemy.name .. "이(가) " .. dmg .. " 데미지!")

    if player.hp <= 0 then
        gameState = "gameover"
        addMessage("** 사망했습니다! **")
    end
end

-- ===== 아이템 줍기 (인벤토리로) =====
local function pickupItem()
    for _, gi in ipairs(groundItems) do
        if not gi.picked and gi.x == player.x and gi.y == player.y then
            if inv:autoPlace(gi.item) then
                gi.picked = true
                addMessage(gi.item.name .. " 획득! (인벤토리)")
            else
                addMessage("인벤토리가 꽉 찼습니다!")
            end
        end
    end
end

-- ===== 계단 =====
local function checkStair()
    if map[player.y] and map[player.y][player.x] == TILE_STAIR then
        floor = floor + 1
        if floor > 5 then
            gameState = "win"
            addMessage("** 던전 탈출 성공! **")
            return
        end
        addMessage(">> " .. floor .. "층으로 이동 <<")
        createMap()
        spawnEnemies()
        spawnGroundItems()
        initPlayer(true)
    end
end

-- ===== 적 AI =====
local function moveEnemies()
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dist = distance(enemy.x, enemy.y, player.x, player.y)
            if dist <= 1 then
                enemyAttack(enemy)
            elseif dist <= 8 then
                local dx, dy = 0, 0
                if enemy.x < player.x then dx = 1
                elseif enemy.x > player.x then dx = -1 end
                if enemy.y < player.y then dy = 1
                elseif enemy.y > player.y then dy = -1 end

                if math.random() > 0.5 then dy = 0 else dx = 0 end

                local nx, ny = enemy.x + dx, enemy.y + dy
                if ny >= 1 and ny <= MAP_HEIGHT and nx >= 1 and nx <= MAP_WIDTH then
                    if map[ny][nx] ~= TILE_WALL then
                        local blocked = false
                        for _, other in ipairs(enemies) do
                            if other ~= enemy and other.alive and other.x == nx and other.y == ny then
                                blocked = true
                                break
                            end
                        end
                        if nx == player.x and ny == player.y then
                            blocked = true
                        end
                        if not blocked then
                            enemy.x = nx
                            enemy.y = ny
                        end
                    end
                end
            end
        end
    end
end

-- ===== 플레이어 이동 =====
local function movePlayer(dx, dy)
    if gameState ~= "playing" then return end

    local nx = player.x + dx
    local ny = player.y + dy

    if ny < 1 or ny > MAP_HEIGHT or nx < 1 or nx > MAP_WIDTH then return end
    if map[ny][nx] == TILE_WALL then return end

    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.x == nx and enemy.y == ny then
            attackEnemy(enemy)
            turn = turn + 1
            moveEnemies()
            return
        end
    end

    player.x = nx
    player.y = ny
    turn = turn + 1

    pickupItem()
    checkStair()
    moveEnemies()
end

-- ===== LÖVE2D 콜백 =====
function love.load()
    love.window.setTitle("Extraction Roguelike")
    love.window.setMode(MAP_WIDTH * TILE_SIZE + 250, MAP_HEIGHT * TILE_SIZE + 10, {resizable = false})

    font = love.graphics.newFont("NanumGothicCoding.ttf", 13)
    love.graphics.setFont(font)

    math.randomseed(os.time())

    -- 인벤토리 & 장비 초기화
    inv = Inventory.new(10, 6)
    equip = Equipment.new()

    addMessage("던전에 오신 것을 환영합니다!")
    addMessage("방향키/WASD: 이동 | I: 인벤토리")
    addMessage("계단(>)을 찾아 5층까지 탈출하세요!")
    addMessage("적을 처치하면 아이템이 드롭됩니다!")

    createMap()
    spawnEnemies()
    spawnGroundItems()
    initPlayer()

    -- 시작 아이템
    local starter = Item.create("short_sword")
    if starter then inv:autoPlace(starter) end
    local pot = Item.create("health_potion")
    if pot then pot.count = 3; inv:autoPlace(pot) end
end

function love.update(dt)
    if gameState == "inventory" then
        if not drag.item then
            local mx, my = love.mouse.getPosition()
            hoverItem = inv:getItemAt(mx, my)
            if not hoverItem then
                local slot = equip:getSlotAt(mx, my)
                if slot then
                    hoverItem = equip:getItem(slot)
                end
            end
        end
    end
end

function love.keypressed(key)
    -- 인벤토리 토글
    if key == "i" or key == "tab" then
        if gameState == "playing" then
            gameState = "inventory"
            drag.item = nil
            hoverItem = nil
            return
        elseif gameState == "inventory" then
            gameState = "playing"
            drag.item = nil
            hoverItem = nil
            return
        end
    end

    if key == "escape" and gameState == "inventory" then
        gameState = "playing"
        drag.item = nil
        hoverItem = nil
        return
    end

    if gameState == "gameover" or gameState == "win" then
        if key == "r" then
            gameState = "playing"
            floor = 1
            turn = 0
            messages = {}
            inv = Inventory.new(10, 6)
            equip = Equipment.new()
            addMessage("새 게임 시작!")
            createMap()
            spawnEnemies()
            spawnGroundItems()
            initPlayer()
            local starter = Item.create("short_sword")
            if starter then inv:autoPlace(starter) end
            local pot = Item.create("health_potion")
            if pot then pot.count = 3; inv:autoPlace(pot) end
        end
        return
    end

    if gameState ~= "playing" then return end

    if key == "up" or key == "w" then
        movePlayer(0, -1)
    elseif key == "down" or key == "s" then
        movePlayer(0, 1)
    elseif key == "left" or key == "a" then
        movePlayer(-1, 0)
    elseif key == "right" or key == "d" then
        movePlayer(1, 0)
    elseif key == "space" then
        turn = turn + 1
        moveEnemies()
    elseif key == "pageup" then
        messageScroll = math.min(messageScroll + 3, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
    elseif key == "pagedown" then
        messageScroll = math.max(0, messageScroll - 3)
    end
end

function love.mousepressed(x, y, button)
    if gameState ~= "inventory" then return end

    if button == 1 then
        local item = inv:getItemAt(x, y)
        if item then
            drag.item = item
            drag.fromInv = true
            drag.fromSlot = nil
            inv:removeItem(item)
            hoverItem = nil
            return
        end

        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                drag.item = eqItem
                drag.fromInv = false
                drag.fromSlot = slot
                hoverItem = nil
                return
            end
        end

    elseif button == 2 then
        local item = inv:getItemAt(x, y)
        if item then
            -- 포션 사용
            if item.id == "health_potion" then
                player.hp = math.min(player.maxHp, player.hp + 30)
                addMessage("체력 포션 사용! (+30 HP)")
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                return
            elseif item.id == "large_potion" then
                player.hp = math.min(player.maxHp, player.hp + 80)
                addMessage("대형 포션 사용! (+80 HP)")
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                return
            end
            -- 장비 장착
            if item.slot then
                inv:removeItem(item)
                local prev = equip:equip(item)
                if prev then
                    inv:autoPlace(prev)
                end
                addMessage(item.name .. " 장착!")
                return
            end
        end

        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                if inv:autoPlace(eqItem) then
                    addMessage(eqItem.name .. " 해제!")
                else
                    equip:equip(eqItem)
                    addMessage("인벤토리가 꽉 찼습니다!")
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and drag.item then
        local item = drag.item

        local col, row = inv:screenToGrid(x, y)
        col = col - math.floor(item.gridW / 2)
        row = row - math.floor(item.gridH / 2)

        if inv:canPlace(item, col, row) then
            inv:placeItem(item, col, row)
            drag.item = nil
            return
        end

        local slot = equip:getSlotAt(x, y)
        if slot and item.slot == slot then
            local prev = equip:equip(item)
            if prev then inv:autoPlace(prev) end
            drag.item = nil
            return
        end

        if drag.fromInv then
            inv:autoPlace(item)
        elseif drag.fromSlot then
            equip:equip(item)
        end

        drag.item = nil
    end
end

function love.wheelmoved(x, y)
    if gameState == "playing" then
        if y > 0 then
            messageScroll = math.min(messageScroll + 2, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
        elseif y < 0 then
            messageScroll = math.max(0, messageScroll - 2)
        end
    end
end

-- ===== 그리기 =====
local function drawGame()
    -- 맵
    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            local tile = map[y][x]
            local sx = (x - 1) * TILE_SIZE
            local sy = (y - 1) * TILE_SIZE

            if tile == TILE_FLOOR then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(0.5, 0.5, 0.4)
                love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
            elseif tile == TILE_WALL then
                love.graphics.setColor(COLOR_WALL)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(0.25, 0.25, 0.35)
                love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
            elseif tile == TILE_STAIR then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(COLOR_STAIR)
                love.graphics.print(">", sx + 3, sy)
            end
        end
    end

    -- 바닥 아이템
    for _, gi in ipairs(groundItems) do
        if not gi.picked then
            local rc = gi.item:getRarityColor()
            love.graphics.setColor(rc[1], rc[2], rc[3])
            love.graphics.print(gi.item.icon, (gi.x - 1) * TILE_SIZE + 3, (gi.y - 1) * TILE_SIZE)
        end
    end

    -- 적
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            love.graphics.setColor(enemy.color)
            love.graphics.print(enemy.char, (enemy.x - 1) * TILE_SIZE + 3, (enemy.y - 1) * TILE_SIZE)
        end
    end

    -- 플레이어
    love.graphics.setColor(COLOR_PLAYER)
    love.graphics.print(player.char, (player.x - 1) * TILE_SIZE + 3, (player.y - 1) * TILE_SIZE)

    -- ===== HUD =====
    local hudX = MAP_WIDTH * TILE_SIZE + 10
    local hudY = 10
    local hudW = 230

    love.graphics.setColor(COLOR_HUD_BG)
    love.graphics.rectangle("fill", hudX - 5, 0, hudW + 10, MAP_HEIGHT * TILE_SIZE + 10)

    -- 플레이어 정보
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("=== 플레이어 ===", hudX, hudY)
    hudY = hudY + 22

    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("레벨 " .. player.level .. "  " .. floor .. "층  턴: " .. turn, hudX, hudY)
    hudY = hudY + 18

    -- HP 바
    love.graphics.setColor(COLOR_HP_BG)
    love.graphics.rectangle("fill", hudX, hudY, 200, 14)
    love.graphics.setColor(COLOR_HP_BAR)
    local hpRatio = player.hp / player.maxHp
    love.graphics.rectangle("fill", hudX, hudY, 200 * hpRatio, 14)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("체력: " .. player.hp .. "/" .. player.maxHp, hudX + 5, hudY)
    hudY = hudY + 18

    -- EXP 바
    love.graphics.setColor(0.1, 0.1, 0.4)
    love.graphics.rectangle("fill", hudX, hudY, 200, 12)
    love.graphics.setColor(0.3, 0.3, 1)
    local expRatio = player.exp / player.nextExp
    love.graphics.rectangle("fill", hudX, hudY, 200 * expRatio, 12)
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("경험치: " .. player.exp .. "/" .. player.nextExp, hudX + 5, hudY - 1)
    hudY = hudY + 18

    -- 스탯 (장비 보너스 포함)
    local eqStats = equip:getTotalStats()
    love.graphics.setColor(1, 0.4, 0.4)
    local atkText = "공격력: " .. player.baseAtk
    if eqStats.atk > 0 then atkText = atkText .. " +" .. eqStats.atk end
    love.graphics.print(atkText, hudX, hudY)
    hudY = hudY + 16

    love.graphics.setColor(0.4, 0.6, 1)
    local defText = "방어력: " .. player.baseDef
    if eqStats.def > 0 then defText = defText .. " +" .. eqStats.def end
    love.graphics.print(defText, hudX, hudY)
    hudY = hudY + 16

    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("골드: " .. player.gold, hudX, hudY)
    hudY = hudY + 22

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("--- 조작법 ---", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("방향키/WASD: 이동", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("적에게 부딪히기: 공격", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("Space: 턴 대기", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("I/Tab: 인벤토리", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print(">: 계단 (밟으면 이동)", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("PgUp/PgDn/휠: 로그", hudX, hudY)
    hudY = hudY + 22

    -- 메시지 로그
    love.graphics.setColor(COLOR_GOLD)
    local scrollInfo = ""
    if #messages > MAX_VISIBLE_MESSAGES then
        scrollInfo = " (" .. (messageScroll + 1) .. "-" .. math.min(messageScroll + MAX_VISIBLE_MESSAGES, #messages) .. "/" .. #messages .. ")"
    end
    love.graphics.print("--- 메시지 ---" .. scrollInfo, hudX, hudY)
    hudY = hudY + 18

    if messageScroll > 0 then
        love.graphics.setColor(COLOR_GOLD)
        love.graphics.print("  ▲ PgUp / 휠↑", hudX, hudY - 4)
    end

    for i = 1 + messageScroll, math.min(#messages, MAX_VISIBLE_MESSAGES + messageScroll) do
        local msg = messages[i]
        local alpha = 1 - (i - 1 - messageScroll) * 0.1
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(msg, hudX, hudY)
        hudY = hudY + 14
    end

    if messageScroll + MAX_VISIBLE_MESSAGES < #messages then
        love.graphics.setColor(COLOR_GRAY)
        love.graphics.print("  ▼ PgDn / 휠↓", hudX, hudY)
    end

    -- 게임오버 / 승리 화면
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("게임 오버", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf(floor .. "층  레벨 " .. player.level .. "  턴: " .. turn, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("R키를 눌러 재시작", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
    elseif gameState == "win" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(COLOR_GOLD)
        love.graphics.printf("탈출 성공!", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf(floor .. "층  레벨 " .. player.level .. "  골드: " .. player.gold .. "  턴: " .. turn, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.printf("R키를 눌러 재시작", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
    end
end

local function drawInventory()
    -- 어두운 배경
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- 인벤토리 위치 설정
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    inv.x = 30
    inv.y = 50

    equip.x = inv.x + inv.cols * inv.cellSize + 140
    equip.y = 170

    -- 인벤토리 그리기
    inv:draw(font)

    -- 장비 패널
    equip:draw(font)

    -- 장비 스탯
    equip:drawStats(equip.x - 80, equip.y + 130)

    -- 플레이어 현재 스탯
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("=== 전투 스탯 ===", equip.x - 80, equip.y + 250)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("공격력: " .. getPlayerAtk() .. " (기본 " .. player.baseAtk .. ")", equip.x - 76, equip.y + 270)
    love.graphics.print("방어력: " .. getPlayerDef() .. " (기본 " .. player.baseDef .. ")", equip.x - 76, equip.y + 286)

    -- 타이틀
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.printf("EXTRACTION INVENTORY", 0, 10, sw, "center")
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 장착/사용 | I/Tab/Esc: 닫기", 0, 28, sw, "center")

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end
end

function love.draw()
    drawGame()
    if gameState == "inventory" then
        drawInventory()
    end
end
