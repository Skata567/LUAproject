-- Roguelike + Extraction RPG Inventory (LÖVE2D)
-- 기존 로그라이크 던전 + 그리드 기반 인벤토리 + 장비 시스템

local Item = require("item")
local Inventory = require("inventory")
local Equipment = require("equipment")
local Shop = require("shop")
local FOV = require("fov")
local SKILLS_DB = require("skills_db")
local ConfigManager = require("config_manager")


local RacesData = require("data.races")
local PLAYER_RACES = RacesData.PLAYER_RACES
local RACE_RESTRICTIONS = RacesData.RACE_RESTRICTIONS

local ClassesData = require("data.classes")
local PLAYER_CLASSES = ClassesData.PLAYER_CLASSES

local DropData = require("data.drop_tables")
local DROP_TABLE = DropData.DROP_TABLE

local Constants = require("data.constants")
local TILE_SIZE = Constants.TILE_SIZE
local MAP_WIDTH = Constants.MAP_WIDTH
local MAP_HEIGHT = Constants.MAP_HEIGHT
local MAX_ROOMS = Constants.MAX_ROOMS
local MIN_ROOM_SIZE = Constants.MIN_ROOM_SIZE
local MAX_ROOM_SIZE = Constants.MAX_ROOM_SIZE
local MAX_ENEMIES_PER_ROOM = Constants.MAX_ENEMIES_PER_ROOM
local MAX_ITEMS_PER_ROOM = Constants.MAX_ITEMS_PER_ROOM

local statAlloc = nil

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
local COLOR_HUD_BG = Constants.COLOR_HUD_BG
local COLOR_HP_BAR = Constants.COLOR_HP_BAR
local COLOR_HP_BG = Constants.COLOR_HP_BG
local COLOR_MP_BAR = Constants.COLOR_MP_BAR
local COLOR_MP_BG = Constants.COLOR_MP_BG
local COLOR_WHITE = Constants.COLOR_WHITE
local COLOR_GRAY = Constants.COLOR_GRAY
local COLOR_GOLD = Constants.COLOR_GOLD

local MapGen = require("systems.map_generator")
local Quest = require("systems.quest")


-- 타일셋 (프로시저럴 렌더링용)
TILESET_IMAGE = nil
TILE_QUADS = {}
ENTITY_QUADS = {}

-- 게임 상태
local gameState = "charselect" -- charselect, playing, inventory, town, shop, stash, gameover, levelup, bestiary
local channeling_return = 0
local map = {}
local visibleMap = {}
local exploredMap = {}
local camera = {x = 0, y = 0}
local currentBiome = "dungeon"
local rooms = {}
local player = {}
local enemies = {}
local groundItems = {}  -- 바닥에 있는 아이템
local messages = {}
local turn = 0
local floor = 1
local floorStates = {}
local inSecretArea = false
local secretAreaReturnState = nil
local secretRewards = {}
local font = nil
local messageScroll = 0
local MAX_VISIBLE_MESSAGES = 8

local generateProceduralTileset -- 전방 선언
local updateFOV, updateCamera   -- 전방 선언

-- 캐릭터 선택 상태
local charSelect = {
    phase = "race",  -- "race" or "class"
    raceSel = 1,
    classSel = 1,
    chosenRace = nil,
    chosenClass = nil,
}



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
local TOWN_MENU = {"상점", "보관함", "도감", "던전 출발", "저장"}
local bestiaryScroll = 0
local dungeonRun = 0        -- 던전 탐험 횟수


local addMessage
local updateCombatContext

local function getRaceRestriction(raceId)
    return RACE_RESTRICTIONS[raceId or (player and player.raceId)] or {}
end

local function isElementForbiddenForRace(raceId, element)
    if not element or element == "physical" then return false end
    local rule = getRaceRestriction(raceId)
    return rule.forbiddenElements and rule.forbiddenElements[element] == true
end

local function isItemForbiddenForRace(raceId, item)
    if not item then return false, nil end
    local rule = getRaceRestriction(raceId)
    if rule.forbiddenItems and rule.forbiddenItems[item.id] then
        return true, rule.reason
    end
    if item.slot == "weapon" and isElementForbiddenForRace(raceId, item.element) then
        return true, rule.reason
    end
    return false, nil
end

local function isClassAllowedForRace(race, class)
    if not race or not class then return true, nil end
    local rule = getRaceRestriction(race.id)
    if rule.forbiddenClasses and rule.forbiddenClasses[class.id] then
        return false, rule.reason
    end
    for _, skill in ipairs(class.skills or {}) do
        if isElementForbiddenForRace(race.id, skill.element) then
            return false, rule.reason
        end
    end
    if class.startWeapon then
        local startWeapon = Item.create(class.startWeapon)
        local blocked, reason = isItemForbiddenForRace(race.id, startWeapon)
        if blocked then return false, reason end
    end
    return true, nil
end

local function canUseSkillByRestriction(skill)
    if not skill then return true end
    if isElementForbiddenForRace(player.raceId, skill.element) then
        local rule = getRaceRestriction(player.raceId)
        addMessage(rule.reason or "이 종족은 해당 속성의 기술을 사용할 수 없습니다.")
        return false
    end
    return true
end

local function canEquipItemByRestriction(item)
    local blocked, reason = isItemForbiddenForRace(player and player.raceId, item)
    if blocked then
        addMessage(reason or "이 종족은 해당 장비를 사용할 수 없습니다.")
        return false
    end
    return true
end

-- ===== 유틸리티 =====
addMessage = function(text)
    table.insert(messages, 1, text)
    messageScroll = 0
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function hasAliveBoss()
    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.isBoss then
            return true
        end
    end
    return false
end

local function saveFloorState()
    floorStates[floor] = {
        map = map,
        rooms = rooms,
        enemies = enemies,
        groundItems = groundItems,
        upX = floorStates[floor] and floorStates[floor].upX or nil,
        upY = floorStates[floor] and floorStates[floor].upY or nil,
        downX = floorStates[floor] and floorStates[floor].downX or nil,
        downY = floorStates[floor] and floorStates[floor].downY or nil,
    }
end

local function loadFloorState(targetFloor)
    local state = floorStates[targetFloor]
    if not state then return false end
    map = state.map
    rooms = state.rooms
    enemies = state.enemies
    groundItems = state.groundItems
    return true
end

local function setPlayerAtFloorEntry(direction)
    local state = floorStates[floor]
    if not state then return end

    if direction == "down" and state.upX then
        player.x, player.y = state.upX, state.upY
    elseif direction == "up" and state.downX then
        player.x, player.y = state.downX, state.downY
    elseif rooms[1] then
        player.x, player.y = rooms[1].cx, rooms[1].cy
    end
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

-- ===== 종족/속성 시스템 =====

-- 종족 데이터베이스
local RACE_DB = {
    human = {
        name = "인간", desc = "균형 잡힌 종족. 특별한 약점이나 저항이 없다.",
        color = {0.9, 0.8, 0.7},
        resist = {},  -- 저항 없음
        weak = {},    -- 약점 없음
    },
    beast = {
        name = "야수", desc = "야생의 동물. 빠르지만 마법에 약하다.",
        color = {0.7, 0.5, 0.3},
        resist = {pierce = 0.2},
        weak = {fire = 0.3, lightning = 0.2},
    },
    goblinoid = {
        name = "고블린류", desc = "작고 교활한 종족. 독에 강하지만 신성에 약하다.",
        color = {0.2, 0.7, 0.2},
        resist = {poison = 0.3},
        weak = {holy = 0.3},
    },
    undead = {
        name = "언데드", desc = "죽은 자. 독/빙결 면역이지만 화염/신성에 매우 약하다.",
        color = {0.4, 0.5, 0.3},
        resist = {poison = 1.0, ice = 0.5, slash = 0.3},
        weak = {fire = 0.5, holy = 0.5, strike = 0.3},
    },
    demon = {
        name = "악마", desc = "지옥의 존재. 화염에 강하지만 신성/빙결에 약하다.",
        color = {0.8, 0.1, 0.2},
        resist = {fire = 0.5, poison = 0.3},
        weak = {holy = 0.5, ice = 0.3},
    },
    dragon = {
        name = "용족", desc = "고대의 비늘 전사. 화염에 강하고 참격에 저항한다.",
        color = {1.0, 0.5, 0.1},
        resist = {fire = 0.5, slash = 0.3},
        weak = {ice = 0.3, pierce = 0.2},
    },
    construct = {
        name = "구조체", desc = "무기물/인공물. 독/화염 면역. 번개/타격에 약하다.",
        color = {0.6, 0.6, 0.6},
        resist = {poison = 1.0, fire = 0.3, slash = 0.3, pierce = 0.3},
        weak = {lightning = 0.5, strike = 0.5},
    },
    insect = {
        name = "곤충", desc = "작은 다지류. 독에 강하지만 화염에 매우 약하다.",
        color = {0.3, 0.6, 0.2},
        resist = {poison = 0.5},
        weak = {fire = 0.5, strike = 0.3},
    },
    reptile = {
        name = "파충류", desc = "냉혈 생물. 독에 저항하지만 빙결에 약하다.",
        color = {0.2, 0.6, 0.4},
        resist = {poison = 0.3},
        weak = {ice = 0.4},
    },
    orc = {
        name = "오크", desc = "강인한 전사 종족. 타격에 강하지만 마법에 약하다.",
        color = {0.5, 0.7, 0.2},
        resist = {strike = 0.2},
        weak = {lightning = 0.2, fire = 0.15},
    },
    troll = {
        name = "트롤", desc = "재생력이 뛰어난 거인. 화염에 매우 약하다.",
        color = {0.3, 0.6, 0.3},
        resist = {strike = 0.2, poison = 0.2},
        weak = {fire = 0.5},
    },
    elf = {
        name = "엘프", desc = "마법 친화적 종족. 마법에 저항하지만 물리에 약하다.",
        color = {0.4, 0.3, 0.7},
        resist = {fire = 0.2, ice = 0.2, lightning = 0.2},
        weak = {strike = 0.3, slash = 0.15},
    },
}

--- 속성 상성 데미지 배율 계산
local function getElementMult(element, race)
    if not race or not RACE_DB[race] then return 1.0 end
    local raceData = RACE_DB[race]

    -- 저항 체크 (데미지 감소)
    local resist = raceData.resist[element]
    if resist then
        if resist >= 1.0 then return 0 end  -- 면역
        return 1.0 - resist
    end

    -- 약점 체크 (데미지 증가)
    local weak = raceData.weak[element]
    if weak then
        return 1.0 + weak
    end

    return 1.0
end

