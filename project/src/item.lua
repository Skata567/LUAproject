--[[
    item.lua — 아이템 정의 및 데이터

    익스트랙션 RPG 스타일 아이템 시스템
    - 각 아이템은 그리드에서 차지하는 크기(w x h)가 다름
    - 등급(rarity)에 따라 테두리 색상이 다름
    - 장착 부위(slot)가 있는 아이템은 장비로 착용 가능
]]

local Item = {}
Item.__index = Item

-- 등급별 색상
Item.RARITY_COLORS = {
    common    = {0.7, 0.7, 0.7},
    uncommon  = {0.2, 0.8, 0.2},
    rare      = {0.3, 0.5, 1.0},
    epic      = {0.7, 0.3, 1.0},
    legendary = {1.0, 0.8, 0.0},
}

-- 등급별 한글 이름
Item.RARITY_NAMES = {
    common    = "일반",
    uncommon  = "고급",
    rare      = "희귀",
    epic      = "영웅",
    legendary = "전설",
}

-- 장착 부위
Item.SLOT_NAMES = {
    weapon  = "무기",
    armor   = "방어구",
    helmet  = "투구",
    boots   = "신발",
    ring    = "반지",
    amulet  = "목걸이",
}

--- 아이템 생성
function Item.new(data)
    local self = setmetatable({}, Item)
    self.id = data.id or "unknown"
    self.name = data.name or "???"
    self.description = data.description or ""
    self.gridW = data.gridW or 1       -- 그리드 가로 크기
    self.gridH = data.gridH or 1       -- 그리드 세로 크기
    self.rarity = data.rarity or "common"
    self.slot = data.slot or nil       -- 장착 부위 (nil이면 장착 불가)
    self.icon = data.icon or "?"       -- 텍스트 아이콘
    self.stats = data.stats or {}      -- {atk=0, def=0, hp=0, ...}
    self.stackable = data.stackable or false
    self.count = data.count or 1
    self.color = data.color or {0.8, 0.8, 0.8}  -- 아이콘 색상
    return self
end

--- 아이템 복제
function Item:clone()
    local data = {
        id = self.id,
        name = self.name,
        description = self.description,
        gridW = self.gridW,
        gridH = self.gridH,
        rarity = self.rarity,
        slot = self.slot,
        icon = self.icon,
        stats = {},
        stackable = self.stackable,
        count = self.count,
        color = {self.color[1], self.color[2], self.color[3]},
    }
    for k, v in pairs(self.stats) do
        data.stats[k] = v
    end
    return Item.new(data)
end

--- 등급 색상 가져오기
function Item:getRarityColor()
    return Item.RARITY_COLORS[self.rarity] or Item.RARITY_COLORS.common
end

--- 등급 한글 이름
function Item:getRarityName()
    return Item.RARITY_NAMES[self.rarity] or "일반"
end

--- 장착 부위 한글 이름
function Item:getSlotName()
    if self.slot then
        return Item.SLOT_NAMES[self.slot] or self.slot
    end
    return nil
end

--- 스탯 텍스트 생성
function Item:getStatsText()
    local parts = {}
    if self.stats.atk and self.stats.atk > 0 then
        table.insert(parts, "공격력 +" .. self.stats.atk)
    end
    if self.stats.def and self.stats.def > 0 then
        table.insert(parts, "방어력 +" .. self.stats.def)
    end
    if self.stats.hp and self.stats.hp > 0 then
        table.insert(parts, "체력 +" .. self.stats.hp)
    end
    if self.stats.spd and self.stats.spd > 0 then
        table.insert(parts, "속도 +" .. self.stats.spd)
    end
    if self.stats.crit and self.stats.crit > 0 then
        table.insert(parts, "치명타 +" .. self.stats.crit .. "%")
    end
    return table.concat(parts, "  ")
end

