-- Roguelike Game (LÖVE2D)
-- 기본 로그라이크 요소: 던전, 플레이어, 적, 아이템, 턴제 전투
--[[
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
local COLOR_ENEMY    = {1, 0, 0}
local COLOR_BOSS     = {1, 0, 0.5}
local COLOR_ITEM     = {0, 0.8, 1}
local COLOR_STAIR    = {1, 0.8, 0}
local COLOR_HUD_BG   = {0.1, 0.1, 0.15, 0.9}
local COLOR_HP_BAR   = {0.8, 0.1, 0.1}
local COLOR_HP_BG    = {0.3, 0.1, 0.1}
local COLOR_WHITE    = {1, 1, 1}
local COLOR_GRAY     = {0.5, 0.5, 0.5}
local COLOR_GOLD     = {1, 0.85, 0}

-- 게임 상태
local gameState = "playing" -- playing, gameover, win
local map = {}
local rooms = {}
local player = {}
local enemies = {}
local items = {}
local messages = {}
local turn = 0
local floor = 1
local camera = {x = 0, y = 0}
local font = nil
local messageScroll = 0
local MAX_VISIBLE_MESSAGES = 8

-- ===== 유틸리티 =====
local function addMessage(text)
    table.insert(messages, 1, text)
    messageScroll = 0
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- ===== 맵 생성 =====
local function createMap()
    map = {}
    rooms = {}
    enemies = {}
    items = {}

    -- 벽으로 초기화
    for y = 1, MAP_HEIGHT do
        map[y] = {}
        for x = 1, MAP_WIDTH do
            map[y][x] = TILE_WALL
        end
    end

    -- 방 생성
    for i = 1, MAX_ROOMS do
        local w = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local h = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local x = math.random(2, MAP_WIDTH - w - 1)
        local y = math.random(2, MAP_HEIGHT - h - 1)

        -- 겹침 확인
        local overlap = false
        for _, room in ipairs(rooms) do
            if x <= room.x + room.w + 1 and x + w + 1 >= room.x and
               y <= room.y + room.h + 1 and y + h + 1 >= room.y then
                overlap = true
                break
            end
        end

        if not overlap then
            -- 방 바닥 생성
            for ry = y, y + h - 1 do
                for rx = x, x + w - 1 do
                    map[ry][rx] = TILE_FLOOR
                end
            end

            local room = {x = x, y = y, w = w, h = h,
                          cx = math.floor(x + w / 2),
                          cy = math.floor(y + h / 2)}
            table.insert(rooms, room)

            -- 복도 연결
            if #rooms > 1 then
                local prev = rooms[#rooms - 1]
                -- 수평 복도
                local sx = math.min(prev.cx, room.cx)
                local ex = math.max(prev.cx, room.cx)
                for cx = sx, ex do
                    if map[prev.cy] then
                        map[prev.cy][cx] = TILE_FLOOR
                    end
                end
                -- 수직 복도
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

    -- 마지막 방에 계단 배치
    if #rooms > 1 then
        local lastRoom = rooms[#rooms]
        map[lastRoom.cy][lastRoom.cx] = TILE_STAIR
    end
end

-- ===== 적 생성 =====
local function spawnEnemies()
    local enemyTypes = {
        {name = "Goblin",  char = "g", hp = 3,  atk = 1, exp = 5,  color = {0, 0.8, 0}},
        {name = "Orc",     char = "o", hp = 6,  atk = 2, exp = 10, color = {0.5, 0.8, 0.2}},
        {name = "Troll",   char = "T", hp = 10, atk = 3, exp = 20, color = {0.3, 0.6, 0.3}},
        {name = "Dragon",  char = "D", hp = 20, atk = 5, exp = 50, color = {1, 0.2, 0}},
    }

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(1, MAX_ENEMIES_PER_ROOM)
        for j = 1, count do
            local ex = math.random(room.x + 1, room.x + room.w - 2)
            local ey = math.random(room.y + 1, room.y + room.h - 2)

            -- 층에 따라 적 난이도 조정
            local maxType = math.min(#enemyTypes, floor + 1)
            local typeIdx = math.random(1, maxType)
            local etype = enemyTypes[typeIdx]

            -- 층 보너스 스탯
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

-- ===== 아이템 생성 =====
local function spawnItems()
    local itemTypes = {
        {name = "Health Potion", char = "!", effect = "heal",    value = 10, color = {1, 0.2, 0.2}},
        {name = "Power Scroll", char = "?", effect = "power",   value = 1,  color = {0.5, 0.5, 1}},
        {name = "Gold",         char = "$", effect = "gold",    value = 10, color = {1, 0.85, 0}},
        {name = "Armor Shard",  char = "]", effect = "defense", value = 1,  color = {0.5, 0.8, 1}},
    }

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(0, MAX_ITEMS_PER_ROOM)
        for j = 1, count do
            local ix = math.random(room.x + 1, room.x + room.w - 2)
            local iy = math.random(room.y + 1, room.y + room.h - 2)

            local itype = itemTypes[math.random(1, #itemTypes)]
            table.insert(items, {
                x = ix, y = iy,
                name = itype.name,
                char = itype.char,
                effect = itype.effect,
                value = itype.value + math.floor(floor / 2),
                color = itype.color,
                picked = false
            })
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
            atk = 3,
            def = 0,
            exp = 0,
            nextExp = 20,
            level = 1,
            gold = 0
        }
    end
end

-- ===== 레벨업 =====
local function checkLevelUp()
    while player.exp >= player.nextExp do
        player.exp = player.exp - player.nextExp
        player.level = player.level + 1
        player.maxHp = player.maxHp + 5
        player.hp = player.maxHp
        player.atk = player.atk + 1
        player.nextExp = math.floor(player.nextExp * 1.5)
        addMessage("** 레벨 업! Lv." .. player.level .. " **")
    end
end

-- ===== 전투 =====
local function attackEnemy(enemy)
    local dmg = math.max(1, player.atk - math.floor(math.random() * 2))
    enemy.hp = enemy.hp - dmg
    addMessage(enemy.name .. "에게 " .. dmg .. " 데미지!")

    if enemy.hp <= 0 then
        enemy.alive = false
        player.exp = player.exp + enemy.exp
        addMessage(enemy.name .. " 처치! (+" .. enemy.exp .. " 경험치)")
        checkLevelUp()
    end
end

local function enemyAttack(enemy)
    local dmg = math.max(1, enemy.atk - player.def)
    player.hp = player.hp - dmg
    addMessage(enemy.name .. "이(가) " .. dmg .. " 데미지!")

    if player.hp <= 0 then
        gameState = "gameover"
        addMessage("** 사망했습니다! **")
    end
end

-- ===== 아이템 줍기 =====
local function pickupItem()
    for _, item in ipairs(items) do
        if not item.picked and item.x == player.x and item.y == player.y then
            item.picked = true
            if item.effect == "heal" then
                player.hp = math.min(player.maxHp, player.hp + item.value)
                addMessage(item.name .. " 사용! (+" .. item.value .. " 체력)")
            elseif item.effect == "power" then
                player.atk = player.atk + item.value
                addMessage(item.name .. " 사용! (+" .. item.value .. " 공격력)")
            elseif item.effect == "gold" then
                player.gold = player.gold + item.value
                addMessage("골드 " .. item.value .. " 획득!")
            elseif item.effect == "defense" then
                player.def = player.def + item.value
                addMessage(item.name .. " 사용! (+" .. item.value .. " 방어력)")
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
        spawnItems()
        initPlayer(true)
    end
end

-- ===== 적 AI (턴) =====
local function moveEnemies()
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dist = distance(enemy.x, enemy.y, player.x, player.y)
            if dist <= 1 then
                enemyAttack(enemy)
            elseif dist <= 8 then
                -- 플레이어 쪽으로 이동
                local dx, dy = 0, 0
                if enemy.x < player.x then dx = 1
                elseif enemy.x > player.x then dx = -1 end
                if enemy.y < player.y then dy = 1
                elseif enemy.y > player.y then dy = -1 end

                -- 한 축만 이동 (간단한 AI)
                if math.random() > 0.5 then dy = 0 else dx = 0 end

                local nx, ny = enemy.x + dx, enemy.y + dy
                if ny >= 1 and ny <= MAP_HEIGHT and nx >= 1 and nx <= MAP_WIDTH then
                    if map[ny][nx] ~= TILE_WALL then
                        -- 다른 적과 겹치지 않는지 확인
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

    -- 맵 범위 확인
    if ny < 1 or ny > MAP_HEIGHT or nx < 1 or nx > MAP_WIDTH then return end
    -- 벽 확인
    if map[ny][nx] == TILE_WALL then return end

    -- 적 확인 (bump-to-attack)
    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.x == nx and enemy.y == ny then
            attackEnemy(enemy)
            turn = turn + 1
            moveEnemies()
            return
        end
    end

    -- 이동
    player.x = nx
    player.y = ny
    turn = turn + 1

    pickupItem()
    checkStair()
    moveEnemies()
end

-- ===== LÖVE2D 콜백 =====
function love.load()
    love.window.setTitle("Roguelike Dungeon")
    love.window.setMode(MAP_WIDTH * TILE_SIZE + 250, MAP_HEIGHT * TILE_SIZE + 10, {resizable = false})

    font = love.graphics.newFont("NanumGothicCoding.ttf", 14)
    love.graphics.setFont(font)

    math.randomseed(os.time())
    addMessage("던전에 오신 것을 환영합니다!")
    addMessage("방향키/WASD: 이동 및 공격")
    addMessage("계단(>)을 찾아 5층까지 탈출하세요!")

    createMap()
    spawnEnemies()
    spawnItems()
    initPlayer()
end

function love.keypressed(key)
    if gameState == "gameover" or gameState == "win" then
        if key == "r" then
            -- 재시작
            gameState = "playing"
            floor = 1
            turn = 0
            messages = {}
            addMessage("새 게임 시작!")
            createMap()
            spawnEnemies()
            spawnItems()
            initPlayer()
        end
        return
    end

    if key == "up" or key == "w" then
        movePlayer(0, -1)
    elseif key == "down" or key == "s" then
        movePlayer(0, 1)
    elseif key == "left" or key == "a" then
        movePlayer(-1, 0)
    elseif key == "right" or key == "d" then
        movePlayer(1, 0)
    elseif key == "space" then
        -- 대기 (턴 넘기기)
        turn = turn + 1
        moveEnemies()
    elseif key == "pageup" then
        messageScroll = math.min(messageScroll + 3, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
    elseif key == "pagedown" then
        messageScroll = math.max(0, messageScroll - 3)
    end
end

function love.wheelmoved(x, y)
    if y > 0 then
        messageScroll = math.min(messageScroll + 2, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
    elseif y < 0 then
        messageScroll = math.max(0, messageScroll - 2)
    end
end

function love.draw()
    -- 맵 그리기
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

    -- 아이템 그리기
    for _, item in ipairs(items) do
        if not item.picked then
            love.graphics.setColor(item.color)
            love.graphics.print(item.char, (item.x - 1) * TILE_SIZE + 3, (item.y - 1) * TILE_SIZE)
        end
    end

    -- 적 그리기
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            love.graphics.setColor(enemy.color)
            love.graphics.print(enemy.char, (enemy.x - 1) * TILE_SIZE + 3, (enemy.y - 1) * TILE_SIZE)
        end
    end

    -- 플레이어 그리기
    love.graphics.setColor(COLOR_PLAYER)
    love.graphics.print(player.char, (player.x - 1) * TILE_SIZE + 3, (player.y - 1) * TILE_SIZE)

    -- ===== HUD (오른쪽 패널) =====
    local hudX = MAP_WIDTH * TILE_SIZE + 10
    local hudY = 10
    local hudW = 230

    love.graphics.setColor(COLOR_HUD_BG)
    love.graphics.rectangle("fill", hudX - 5, 0, hudW + 10, MAP_HEIGHT * TILE_SIZE + 10)

    -- 플레이어 정보
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("=== 플레이어 ===", hudX, hudY)
    hudY = hudY + 25

    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("레벨 " .. player.level .. "  " .. floor .. "층", hudX, hudY)
    hudY = hudY + 20

    -- HP 바
    love.graphics.setColor(COLOR_HP_BG)
    love.graphics.rectangle("fill", hudX, hudY, 200, 16)
    love.graphics.setColor(COLOR_HP_BAR)
    local hpRatio = player.hp / player.maxHp
    love.graphics.rectangle("fill", hudX, hudY, 200 * hpRatio, 16)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("체력: " .. player.hp .. "/" .. player.maxHp, hudX + 5, hudY)
    hudY = hudY + 22

    -- EXP 바
    love.graphics.setColor(0.1, 0.1, 0.4)
    love.graphics.rectangle("fill", hudX, hudY, 200, 12)
    love.graphics.setColor(0.3, 0.3, 1)
    local expRatio = player.exp / player.nextExp
    love.graphics.rectangle("fill", hudX, hudY, 200 * expRatio, 12)
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("경험치: " .. player.exp .. "/" .. player.nextExp, hudX + 5, hudY - 1)
    hudY = hudY + 20

    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("공격력: " .. player.atk .. "  방어력: " .. player.def, hudX, hudY)
    hudY = hudY + 20
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("골드: " .. player.gold, hudX, hudY)
    hudY = hudY + 30

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("--- 조작법 ---", hudX, hudY)
    hudY = hudY + 18
    love.graphics.print("방향키/WASD: 이동", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("적에게 부딪히기: 공격", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("Space: 턴 대기", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print(">: 계단 (밟으면 이동)", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("PgUp/PgDn/휠: 로그", hudX, hudY)
    hudY = hudY + 30

    -- 메시지 로그
    love.graphics.setColor(COLOR_GOLD)
    local scrollInfo = ""
    if #messages > MAX_VISIBLE_MESSAGES then
        scrollInfo = " (" .. (messageScroll + 1) .. "-" .. math.min(messageScroll + MAX_VISIBLE_MESSAGES, #messages) .. "/" .. #messages .. ")"
    end
    love.graphics.print("--- 메시지 ---" .. scrollInfo, hudX, hudY)
    hudY = hudY + 20

    if messageScroll > 0 then
        love.graphics.setColor(COLOR_GOLD)
        love.graphics.print("  ▲ PgUp / 휠↑", hudX, hudY - 4)
    end

    for i = 1 + messageScroll, math.min(#messages, MAX_VISIBLE_MESSAGES + messageScroll) do
        local msg = messages[i]
        local alpha = 1 - (i - 1 - messageScroll) * 0.1
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(msg, hudX, hudY)
        hudY = hudY + 16
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
]]