-- ===== 몬스터 데이터베이스 (DCSS 스타일 + 종족) =====
local ENEMY_DB = {
    -- 1층: 약한 적
    {name="쥐",         char="r", hp=3,  atk=1, def=0, spd=1.2, exp=3,  ev=15, color={0.5,0.4,0.3}, floors={1,2}, race="beast", atkElement="pierce"},
    {name="고블린",      char="g", hp=6,  atk=2, def=0, spd=1.0, exp=6,  ev=10, color={0,0.8,0},     floors={1,2,3}, race="goblinoid", atkElement="slash"},
    {name="코볼트",      char="k", hp=5,  atk=2, def=1, spd=1.1, exp=5,  ev=12, color={0.6,0.5,0.2}, floors={1,2}, race="goblinoid", atkElement="pierce", biomes={"dungeon", "forest"}},
    {name="박쥐",        char="b", hp=3,  atk=1, def=0, spd=1.5, exp=3,  ev=25, color={0.4,0.3,0.5}, floors={1,2,3}, race="beast", atkElement="pierce", biomes={"dungeon", "ice_cave"}},
    {name="좀비",        char="z", hp=10, atk=2, def=2, spd=0.5, exp=8,  ev=0,  color={0.3,0.5,0.2}, floors={1,2,3}, race="undead", atkElement="strike", biomes={"dungeon"}},
    -- 2층: 중간 적
    {name="오크",        char="o", hp=12, atk=4, def=2, spd=1.0, exp=12, ev=8,  color={0.5,0.8,0.2}, floors={2,3,4}, race="orc", atkElement="slash", biomes={"forest", "volcano"}},
    {name="스켈레톤",    char="s", hp=8,  atk=3, def=4, spd=0.8, exp=10, ev=5,  color={0.9,0.9,0.8}, floors={2,3}, race="undead", atkElement="slash", biomes={"dungeon", "ice_cave"}},
    {name="독거미",      char="S", hp=7,  atk=3, def=0, spd=1.3, exp=10, ev=18, color={0.2,0.7,0.2}, floors={2,3}, race="insect", atkElement="poison", biomes={"forest"}},
    {name="늑대",        char="w", hp=9,  atk=4, def=1, spd=1.4, exp=10, ev=15, color={0.5,0.5,0.5}, floors={2,3}, race="beast", atkElement="pierce", biomes={"forest", "ice_cave"}},
    {name="오크전사",    char="O", hp=18, atk=5, def=3, spd=0.9, exp=18, ev=8,  color={0.5,0.6,0.2}, floors={2,3,4}, race="orc", atkElement="strike", biomes={"forest", "volcano"}},
    -- 3층: 강한 적
    {name="트롤",        char="T", hp=25, atk=7, def=3, spd=0.7, exp=25, ev=5,  color={0.3,0.6,0.3}, floors={3,4}, race="troll", atkElement="strike", biomes={"forest"}},
    {name="가고일",      char="G", hp=20, atk=5, def=8, spd=0.6, exp=22, ev=3,  color={0.5,0.5,0.5}, floors={3,4}, race="construct", atkElement="strike", biomes={"dungeon", "volcano"}},
    {name="리자드맨",    char="L", hp=18, atk=6, def=4, spd=1.1, exp=20, ev=12, color={0.2,0.6,0.4}, floors={3,4}, race="reptile", atkElement="slash", biomes={"forest", "ice_cave"}},
    {name="미노타우로스",char="M", hp=30, atk=8, def=4, spd=1.0, exp=30, ev=6,  color={0.6,0.3,0.1}, floors={3,4,5}, race="beast", atkElement="strike"},
    {name="워록",        char="W", hp=15, atk=9, def=2, spd=0.8, exp=28, ev=10, color={0.5,0.2,0.7}, floors={3,4,5}, race="human", atkElement="fire", biomes={"dungeon", "ice_cave"}},
    -- 4층: 엘리트
    {name="오우거",      char="F", hp=35, atk=10,def=5, spd=0.6, exp=35, ev=3,  color={0.7,0.4,0.2}, floors={4,5}, race="troll", atkElement="strike", biomes={"forest", "volcano"}},
    {name="다크엘프",    char="e", hp=20, atk=8, def=3, spd=1.3, exp=30, ev=20, color={0.3,0.2,0.5}, floors={4,5}, race="elf", atkElement="lightning", biomes={"dungeon", "forest"}},
    {name="네크로맨서",  char="N", hp=22, atk=10,def=3, spd=0.9, exp=35, ev=12, color={0.4,0.1,0.4}, floors={4,5}, race="human", atkElement="poison", biomes={"dungeon", "ice_cave"}},
    {name="석상",        char="X", hp=40, atk=6, def=12,spd=0.4, exp=30, ev=0,  color={0.6,0.6,0.65},floors={4,5}, race="construct", atkElement="strike", biomes={"dungeon", "volcano"}},
    {name="화염마",      char="E", hp=25, atk=12,def=4, spd=1.0, exp=40, ev=15, color={1.0,0.3,0.1}, floors={4,5}, race="demon", atkElement="fire", biomes={"volcano"}},
    -- 5층: 보스급
    {name="드래곤",      char="D", hp=60, atk=15,def=8, spd=0.8, exp=80, ev=10, color={1,0.2,0},     floors={5}, race="dragon", atkElement="fire", biomes={"volcano"}},
    {name="리치",        char="$", hp=40, atk=14,def=5, spd=0.7, exp=70, ev=12, color={0.3,0.8,0.3}, floors={5}, race="undead", atkElement="ice", biomes={"ice_cave"}},
    {name="골렘",        char="#", hp=70, atk=12,def=15,spd=0.3, exp=60, ev=0,  color={0.5,0.4,0.3}, floors={5}, race="construct", atkElement="strike", biomes={"dungeon"}},
    {name="악마",        char="&", hp=50, atk=16,def=6, spd=1.2, exp=90, ev=18, color={0.8,0.1,0.1}, floors={5}, race="demon", atkElement="fire"},
    {name="고대용",      char="@", hp=100,atk=20,def=10,spd=0.9, exp=150,ev=8,  color={1.0,0.8,0.0}, floors={5}, race="dragon", atkElement="fire"},
}

local BOSS_DB = {
    [2] = {name="고블린 왕", char="K", hp=45, atk=7, def=4, spd=0.9, exp=70, ev=10, color={0.2,1.0,0.2}, race="goblinoid", atkElement="slash"},
    [3] = {name="거미 여왕", char="Q", hp=70, atk=10, def=5, spd=1.1, exp=110, ev=16, color={0.4,0.9,0.3}, race="insect", atkElement="poison"},
    [4] = {name="룬 골렘", char="R", hp=95, atk=13, def=14, spd=0.5, exp=160, ev=2, color={0.6,0.7,1.0}, race="construct", atkElement="lightning"},
    [5] = {name="심연의 고대용", char="A", hp=150, atk=22, def=12, spd=0.8, exp=300, ev=8, color={1.0,0.15,0.15}, race="dragon", atkElement="fire"},
}

local function spawnBoss()
    local btype = BOSS_DB[floor]
    if not btype or #rooms < 2 then return end

    local room = rooms[#rooms]
    local bx, by = getRandomFloorInRoom(room)
    local hpVal = btype.hp + floor * 8
    table.insert(enemies, {
        x = bx,
        y = by,
        name = btype.name,
        char = btype.char,
        hp = hpVal,
        maxHp = hpVal,
        atk = btype.atk + floor,
        def = btype.def,
        ev = btype.ev,
        spd = btype.spd or 1.0,
        exp = btype.exp,
        color = btype.color,
        alive = true,
        race = btype.race or "human",
        atkElement = btype.atkElement or "physical",
        isBoss = true,
    })
    addMessage("보스 출현: " .. btype.name)
end

local function spawnTreasureRoom()
    if floor < 3 then return end
    local prob = (floor - 2) * 15 -- 3층 15%, 4층 30%, 5층 45%
    if math.random(1, 100) > prob then return end
    if #rooms < 3 then return end

    local roomIdx = math.random(2, #rooms - 1)
    local room = rooms[roomIdx]

    -- 상자 배치
    map[room.cy][room.cx] = TILE_LOCKED_CHEST

    -- 수호자 배치
    local ex, ey = room.cx + 1, room.cy
    if map[ey] and map[ey][ex] == TILE_WALL then ex = room.cx - 1 end

    table.insert(enemies, {
        x = ex,
        y = ey,
        name = "엘리트 수호자",
        char = "G",
        hp = 80 + floor * 15,
        maxHp = 80 + floor * 15,
        atk = 15 + floor * 2,
        def = 10 + floor,
        ev = 5,
        spd = 1.0,
        exp = 100 + floor * 20,
        color = {0.8, 0.2, 0.8},
        alive = true,
        race = "construct",
        atkElement = "strike",
        isBoss = true,
    })
    addMessage(">> 이 층 어딘가에 강력한 수호자가 지키는 보물 상자가 있습니다! <<", {1, 0.8, 0.2})
end

-- ===== 적 생성 =====
local function spawnEnemies()
    local available = {}
    for _, e in ipairs(ENEMY_DB) do
        local floorMatch = false
        for _, f in ipairs(e.floors) do
            if f == floor then
                floorMatch = true
                break
            end
        end

        local biomeMatch = true
        if e.biomes then
            biomeMatch = false
            for _, b in ipairs(e.biomes) do
                if b == currentBiome then
                    biomeMatch = true
                    break
                end
            end
        end

        if floorMatch and biomeMatch then
            table.insert(available, e)
        end
    end
    if #available == 0 then return end

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(1, MAX_ENEMIES_PER_ROOM)
        for j = 1, count do
            local ex, ey = getRandomFloorInRoom(room)

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
                race = etype.race or "human",
                atkElement = etype.atkElement or "physical",
            })
        end
    end
    spawnBoss()
    spawnTreasureRoom()
end

-- ===== 바닥 아이템 생성 =====
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
end

local function spawnGroundItems()
    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(0, MAX_ITEMS_PER_ROOM)
        for j = 1, count do
            local ix, iy = getRandomFloorInRoom(room)
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
        local race = charSelect.chosenRace or PLAYER_RACES[1]
        local class = charSelect.chosenClass or PLAYER_CLASSES[1]

        -- 기본 스탯 = 종족 기본 + 직업 보너스
        local baseStr = race.stats.str + class.statBonus.str
        local baseDex = race.stats.dex + class.statBonus.dex
        local baseInt = race.stats.int + class.statBonus.int
        local baseCon = race.stats.con + class.statBonus.con
        local baseLck = race.stats.lck + class.statBonus.lck

        -- 무기 숙련도 초기값 (종족 + 직업)
        local prof = {}
        local profElements = {"slash", "pierce", "strike", "fire", "ice", "lightning", "poison", "holy"}
        for _, e in ipairs(profElements) do
            prof[e] = (race.profBonus[e] or 0) + (class.profBonus[e] or 0)
        end

        -- 스킬 목록 (종족 + 직업)
        local skills = {}
        local function cloneSkill(s)
            return {
                id = s.id,
                name = s.name,
                desc = s.desc,
                cooldown = s.cooldown,
                currentCd = 0,
                duration = s.duration,
                type = s.type,
                value = s.value,
                element = s.element,
                statBonus = s.statBonus,
                attackScale = s.attackScale,
                healScale = s.healScale,
                range = s.range,
                active = 0
            }
        end
        for _, s in ipairs(race.skills) do
            table.insert(skills, cloneSkill(s))
        end
        for _, s in ipairs(class.skills) do
            table.insert(skills, cloneSkill(s))
        end

        -- 종족/직업 저항/약점 합산
        local pResist = {}
        local pWeak = {}
        for k, v in pairs(race.resist) do pResist[k] = v end
        for k, v in pairs(race.weak) do pWeak[k] = v end

        player = {
            x = startRoom and startRoom.cx or 1,
            y = startRoom and startRoom.cy or 1,
            char = race.char or "@",
            hp = 30,
            maxHp = 30,
            mana = 0,
            maxMana = 0,
            baseAtk = 3,
            baseDef = 0,
            exp = 0,
            nextExp = 20,
            level = 1,
            gold = 0,
            str = baseStr,
            dex = baseDex,
            int = baseInt,
            con = baseCon,
            lck = baseLck,
            raceName = race.name,
            raceId = race.id,
            className = class.name,
            classId = class.id,
            raceColor = race.color,
            classColor = class.color,
            proficiency = prof,
            skills = skills,
            resist = pResist,
            weak = pWeak,
            hpBonus = race.hpBonus or 0,
            expBonus = race.expBonus or 0,
            buffs = {},  -- {id, name, duration, ...}
            nextAtkBonus = nil,  -- 다음 공격 보너스 (강타/급소 등)
            skillPoints = 0,
            unlockedSkills = {},  -- { skill_id = true }
        }
        updateCombatContext()
    end
end

local Combat = require("systems.combat")

-- Update Context helper for main.lua to call when player/enemies change
local function interruptChanneling()
    if channeling_return > 0 then
        channeling_return = 0
        addMessage("피격당해 귀환 주문서 시전이 취소되었습니다!", {1.0, 0.2, 0.2})
    end
end

local function setGameState(state)
    gameState = state
end

local function setStatAlloc(alloc)
    statAlloc = alloc
end

updateCombatContext = function()
    Combat.init({
        player = player,
        enemies = enemies,
        equip = equip,
        addMessage = addMessage,
        Item = Item,
        getElementMult = getElementMult,
        canUseSkillByRestriction = canUseSkillByRestriction,
        SKILLS_DB = SKILLS_DB,
        groundItems = groundItems,
        rollDrop = rollDrop,
        floor = floor,
        map = map,
        interruptChanneling = interruptChanneling,
        setGameState = setGameState,
        setStatAlloc = setStatAlloc
    })
    Quest.init({
        player = player,
        inventory = inventory,
        Item = Item,
        addMessage = addMessage
    })
end

local getPlayerAtk = Combat.getPlayerAtk
local getPlayerDef = Combat.getPlayerDef
local getPlayerEvasion = Combat.getPlayerEvasion
local getPlayerAccuracy = Combat.getPlayerAccuracy
local getPlayerCritChance = Combat.getPlayerCritChance
local getPlayerCritMult = Combat.getPlayerCritMult
local getPlayerMaxHp = Combat.getPlayerMaxHp
local getPlayerMaxMana = Combat.getPlayerMaxMana
local getPlayerManaRegen = Combat.getPlayerManaRegen
local getEquipPassives = Combat.getEquipPassives
local getPassiveValue = Combat.getPassiveValue
local getPlayerEvasionFull = Combat.getPlayerEvasionFull
local getPlayerCritFull = Combat.getPlayerCritFull
local getPlayerElement = Combat.getPlayerElement
local getProficiencyBonus = Combat.getProficiencyBonus
local gainProficiency = Combat.gainProficiency
local getPlayerElementDefense = Combat.getPlayerElementDefense
local hasBuff = Combat.hasBuff
local addPassives = Combat.addPassives
local applyBuff = Combat.applyBuff
local tickBuffs = Combat.tickBuffs
local tickSkillCooldowns = Combat.tickSkillCooldowns
local getSkillManaCost = Combat.getSkillManaCost
local recoverMana = Combat.recoverMana
local useSkill = Combat.useSkill
local gainExp = Combat.gainExp
local checkLevelUp = Combat.checkLevelUp
local dealPlayerAttack = Combat.dealPlayerAttack
local attackEnemy = Combat.attackEnemy
local enemyAttack = Combat.enemyAttack

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