-- ===== 아이템 데이터베이스 =====
Item.DATABASE = {
    -- 무기 (2x1, 1x3, 2x4 등)
    short_sword = Item.new({
        id = "short_sword", name = "단검", description = "가벼운 단검",
        gridW = 1, gridH = 3, rarity = "common", slot = "weapon",
        icon = "/", color = {0.8, 0.8, 0.8},
        stats = {atk = 3},
    }),
    long_sword = Item.new({
        id = "long_sword", name = "장검", description = "긴 검",
        gridW = 1, gridH = 4, rarity = "uncommon", slot = "weapon",
        icon = "|", color = {0.6, 0.8, 1.0},
        stats = {atk = 7, crit = 5},
    }),
    battle_axe = Item.new({
        id = "battle_axe", name = "전투도끼", description = "무거운 도끼",
        gridW = 2, gridH = 3, rarity = "rare", slot = "weapon",
        icon = "P", color = {0.9, 0.5, 0.2},
        stats = {atk = 12, crit = 10},
    }),
    dragon_blade = Item.new({
        id = "dragon_blade", name = "용의 검", description = "드래곤의 비늘로 만든 검",
        gridW = 2, gridH = 5, rarity = "legendary", slot = "weapon",
        icon = "†", color = {1.0, 0.4, 0.1},
        stats = {atk = 25, crit = 15},
    }),

    -- 방어구 (2x3, 2x2 등)
    leather_armor = Item.new({
        id = "leather_armor", name = "가죽 갑옷", description = "기본 가죽 갑옷",
        gridW = 2, gridH = 3, rarity = "common", slot = "armor",
        icon = "A", color = {0.6, 0.4, 0.2},
        stats = {def = 3, hp = 5},
    }),
    chain_mail = Item.new({
        id = "chain_mail", name = "사슬 갑옷", description = "튼튼한 사슬 갑옷",
        gridW = 2, gridH = 3, rarity = "uncommon", slot = "armor",
        icon = "M", color = {0.5, 0.5, 0.6},
        stats = {def = 7, hp = 10},
    }),
    dragon_armor = Item.new({
        id = "dragon_armor", name = "용린 갑옷", description = "용의 비늘로 만든 갑옷",
        gridW = 2, gridH = 3, rarity = "legendary", slot = "armor",
        icon = "D", color = {1.0, 0.3, 0.1},
        stats = {def = 20, hp = 30},
    }),

    -- 투구 (2x2)
    iron_helmet = Item.new({
        id = "iron_helmet", name = "철 투구", description = "기본 철 투구",
        gridW = 2, gridH = 2, rarity = "common", slot = "helmet",
        icon = "H", color = {0.6, 0.6, 0.7},
        stats = {def = 2, hp = 3},
    }),
    royal_crown = Item.new({
        id = "royal_crown", name = "왕관", description = "고대 왕의 왕관",
        gridW = 2, gridH = 2, rarity = "epic", slot = "helmet",
        icon = "W", color = {1.0, 0.85, 0.0},
        stats = {def = 8, hp = 15, crit = 5},
    }),

    -- 신발 (2x2)
    leather_boots = Item.new({
        id = "leather_boots", name = "가죽 장화", description = "가벼운 장화",
        gridW = 2, gridH = 2, rarity = "common", slot = "boots",
        icon = "B", color = {0.5, 0.35, 0.2},
        stats = {def = 1, spd = 2},
    }),
    swift_boots = Item.new({
        id = "swift_boots", name = "신속의 장화", description = "바람처럼 빠른 장화",
        gridW = 2, gridH = 2, rarity = "rare", slot = "boots",
        icon = "S", color = {0.3, 0.9, 0.9},
        stats = {def = 3, spd = 8},
    }),

    -- 반지 (1x1)
    copper_ring = Item.new({
        id = "copper_ring", name = "구리 반지", description = "단순한 반지",
        gridW = 1, gridH = 1, rarity = "common", slot = "ring",
        icon = "o", color = {0.8, 0.5, 0.3},
        stats = {atk = 1},
    }),
    ruby_ring = Item.new({
        id = "ruby_ring", name = "루비 반지", description = "붉은 보석이 박힌 반지",
        gridW = 1, gridH = 1, rarity = "epic", slot = "ring",
        icon = "O", color = {1.0, 0.2, 0.2},
        stats = {atk = 5, crit = 10},
    }),

    -- 목걸이 (1x1)
    silver_amulet = Item.new({
        id = "silver_amulet", name = "은 목걸이", description = "은으로 된 목걸이",
        gridW = 1, gridH = 1, rarity = "uncommon", slot = "amulet",
        icon = "V", color = {0.8, 0.8, 0.9},
        stats = {hp = 10, def = 2},
    }),

    -- 소비 아이템 (1x1, 1x2)
    health_potion = Item.new({
        id = "health_potion", name = "체력 포션", description = "HP를 30 회복",
        gridW = 1, gridH = 1, rarity = "common", slot = nil,
        icon = "!", color = {1.0, 0.2, 0.2},
        stackable = true,
    }),
    large_potion = Item.new({
        id = "large_potion", name = "대형 포션", description = "HP를 80 회복",
        gridW = 1, gridH = 2, rarity = "uncommon", slot = nil,
        icon = "!", color = {1.0, 0.4, 0.6},
        stackable = true,
    }),

    -- 재료 (1x1)
    gold_coin = Item.new({
        id = "gold_coin", name = "골드 코인", description = "반짝이는 금화",
        gridW = 1, gridH = 1, rarity = "common", slot = nil,
        icon = "$", color = {1.0, 0.85, 0.0},
        stackable = true,
    }),
    dragon_scale = Item.new({
        id = "dragon_scale", name = "용의 비늘", description = "드래곤에게서 얻은 비늘",
        gridW = 1, gridH = 1, rarity = "legendary", slot = nil,
        icon = "#", color = {1.0, 0.5, 0.0},
        stackable = true,
    }),
}

--- 데이터베이스에서 아이템 복제 생성
function Item.create(id)
    local template = Item.DATABASE[id]
    if template then
        return template:clone()
    end
    return nil
end

--- 랜덤 아이템 생성
function Item.createRandom()
    local keys = {}
    for k, _ in pairs(Item.DATABASE) do
        table.insert(keys, k)
    end
    local key = keys[math.random(1, #keys)]
    return Item.create(key)
end

return Item
