-- Roguelike + Extraction RPG Inventory (LÖVE2D)
-- 기존 로그라이크 던전 + 그리드 기반 인벤토리 + 장비 시스템

local Item = require("item")
local Inventory = require("inventory")
local Equipment = require("equipment")
local Shop = require("shop")

-- ===== 설정 =====
local TILE_SIZE = 16
local MAP_WIDTH = 50
local MAP_HEIGHT = 35
local MAX_ROOMS = 10
local MIN_ROOM_SIZE = 4
local MAX_ROOM_SIZE = 10
local MAX_ENEMIES_PER_ROOM = 4
local MAX_ITEMS_PER_ROOM = 2

-- 스탯 포인트 배분 상태
local statAlloc = nil   -- {points=N, sel=1}  레벨업 시 활성화

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
local gameState = "playing" -- playing, inventory, town, shop, stash, gameover, levelup
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

-- 상점 & 마을
local shop = nil
local stash = nil           -- 보관함 (마을 인벤토리)
local townMenuSel = 1       -- 마을 메뉴 선택
local TOWN_MENU = {"상점", "보관함", "던전 출발", "저장"}
local dungeonRun = 0        -- 던전 탐험 횟수

-- 바닥 아이템 드롭 테이블 (층별 가중치)
local DROP_TABLE = {
    -- 소비/재료
    {id = "health_potion", weight = 30, minFloor = 1},
    {id = "large_potion",  weight = 10, minFloor = 2},
    {id = "gold_coin",     weight = 25, minFloor = 1},
    -- 일반 무기
    {id = "short_sword",   weight = 15, minFloor = 1},
    {id = "rusty_sword",   weight = 18, minFloor = 1},
    -- 고급 무기
    {id = "dagger",        weight = 10, minFloor = 1},
    {id = "steel_sword",   weight = 8,  minFloor = 2},
    {id = "long_sword",    weight = 7,  minFloor = 2},
    -- 희귀 무기
    {id = "flame_dagger",  weight = 4,  minFloor = 3},
    {id = "venom_blade",   weight = 4,  minFloor = 3},
    {id = "battle_axe",    weight = 4,  minFloor = 3},
    {id = "frost_halberd", weight = 3,  minFloor = 3},
    -- 영웅 무기
    {id = "vampiric_blade",     weight = 2, minFloor = 4},
    {id = "thunder_sword",      weight = 2, minFloor = 4},
    {id = "inferno_greatsword", weight = 2, minFloor = 4},
    -- 전설 무기
    {id = "dragon_blade",   weight = 1, minFloor = 5},
    {id = "soul_reaper",    weight = 1, minFloor = 5},
    {id = "abyssal_scythe", weight = 1, minFloor = 5},
    -- 방패
    {id = "wooden_shield", weight = 12, minFloor = 1},
    {id = "iron_shield",   weight = 6,  minFloor = 2},
    {id = "thorn_shield",  weight = 3,  minFloor = 3},
    {id = "mirror_shield", weight = 2,  minFloor = 4},
    {id = "dragon_shield", weight = 1,  minFloor = 5},
    -- 방어구
    {id = "leather_armor", weight = 12, minFloor = 1},
    {id = "chain_mail",    weight = 6,  minFloor = 2},
    {id = "plate_armor",   weight = 3,  minFloor = 3},
    {id = "shadow_robe",   weight = 2,  minFloor = 4},
    {id = "dragon_armor",  weight = 1,  minFloor = 5},
    -- 투구
    {id = "iron_helmet",     weight = 10, minFloor = 1},
    {id = "mage_hat",        weight = 6,  minFloor = 2},
    {id = "berserker_helm",  weight = 3,  minFloor = 3},
    {id = "royal_crown",     weight = 2,  minFloor = 4},
    {id = "dragon_helm",     weight = 1,  minFloor = 5},
    -- 신발
    {id = "leather_boots",  weight = 10, minFloor = 1},
    {id = "iron_greaves",   weight = 6,  minFloor = 2},
    {id = "swift_boots",    weight = 3,  minFloor = 3},
    {id = "shadow_boots",   weight = 2,  minFloor = 4},
    {id = "dragon_boots",   weight = 1,  minFloor = 5},
    -- 반지
    {id = "copper_ring",    weight = 8,  minFloor = 1},
    {id = "silver_ring",    weight = 5,  minFloor = 2},
    {id = "emerald_ring",   weight = 3,  minFloor = 3},
    {id = "ruby_ring",      weight = 2,  minFloor = 4},
    {id = "ring_of_power",  weight = 1,  minFloor = 5},
    -- 목걸이
    {id = "silver_amulet",      weight = 6, minFloor = 2},
    {id = "healing_pendant",    weight = 3, minFloor = 3},
    {id = "amulet_of_fury",     weight = 2, minFloor = 4},
    {id = "amulet_of_eternity", weight = 1, minFloor = 5},
    -- 재료
    {id = "dragon_scale",  weight = 1,  minFloor = 5},
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

-- ===== 몬스터 데이터베이스 (DCSS 스타일) =====
local ENEMY_DB = {
    -- 1층: 약한 적
    {name="쥐",         char="r", hp=3,  atk=1, def=0, spd=1.2, exp=3,  ev=15, color={0.5,0.4,0.3}, floors={1,2}},
    {name="고블린",      char="g", hp=6,  atk=2, def=0, spd=1.0, exp=6,  ev=10, color={0,0.8,0},     floors={1,2,3}},
    {name="코볼트",      char="k", hp=5,  atk=2, def=1, spd=1.1, exp=5,  ev=12, color={0.6,0.5,0.2}, floors={1,2}},
    {name="박쥐",        char="b", hp=3,  atk=1, def=0, spd=1.5, exp=3,  ev=25, color={0.4,0.3,0.5}, floors={1,2,3}},
    {name="좀비",        char="z", hp=10, atk=2, def=2, spd=0.5, exp=8,  ev=0,  color={0.3,0.5,0.2}, floors={1,2,3}},
    -- 2층: 중간 적
    {name="오크",        char="o", hp=12, atk=4, def=2, spd=1.0, exp=12, ev=8,  color={0.5,0.8,0.2}, floors={2,3,4}},
    {name="스켈레톤",    char="s", hp=8,  atk=3, def=4, spd=0.8, exp=10, ev=5,  color={0.9,0.9,0.8}, floors={2,3}},
    {name="독거미",      char="S", hp=7,  atk=3, def=0, spd=1.3, exp=10, ev=18, color={0.2,0.7,0.2}, floors={2,3}},
    {name="늑대",        char="w", hp=9,  atk=4, def=1, spd=1.4, exp=10, ev=15, color={0.5,0.5,0.5}, floors={2,3}},
    {name="오크전사",    char="O", hp=18, atk=5, def=3, spd=0.9, exp=18, ev=8,  color={0.5,0.6,0.2}, floors={2,3,4}},
    -- 3층: 강한 적
    {name="트롤",        char="T", hp=25, atk=7, def=3, spd=0.7, exp=25, ev=5,  color={0.3,0.6,0.3}, floors={3,4}},
    {name="가고일",      char="G", hp=20, atk=5, def=8, spd=0.6, exp=22, ev=3,  color={0.5,0.5,0.5}, floors={3,4}},
    {name="리자드맨",    char="L", hp=18, atk=6, def=4, spd=1.1, exp=20, ev=12, color={0.2,0.6,0.4}, floors={3,4}},
    {name="미노타우로스",char="M", hp=30, atk=8, def=4, spd=1.0, exp=30, ev=6,  color={0.6,0.3,0.1}, floors={3,4,5}},
    {name="워록",        char="W", hp=15, atk=9, def=2, spd=0.8, exp=28, ev=10, color={0.5,0.2,0.7}, floors={3,4,5}},
    -- 4층: 엘리트
    {name="오우거",      char="F", hp=35, atk=10,def=5, spd=0.6, exp=35, ev=3,  color={0.7,0.4,0.2}, floors={4,5}},
    {name="다크엘프",    char="e", hp=20, atk=8, def=3, spd=1.3, exp=30, ev=20, color={0.3,0.2,0.5}, floors={4,5}},
    {name="네크로맨서",  char="N", hp=22, atk=10,def=3, spd=0.9, exp=35, ev=12, color={0.4,0.1,0.4}, floors={4,5}},
    {name="석상",        char="X", hp=40, atk=6, def=12,spd=0.4, exp=30, ev=0,  color={0.6,0.6,0.65},floors={4,5}},
    {name="화염마",      char="E", hp=25, atk=12,def=4, spd=1.0, exp=40, ev=15, color={1.0,0.3,0.1}, floors={4,5}},
    -- 5층: 보스급
    {name="드래곤",      char="D", hp=60, atk=15,def=8, spd=0.8, exp=80, ev=10, color={1,0.2,0},     floors={5}},
    {name="리치",        char="$", hp=40, atk=14,def=5, spd=0.7, exp=70, ev=12, color={0.3,0.8,0.3}, floors={5}},
    {name="골렘",        char="#", hp=70, atk=12,def=15,spd=0.3, exp=60, ev=0,  color={0.5,0.4,0.3}, floors={5}},
    {name="악마",        char="&", hp=50, atk=16,def=6, spd=1.2, exp=90, ev=18, color={0.8,0.1,0.1}, floors={5}},
    {name="고대용",      char="@", hp=100,atk=20,def=10,spd=0.9, exp=150,ev=8,  color={1.0,0.8,0.0}, floors={5}},
}

-- ===== 적 생성 =====
local function spawnEnemies()
    local available = {}
    for _, e in ipairs(ENEMY_DB) do
        for _, f in ipairs(e.floors) do
            if f == floor then
                table.insert(available, e)
                break
            end
        end
    end
    if #available == 0 then return end

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(1, MAX_ENEMIES_PER_ROOM)
        for j = 1, count do
            local ex = math.random(room.x + 1, room.x + room.w - 2)
            local ey = math.random(room.y + 1, room.y + room.h - 2)

            local etype = available[math.random(1, #available)]

            -- 층별 스케일링
            local scale = 1 + (floor - 1) * 0.15
            local hpVal  = math.floor(etype.hp * scale)
            local atkVal = math.floor(etype.atk * scale)
            local defVal = math.floor(etype.def * scale)

            table.insert(enemies, {
                x = ex, y = ey,
                name = etype.name,
                char = etype.char,
                hp = hpVal,
                maxHp = hpVal,
                atk = atkVal,
                def = defVal,
                ev = etype.ev,
                spd = etype.spd or 1.0,
                exp = math.floor(etype.exp * scale),
                color = etype.color,
                alive = true,
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
        if startRoom then
            player.x = startRoom.cx
            player.y = startRoom.cy
        end
    else
        player = {
            x = startRoom and startRoom.cx or 1,
            y = startRoom and startRoom.cy or 1,
            char = "@",
            hp = 30,
            maxHp = 30,
            baseAtk = 3,
            baseDef = 0,
            exp = 0,
            nextExp = 20,
            level = 1,
            gold = 0,
            -- DCSS 스타일 스탯
            str = 5,   -- 힘: 근접 데미지, 무거운 장비
            dex = 5,   -- 민첩: 명중률, 회피, 치명타
            int = 5,   -- 지능: 마법 데미지 (향후 확장)
            con = 5,   -- 체력: 최대 HP, HP 재생
            lck = 5,   -- 운: 치명타, 드롭률, 회피
        }
    end
end

--- 장비 스탯 포함 최종 스탯 계산
local function getPlayerAtk()
    local bonus = equip and equip:getTotalStats().atk or 0
    local strBonus = math.floor(player.str / 3)
    return player.baseAtk + bonus + strBonus
end

local function getPlayerDef()
    local bonus = equip and equip:getTotalStats().def or 0
    local conBonus = math.floor(player.con / 5)
    return player.baseDef + bonus + conBonus
end

--- 회피율 (DEX + LCK 기반)
local function getPlayerEvasion()
    local eqSpd = equip and equip:getTotalStats().spd or 0
    return 5 + player.dex * 1.5 + player.lck * 0.5 + eqSpd
end

--- 명중률 (DEX 기반)
local function getPlayerAccuracy()
    return 70 + player.dex * 2 + player.lck * 0.5
end

--- 치명타 확률 (DEX + LCK 기반)
local function getPlayerCritChance()
    local eqCrit = equip and equip:getTotalStats().crit or 0
    return 5 + player.dex * 0.5 + player.lck * 1.0 + eqCrit
end

--- 치명타 배율
local function getPlayerCritMult()
    return 1.5 + player.str * 0.02
end

--- 최대 HP (CON 기반)
local function getPlayerMaxHp()
    local eqHp = equip and equip:getTotalStats().hp or 0
    local base = 30 + (player.level - 1) * 5
    return base + player.con * 3 + eqHp
end

--- 장비 패시브 효과 수집
local function getEquipPassives()
    local passives = {}
    if not equip then return passives end
    for _, item in pairs(equip.slots) do
        if item and item.passive then
            table.insert(passives, item.passive)
        end
    end
    return passives
end

--- 특정 패시브 합산
local function getPassiveValue(pType)
    local total = 0
    for _, p in ipairs(getEquipPassives()) do
        if p.type == pType then
            total = total + p.value
        end
    end
    return total
end

--- 패시브 보정된 회피율
local function getPlayerEvasionFull()
    return getPlayerEvasion() + getPassiveValue("dodge_boost")
end

--- 패시브 보정된 치명타
local function getPlayerCritFull()
    return getPlayerCritChance() + getPassiveValue("crit_boost")
end

-- ===== 레벨업 =====
local function checkLevelUp()
    while player.exp >= player.nextExp do
        player.exp = player.exp - player.nextExp
        player.level = player.level + 1
        player.baseAtk = player.baseAtk + 1
        player.nextExp = math.floor(player.nextExp * 1.5)

        -- 스탯 포인트 3점 배분
        statAlloc = {points = 3, sel = 1}
        gameState = "levelup"

        -- maxHp 재계산 + 풀HP
        player.maxHp = getPlayerMaxHp()
        player.hp = player.maxHp

        addMessage("** 레벨 업! Lv." .. player.level .. " — 스탯 포인트 3점을 배분하세요! **")
    end
end

-- ===== 전투 (DCSS 스타일 공식 + 패시브 효과) =====

--- 플레이어 → 적 한 번 공격 (내부 함수)
local function dealPlayerAttack(enemy)
    local accuracy = getPlayerAccuracy()
    local hitRoll = math.random(1, 100)
    local evade = enemy.ev or 0

    if hitRoll > accuracy - evade then
        addMessage(enemy.name .. "이(가) 공격을 회피했다!")
        return 0
    end

    local atk = getPlayerAtk()
    local enemyDef = enemy.def or 0

    -- 방어관통 패시브
    local armorBreak = getPassiveValue("armor_break")
    if armorBreak > 0 then
        enemyDef = math.floor(enemyDef * (1 - armorBreak / 100))
    end

    local dmgReduction = math.floor(enemyDef * 0.6)
    local baseDmg = math.max(1, atk - dmgReduction)

    local variance = math.floor(baseDmg * 0.2)
    local dmg = baseDmg + math.random(-variance, variance)

    -- 치명타 판정 (패시브 보정)
    local critChance = getPlayerCritFull()
    local isCrit = math.random(1, 100) <= critChance
    if isCrit then
        dmg = math.floor(dmg * getPlayerCritMult())
    end
    dmg = math.max(1, dmg)

    enemy.hp = enemy.hp - dmg
    local msg = enemy.name .. "에게 " .. dmg .. " 데미지!"
    if isCrit then msg = "★ 치명타! " .. msg end
    addMessage(msg)

    -- 흡혈 패시브
    local lifesteal = getPassiveValue("lifesteal")
    if lifesteal > 0 then
        local heal = math.max(1, math.floor(dmg * lifesteal / 100))
        player.hp = math.min(player.maxHp, player.hp + heal)
        addMessage("  ♥ 흡혈 +" .. heal .. " HP")
    end

    -- 화상 패시브
    local burnVal = getPassiveValue("burn")
    if burnVal > 0 and math.random(1, 100) <= 35 then
        enemy.burn = (enemy.burn or 0) + burnVal
        addMessage("  🔥 " .. enemy.name .. " 화상! (" .. burnVal .. "턴)")
    end

    -- 독 패시브
    local poisonVal = getPassiveValue("poison")
    if poisonVal > 0 and math.random(1, 100) <= 25 then
        enemy.poison = (enemy.poison or 0) + poisonVal
        addMessage("  ☠ " .. enemy.name .. " 중독! (" .. poisonVal .. "턴)")
    end

    -- 기절 패시브
    local stunVal = getPassiveValue("stun")
    if stunVal > 0 and math.random(1, 100) <= stunVal then
        enemy.stunned = true
        addMessage("  ⚡ " .. enemy.name .. " 기절!")
    end

    return dmg
end

local function attackEnemy(enemy)
    local totalDmg = dealPlayerAttack(enemy)

    -- 연속타격 패시브
    if enemy.alive and enemy.hp > 0 then
        local doubleHit = getPassiveValue("double_hit")
        if doubleHit > 0 and math.random(1, 100) <= doubleHit then
            addMessage("  >> 연속 타격!")
            totalDmg = totalDmg + dealPlayerAttack(enemy)
        end
    end

    if enemy.hp <= 0 then
        enemy.alive = false

        -- 경험치 (exp_boost 패시브)
        local expBoost = getPassiveValue("exp_boost")
        local expGain = math.floor(enemy.exp * (1 + expBoost / 100))
        player.exp = player.exp + expGain
        addMessage(enemy.name .. " 처치! (+" .. expGain .. " 경험치)")

        -- 아이템 드롭 (40% + LCK 보정)
        local dropChance = 0.4 + player.lck * 0.01
        if math.random() < dropChance then
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

        -- 골드 드롭 (gold_boost 패시브)
        local goldBoost = getPassiveValue("gold_boost")
        local goldDrop = math.random(1, 5) + floor * 2
        goldDrop = math.floor(goldDrop * (1 + goldBoost / 100))
        player.gold = player.gold + goldDrop
        addMessage("  → " .. goldDrop .. "G 획득!")

        checkLevelUp()
    end
end

local function enemyAttack(enemy)
    -- 기절 체크
    if enemy.stunned then
        enemy.stunned = false
        addMessage(enemy.name .. "은(는) 기절에서 깨어났다!")
        return
    end

    local evasion = getPlayerEvasionFull()
    local hitRoll = math.random(1, 100)
    local enemyAcc = 60 + (enemy.atk or 0) * 2

    if hitRoll > enemyAcc - evasion then
        addMessage(enemy.name .. "의 공격을 회피했다!")
        return
    end

    local def = getPlayerDef()
    local dmg = math.max(1, (enemy.atk or 0) - math.floor(def * 0.6))
    local variance = math.floor(dmg * 0.15)
    dmg = dmg + math.random(-variance, variance)
    dmg = math.max(1, dmg)

    player.hp = player.hp - dmg
    addMessage(enemy.name .. "이(가) " .. dmg .. " 데미지!")

    -- 가시/반사 패시브
    local thorns = getPassiveValue("thorns")
    if thorns > 0 then
        enemy.hp = enemy.hp - thorns
        addMessage("  ◆ 가시 반사 " .. thorns .. " 데미지!")
        if enemy.hp <= 0 then
            enemy.alive = false
            player.exp = player.exp + enemy.exp
            addMessage(enemy.name .. " 처치! (가시 반사)")
            checkLevelUp()
        end
    end

    local reflect = getPassiveValue("reflect")
    if reflect > 0 then
        local refDmg = math.max(1, math.floor(dmg * reflect / 100))
        enemy.hp = enemy.hp - refDmg
        addMessage("  ◆ 반사 " .. refDmg .. " 데미지!")
        if enemy.hp <= 0 and enemy.alive then
            enemy.alive = false
            player.exp = player.exp + enemy.exp
            addMessage(enemy.name .. " 처치! (반사)")
            checkLevelUp()
        end
    end

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

-- ===== 마을로 귀환 =====
local function goToTown()
    gameState = "town"
    townMenuSel = 1
    dungeonRun = dungeonRun + 1
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    shop.needsRefresh = true
    addMessage("** 마을에 도착했습니다! (HP 회복) **")
end

-- ===== 던전 출발 =====
local function startDungeon()
    floor = 1
    turn = 0
    gameState = "playing"
    addMessage(">> 던전 " .. (dungeonRun + 1) .. "번째 탐험 출발! <<")
    createMap()
    spawnEnemies()
    spawnGroundItems()
    initPlayer(true)
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
end

-- ===== 계단 =====
local function checkStair()
    if map[player.y] and map[player.y][player.x] == TILE_STAIR then
        floor = floor + 1
        if floor > 5 then
            addMessage("** 던전 클리어! 마을로 귀환합니다 **")
            goToTown()
            return
        end
        addMessage(">> " .. floor .. "층으로 이동 <<")
        createMap()
        spawnEnemies()
        spawnGroundItems()
        initPlayer(true)
    end
end

-- ===== 턴 상태효과 처리 =====
local function processStatusEffects()
    -- 적 화상/독 처리
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            if enemy.burn and enemy.burn > 0 then
                local burnDmg = 2
                enemy.hp = enemy.hp - burnDmg
                enemy.burn = enemy.burn - 1
                addMessage("  " .. enemy.name .. " 화상 " .. burnDmg .. " 데미지! (남은 " .. enemy.burn .. "턴)")
                if enemy.hp <= 0 then
                    enemy.alive = false
                    player.exp = player.exp + enemy.exp
                    addMessage(enemy.name .. " 처치! (화상)")
                    checkLevelUp()
                end
            end
            if enemy.poison and enemy.poison > 0 then
                local poisonDmg = 3
                enemy.hp = enemy.hp - poisonDmg
                enemy.poison = enemy.poison - 1
                addMessage("  " .. enemy.name .. " 독 " .. poisonDmg .. " 데미지! (남은 " .. enemy.poison .. "턴)")
                if enemy.hp <= 0 and enemy.alive then
                    enemy.alive = false
                    player.exp = player.exp + enemy.exp
                    addMessage(enemy.name .. " 처치! (중독)")
                    checkLevelUp()
                end
            end
        end
    end

    -- 플레이어 재생 패시브
    local regen = getPassiveValue("regen")
    if regen > 0 and player.hp < player.maxHp then
        player.hp = math.min(player.maxHp, player.hp + regen)
        addMessage("재생 +" .. regen .. " HP")
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
            processStatusEffects()
            moveEnemies()
            return
        end
    end

    player.x = nx
    player.y = ny
    turn = turn + 1

    pickupItem()
    checkStair()
    processStatusEffects()
    moveEnemies()
end

-- ===== LÖVE2D 콜백 =====
function love.load()
    love.window.setTitle("Extraction Roguelike")
    love.window.setMode(MAP_WIDTH * TILE_SIZE + 270, MAP_HEIGHT * TILE_SIZE + 10, {resizable = false})

    font = love.graphics.newFont("NanumGothicCoding.ttf", 13)
    love.graphics.setFont(font)

    math.randomseed(os.time())

    -- 인벤토리 & 장비 & 상점 & 보관함 초기화
    inv = Inventory.new(10, 6)
    equip = Equipment.new()
    shop = Shop.new()
    stash = Inventory.new(10, 6)

    -- 마을에서 시작
    gameState = "town"
    townMenuSel = 1
    dungeonRun = 0

    addMessage("마을에 오신 것을 환영합니다!")
    addMessage("상점에서 아이템을 사고팔 수 있습니다.")
    addMessage("던전 출발을 선택하여 탐험을 시작하세요!")

    initPlayer()
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp

    -- 시작 아이템
    local starter = Item.create("short_sword")
    if starter then inv:autoPlace(starter) end
    local pot = Item.create("health_potion")
    if pot then pot.count = 3; inv:autoPlace(pot) end
end

function love.update(dt)
    if gameState == "inventory" or gameState == "stash" or gameState == "shop" then
        if not drag.item then
            local mx, my = love.mouse.getPosition()
            hoverItem = inv:getItemAt(mx, my)
            if not hoverItem then
                local slot = equip:getSlotAt(mx, my)
                if slot then
                    hoverItem = equip:getItem(slot)
                end
            end
            if not hoverItem and gameState == "stash" then
                hoverItem = stash:getItemAt(mx, my)
            end
            if not hoverItem and gameState == "shop" then
                hoverItem = shop:getItemAt(mx, my)
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

    if key == "escape" then
        if gameState == "inventory" then
            gameState = "playing"
            drag.item = nil
            hoverItem = nil
            return
        elseif gameState == "shop" then
            if drag.item then
                if drag.fromSlot == "shop" then
                    shop:addItem(drag.item, drag.shopPrice)
                else
                    inv:autoPlace(drag.item)
                end
                drag.item = nil
            end
            gameState = "town"
            hoverItem = nil
            return
        elseif gameState == "stash" then
            gameState = "town"
            drag.item = nil
            hoverItem = nil
            return
        end
    end

    -- 마을 메뉴
    if gameState == "town" then
        if key == "up" or key == "w" then
            townMenuSel = townMenuSel - 1
            if townMenuSel < 1 then townMenuSel = #TOWN_MENU end
        elseif key == "down" or key == "s" then
            townMenuSel = townMenuSel + 1
            if townMenuSel > #TOWN_MENU then townMenuSel = 1 end
        elseif key == "return" or key == "space" then
            local sel = TOWN_MENU[townMenuSel]
            if sel == "상점" then
                if shop.needsRefresh then
                    shop:refresh()
                end
                gameState = "shop"
                drag.item = nil
                hoverItem = nil
            elseif sel == "보관함" then
                gameState = "stash"
                drag.item = nil
                hoverItem = nil
            elseif sel == "던전 출발" then
                startDungeon()
            elseif sel == "저장" then
                addMessage("게임이 저장되었습니다!")
            end
        end
        return
    end

    if gameState == "gameover" then
        if key == "r" then
            -- 사망 시 마을로 귀환, 인벤토리 유지 (익스트랙션 스타일)
            addMessage("** 사망했지만 마을로 돌아왔습니다... **")
            goToTown()
        end
        return
    end

    -- 레벨업 스탯 배분
    if gameState == "levelup" and statAlloc then
        local STAT_KEYS = {"str", "dex", "int", "con", "lck"}
        if key == "up" or key == "w" then
            statAlloc.sel = statAlloc.sel - 1
            if statAlloc.sel < 1 then statAlloc.sel = #STAT_KEYS end
        elseif key == "down" or key == "s" then
            statAlloc.sel = statAlloc.sel + 1
            if statAlloc.sel > #STAT_KEYS then statAlloc.sel = 1 end
        elseif key == "return" or key == "space" then
            local stat = STAT_KEYS[statAlloc.sel]
            player[stat] = player[stat] + 1
            statAlloc.points = statAlloc.points - 1
            addMessage(stat:upper() .. " +1! (현재 " .. player[stat] .. ")")

            -- maxHp 재계산
            player.maxHp = getPlayerMaxHp()
            player.hp = math.min(player.hp, player.maxHp)

            if statAlloc.points <= 0 then
                statAlloc = nil
                gameState = "playing"
                addMessage("스탯 배분 완료!")
            end
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
        processStatusEffects()
        moveEnemies()
    elseif key == "pageup" then
        messageScroll = math.min(messageScroll + 3, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
    elseif key == "pagedown" then
        messageScroll = math.max(0, messageScroll - 3)
    end
end

function love.mousepressed(x, y, button)
    -- 상점 클릭
    if gameState == "shop" then
        if button == 1 then
            -- 상점 그리드에서 드래그
            local shopItem = shop:getItemAt(x, y)
            if shopItem then
                drag.item = shopItem
                drag.fromInv = false
                drag.fromSlot = "shop"
                drag.shopPrice = shop:getPrice(shopItem)
                shop:removeItem(shopItem)
                hoverItem = nil
                return
            end
            -- 인벤토리에서 드래그
            local invItem = inv:getItemAt(x, y)
            if invItem then
                drag.item = invItem
                drag.fromInv = true
                drag.fromSlot = nil
                drag.shopPrice = nil
                inv:removeItem(invItem)
                hoverItem = nil
                return
            end
        elseif button == 2 then
            -- 우클릭: 빠른 구매/판매
            local shopItem = shop:getItemAt(x, y)
            if shopItem then
                local price = shop:getPrice(shopItem)
                if player.gold >= price then
                    shop:removeItem(shopItem)
                    if inv:autoPlace(shopItem) then
                        player.gold = player.gold - price
                        addMessage(shopItem.name .. " 구매! (-" .. price .. "G)")
                    else
                        shop:addItem(shopItem, price)
                        addMessage("인벤토리가 꽉 찼습니다!")
                    end
                else
                    addMessage("골드가 부족합니다!")
                end
                return
            end
            local invItem = inv:getItemAt(x, y)
            if invItem then
                local price = shop:getSellPrice(invItem)
                inv:removeItem(invItem)
                player.gold = player.gold + price
                shop:addItem(invItem, price)
                addMessage(invItem.name .. " 판매! (+" .. price .. "G)")
                return
            end
        end
        return
    end

    -- 보관함 클릭
    if gameState == "stash" then
        if button == 1 then
            -- 인벤토리에서 드래그
            local item = inv:getItemAt(x, y)
            if item then
                drag.item = item
                drag.fromInv = true
                drag.fromSlot = nil
                inv:removeItem(item)
                hoverItem = nil
                return
            end
            -- 보관함에서 드래그
            local sItem = stash:getItemAt(x, y)
            if sItem then
                drag.item = sItem
                drag.fromInv = false
                drag.fromSlot = "stash"
                stash:removeItem(sItem)
                hoverItem = nil
                return
            end
        elseif button == 2 then
            -- 인벤토리 → 보관함 이동
            local item = inv:getItemAt(x, y)
            if item then
                inv:removeItem(item)
                if not stash:autoPlace(item) then
                    inv:autoPlace(item)
                    addMessage("보관함이 꽉 찼습니다!")
                else
                    addMessage(item.name .. " → 보관함")
                end
                return
            end
            -- 보관함 → 인벤토리 이동
            local sItem = stash:getItemAt(x, y)
            if sItem then
                stash:removeItem(sItem)
                if not inv:autoPlace(sItem) then
                    stash:autoPlace(sItem)
                    addMessage("인벤토리가 꽉 찼습니다!")
                else
                    addMessage(sItem.name .. " → 인벤토리")
                end
                return
            end
        end
        return
    end

    -- 마을 메뉴 클릭
    if gameState == "town" then
        if button == 1 then
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            local menuW = 200
            local menuH = #TOWN_MENU * 40 + 20
            local menuX = sw / 2 - menuW / 2
            local menuY = sh / 2 - menuH / 2
            for i, label in ipairs(TOWN_MENU) do
                local btnY = menuY + 10 + (i - 1) * 40
                if x >= menuX and x <= menuX + menuW and y >= btnY and y <= btnY + 34 then
                    townMenuSel = i
                    -- 실행
                    if label == "상점" then
                        if shop.needsRefresh then
                            shop:refresh()
                        end
                        gameState = "shop"
                        drag.item = nil
                        hoverItem = nil
                    elseif label == "보관함" then
                        gameState = "stash"
                        drag.item = nil
                        hoverItem = nil
                    elseif label == "던전 출발" then
                        startDungeon()
                    elseif label == "저장" then
                        addMessage("게임이 저장되었습니다!")
                    end
                    return
                end
            end
        end
        return
    end

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
                local removed = equip:equip(item)
                for _, prev in ipairs(removed) do
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

        -- 상점 모드에서 드랍
        if gameState == "shop" then
            -- 상점→인벤: 구매
            if drag.fromSlot == "shop" then
                local col, row = inv:screenToGrid(x, y)
                col = col - math.floor(item.gridW / 2)
                row = row - math.floor(item.gridH / 2)
                local price = drag.shopPrice or 0
                if inv:canPlace(item, col, row) and player.gold >= price then
                    inv:placeItem(item, col, row)
                    player.gold = player.gold - price
                    addMessage(item.name .. " 구매! (-" .. price .. "G)")
                    drag.item = nil
                    return
                end
                -- 상점 그리드에 드롭 시도
                local sc, sr = shop:screenToGrid(x, y)
                sc = sc - math.floor(item.gridW / 2)
                sr = sr - math.floor(item.gridH / 2)
                if shop:canPlace(item, sc, sr) then
                    shop:placeItem(item, sc, sr, drag.shopPrice)
                    drag.item = nil
                    return
                end
                -- 실패 → 원위치
                shop:addItem(item, drag.shopPrice)
                if player.gold < price then
                    addMessage("골드가 부족합니다!")
                end
            else
                -- 인벤→상점: 판매
                local sc, sr = shop:screenToGrid(x, y)
                sc = sc - math.floor(item.gridW / 2)
                sr = sr - math.floor(item.gridH / 2)
                if shop:canPlace(item, sc, sr) then
                    local price = shop:getSellPrice(item)
                    shop:placeItem(item, sc, sr, price)
                    player.gold = player.gold + price
                    addMessage(item.name .. " 판매! (+" .. price .. "G)")
                    drag.item = nil
                    return
                end
                -- 인벤에 드롭 시도
                local col, row = inv:screenToGrid(x, y)
                col = col - math.floor(item.gridW / 2)
                row = row - math.floor(item.gridH / 2)
                if inv:canPlace(item, col, row) then
                    inv:placeItem(item, col, row)
                    drag.item = nil
                    return
                end
                -- 실패 → 원위치
                inv:autoPlace(item)
            end
            drag.item = nil
            return
        end

        -- 보관함 모드에서 드랍
        if gameState == "stash" then
            -- 인벤토리에 드롭 시도
            local col, row = inv:screenToGrid(x, y)
            col = col - math.floor(item.gridW / 2)
            row = row - math.floor(item.gridH / 2)
            if inv:canPlace(item, col, row) then
                inv:placeItem(item, col, row)
                drag.item = nil
                return
            end

            -- 보관함에 드롭 시도
            local sc, sr = stash:screenToGrid(x, y)
            sc = sc - math.floor(item.gridW / 2)
            sr = sr - math.floor(item.gridH / 2)
            if stash:canPlace(item, sc, sr) then
                stash:placeItem(item, sc, sr)
                drag.item = nil
                return
            end

            -- 실패 — 원래 위치로
            if drag.fromInv then
                inv:autoPlace(item)
            elseif drag.fromSlot == "stash" then
                stash:autoPlace(item)
            end
            drag.item = nil
            return
        end

        -- 인벤토리 모드
        local col, row = inv:screenToGrid(x, y)
        col = col - math.floor(item.gridW / 2)
        row = row - math.floor(item.gridH / 2)

        if inv:canPlace(item, col, row) then
            inv:placeItem(item, col, row)
            drag.item = nil
            return
        end

        local slot = equip:getSlotAt(x, y)
        if slot and equip:canDropToSlot(item, slot) then
            local removed = equip:equip(item, slot)
            for _, prev in ipairs(removed) do
                inv:autoPlace(prev)
            end
            drag.item = nil
            return
        end

        if drag.fromInv then
            inv:autoPlace(item)
        elseif drag.fromSlot then
            equip:equip(item, drag.fromSlot)
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

    -- 스탯 (DCSS 스타일)
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("--- 스탯 ---", hudX, hudY)
    hudY = hudY + 16

    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("힘(STR):  " .. player.str, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("민첩(DEX): " .. player.dex, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("지능(INT): " .. player.int, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(1, 0.7, 0.3)
    love.graphics.print("체력(CON): " .. player.con, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print("운(LCK):  " .. player.lck, hudX, hudY)
    hudY = hudY + 18

    -- 전투 스탯
    local eqStats = equip:getTotalStats()
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("공격: " .. getPlayerAtk(), hudX, hudY)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("방어: " .. getPlayerDef(), hudX + 70, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("회피: " .. math.floor(getPlayerEvasionFull()) .. "%", hudX, hudY)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print("치명: " .. math.floor(getPlayerCritFull()) .. "%", hudX + 70, hudY)
    hudY = hudY + 14

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 특수효과 ---", hudX, hudY)
        hudY = hudY + 14
        for _, p in ipairs(passives) do
            local pName = Item.PASSIVE_NAMES[p.type] or p.type
            love.graphics.setColor(0.7, 0.5, 1)
            love.graphics.print("◆ " .. pName, hudX, hudY)
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("골드: " .. player.gold, hudX, hudY)
    hudY = hudY + 18

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("--- 조작법 ---", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("방향키/WASD: 이동", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("부딪히기: 공격 | Space: 대기", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("I/Tab: 인벤토리", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print(">: 계단 | PgUp/Dn: 로그", hudX, hudY)
    hudY = hudY + 18

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

    -- 게임오버 화면
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("사망했습니다...", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf(floor .. "층  레벨 " .. player.level .. "  턴: " .. turn, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("R키: 마을로 귀환 (인벤토리 유지)", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
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
    love.graphics.print("=== 전투 스탯 ===", equip.x - 80, equip.y + 230)
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("공격: " .. getPlayerAtk(), equip.x - 76, equip.y + 248)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("방어: " .. getPlayerDef(), equip.x - 76, equip.y + 264)
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("회피: " .. math.floor(getPlayerEvasionFull()) .. "%", equip.x - 76, equip.y + 280)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print("치명: " .. math.floor(getPlayerCritFull()) .. "%", equip.x - 76, equip.y + 296)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("STR:" .. player.str .. " DEX:" .. player.dex .. " INT:" .. player.int, equip.x - 76, equip.y + 316)
    love.graphics.print("CON:" .. player.con .. " LCK:" .. player.lck, equip.x - 76, equip.y + 332)

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        local py = equip.y + 350
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 특수효과 ---", equip.x - 76, py)
        py = py + 16
        for _, p in ipairs(passives) do
            love.graphics.setColor(0.7, 0.5, 1)
            love.graphics.print("◆ " .. (p.desc or ""), equip.x - 76, py)
            py = py + 14
        end
    end

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

local function drawTown()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 배경
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("마 을", 0, 40, sw, "center")

    -- 플레이어 정보
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.printf("Lv." .. player.level .. "  골드: " .. player.gold .. "  탐험: " .. dungeonRun .. "회", 0, 70, sw, "center")

    -- 메뉴
    local menuW = 200
    local menuH = #TOWN_MENU * 40 + 20
    local menuX = sw / 2 - menuW / 2
    local menuY = sh / 2 - menuH / 2

    love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
    love.graphics.rectangle("fill", menuX - 10, menuY - 10, menuW + 20, menuH + 20, 8, 8)

    for i, label in ipairs(TOWN_MENU) do
        local btnY = menuY + 10 + (i - 1) * 40
        if i == townMenuSel then
            love.graphics.setColor(0.3, 0.5, 0.3)
        else
            love.graphics.setColor(0.18, 0.18, 0.22)
        end
        love.graphics.rectangle("fill", menuX, btnY, menuW, 34, 4, 4)

        if i == townMenuSel then
            love.graphics.setColor(0.4, 0.8, 0.4)
            love.graphics.rectangle("line", menuX, btnY, menuW, 34, 4, 4)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(label, menuX, btnY + 8, menuW, "center")
    end

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("↑↓: 선택 | Enter/Space: 확인 | 클릭: 선택", 0, sh - 30, sw, "center")
end

local function drawStash()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 인벤토리 위치
    inv.x = 30
    inv.y = 50

    -- 보관함 위치
    stash.x = inv.x + inv.cols * inv.cellSize + 40
    stash.y = 50

    -- 타이틀
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("인벤토리", inv.x, 20)
    love.graphics.print("보관함", stash.x, 20)

    inv:draw(font)
    stash:draw(font)

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        stash:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 빠른 이동 | Esc: 닫기", 0, sh - 25, sw, "center")
end

local function drawShop()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 상점 그리드 위치 설정
    shop.grid.x = 30
    shop.grid.y = 50

    -- 인벤토리 위치 설정
    inv.x = shop.grid.x + shop.grid.cols * shop.grid.cellSize + 40
    inv.y = 50

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("상 점", 0, 8, sw, "center")
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("골드: " .. player.gold, 0, 8, sw - 20, "right")

    -- 라벨
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print("상점 재고", shop.grid.x, shop.grid.y - 20)
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("인벤토리", inv.x, inv.y - 20)

    -- 그리드 그리기
    shop.grid:draw(font)
    inv:draw(font)

    -- 가격 표시 (상점 아이템)
    for _, item in ipairs(shop.grid.items) do
        local price = shop:getPrice(item)
        local ix = shop.grid.x + (item._gridCol - 1) * shop.grid.cellSize
        local iy = shop.grid.y + (item._gridRow - 1) * shop.grid.cellSize

        love.graphics.setColor(0, 0, 0, 0.7)
        local priceText = price .. "G"
        local tw = font:getWidth(priceText)
        love.graphics.rectangle("fill", ix, iy, tw + 4, 14)

        if player.gold >= price then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(0.7, 0.3, 0.3)
        end
        love.graphics.print(priceText, ix + 2, iy)
    end

    -- 인벤토리 아이템 판매가 표시
    for _, item in ipairs(inv:getAllItems()) do
        local price = shop:getSellPrice(item)
        local ix = inv.x + (item._gridCol - 1) * inv.cellSize
        local iy = inv.y + (item._gridRow - 1) * inv.cellSize
        local iw = item.gridW * inv.cellSize
        local priceText = price .. "G"
        local tw = font:getWidth(priceText)

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", ix + iw - tw - 4, iy, tw + 4, 14)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.print(priceText, ix + iw - tw - 2, iy)
    end

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        shop.grid:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 (상점↔인벤) | 우클릭: 빠른 구매/판매 | Esc: 나가기", 0, sh - 25, sw, "center")
end

local function drawLevelUp()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 배경
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local panelW = 300
    local panelH = 280
    local px = sw / 2 - panelW / 2
    local py = sh / 2 - panelH / 2

    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", px, py, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.rectangle("line", px, py, panelW, panelH, 8, 8)

    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("레벨 업! Lv." .. player.level, px, py + 12, panelW, "center")

    if statAlloc then
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf("남은 포인트: " .. statAlloc.points, px, py + 35, panelW, "center")

        local STAT_KEYS = {"str", "dex", "int", "con", "lck"}
        local STAT_NAMES = {"힘 (STR)  — 근접 데미지", "민첩 (DEX) — 명중/회피/치명타", "지능 (INT) — 마법 (향후 확장)", "체력 (CON) — 최대 HP/방어", "운 (LCK)  — 치명타/드롭률"}
        local STAT_COLORS = {{1,0.4,0.4},{0.4,1,0.4},{0.4,0.6,1},{1,0.7,0.3},{1,1,0.4}}

        for i, stat in ipairs(STAT_KEYS) do
            local sy = py + 60 + (i - 1) * 38

            if i == statAlloc.sel then
                love.graphics.setColor(0.3, 0.4, 0.3)
                love.graphics.rectangle("fill", px + 15, sy - 2, panelW - 30, 34, 4, 4)
                love.graphics.setColor(0.5, 0.8, 0.5)
                love.graphics.rectangle("line", px + 15, sy - 2, panelW - 30, 34, 4, 4)
            end

            love.graphics.setColor(STAT_COLORS[i])
            love.graphics.print(STAT_NAMES[i], px + 25, sy + 2)
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.print("현재: " .. player[stat], px + 25, sy + 17)
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter/Space: 배분", px, py + panelH - 25, panelW, "center")
    end
end

function love.draw()
    if gameState == "town" then
        drawTown()
    elseif gameState == "shop" then
        drawShop()
    elseif gameState == "stash" then
        drawStash()
    elseif gameState == "levelup" then
        drawGame()
        drawLevelUp()
    else
        drawGame()
        if gameState == "inventory" then
            drawInventory()
        end
    end
end