-- ===== 아이템 버리기 =====
local function dropItemAtPlayer(item)
    if not item or not player.x or not player.y then
        return false
    end

    -- 버린 아이템은 즉시 줍기 루프에 다시 먹히지 않도록 바닥 아이템 상태만 새로 만든다.
    item._gridCol = nil
    item._gridRow = nil
    item._inventory = nil
    table.insert(groundItems, {
        x = player.x,
        y = player.y,
        item = item,
        picked = false
    })
    addMessage(item.name .. " 버림. (현재 위치 바닥)")
    return true
end

local function discardHoveredInventoryItem()
    if gameState ~= "inventory" or not inv then
        return false
    end

    local mx, my = love.mouse.getPosition()
    local item = inv:getItemAt(mx, my)
    if not item then
        addMessage("버릴 인벤토리 아이템에 마우스를 올리세요.")
        return false
    end

    inv:removeItem(item)
    hoverItem = nil
    return dropItemAtPlayer(item)
end

-- ===== 마을로 귀환 =====
local function goToTown()
    gameState = "town"
    townMenuSel = 1
    dungeonRun = dungeonRun + 1
    Quest.claimRewards()
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana
    shop.needsRefresh = true
    addMessage("** 마을에 도착했습니다! (HP/MP 회복) **")
end

-- ===== 던전 출발 =====
local function startDungeon()
    floor = 1
    turn = 0
    floorStates = {}
    gameState = "playing"
    addMessage(">> 제 " .. (dungeonRun + 1) .. "번째 탐험 시작! <<")
    Quest.generateQuests()
    local gen = MapGen.generate(floor)
    map = gen.map
    visibleMap = gen.visibleMap
    exploredMap = gen.exploredMap
    rooms = gen.rooms
    COLOR_WALL = gen.colorWall
    COLOR_FLOOR = gen.colorFloor
    
    if gen.stairUpX then
        floorStates[floor] = floorStates[floor] or {}
        floorStates[floor].upX = gen.stairUpX
        floorStates[floor].upY = gen.stairUpY
    end
    if gen.stairDownX then
        floorStates[floor] = floorStates[floor] or {}
        floorStates[floor].downX = gen.stairDownX
        floorStates[floor].downY = gen.stairDownY
    end

    enemies = {}
    groundItems = {}

    generateProceduralTileset()
    updateCombatContext()
    spawnEnemies()
    spawnGroundItems()
    saveFloorState()
    initPlayer(true)
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana
end

-- ===== 계단 =====
local function checkStair()
    if not map[player.y] then return end
    local tile = map[player.y][player.x]

    if tile == TILE_STAIR_DOWN then
        if hasAliveBoss() then
            addMessage("보스의 힘 때문에 아래 계단이 봉인되어 있습니다.")
            return
        end
        saveFloorState()
        floor = floor + 1
        if floor > 5 then
            addMessage("** 던전 클리어! 마을로 귀환합니다 **")
            goToTown()
            return
        end
        addMessage(">> " .. floor .. "층으로 이동 <<")
        Quest.updateReach(floor)
        turn = 0
        if not loadFloorState(floor) then
            local gen = MapGen.generate(floor)
            map = gen.map
            visibleMap = gen.visibleMap
            exploredMap = gen.exploredMap
            rooms = gen.rooms
            COLOR_WALL = gen.colorWall
            COLOR_FLOOR = gen.colorFloor

            if gen.stairUpX then
                floorStates[floor] = floorStates[floor] or {}
                floorStates[floor].upX = gen.stairUpX
                floorStates[floor].upY = gen.stairUpY
            end
            if gen.stairDownX then
                floorStates[floor] = floorStates[floor] or {}
                floorStates[floor].downX = gen.stairDownX
                floorStates[floor].downY = gen.stairDownY
            end

            enemies = {}
            groundItems = {}

            generateProceduralTileset()
            updateCombatContext()
            spawnEnemies()
            spawnGroundItems()
            saveFloorState()
        end
        initPlayer(true)
        setPlayerAtFloorEntry("down")
        player.maxMana = getPlayerMaxMana()
        player.mana = math.min(player.mana or player.maxMana, player.maxMana)
        updateFOV()
        updateCamera()
    elseif tile == TILE_STAIR_UP then
        if floor <= 1 then return end
        saveFloorState()
        floor = floor - 1
        addMessage("<< " .. floor .. "층으로 올라감 >>")
        loadFloorState(floor)
        initPlayer(true)
        setPlayerAtFloorEntry("up")
        player.maxMana = getPlayerMaxMana()
        player.mana = math.min(player.mana or player.maxMana, player.maxMana)
        updateFOV()
        updateCamera()
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
                    gainExp(enemy.exp)
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
                    gainExp(enemy.exp)
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

    -- 트롤 재생 버프
    if hasBuff("regenerate") and player.hp < getPlayerMaxHp() then
        local healAmt = 3
        player.hp = math.min(getPlayerMaxHp(), player.hp + healAmt)
        addMessage("  ★ 재생 +" .. healAmt .. " HP")
    end

    local manaBefore = player.mana or 0
    recoverMana(getPlayerManaRegen())
    if player.mana and player.mana > manaBefore then
        addMessage("마나 +" .. (player.mana - manaBefore))
    end

    -- 버프/스킬 쿨다운 처리
    tickBuffs()
    tickSkillCooldowns()

    -- 횃불(조명) 수명 감소
    if equip and equip.slots.torch then
        local torch = equip.slots.torch
        if torch.passive and torch.passive.type == "torch" then
            torch.passive.value = torch.passive.value - 1
            if torch.passive.value <= 0 then
                equip:equip(nil, "torch") -- 장착 해제 및 파괴
                addMessage("횃불이 다 탔습니다! 주위가 어두워집니다.", {1, 0.5, 0.5})
            end
        end
    end

    if channeling_return > 0 then
        channeling_return = channeling_return - 1
        if channeling_return <= 0 then
            addMessage("무사히 귀환했습니다!", {0.5, 1.0, 0.5})
            goToTown()
        else
            addMessage("귀환까지 " .. channeling_return .. "턴 남았습니다...", {0.8, 0.6, 1.0})
        end
    end

    -- 지형 효과 적용 (용암)
    if map[player.y] and map[player.y][player.x] == TILE_LAVA then
        local dmg = math.max(1, math.floor(getPlayerMaxHp() * 0.05))
        player.hp = player.hp - dmg
        addMessage("용암을 밟아 " .. dmg .. "의 화상 데미지를 입었습니다!", {1.0, 0.3, 0.1})
        if channeling_return > 0 then
            channeling_return = 0
            addMessage("피격당해 귀환 주문서 시전이 취소되었습니다!", {1.0, 0.2, 0.2})
        end
    end

    for _, enemy in ipairs(enemies) do
        if enemy.alive and map[enemy.y] and map[enemy.y][enemy.x] == TILE_LAVA then
            local dmg = math.max(1, math.floor(enemy.maxHp * 0.05))
            enemy.hp = enemy.hp - dmg
            if enemy.hp <= 0 then
                enemy.alive = false
                addMessage(enemy.name .. "이(가) 용암에 타죽었습니다!", {1.0, 0.5, 0.1})
                gainExp(enemy.exp)
            end
        end
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

function updateCamera()
    local screenW = 1280 - 270
    local screenH = 720
    camera.x = math.max(0, math.min((player.x * TILE_SIZE) - (screenW / 2), (MAP_WIDTH * TILE_SIZE) - screenW))
    camera.y = math.max(0, math.min((player.y * TILE_SIZE) - (screenH / 2), (MAP_HEIGHT * TILE_SIZE) - screenH))
end

function updateFOV()
    local radius = 5
    -- 종족 기본 시야
    if player.raceName == "뱀파이어" or player.raceName == "자동인형" then
        radius = 8
    end
    -- 횃불 장착 시 시야 보너스
    if equip and equip.slots.torch then
        radius = 10
    end

    local function isOpaque(x, y)
        if y < 1 or y > MAP_HEIGHT or x < 1 or x > MAP_WIDTH then return true end
        return map[y][x] == TILE_WALL
    end

    visibleMap = FOV.calculate(player.x, player.y, radius, map, MAP_WIDTH, MAP_HEIGHT, isOpaque, visibleMap)

    -- 시야에 들어온 곳은 탐험됨 처리 (반경 내에서만 확인하여 최적화)
    local startX = math.max(1, player.x - radius)
    local endX = math.min(MAP_WIDTH, player.x + radius)
    local startY = math.max(1, player.y - radius)
    local endY = math.min(MAP_HEIGHT, player.y + radius)

    for y = startY, endY do
        for x = startX, endX do
            if visibleMap[y][x] then
                exploredMap[y][x] = true
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
    
    if map[ny][nx] == TILE_OPEN_CHEST then
        addMessage("이미 열려있는 빈 상자입니다.")
        return
    end

    if map[ny][nx] == TILE_LOCKED_CHEST then
        if inventory:hasItem("dungeon_key") then
            inventory:consumeItem("dungeon_key")
            map[ny][nx] = TILE_OPEN_CHEST
            addMessage("신비한 던전 열쇠로 상자를 열었습니다!", {0.2, 1.0, 0.2})
            
            local highTierIds = {
                "executioner_axe", "mjolnir", "crystal_sword", 
                "aegis_shield", "retribution_armor", 
                "phoenix_feather", "mana_stone_ring"
            }
            local dropId = highTierIds[math.random(1, #highTierIds)]
            local itemData = Item.DATABASE[dropId]
            if itemData then
                local newItem = Item.new(itemData)
                table.insert(groundItems, {x = nx, y = ny, item = newItem, picked = false})
                addMessage("상자에서 [" .. newItem.name .. "]을(를) 발견했습니다!", {1.0, 0.8, 0.2})
            end
        else
            addMessage("잠겨 있습니다. (신비한 던전 열쇠 필요)", {1.0, 0.5, 0.5})
        end
        return
    end

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
    
    updateFOV()
    updateCamera()
end

-- ===== LÖVE2D 콜백 =====
--- 캐릭터 생성 완료 → 마을로 이동
local function finishCharCreation()
    -- 인벤토리 & 장비 & 상점 & 보관함 초기화
    inv = Inventory.new(10, 6)
    equip = Equipment.new()
    updateCombatContext()
    shop = Shop.new()
    stash = Inventory.new(10, 6)

    dungeonRun = 0
    initPlayer()
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana

    -- 직업별 시작 장비
    local cls = charSelect.chosenClass or PLAYER_CLASSES[1]
    if cls.startWeapon then
        local w = Item.create(cls.startWeapon)
        if w and canEquipItemByRestriction(w) then inv:autoPlace(w) end
    end
    if cls.startArmor then
        local a = Item.create(cls.startArmor)
        if a and canEquipItemByRestriction(a) then inv:autoPlace(a) end
    end
    if cls.startItems then
        for _, itemId in ipairs(cls.startItems) do
            local it = Item.create(itemId)
            if it then inv:autoPlace(it) end
        end
    end

    gameState = "town"
    townMenuSel = 1
    addMessage("마을에 오신 것을 환영합니다!")
    addMessage(player.raceName .. " " .. player.className .. "(으)로 모험을 시작합니다!")
    addMessage("상점에서 아이템을 사고팔 수 있습니다.")
end

local function resetAfterDeath()
    inv = nil
    equip = nil
    shop = nil
    stash = nil
    player = {}
    enemies = {}
    groundItems = {}
    map = {}
    rooms = {}
    floorStates = {}
    floor = 1
    turn = 0
    dungeonRun = 0
    statAlloc = nil
    drag.item = nil
    drag.fromInv = nil
    drag.fromSlot = nil
    hoverItem = nil
    charSelect = {
        phase = "race",
        raceSel = 1,
        classSel = 1,
        chosenRace = nil,
        chosenClass = nil,
    }
    messages = {}
    messageScroll = 0
    addMessage("사망했습니다. 캐릭터와 인벤토리가 모두 사라졌습니다.")
    addMessage("새 종족과 직업을 선택하세요.")
    gameState = "charselect"
end

function generateProceduralTileset()
    local canvasWidth = 256
    local canvasHeight = 256
    local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    
    local tx, ty = 0, 0
    local function getNextRect()
        local rx, ry = tx * TILE_SIZE, ty * TILE_SIZE
        tx = tx + 1
        if tx * TILE_SIZE >= canvasWidth then
            tx = 0
            ty = ty + 1
        end
        return rx, ry
    end
    
    local function createTileQuad(colorBase, colorDetail, drawDetailFunc)
        local x, y = getNextRect()
        love.graphics.setColor(colorBase)
        love.graphics.rectangle("fill", x, y, TILE_SIZE, TILE_SIZE)
        love.graphics.setColor(colorDetail)
        if drawDetailFunc then
            drawDetailFunc(x, y)
        end
        return love.graphics.newQuad(x, y, TILE_SIZE, TILE_SIZE, canvasWidth, canvasHeight)
    end

    TILE_QUADS[TILE_WALL] = createTileQuad(COLOR_WALL, {0.2, 0.2, 0.25}, function(x, y)
        love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE)
        love.graphics.line(x, y + 8, x + 16, y + 8)
        love.graphics.line(x + 8, y, x + 8, y + 8)
        love.graphics.line(x + 4, y + 8, x + 4, y + 16)
        love.graphics.line(x + 12, y + 8, x + 12, y + 16)
    end)
    TILE_QUADS[TILE_FLOOR] = createTileQuad(COLOR_FLOOR, {0.5, 0.5, 0.4}, function(x, y)
        love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE)
        love.graphics.rectangle("fill", x+3, y+3, 1, 1)
        love.graphics.rectangle("fill", x+12, y+8, 1, 1)
        love.graphics.rectangle("fill", x+5, y+14, 1, 1)
    end)
    TILE_QUADS[TILE_WATER] = createTileQuad(COLOR_WATER, {0.2, 0.5, 0.9}, function(x, y)
        love.graphics.line(x+2, y+4, x+6, y+4)
        love.graphics.line(x+8, y+8, x+12, y+8)
        love.graphics.line(x+4, y+12, x+8, y+12)
    end)
    TILE_QUADS[TILE_LAVA] = createTileQuad(COLOR_LAVA, {1.0, 0.6, 0.1}, function(x, y)
        love.graphics.circle("fill", x+4, y+5, 2)
        love.graphics.circle("fill", x+11, y+10, 3)
        love.graphics.circle("fill", x+6, y+14, 1)
    end)
    TILE_QUADS[TILE_GRASS] = createTileQuad(COLOR_GRASS, {0.3, 0.8, 0.4}, function(x, y)
        love.graphics.line(x+4, y+12, x+4, y+8)
        love.graphics.line(x+5, y+12, x+6, y+7)
        love.graphics.line(x+10, y+14, x+10, y+10)
        love.graphics.line(x+11, y+14, x+13, y+9)
    end)
    TILE_QUADS[TILE_DIRT] = createTileQuad(COLOR_DIRT, {0.4, 0.3, 0.15}, function(x, y)
        love.graphics.rectangle("fill", x+2, y+3, 4, 2)
        love.graphics.rectangle("fill", x+10, y+8, 3, 3)
        love.graphics.rectangle("fill", x+5, y+12, 2, 2)
    end)
    TILE_QUADS[TILE_STAIR_DOWN] = createTileQuad(COLOR_FLOOR, COLOR_STAIR, function(x, y)
        love.graphics.rectangle("fill", x+2, y+2, 12, 12)
        love.graphics.setColor(0,0,0)
        love.graphics.rectangle("fill", x+4, y+4, 8, 8)
    end)
    TILE_QUADS[TILE_STAIR_UP] = createTileQuad(COLOR_FLOOR, {0.6, 0.9, 1.0}, function(x, y)
        love.graphics.rectangle("fill", x+2, y+2, 12, 12)
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle("fill", x+6, y+6, 4, 4)
    end)

    local function createEntityQuad(baseColor, eyeColor, isBig, typeStr)
        local x, y = getNextRect()
        love.graphics.setColor(baseColor)
        
        if typeStr == "dragon" then
            love.graphics.polygon("fill", x, y+8, x+8, y, x+16, y+8)
            love.graphics.rectangle("fill", x+2, y+8, 12, 8)
        elseif typeStr == "slime" then
            love.graphics.arc("fill", "pie", x+8, y+16, 8, math.pi, math.pi*2)
        elseif typeStr == "skeleton" then
            love.graphics.rectangle("fill", x+3, y+2, 10, 10)
            love.graphics.rectangle("fill", x+5, y+12, 6, 4)
        elseif typeStr == "beast" then
            love.graphics.polygon("fill", x+2, y+6, x+4, y, x+6, y+6)
            love.graphics.polygon("fill", x+10, y+6, x+12, y, x+14, y+6)
            love.graphics.rectangle("fill", x+2, y+6, 12, 10)
        elseif typeStr == "humanoid" then
            love.graphics.circle("fill", x+8, y+6, 4)
            love.graphics.rectangle("fill", x+4, y+10, 8, 6)
        else
            if isBig then
                love.graphics.rectangle("fill", x, y, 16, 16)
            else
                love.graphics.rectangle("fill", x+2, y+2, 12, 12)
            end
        end

        love.graphics.setColor(eyeColor)
        if typeStr == "slime" then
            love.graphics.rectangle("fill", x+4, y+10, 2, 2)
            love.graphics.rectangle("fill", x+10, y+10, 2, 2)
        else
            love.graphics.rectangle("fill", x+4, y+5, 2, 2)
            love.graphics.rectangle("fill", x+10, y+5, 2, 2)
        end

        return love.graphics.newQuad(x, y, TILE_SIZE, TILE_SIZE, canvasWidth, canvasHeight)
    end

    ENTITY_QUADS["@"] = createEntityQuad({1, 1, 0}, {0,0,0}, false, "humanoid")
    ENTITY_QUADS["r"] = createEntityQuad({0.6, 0.4, 0.2}, {1,0,0}, false, "beast")
    ENTITY_QUADS["g"] = createEntityQuad({0.2, 0.8, 0.2}, {1,1,0}, false, "humanoid")
    ENTITY_QUADS["k"] = createEntityQuad({0.7, 0.2, 0.2}, {0,0,0}, false, "humanoid")
    ENTITY_QUADS["b"] = createEntityQuad({0.3, 0.3, 0.3}, {1,0,0}, false, "beast")
    ENTITY_QUADS["z"] = createEntityQuad({0.4, 0.6, 0.4}, {0,0,0}, false, "humanoid")
    ENTITY_QUADS["o"] = createEntityQuad({0.1, 0.5, 0.1}, {1,0,0}, true, "humanoid")
    ENTITY_QUADS["s"] = createEntityQuad({0.9, 0.9, 0.9}, {0,0,0}, false, "skeleton")
    ENTITY_QUADS["p"] = createEntityQuad({0.4, 0.2, 0.6}, {1,0,1}, false, "beast")
    ENTITY_QUADS["w"] = createEntityQuad({0.6, 0.6, 0.6}, {1,1,0}, false, "beast")
    ENTITY_QUADS["O"] = createEntityQuad({0.2, 0.6, 0.2}, {1,0,0}, true, "humanoid")
    ENTITY_QUADS["T"] = createEntityQuad({0.3, 0.5, 0.3}, {0,0,0}, true, "humanoid")
    ENTITY_QUADS["G"] = createEntityQuad({0.5, 0.5, 0.5}, {1,0,0}, true, "dragon")
    ENTITY_QUADS["l"] = createEntityQuad({0.2, 0.6, 0.4}, {1,1,0}, false, "humanoid")
    ENTITY_QUADS["M"] = createEntityQuad({0.6, 0.3, 0.1}, {1,0,0}, true, "beast")
    ENTITY_QUADS["W"] = createEntityQuad({0.3, 0.1, 0.5}, {1,1,1}, false, "humanoid")
    ENTITY_QUADS["U"] = createEntityQuad({0.6, 0.5, 0.4}, {0,0,0}, true, "humanoid")
    ENTITY_QUADS["E"] = createEntityQuad({0.4, 0.4, 0.6}, {1,0,0}, false, "humanoid")
    ENTITY_QUADS["N"] = createEntityQuad({0.2, 0.2, 0.2}, {1,0,0}, false, "humanoid")
    ENTITY_QUADS["S"] = createEntityQuad({0.6, 0.6, 0.6}, {1,1,1}, true, "skeleton")
    ENTITY_QUADS["H"] = createEntityQuad({0.9, 0.4, 0.1}, {1,1,0}, true, "beast")
    ENTITY_QUADS["D"] = createEntityQuad({0.8, 0.2, 0.2}, {1,1,0}, true, "dragon")
    ENTITY_QUADS["L"] = createEntityQuad({0.8, 0.8, 0.9}, {0,1,1}, false, "skeleton")
    ENTITY_QUADS["C"] = createEntityQuad({0.7, 0.7, 0.8}, {1,0,1}, true, "humanoid")
    ENTITY_QUADS["A"] = createEntityQuad({0.7, 0.1, 0.1}, {1,1,0}, true, "dragon")
    ENTITY_QUADS["X"] = createEntityQuad({0.3, 0.1, 0.1}, {1,0.5,0}, true, "dragon")
    
    local function createItemQuad(typeStr)
        local x, y = getNextRect()
        if typeStr == "sword" then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.polygon("fill", x+12, y+2, x+14, y+4, x+4, y+14, x+2, y+12)
            love.graphics.setColor(0.6, 0.3, 0.1)
            love.graphics.line(x+6, y+10, x+2, y+14)
        elseif typeStr == "shield" then
            love.graphics.setColor(0.6, 0.4, 0.2)
            love.graphics.polygon("fill", x+3, y+2, x+13, y+2, x+13, y+10, x+8, y+15, x+3, y+10)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.rectangle("fill", x+7, y+4, 2, 4)
        elseif typeStr == "armor" then
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.polygon("fill", x+4, y+2, x+12, y+2, x+14, y+6, x+12, y+14, x+4, y+14, x+2, y+6)
        elseif typeStr == "potion" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.rectangle("fill", x+6, y+2, 4, 4)
            love.graphics.setColor(1, 0.2, 0.3)
            love.graphics.polygon("fill", x+6, y+6, x+10, y+6, x+12, y+14, x+4, y+14)
        elseif typeStr == "scroll" then
            love.graphics.setColor(0.9, 0.9, 0.7)
            love.graphics.rectangle("fill", x+3, y+3, 10, 10)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.line(x+5, y+6, x+11, y+6)
            love.graphics.line(x+5, y+9, x+9, y+9)
        elseif typeStr == "gold" then
            love.graphics.setColor(1, 0.85, 0)
            love.graphics.circle("fill", x+6, y+12, 3)
            love.graphics.circle("fill", x+10, y+10, 3)
            love.graphics.circle("fill", x+8, y+8, 3)
        elseif typeStr == "ring" then
            love.graphics.setColor(1, 0.85, 0)
            love.graphics.circle("line", x+8, y+8, 4)
            love.graphics.setColor(0.2, 0.8, 1)
            love.graphics.circle("fill", x+8, y+4, 2)
        elseif typeStr == "relic" then
            love.graphics.setColor(0.8, 0.2, 0.6)
            love.graphics.polygon("fill", x+8, y+2, x+14, y+8, x+8, y+14, x+2, y+8)
        else
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.rectangle("fill", x+4, y+4, 8, 8)
        end
        return love.graphics.newQuad(x, y, TILE_SIZE, TILE_SIZE, canvasWidth, canvasHeight)
    end

    -- 의미론적 아이템 매핑
    ENTITY_QUADS["item_sword"] = createItemQuad("sword")
    ENTITY_QUADS["item_bow"] = createItemQuad("sword") -- 임시로 sword 재사용
    ENTITY_QUADS["item_wand"] = createItemQuad("sword")
    ENTITY_QUADS["item_shield"] = createItemQuad("shield")
    ENTITY_QUADS["item_armor"] = createItemQuad("armor")
    ENTITY_QUADS["item_helmet"] = createItemQuad("armor") -- 임시로 armor 재사용
    ENTITY_QUADS["item_boots"] = createItemQuad("shield") -- 임시로 약간 작은 쿼드 재사용
    ENTITY_QUADS["item_potion"] = createItemQuad("potion")
    ENTITY_QUADS["item_scroll"] = createItemQuad("scroll")
    ENTITY_QUADS["item_gold"] = createItemQuad("gold")
    ENTITY_QUADS["item_ring"] = createItemQuad("ring")
    ENTITY_QUADS["item_relic"] = createItemQuad("relic")
    ENTITY_QUADS["item_default"] = createItemQuad("default")

    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)
    TILESET_IMAGE = canvas
end

function getItemQuadKey(item)
    if item.slot == "weapon" or item.slot == "weapon1" or item.slot == "weapon2" then
        if item.name:find("방패") then return "item_shield" end
        if item.name:find("활") or item.name:find("석궁") then return "item_bow" end
        if item.name:find("지팡이") then return "item_wand" end
        return "item_sword"
    elseif item.slot == "armor" then return "item_armor"
    elseif item.slot == "helmet" then return "item_helmet"
    elseif item.slot == "boots" then return "item_boots"
    elseif item.slot == "ring" or item.slot == "amulet" then return "item_ring"
    else
        if item.name:find("포션") or item.name:find("물약") or item.name:find("영약") then return "item_potion"
        elseif item.name:find("주문서") or item.name:find("스크롤") then return "item_scroll"
        elseif item.name:find("유물") or item.name:find("성배") then return "item_relic"
        elseif item.name:find("골드") or item.name:find("돈") or item.name:find("금화") then return "item_gold"
        end
    end
    return "item_default"
end

function love.load()
    MapGen.init({addMessage = addMessage})
    love.window.setTitle("Extraction Roguelike")
    love.window.setMode(1280, 720, {resizable = false})
    
    generateProceduralTileset()

    font = love.graphics.newFont("NanumGothicCoding.ttf", 13)
    love.graphics.setFont(font)

    math.randomseed(os.time())

    -- 캐릭터 선택 화면으로 시작
    gameState = "charselect"
    charSelect.phase = "race"
    charSelect.raceSel = 1
    charSelect.classSel = 1
end

local function checkSecretAreaClear()
    if not inSecretArea or gameState ~= "playing" then return end
    
    local anyAlive = false
    for _, e in ipairs(enemies) do
        if e.alive then anyAlive = true; break end
    end
    
    if not anyAlive then
        gameState = "secret_reward"
        addMessage("투기장의 모든 수호자를 물리쳤습니다!", {0.2, 1.0, 0.2})
        addMessage("원하는 보상을 하나 선택하세요.", {1.0, 0.8, 0.2})
        secretRewards = {}
        local highTierIds = {
            "executioner_axe", "mjolnir", "crystal_sword", 
            "aegis_shield", "retribution_armor", 
            "phoenix_feather", "mana_stone_ring"
        }
        for i=1, 3 do
            local dropId = highTierIds[math.random(1, #highTierIds)]
            local itemData = Item.DATABASE[dropId]
            if itemData then
                table.insert(secretRewards, Item.new(itemData))
            end
        end
    end
end

function love.update(dt)
    if gameState == "charselect" then return end
    if gameState == "gameover" then return end
    checkSecretAreaClear()
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

local function isKey(action, key)
    if not CONFIG or not CONFIG.keys then return false end
    return key == CONFIG.keys[action]
end

-- 설정용 전역 변수
optionsMenuSel = 1
local OPTIONS_MENU = {"오디오: BGM", "오디오: SFX", "조작: 위", "조작: 아래", "조작: 좌", "조작: 우", "조작: 대기", "조작: 상호작용", "조작: 인벤토리", "조작: 스킬트리", "타이틀로 돌아가기"}
local waitingForKey = nil

function love.keypressed(key)
    -- 키 바인딩 대기 상태
    if waitingForKey then
        if key ~= "escape" then
            local actionMap = {
                ["조작: 위"] = "up",
                ["조작: 아래"] = "down",
                ["조작: 좌"] = "left",
                ["조작: 우"] = "right",
                ["조작: 대기"] = "wait",
                ["조작: 상호작용"] = "interact",
                ["조작: 인벤토리"] = "inventory",
                ["조작: 스킬트리"] = "skilltree"
            }
            local action = actionMap[OPTIONS_MENU[optionsMenuSel]]
            if action then
                CONFIG.keys[action] = key
                ConfigManager.save()
            end
        end
        waitingForKey = nil
        return
    end

    -- 환경 설정 화면
    if gameState == "options" then
        if key == "escape" then
            gameState = "playing"
            return
        end
        if isKey("up", key) or key == "up" then
            optionsMenuSel = optionsMenuSel - 1
            if optionsMenuSel < 1 then optionsMenuSel = #OPTIONS_MENU end
        elseif isKey("down", key) or key == "down" then
            optionsMenuSel = optionsMenuSel + 1
            if optionsMenuSel > #OPTIONS_MENU then optionsMenuSel = 1 end
        elseif isKey("left", key) or key == "left" then
            local sel = OPTIONS_MENU[optionsMenuSel]
            if sel == "오디오: BGM" then
                CONFIG.audio.bgm = math.max(0, CONFIG.audio.bgm - 10)
                ConfigManager.save()
            elseif sel == "오디오: SFX" then
                CONFIG.audio.sfx = math.max(0, CONFIG.audio.sfx - 10)
                ConfigManager.save()
            end
        elseif isKey("right", key) or key == "right" then
            local sel = OPTIONS_MENU[optionsMenuSel]
            if sel == "오디오: BGM" then
                CONFIG.audio.bgm = math.min(100, CONFIG.audio.bgm + 10)
                ConfigManager.save()
            elseif sel == "오디오: SFX" then
                CONFIG.audio.sfx = math.min(100, CONFIG.audio.sfx + 10)
                ConfigManager.save()
            end
        elseif isKey("interact", key) or key == "return" or key == "space" then
            local sel = OPTIONS_MENU[optionsMenuSel]
            if sel:find("조작:") then
                waitingForKey = true
            elseif sel == "타이틀로 돌아가기" then
                gameState = "charselect"
                charSelect.phase = "race"
                player = nil
            end
        end
        return
    end

    -- 옵션 토글
    if key == "escape" or isKey("escape", key) then
        if gameState == "playing" then
            gameState = "options"
            return
        elseif gameState == "inventory" then
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
        elseif gameState == "bestiary" then
            gameState = "town"
            return
        elseif gameState == "skilltree" then
            gameState = "playing"
            return
        end
    end

    -- 캐릭터 선택 화면
    if gameState == "charselect" then
        if charSelect.phase == "race" then
            if isKey("up", key) or key == "up" then
                charSelect.raceSel = math.max(1, charSelect.raceSel - 1)
            elseif isKey("down", key) or key == "down" then
                charSelect.raceSel = math.min(#PLAYER_RACES, charSelect.raceSel + 1)
            elseif isKey("interact", key) or key == "return" then
                charSelect.chosenRace = PLAYER_RACES[charSelect.raceSel]
                charSelect.phase = "class"
            end
        elseif charSelect.phase == "class" then
            if isKey("up", key) or key == "up" then
                charSelect.classSel = math.max(1, charSelect.classSel - 1)
            elseif isKey("down", key) or key == "down" then
                charSelect.classSel = math.min(#PLAYER_CLASSES, charSelect.classSel + 1)
            elseif isKey("interact", key) or key == "return" then
                local selectedClass = PLAYER_CLASSES[charSelect.classSel]
                local ok, reason = isClassAllowedForRace(charSelect.chosenRace, selectedClass)
                if not ok then
                    addMessage(reason or "이 종족은 해당 직업을 선택할 수 없습니다.")
                    return
                end
                charSelect.chosenClass = selectedClass
                finishCharCreation()
            elseif isKey("escape", key) or key == "escape" then
                charSelect.phase = "race"
            end
        end
        return
    end

    -- 스킬 핫키 — 게임 플레이 중
    if gameState == "playing" and player and player.skills then
        local skillKey = tonumber(key)
        if skillKey and skillKey >= 1 and skillKey <= #player.skills then
            local selectedSkill = player.skills[skillKey]
            local target = nil

            if selectedSkill.type == "attack" then
                local range = selectedSkill.range or 6
                local bestDist = range + 1
                for _, e in ipairs(enemies) do
                    local dist = distance(player.x, player.y, e.x, e.y)
                    if e.alive and dist <= range and dist < bestDist then
                        target = e
                        bestDist = dist
                    end
                end
                if not target then
                    addMessage("사거리 안에 대상이 없습니다.")
                    return
                end
            end

            local used = useSkill(skillKey, target)
            if used then
                local s = selectedSkill
                if s.type == "attack" or s.type == "heal" then
                    turn = turn + 1
                    processStatusEffects()
                    moveEnemies()
                end
                if target and target.hp <= 0 and target.alive then
                    target.alive = false
                    gainExp(target.exp or 0)
                    local goldDrop = math.random(5, 15) * floor
                    if target.isBoss then
                        goldDrop = goldDrop + floor * 25
                        addMessage("★ 보스를 쓰러뜨렸습니다! 계단이 안정되었습니다.")
                    end
                    player.gold = player.gold + goldDrop
                    addMessage(target.name .. " 처치! (+" .. target.exp .. " 경험치, +" .. goldDrop .. " 골드)")
                    if target.isBoss then
                        local drop = rollDrop()
                        if drop then
                            table.insert(groundItems, {x = target.x, y = target.y, item = drop, picked = false})
                            addMessage("  → " .. drop.name .. " 드롭!")
                        end
                    end
                    checkLevelUp()
                end
            end
            return
        end
    end

    -- 스킬 트리 토글
    if isKey("skilltree", key) then
        if gameState == "playing" then
            gameState = "skilltree"
            return
        elseif gameState == "skilltree" then
            gameState = "playing"
            return
        end
    end

    -- 인벤토리 토글
    if isKey("inventory", key) then
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

    if gameState == "inventory" and (key == "delete" or key == "backspace") then
        discardHoveredInventoryItem()
        return
    end

    -- 마을 메뉴
    if gameState == "town" then
        if isKey("up", key) or key == "up" then
            townMenuSel = townMenuSel - 1
            if townMenuSel < 1 then townMenuSel = #TOWN_MENU end
        elseif isKey("down", key) or key == "down" then
            townMenuSel = townMenuSel + 1
            if townMenuSel > #TOWN_MENU then townMenuSel = 1 end
        elseif isKey("interact", key) or key == "return" then
            local sel = TOWN_MENU[townMenuSel]
            if sel == "상점" then
                if shop.needsRefresh then shop:refresh() end
                gameState = "shop"
                drag.item = nil
                hoverItem = nil
            elseif sel == "보관함" then
                gameState = "stash"
                drag.item = nil
                hoverItem = nil
            elseif sel == "도감" then
                gameState = "bestiary"
                bestiaryScroll = 0
            elseif sel == "던전 출발" then
                startDungeon()
            elseif sel == "저장" then
                addMessage("게임이 저장되었습니다!")
            end
        end
        return
    end

    -- 도감 조작
    if gameState == "bestiary" then
        local totalRaces = 0
        for _ in pairs(RACE_DB) do totalRaces = totalRaces + 1 end
        if isKey("up", key) or key == "up" then
            bestiaryScroll = math.max(0, bestiaryScroll - 1)
        elseif isKey("down", key) or key == "down" then
            bestiaryScroll = math.min(math.max(0, totalRaces - 4), bestiaryScroll + 1)
        end
        return
    end

    if gameState == "gameover" then
        if key == "r" then
            resetAfterDeath()
        end
        return
    end

    -- 레벨업 스탯 배분
    if gameState == "levelup" and statAlloc then
        local STAT_KEYS = {"str", "dex", "int", "con", "lck"}
        if isKey("up", key) or key == "up" then
            statAlloc.sel = statAlloc.sel - 1
            if statAlloc.sel < 1 then statAlloc.sel = #STAT_KEYS end
        elseif isKey("down", key) or key == "down" then
            statAlloc.sel = statAlloc.sel + 1
            if statAlloc.sel > #STAT_KEYS then statAlloc.sel = 1 end
        elseif isKey("interact", key) or key == "return" then
            local stat = STAT_KEYS[statAlloc.sel]
            player[stat] = player[stat] + 1
            statAlloc.points = statAlloc.points - 1
            addMessage(stat:upper() .. " +1! (현재 " .. player[stat] .. ")")

            player.maxHp = getPlayerMaxHp()
            player.hp = math.min(player.hp, player.maxHp)
            player.maxMana = getPlayerMaxMana()
            player.mana = math.min(player.mana or player.maxMana, player.maxMana)

            if statAlloc.points <= 0 then
                statAlloc = nil
                gameState = "playing"
                addMessage("스탯 배분 완료!")
            end
        end
        return
    end

    if gameState ~= "playing" then return end

    if isKey("up", key) then
        movePlayer(0, -1)
    elseif isKey("down", key) then
        movePlayer(0, 1)
    elseif isKey("left", key) then
        movePlayer(-1, 0)
    elseif isKey("right", key) then
        movePlayer(1, 0)
    elseif isKey("wait", key) then
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
    if gameState == "charselect" then return end

    if gameState == "secret_reward" then
        if button == 1 then
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            local boxW, boxH = 160, 220
            local startX = sw/2 - (boxW * 3 + 40) / 2
            local startY = sh/2 - boxH/2
            
            for i, item in ipairs(secretRewards) do
                local bx = startX + (i-1) * (boxW + 20)
                if x >= bx and x <= bx + boxW and y >= startY and y <= startY + boxH then
                    if inv:autoPlace(item) then
                        addMessage(item.name .. " 획득!", {1, 0.8, 0.2})
                    else
                        table.insert(groundItems, {x=player.x, y=player.y, item=item, picked=false})
                        addMessage("인벤토리가 가득 차 바닥에 떨어졌습니다.", {1, 0.5, 0.5})
                    end
                    
                    if secretAreaReturnState then
                        floor = secretAreaReturnState.floor
                        player.x = secretAreaReturnState.x
                        player.y = secretAreaReturnState.y
                        map = secretAreaReturnState.map
                        visibleMap = secretAreaReturnState.visibleMap
                        exploredMap = secretAreaReturnState.exploredMap
                        rooms = secretAreaReturnState.rooms
                        enemies = secretAreaReturnState.enemies
                        groundItems = secretAreaReturnState.groundItems
                        COLOR_WALL = secretAreaReturnState.colorWall
                        COLOR_FLOOR = secretAreaReturnState.colorFloor
                        currentBiome = secretAreaReturnState.currentBiome
                    end
                    inSecretArea = false
                    secretAreaReturnState = nil
                    gameState = "playing"
                    return
                end
            end
        end
        return
    end

    -- 스킬 트리 클릭
    if gameState == "skilltree" then
        if button == 1 and player.skillPoints > 0 then
            local rData = SKILLS_DB.races[player.raceId]
            local cData = SKILLS_DB.classes[player.classId]
            if not rData or not cData then return end
            
            local function checkClick(data)
                local tiers = {data.tier1, data.tier2, data.tier3}
                for t=1, 3 do
                    if tiers[t] then
                        for _, s in ipairs(tiers[t]) do
                            if s.uiBox and s.uiBox.unlocked and not s.uiBox.isUnlocked then
                                if x >= s.uiBox.x and x <= s.uiBox.x + s.uiBox.w and y >= s.uiBox.y and y <= s.uiBox.y + s.uiBox.h then
                                    -- 스킬 해금
                                    player.skillPoints = player.skillPoints - 1
                                    player.unlockedSkills[s.id] = true
                                    addMessage(s.name .. " 스킬을 습득했습니다!")
                                    
                                    -- 만약 액티브 스킬이면 player.skills 에도 추가
                                    if s.type == "active" then
                                        local clone = {}
                                        for k,v in pairs(s) do clone[k] = v end
                                        clone.currentCd = 0
                                        table.insert(player.skills, clone)
                                    end
                                    return true
                                end
                            end
                        end
                    end
                end
                return false
            end
            
            if checkClick(rData) then return end
            checkClick(cData)
        end
        return
    end

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
                    elseif label == "도감" then
                        gameState = "bestiary"
                        bestiaryScroll = 0
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
            elseif item.id == "return_scroll" then
                if channeling_return > 0 then
                    addMessage("이미 시전 중입니다!", {1.0, 1.0, 0.0})
                    return
                end
                channeling_return = 3
                addMessage("귀환 주문서 시전 중... (3턴 대기)", {0.8, 0.6, 1.0})
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                return
            elseif item.id == "secret_scroll" then
                if inSecretArea then
                    addMessage("이곳에서는 스크롤을 사용할 수 없습니다!", {1.0, 0.5, 0.5})
                    return
                end
                
                -- 백업
                secretAreaReturnState = {
                    floor = floor,
                    x = player.x,
                    y = player.y,
                    map = map,
                    visibleMap = visibleMap,
                    exploredMap = exploredMap,
                    rooms = rooms,
                    enemies = enemies,
                    groundItems = groundItems,
                    colorWall = COLOR_WALL,
                    colorFloor = COLOR_FLOOR,
                    currentBiome = currentBiome
                }
                inSecretArea = true
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                
                gameState = "playing"
                addMessage("비밀 지역으로 빨려 들어갑니다!", {0.8, 0.2, 0.8})
                
                -- 투기장 맵 생성
                local w, h = 15, 15
                map = {}
                visibleMap = {}
                exploredMap = {}
                rooms = {{x=2, y=2, w=11, h=11, cx=7, cy=7}}
                COLOR_WALL = {0.2, 0.1, 0.3}
                COLOR_FLOOR = {0.4, 0.2, 0.5}
                for y=1, h do
                    map[y] = {}
                    visibleMap[y] = {}
                    exploredMap[y] = {}
                    for x=1, w do
                        if y == 1 or y == h or x == 1 or x == w then
                            map[y][x] = TILE_WALL
                        else
                            map[y][x] = TILE_FLOOR
                        end
                        visibleMap[y][x] = true
                        exploredMap[y][x] = true
                    end
                end
                
                player.x, player.y = 7, 7
                enemies = {}
                groundItems = {}
                
                -- 강력한 몬스터 스폰 (스케일링: 현재층 + 3)
                local elv = floor + 3
                for i=1, 4 do
                    local ex, ey
                    repeat
                        ex, ey = 7 + math.random(-4, 4), 7 + math.random(-4, 4)
                    until ex ~= 7 or ey ~= 7
                    
                    table.insert(enemies, {
                        x = ex, y = ey,
                        name = (i==1) and "투기장 보스" or "투기장 수호자",
                        char = (i==1) and "B" or "X",
                        hp = (i==1) and (100 + elv * 20) or (50 + elv * 10),
                        maxHp = (i==1) and (100 + elv * 20) or (50 + elv * 10),
                        atk = (i==1) and (15 + elv * 3) or (10 + elv * 2),
                        def = 5 + elv,
                        ev = 5,
                        spd = 1.0,
                        exp = (i==1) and (150 + elv * 20) or (50 + elv * 10),
                        color = (i==1) and {1, 0.1, 0.1} or {1, 0.4, 0.4},
                        alive = true,
                        race = "demon",
                        atkElement = "fire",
                        isBoss = (i==1)
                    })
                end
                return
            end
            -- 장비 장착
            if item.slot then
                if not canEquipItemByRestriction(item) then
                    return
                end
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
            local checkItem = equip:getItem(slot)
            if checkItem and checkItem.cursed and gameState ~= "town" and gameState ~= "shop" then
                addMessage("저주받은 유물은 마을에서만 해제할 수 있습니다!", {1.0, 0.2, 0.2})
                return
            end
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
    if gameState == "charselect" then return end
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
        if slot and equip:canDropToSlot(item, slot) and canEquipItemByRestriction(item) then
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
    elseif gameState == "bestiary" then
        local totalRaces = 0
        for _ in pairs(RACE_DB) do totalRaces = totalRaces + 1 end
        if y > 0 then
            bestiaryScroll = math.max(0, bestiaryScroll - 1)
        elseif y < 0 then
            bestiaryScroll = math.min(math.max(0, totalRaces - 4), bestiaryScroll + 1)
        end
    end
end

-- ===== 그리기 =====
local function drawGame()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    local screenW = 1280 - 270
    local screenH = 720
    
    local startCol = math.floor(camera.x / TILE_SIZE)
    local endCol = math.floor((camera.x + screenW) / TILE_SIZE) + 1
    local startRow = math.floor(camera.y / TILE_SIZE)
    local endRow = math.floor((camera.y + screenH) / TILE_SIZE) + 1

    startCol = math.max(1, startCol)
    endCol = math.min(MAP_WIDTH, endCol)
    startRow = math.max(1, startRow)
    endRow = math.min(MAP_HEIGHT, endRow)

    -- 맵
    for y = startRow, endRow do
        for x = startCol, endCol do
            if exploredMap[y] and exploredMap[y][x] then
                local tile = map[y][x]
                local sx = (x - 1) * TILE_SIZE
                local sy = (y - 1) * TILE_SIZE

                -- 시야 밖에 있으면 어둡게 처리
                if visibleMap[y] and visibleMap[y][x] then
                    love.graphics.setColor(1, 1, 1, 1)
                else
                    love.graphics.setColor(0.3, 0.3, 0.3, 1)
                end

                if TILE_QUADS[tile] and TILESET_IMAGE then
                    love.graphics.draw(TILESET_IMAGE, TILE_QUADS[tile], sx, sy)
                else
                    if tile == TILE_FLOOR then
                        love.graphics.setColor(COLOR_FLOOR[1]*0.5, COLOR_FLOOR[2]*0.5, COLOR_FLOOR[3]*0.5)
                        love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                    elseif tile == TILE_WALL then
                        love.graphics.setColor(COLOR_WALL[1]*0.5, COLOR_WALL[2]*0.5, COLOR_WALL[3]*0.5)
                        love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                    elseif tile == TILE_LOCKED_CHEST then
                        love.graphics.setColor(COLOR_CHEST_LOCKED)
                        love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                        love.graphics.setColor(0, 0, 0, 0.5)
                        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
                        love.graphics.setColor(1, 1, 1)
                        love.graphics.print("?", sx + 5, sy + 1)
                    elseif tile == TILE_OPEN_CHEST then
                        love.graphics.setColor(COLOR_CHEST_OPEN)
                        love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                        love.graphics.setColor(0, 0, 0, 0.5)
                        love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
                        love.graphics.setColor(0.5, 0.5, 0.5)
                        love.graphics.print("_", sx + 5, sy + 1)
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- 바닥 아이템
    local t = love.timer.getTime()
    for _, gi in ipairs(groundItems) do
        if not gi.picked and visibleMap[gi.y] and visibleMap[gi.y][gi.x] then
            local sx = (gi.x - 1) * TILE_SIZE
            local sy = (gi.y - 1) * TILE_SIZE
            
            -- 아이템 둥둥 뜨는 애니메이션
            local floatOffset = math.sin(t * 5 + gi.x + gi.y) * 2
            
            local rc = gi.item:getRarityColor()
            
            -- 후광 효과 (아이템 바닥에 빛남)
            love.graphics.setColor(rc[1], rc[2], rc[3], 0.3)
            love.graphics.circle("fill", sx + TILE_SIZE/2, sy + TILE_SIZE/2 + 2, TILE_SIZE/2 - 2)
            love.graphics.setColor(1, 1, 1, 1)

            local itemKey = getItemQuadKey(gi.item)
            if ENTITY_QUADS[itemKey] and TILESET_IMAGE then
                love.graphics.draw(TILESET_IMAGE, ENTITY_QUADS[itemKey], sx, sy + floatOffset)
            else
                love.graphics.setColor(rc[1], rc[2], rc[3])
                love.graphics.print(gi.item.icon, sx + 3, sy + floatOffset)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)

    -- 적
    for _, enemy in ipairs(enemies) do
        if enemy.alive and visibleMap[enemy.y] and visibleMap[enemy.y][enemy.x] then
            local sx = (enemy.x - 1) * TILE_SIZE
            local sy = (enemy.y - 1) * TILE_SIZE
            
            -- 적 발밑 빨간/주황 그림자
            love.graphics.setColor(0.8, 0.1, 0.1, 0.4)
            love.graphics.ellipse("fill", sx + TILE_SIZE/2, sy + TILE_SIZE - 2, TILE_SIZE/2 - 1, 3)

            if enemy.isBoss then
                -- 보스는 더 크고 위협적인 오라
                love.graphics.setColor(1, 0.2, 0, 0.3)
                love.graphics.circle("fill", sx + TILE_SIZE/2, sy + TILE_SIZE/2, TILE_SIZE/2 + 4)
                love.graphics.setColor(1, 0.85, 0, 0.8)
                love.graphics.rectangle("line", sx-1, sy-1, TILE_SIZE+2, TILE_SIZE+2)
            end
            love.graphics.setColor(1, 1, 1)

            if ENTITY_QUADS[enemy.char] and TILESET_IMAGE then
                love.graphics.draw(TILESET_IMAGE, ENTITY_QUADS[enemy.char], sx, sy)
            else
                -- 그림자 처리
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.print(enemy.char, sx + 4, sy + 1)
                -- 본체
                love.graphics.setColor(enemy.color)
                love.graphics.print(enemy.char, sx + 3, sy)
            end
            love.graphics.setColor(1, 1, 1)
        end
    end

    -- 플레이어
    local px = (player.x - 1) * TILE_SIZE
    local py = (player.y - 1) * TILE_SIZE
    
    -- 플레이어 스포트라이트 오라 (노란 계열)
    love.graphics.setColor(1, 1, 0.8, 0.15)
    love.graphics.circle("fill", px + TILE_SIZE/2, py + TILE_SIZE/2, TILE_SIZE * 1.5)
    love.graphics.setColor(1, 1, 0.5, 0.25)
    love.graphics.circle("fill", px + TILE_SIZE/2, py + TILE_SIZE/2, TILE_SIZE * 0.9)
    
    -- 플레이어 호흡 애니메이션
    local breath = math.sin(t * 4) * 1
    
    if ENTITY_QUADS["@"] and TILESET_IMAGE then
        love.graphics.draw(TILESET_IMAGE, ENTITY_QUADS["@"], px, py + breath)
    else
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.print(player.char, px + 4, py + breath + 1)
        love.graphics.setColor(COLOR_PLAYER)
        love.graphics.print(player.char, px + 3, py + breath)
    end
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.pop()

    -- ===== HUD =====
    local hudW = 270
    local hudX = 1280 - hudW
    local hudY = 10
    local hudH = 720

    love.graphics.setColor(COLOR_HUD_BG)
    love.graphics.rectangle("fill", hudX - 5, 0, hudW + 10, MAP_HEIGHT * TILE_SIZE + 10)

    -- 플레이어 정보
    love.graphics.setColor(COLOR_GOLD)
    local rn = player.raceName or "인간"
    local cn = player.className or "전사"
    love.graphics.print("=== " .. rn .. " " .. cn .. " ===", hudX, hudY)
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

    -- MP 바
    love.graphics.setColor(COLOR_MP_BG)
    love.graphics.rectangle("fill", hudX, hudY, 200, 14)
    love.graphics.setColor(COLOR_MP_BAR)
    local mpRatio = 0
    if player.maxMana and player.maxMana > 0 then
        mpRatio = (player.mana or 0) / player.maxMana
    end
    love.graphics.rectangle("fill", hudX, hudY, 200 * mpRatio, 14)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("마나: " .. (player.mana or 0) .. "/" .. (player.maxMana or 0), hudX + 5, hudY)
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

    -- 무기 속성 표시
    local pElem = getPlayerElement()
    local elemColor = Item.ELEMENT_COLORS[pElem] or {0.8, 0.8, 0.8}
    love.graphics.setColor(elemColor[1], elemColor[2], elemColor[3])
    love.graphics.print("속성: " .. (Item.ELEMENT_NAMES[pElem] or "물리"), hudX, hudY)
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

    -- 스킬 표시
    if player.skills and #player.skills > 0 then
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 스킬 ---", hudX, hudY)
        hudY = hudY + 15
        for i, s in ipairs(player.skills) do
            local cost = getSkillManaCost(s)
            if s.currentCd > 0 then
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost .. " (쿨:" .. s.currentCd .. ")", hudX, hudY)
            elseif (player.mana or 0) < cost then
                love.graphics.setColor(0.35, 0.35, 0.55)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost, hudX, hudY)
            else
                love.graphics.setColor(0.9, 0.8, 1)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost, hudX, hudY)
            end
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    -- 활성 버프 표시
    if player.buffs and #player.buffs > 0 then
        love.graphics.setColor(0.3, 1, 0.6)
        love.graphics.print("--- 버프 ---", hudX, hudY)
        hudY = hudY + 15
        for _, b in ipairs(player.buffs) do
            love.graphics.setColor(0.5, 1, 0.7)
            love.graphics.print("◆ " .. b.name .. " (" .. b.duration .. "턴)", hudX, hudY)
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("--- 조작법 ---", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("방향키/WASD: 이동", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("부딪히기: 공격 | Space: 대기", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("I/Tab: 인벤 | 숫자: 스킬", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print(">/<: 계단 | PgUp/Dn: 로그", hudX, hudY)
    hudY = hudY + 18

    -- 퀘스트 표시
    local questStrings = Quest.getActiveQuestStrings()
    if #questStrings > 0 then
        love.graphics.setColor(0.3, 0.8, 1)
        love.graphics.print("--- 퀘스트 ---", hudX, hudY)
        hudY = hudY + 16
        for _, qs in ipairs(questStrings) do
            if string.find(qs, "%[완료%]") then
                love.graphics.setColor(0.5, 1, 0.5)
            else
                love.graphics.setColor(0.8, 0.9, 1)
            end
            love.graphics.print("▶ " .. qs, hudX, hudY)
            hudY = hudY + 14
        end
        hudY = hudY + 6
    end

    -- 인접 적 정보
    for _, enemy in ipairs(enemies) do
        if enemy.alive and distance(player.x, player.y, enemy.x, enemy.y) <= 2 then
            local rd = RACE_DB[enemy.race]
            local raceName = rd and rd.name or "???"
            local raceCol = rd and rd.color or {0.8, 0.8, 0.8}
            love.graphics.setColor(raceCol[1], raceCol[2], raceCol[3])
            love.graphics.print("▶ " .. enemy.name .. " [" .. raceName .. "]", hudX, hudY)
            hudY = hudY + 14
            -- HP바
            local hpRatio = enemy.hp / enemy.maxHp
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", hudX, hudY, 100, 6)
            love.graphics.setColor(1 - hpRatio, hpRatio, 0)
            love.graphics.rectangle("fill", hudX, hudY, 100 * hpRatio, 6)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(enemy.hp .. "/" .. enemy.maxHp, hudX + 105, hudY - 3)
            hudY = hudY + 14
            break
        end
    end

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
        love.graphics.printf("R키: 캐릭터 삭제 후 새로 시작", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
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
    love.graphics.setColor(0.45, 0.65, 1)
    love.graphics.print("MP:" .. (player.mana or 0) .. "/" .. (player.maxMana or 0) .. "  회복:" .. getPlayerManaRegen(), equip.x - 76, equip.y + 348)

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        local py = equip.y + 366
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
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 장착/사용 | Delete/Backspace: 마우스 아이템 버리기 | I/Tab/Esc: 닫기", 0, 28, sw, "center")

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
    local rn = player.raceName or "인간"
    local cn = player.className or "전사"
    love.graphics.setColor(player.raceColor or {1,1,1})
    love.graphics.printf(rn .. " " .. cn .. "  Lv." .. player.level .. "  골드: " .. player.gold .. "  탐험: " .. dungeonRun .. "회", 0, 70, sw, "center")

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

-- 속성 한글/색상 참조 (item.lua)
local ELEMENT_LIST = {"slash", "pierce", "strike", "fire", "ice", "lightning", "poison", "holy"}
local ELEMENT_NAMES = Item.ELEMENT_NAMES
local ELEMENT_COLORS = Item.ELEMENT_COLORS

-- ===== 캐릭터 선택 화면 =====
local function drawCharSelect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0.05, 0.05, 0.12)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if charSelect.phase == "race" then
        -- 종족 선택
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.printf("= 종족 선택 =", 0, 15, sw, "center")

        local listX = 30
        local infoX = sw * 0.45
        local startY = 50
        local rowH = math.max(18, math.min(28, math.floor((sh - startY - 35) / #PLAYER_RACES)))
        local rowBoxH = math.max(16, rowH - 2)

        for i, race in ipairs(PLAYER_RACES) do
            local y = startY + (i - 1) * rowH
            if i == charSelect.raceSel then
                love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, rowBoxH, 4, 4)
                love.graphics.setColor(race.color[1], race.color[2], race.color[3])
                love.graphics.print("▶ " .. race.name, listX, y)
            else
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.print("  " .. race.name, listX, y)
            end
        end

        -- 선택된 종족 상세 정보
        local sel = PLAYER_RACES[charSelect.raceSel]
        if sel then
            local iy = startY
            love.graphics.setColor(sel.color[1], sel.color[2], sel.color[3])
            love.graphics.print("【" .. sel.name .. "】", infoX, iy)
            iy = iy + 22

            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(sel.desc, infoX, iy, sw - infoX - 20, "left")
            iy = iy + 40

            -- 기본 스탯
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.print("기본 스탯:", infoX, iy)
            iy = iy + 18
            love.graphics.setColor(1, 0.5, 0.3)
            love.graphics.print("STR " .. sel.stats.str, infoX, iy)
            love.graphics.setColor(0.3, 1, 0.5)
            love.graphics.print("DEX " .. sel.stats.dex, infoX + 55, iy)
            love.graphics.setColor(0.4, 0.7, 1)
            love.graphics.print("INT " .. sel.stats.int, infoX + 110, iy)
            iy = iy + 16
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.print("CON " .. sel.stats.con, infoX, iy)
            love.graphics.setColor(1, 1, 0.4)
            love.graphics.print("LCK " .. sel.stats.lck, infoX + 55, iy)
            iy = iy + 22

            -- HP/경험치 보너스
            if sel.hpBonus ~= 0 then
                local sign = sel.hpBonus > 0 and "+" or ""
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.print("HP 보너스: " .. sign .. sel.hpBonus, infoX, iy)
                iy = iy + 16
            end
            if sel.expBonus ~= 0 then
                local sign = sel.expBonus > 0 and "+" or ""
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.print("경험치 보너스: " .. sign .. sel.expBonus .. "%", infoX, iy)
                iy = iy + 16
            end

            -- 저항
            iy = iy + 4
            love.graphics.setColor(0.3, 0.7, 1)
            love.graphics.print("저항:", infoX, iy)
            local rx = infoX + 40
            if next(sel.resist) then
                for elem, val in pairs(sel.resist) do
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label
                    if val >= 1.0 then label = (ELEMENT_NAMES[elem] or elem) .. "(면역)"
                    else label = (ELEMENT_NAMES[elem] or elem) .. "(-" .. math.floor(val*100) .. "%)" end
                    love.graphics.print(label, rx, iy)
                    rx = rx + font:getWidth(label) + 10
                end
            else
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("없음", rx, iy)
            end
            iy = iy + 18

            -- 약점
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.print("약점:", infoX, iy)
            local wx = infoX + 40
            if next(sel.weak) then
                for elem, val in pairs(sel.weak) do
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "(+" .. math.floor(val*100) .. "%)"
                    love.graphics.print(label, wx, iy)
                    wx = wx + font:getWidth(label) + 10
                end
            else
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("없음", wx, iy)
            end
            iy = iy + 22

            -- 숙련 보너스
            love.graphics.setColor(0.8, 0.6, 1)
            love.graphics.print("무기 숙련:", infoX, iy)
            local px = infoX + 60
            local hasProf = false
            for elem, val in pairs(sel.profBonus) do
                if val > 0 then
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "+" .. val
                    love.graphics.print(label, px, iy)
                    px = px + font:getWidth(label) + 10
                    hasProf = true
                end
            end
            if not hasProf then
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("균등", px, iy)
            end
            iy = iy + 22

            -- 종족 스킬
            if #sel.skills > 0 then
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.print("종족 스킬:", infoX, iy)
                iy = iy + 18
                for _, sk in ipairs(sel.skills) do
                    love.graphics.setColor(0.9, 0.7, 1)
                    love.graphics.print("◆ " .. sk.name, infoX + 8, iy)
                    iy = iy + 15
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.printf("  " .. sk.desc .. " (쿨: " .. sk.cooldown .. "턴)", infoX + 8, iy, sw - infoX - 30, "left")
                    iy = iy + 18
                end
            end
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter: 확정", 0, sh - 25, sw, "center")

    elseif charSelect.phase == "class" then
        -- 직업 선택
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.printf("= 직업 선택 = [" .. charSelect.chosenRace.name .. "]", 0, 15, sw, "center")

        local listX = 30
        local infoX = sw * 0.45
        local startY = 50
        local rowH = math.max(18, math.min(28, math.floor((sh - startY - 35) / #PLAYER_CLASSES)))
        local rowBoxH = math.max(16, rowH - 2)

        for i, cls in ipairs(PLAYER_CLASSES) do
            local y = startY + (i - 1) * rowH
            local allowed = isClassAllowedForRace(charSelect.chosenRace, cls)
            if i == charSelect.classSel then
                love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, rowBoxH, 4, 4)
                if allowed then
                    love.graphics.setColor(cls.color[1], cls.color[2], cls.color[3])
                    love.graphics.print("▶ " .. cls.name, listX, y)
                else
                    love.graphics.setColor(0.45, 0.25, 0.25)
                    love.graphics.print("× " .. cls.name, listX, y)
                end
            else
                if allowed then
                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.print("  " .. cls.name, listX, y)
                else
                    love.graphics.setColor(0.32, 0.25, 0.25)
                    love.graphics.print("  × " .. cls.name, listX, y)
                end
            end
        end

        local sel = PLAYER_CLASSES[charSelect.classSel]
        if sel then
            local iy = startY
            local allowed, blockReason = isClassAllowedForRace(charSelect.chosenRace, sel)
            love.graphics.setColor(sel.color[1], sel.color[2], sel.color[3])
            love.graphics.print("【" .. sel.name .. "】", infoX, iy)
            iy = iy + 22

            if not allowed then
                love.graphics.setColor(1, 0.35, 0.25)
                love.graphics.printf("선택 불가: " .. (blockReason or "종족 금기와 충돌합니다."), infoX, iy, sw - infoX - 20, "left")
                iy = iy + 34
            end

            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(sel.desc, infoX, iy, sw - infoX - 20, "left")
            iy = iy + 40

            -- 스탯 보너스
            local race = charSelect.chosenRace
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.print("최종 스탯 (종족+직업):", infoX, iy)
            iy = iy + 18
            local finalStr = race.stats.str + sel.statBonus.str
            local finalDex = race.stats.dex + sel.statBonus.dex
            local finalInt = race.stats.int + sel.statBonus.int
            local finalCon = race.stats.con + sel.statBonus.con
            local finalLck = race.stats.lck + sel.statBonus.lck
            love.graphics.setColor(1, 0.5, 0.3)
            love.graphics.print("STR " .. finalStr .. " (+" .. sel.statBonus.str .. ")", infoX, iy)
            love.graphics.setColor(0.3, 1, 0.5)
            love.graphics.print("DEX " .. finalDex .. " (+" .. sel.statBonus.dex .. ")", infoX + 100, iy)
            iy = iy + 16
            love.graphics.setColor(0.4, 0.7, 1)
            love.graphics.print("INT " .. finalInt .. " (+" .. sel.statBonus.int .. ")", infoX, iy)
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.print("CON " .. finalCon .. " (+" .. sel.statBonus.con .. ")", infoX + 100, iy)
            iy = iy + 16
            love.graphics.setColor(1, 1, 0.4)
            love.graphics.print("LCK " .. finalLck .. " (+" .. sel.statBonus.lck .. ")", infoX, iy)
            iy = iy + 22

            -- 무기 숙련
            love.graphics.setColor(0.8, 0.6, 1)
            love.graphics.print("무기 숙련:", infoX, iy)
            local px = infoX + 60
            for elem, val in pairs(sel.profBonus) do
                if val > 0 then
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "+" .. val
                    love.graphics.print(label, px, iy)
                    px = px + font:getWidth(label) + 10
                end
            end
            iy = iy + 22

            -- 시작 장비
            love.graphics.setColor(0.7, 0.9, 0.7)
            love.graphics.print("시작 장비:", infoX, iy)
            iy = iy + 16
            if sel.startWeapon then
                local wData = Item.DATABASE[sel.startWeapon]
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("  무기: " .. (wData and wData.name or sel.startWeapon), infoX, iy)
                iy = iy + 15
            end
            if sel.startArmor then
                local aData = Item.DATABASE[sel.startArmor]
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("  방어구: " .. (aData and aData.name or sel.startArmor), infoX, iy)
                iy = iy + 15
            end
            iy = iy + 8

            -- 직업 스킬
            if #sel.skills > 0 then
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.print("직업 스킬:", infoX, iy)
                iy = iy + 18
                for _, sk in ipairs(sel.skills) do
                    love.graphics.setColor(0.9, 0.7, 1)
                    love.graphics.print("◆ " .. sk.name, infoX + 8, iy)
                    iy = iy + 15
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.printf("  " .. sk.desc .. " (쿨: " .. sk.cooldown .. "턴)", infoX + 8, iy, sw - infoX - 30, "left")
                    iy = iy + 18
                end
            end
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter: 확정 | Esc: 종족 재선택", 0, sh - 25, sw, "center")
    end
end

local function drawBestiary()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("= 도감 (종족/속성) =", 0, 15, sw, "center")

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("↑↓/마우스 휠: 스크롤 | ESC: 돌아가기", 0, sh - 25, sw, "center")

    -- 종족 목록 정렬 (일관된 순서)
    local raceOrder = {"human", "beast", "goblinoid", "orc", "troll", "undead", "demon", "dragon", "construct", "insect", "reptile", "elf"}
    local cardH = 130
    local cardW = sw - 60
    local startY = 50
    local visibleCards = math.floor((sh - 90) / (cardH + 8))

    for idx, raceKey in ipairs(raceOrder) do
        local raceData = RACE_DB[raceKey]
        if raceData then
            local cardIdx = idx - bestiaryScroll
            if cardIdx >= 1 and cardIdx <= visibleCards then
                local cy = startY + (cardIdx - 1) * (cardH + 8)
                local cx = 30

                -- 카드 배경
                love.graphics.setColor(0.12, 0.12, 0.18, 0.9)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6, 6)
                love.graphics.setColor(raceData.color[1], raceData.color[2], raceData.color[3], 0.7)
                love.graphics.rectangle("line", cx, cy, cardW, cardH, 6, 6)

                -- 종족명
                love.graphics.setColor(raceData.color[1], raceData.color[2], raceData.color[3])
                love.graphics.print("【" .. raceData.name .. "】", cx + 10, cy + 6)

                -- 설명
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.printf(raceData.desc, cx + 10, cy + 24, cardW - 20, "left")

                -- 해당 종족의 몬스터들
                local monsters = {}
                for _, m in ipairs(ENEMY_DB) do
                    if m.race == raceKey then
                        table.insert(monsters, m.name)
                    end
                end
                love.graphics.setColor(0.6, 0.7, 0.8)
                love.graphics.print("몬스터: " .. table.concat(monsters, ", "), cx + 10, cy + 46)

                -- 저항 표시
                local ry = cy + 66
                love.graphics.setColor(0.3, 0.7, 1)
                love.graphics.print("저항:", cx + 10, ry)
                local rx = cx + 50
                if next(raceData.resist) then
                    for elem, val in pairs(raceData.resist) do
                        local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                        love.graphics.setColor(ec[1], ec[2], ec[3])
                        local label = (ELEMENT_NAMES[elem] or elem)
                        if val >= 1.0 then
                            label = label .. "(면역)"
                        else
                            label = label .. "(-" .. math.floor(val * 100) .. "%)"
                        end
                        love.graphics.print(label, rx, ry)
                        rx = rx + font:getWidth(label) + 12
                    end
                else
                    love.graphics.setColor(COLOR_GRAY)
                    love.graphics.print("없음", rx, ry)
                end

                -- 약점 표시
                local wy = cy + 86
                love.graphics.setColor(1, 0.4, 0.3)
                love.graphics.print("약점:", cx + 10, wy)
                local wx = cx + 50
                if next(raceData.weak) then
                    for elem, val in pairs(raceData.weak) do
                        local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                        love.graphics.setColor(ec[1], ec[2], ec[3])
                        local label = (ELEMENT_NAMES[elem] or elem) .. "(+" .. math.floor(val * 100) .. "%)"
                        love.graphics.print(label, wx, wy)
                        wx = wx + font:getWidth(label) + 12
                    end
                else
                    love.graphics.setColor(COLOR_GRAY)
                    love.graphics.print("없음", wx, wy)
                end

                -- 속성 범례 줄 (하단)
                local ly = cy + 108
                love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
                love.graphics.line(cx + 10, ly, cx + cardW - 10, ly)
            end
        end
    end
end

-- ===== 스킬 트리 그리기 =====
local function drawSkillTree()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(COLOR_GOLD)
    love.graphics.printf("스킬 트리 - [K] 닫기", 0, 30, sw, "center")

    love.graphics.setColor(COLOR_WHITE)
    love.graphics.printf("사용 가능 포인트: " .. player.skillPoints .. "  /  현재 레벨: " .. player.level, 0, 60, sw, "center")

    if not SKILLS_DB then return end

    local rData = SKILLS_DB.races[player.raceId]
    local cData = SKILLS_DB.classes[player.classId]

    if not rData or not cData then
        love.graphics.printf("해당 직업/종족의 스킬 데이터가 없습니다.", 0, sh/2, sw, "center")
        return
    end

    local function drawSkillTreeSection(title, data, startX, startY)
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf(title, startX, startY, 400, "center")

        local tiers = {data.tier1, data.tier2, data.tier3}
        local reqLevels = {1, 5, 10}

        for t=1, 3 do
            local ty = startY + 50 + (t-1)*120
            local reqLvl = reqLevels[t]
            local unlocked = player.level >= reqLvl
            
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf("Tier " .. t .. (unlocked and "" or " (Lv." .. reqLvl .. " 오픈)"), startX, ty, 400, "center")

            local skills = tiers[t]
            if skills then
                for i, s in ipairs(skills) do
                    local sx = startX + 50 + (i-1)*110
                    local sy = ty + 30
                    
                    local isUnlocked = player.unlockedSkills[s.id]
                    
                    if isUnlocked then
                        love.graphics.setColor(0.3, 0.8, 0.3, 0.9)
                    elseif unlocked then
                        love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
                    else
                        love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
                    end
                    
                    love.graphics.rectangle("fill", sx, sy, 100, 60)
                    love.graphics.setColor(COLOR_GOLD)
                    love.graphics.rectangle("line", sx, sy, 100, 60)
                    
                    love.graphics.setColor(COLOR_WHITE)
                    love.graphics.printf(s.name, sx, sy + 5, 100, "center")
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.printf(s.type == "active" and "(액티브)" or "(패시브)", sx, sy + 25, 100, "center")
                    
                    -- 스킬 아이디와 클릭 박스를 위해 임시 데이터 저장 (mousepressed 연동용)
                    s.uiBox = {x=sx, y=sy, w=100, h=60, unlocked=unlocked, isUnlocked=isUnlocked}
                    
                    -- 마우스 오버 툴팁
                    local mx, my = love.mouse.getPosition()
                    if mx >= sx and mx <= sx+100 and my >= sy and my <= sy+60 then
                        love.graphics.setColor(0, 0, 0, 0.9)
                        love.graphics.rectangle("fill", mx+15, my+15, 200, 60)
                        love.graphics.setColor(COLOR_WHITE)
                        love.graphics.printf(s.name, mx+20, my+20, 190, "left")
                        love.graphics.setColor(0.8, 0.8, 0.8)
                        love.graphics.printf(s.desc, mx+20, my+40, 190, "left")
                    end
                end
            end
        end
    end

    drawSkillTreeSection("종족 특성 (" .. player.raceName .. ")", rData, sw/2 - 450, 100)
    drawSkillTreeSection("직업 특성 (" .. player.className .. ")", cData, sw/2 + 50, 100)
end

-- ===== 옵션 메뉴 그리기 =====
local function drawOptions()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(COLOR_GOLD)
    love.graphics.printf("환경 설정 (Options)", 0, 50, sw, "center")

    if waitingForKey then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.printf("변경할 새 키를 누르세요... (취소: ESC)", 0, 90, sw, "center")
    else
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("위/아래: 선택 | 좌/우/엔터: 조절/변경 | ESC: 닫기", 0, 90, sw, "center")
    end

    local startY = 150
    local actionMap = {
        ["조작: 위"] = "up",
        ["조작: 아래"] = "down",
        ["조작: 좌"] = "left",
        ["조작: 우"] = "right",
        ["조작: 대기"] = "wait",
        ["조작: 상호작용"] = "interact",
        ["조작: 인벤토리"] = "inventory",
        ["조작: 스킬트리"] = "skilltree"
    }

    for i, menuText in ipairs(OPTIONS_MENU) do
        if i == optionsMenuSel then
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.print("> " .. menuText, sw/2 - 150, startY + i*30)
        else
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.print("  " .. menuText, sw/2 - 150, startY + i*30)
        end

        local valText = ""
        if menuText == "오디오: BGM" then
            valText = tostring(CONFIG.audio.bgm) .. "%"
        elseif menuText == "오디오: SFX" then
            valText = tostring(CONFIG.audio.sfx) .. "%"
        elseif actionMap[menuText] then
            valText = "[" .. tostring(CONFIG.keys[actionMap[menuText]]:upper()) .. "]"
        end
        
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.print(valText, sw/2 + 100, startY + i*30)
    end
end

local function drawSecretReward()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.printf("비밀 지역 클리어 보상", 0, sh/2 - 180, sw, "center")
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.printf("아래 3가지 중 하나의 보상을 선택하세요.", 0, sh/2 - 140, sw, "center")
    
    local boxW, boxH = 160, 220
    local startX = sw/2 - (boxW * 3 + 40) / 2
    local startY = sh/2 - boxH/2
    local mx, my = love.mouse.getPosition()
    
    for i, item in ipairs(secretRewards) do
        local bx = startX + (i-1) * (boxW + 20)
        
        -- Hover effect
        if mx >= bx and mx <= bx + boxW and my >= startY and my <= startY + boxH then
            love.graphics.setColor(0.3, 0.3, 0.5, 0.9)
            love.graphics.rectangle("fill", bx, startY, boxW, boxH)
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.rectangle("line", bx, startY, boxW, boxH)
            
            -- Tooltip below
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.rectangle("fill", bx - 20, startY + boxH + 10, boxW + 40, 100)
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.printf(item.desc or "", bx - 10, startY + boxH + 15, boxW + 20, "left")
        else
            love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
            love.graphics.rectangle("fill", bx, startY, boxW, boxH)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.rectangle("line", bx, startY, boxW, boxH)
        end
        
        -- Item name & icon
        local rCol = item:getRarityColor()
        love.graphics.setColor(rCol)
        love.graphics.printf(item.name, bx + 5, startY + 20, boxW - 10, "center")
        
        love.graphics.setColor(COLOR_WHITE)
        if item.icon then
            love.graphics.draw(item.icon, bx + boxW/2 - 16, startY + 60, 0, 2, 2)
        end
        
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf(item:getRarityName(), bx + 5, startY + 120, boxW - 10, "center")
    end
end

function love.draw()
    if gameState == "charselect" then
        drawCharSelect()
    elseif gameState == "town" then
        drawTown()
    elseif gameState == "bestiary" then
        drawBestiary()
    elseif gameState == "shop" then
        drawShop()
    elseif gameState == "stash" then
        drawStash()
    elseif gameState == "levelup" then
        drawGame()
        drawLevelUp()
    elseif gameState == "skilltree" then
        drawGame()
        drawSkillTree()
    elseif gameState == "options" then
        drawGame()
        drawOptions()
    elseif gameState == "secret_reward" then
        drawGame()
        drawSecretReward()
    else
        drawGame()
        if gameState == "inventory" then
            drawInventory()
        end
    end
end
