--[[
    item.lua — 아이템 정의 및 데이터

    익스트랙션 RPG 스타일 아이템 시스템
    - 각 아이템은 그리드에서 차지하는 크기(w x h)가 다름
    - 등급(rarity)에 따라 테두리 색상이 다름
    - 장착 부위(slot)가 있는 아이템은 장비로 착용 가능
    - 등급별 특수 효과(passive) 부여
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

-- 등급 순서 (강도)
Item.RARITY_ORDER = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
}

-- 특수효과 한글 설명
Item.PASSIVE_NAMES = {
    lifesteal   = "흡혈",
    burn        = "화상",
    poison      = "독",
    reflect     = "반사",
    thorns      = "가시",
    regen       = "재생",
    stun        = "기절",
    armor_break = "방어관통",
    double_hit  = "연속타격",
    exp_boost   = "경험치 증가",
    gold_boost  = "골드 증가",
    dodge_boost = "회피 증가",
    crit_boost  = "치명타 증가",
}

-- 장착 부위
Item.SLOT_NAMES = {
    weapon  = "무기",
    weapon1 = "주무기",
    weapon2 = "보조",
    armor   = "방어구",
    helmet  = "투구",
    boots   = "신발",
    ring    = "반지",
    amulet  = "목걸이",
    torch   = "조명",
}

--- 아이템 생성
function Item.new(data)
    local self = setmetatable({}, Item)
    self.id = data.id or "unknown"
    self.name = data.name or "???"
    self.description = data.description or ""
    self.gridW = data.gridW or 1
    self.gridH = data.gridH or 1
    self.rarity = data.rarity or "common"
    self.slot = data.slot or nil
    self.icon = data.icon or "?"
    self.stats = data.stats or {}
    self.twoHanded = data.twoHanded or false
    self.stackable = data.stackable or false
    self.count = data.count or 1
    self.color = data.color or {0.8, 0.8, 0.8}
    self.passive = data.passive or nil  -- {type="lifesteal", value=10, desc="..."}
    self.element = data.element or "physical"  -- 공격 속성: physical/slash/pierce/strike/fire/ice/lightning/poison/holy
    self.cursed = data.cursed or false
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
        twoHanded = self.twoHanded,
        stackable = self.stackable,
        count = self.count,
        color = {self.color[1], self.color[2], self.color[3]},
        passive = nil,
        element = self.element,
        cursed = self.cursed,
    }
    for k, v in pairs(self.stats) do
        data.stats[k] = v
    end
    if self.passive then
        data.passive = {}
        for k, v in pairs(self.passive) do
            data.passive[k] = v
        end
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
        local name = Item.SLOT_NAMES[self.slot] or self.slot
        if self.twoHanded then name = name .. " (양손)" end
        return name
    end
    return nil
end

-- 속성별 한글 이름
Item.ELEMENT_NAMES = {
    physical  = "물리",
    slash     = "참격",
    pierce    = "찌르기",
    strike    = "타격",
    fire      = "화염",
    ice       = "빙결",
    lightning = "번개",
    poison    = "독",
    holy      = "신성",
}

-- 속성별 색상
Item.ELEMENT_COLORS = {
    physical  = {0.8, 0.8, 0.8},
    slash     = {0.9, 0.9, 0.9},
    pierce    = {0.7, 0.7, 0.9},
    strike    = {0.9, 0.7, 0.5},
    fire      = {1.0, 0.4, 0.1},
    ice       = {0.3, 0.7, 1.0},
    lightning = {1.0, 1.0, 0.3},
    poison    = {0.3, 0.9, 0.3},
    holy      = {1.0, 1.0, 0.8},
}

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
    if self.twoHanded then
        table.insert(parts, "[양손]")
    end
    if self.element and self.element ~= "physical" then
        local eName = Item.ELEMENT_NAMES[self.element] or self.element
        table.insert(parts, "[" .. eName .. "]")
    end
    return table.concat(parts, "  ")
end

--- 특수효과 텍스트
function Item:getPassiveText()
    if not self.passive then return nil end
    local pName = Item.PASSIVE_NAMES[self.passive.type] or self.passive.type
    return "◆ " .. pName .. ": " .. (self.passive.desc or "")
end

-- ===== 아이템 데이터베이스 =====
Item.DATABASE = {
    -- =============================================
    -- 조명 (횃불류)
    -- =============================================
    basic_torch = Item.new({
        id = "basic_torch", name = "나무 횃불", description = "어둠을 밝히는 기본적인 횃불. 수명이 짧다.",
        gridW = 1, gridH = 2, rarity = "common", slot = "torch",
        icon = "i", color = {1.0, 0.6, 0.2},
        stats = {},
        passive = {type = "torch", value = 150, desc = "시야 10칸 제공 (150턴)"},
    }),
    magic_lantern = Item.new({
        id = "magic_lantern", name = "마력의 랜턴", description = "오래가는 신비한 빛을 내는 랜턴.",
        gridW = 1, gridH = 2, rarity = "rare", slot = "torch",
        icon = "i", color = {0.2, 0.8, 1.0},
        stats = {int = 1},
        passive = {type = "torch", value = 300, desc = "시야 10칸 제공 (300턴)"},
    }),

    -- =============================================
    -- 무기: 한손
    -- =============================================
    -- 일반 (common)
    short_sword = Item.new({
        id = "short_sword", name = "단검", description = "가벼운 한손 단검",
        gridW = 1, gridH = 3, rarity = "common", slot = "weapon",
        icon = "/", color = {0.8, 0.8, 0.8},
        stats = {atk = 3}, element = "slash",
    }),
    rusty_sword = Item.new({
        id = "rusty_sword", name = "녹슨 검", description = "낡은 녹슨 검",
        gridW = 1, gridH = 3, rarity = "common", slot = "weapon",
        icon = "/", color = {0.6, 0.4, 0.3},
        stats = {atk = 2}, element = "slash",
    }),
    -- 고급 (uncommon)
    dagger = Item.new({
        id = "dagger", name = "비수", description = "빠른 한손 비수",
        gridW = 1, gridH = 2, rarity = "uncommon", slot = "weapon",
        icon = "-", color = {0.7, 0.9, 0.7},
        stats = {atk = 4, crit = 8, spd = 2}, element = "pierce",
        passive = {type = "crit_boost", value = 5, desc = "치명타 +5%"},
    }),
    steel_sword = Item.new({
        id = "steel_sword", name = "강철 검", description = "잘 벼려진 강철 검",
        gridW = 1, gridH = 3, rarity = "uncommon", slot = "weapon",
        icon = "/", color = {0.7, 0.7, 0.9},
        stats = {atk = 6, crit = 3}, element = "slash",
    }),
    -- 희귀 (rare)
    flame_dagger = Item.new({
        id = "flame_dagger", name = "화염 단검", description = "불꽃이 깃든 단검",
        gridW = 1, gridH = 2, rarity = "rare", slot = "weapon",
        icon = "-", color = {1.0, 0.4, 0.1},
        stats = {atk = 8, crit = 10}, element = "fire",
        passive = {type = "burn", value = 3, desc = "공격 시 30% 확률로 3턴간 화상 (턴당 2뎀)"},
    }),
    venom_blade = Item.new({
        id = "venom_blade", name = "독날 검", description = "독이 묻은 검",
        gridW = 1, gridH = 3, rarity = "rare", slot = "weapon",
        icon = "/", color = {0.3, 0.9, 0.3},
        stats = {atk = 7, spd = 1}, element = "poison",
        passive = {type = "poison", value = 3, desc = "공격 시 25% 확률로 3턴간 독 (턴당 3뎀)"},
    }),
    -- 영웅 (epic)
    vampiric_blade = Item.new({
        id = "vampiric_blade", name = "흡혈검", description = "피를 빨아들이는 저주받은 검",
        gridW = 1, gridH = 3, rarity = "epic", slot = "weapon",
        icon = "/", color = {0.8, 0.1, 0.2},
        stats = {atk = 12, crit = 8}, element = "slash",
        passive = {type = "lifesteal", value = 15, desc = "공격 데미지의 15% HP 흡수"},
    }),
    thunder_sword = Item.new({
        id = "thunder_sword", name = "뇌전검", description = "번개가 깃든 검",
        gridW = 1, gridH = 3, rarity = "epic", slot = "weapon",
        icon = "/", color = {0.9, 0.9, 0.3},
        stats = {atk = 14, spd = 3, crit = 12}, element = "lightning",
        passive = {type = "stun", value = 15, desc = "공격 시 15% 확률로 적 1턴 기절"},
    }),
    -- 전설 (legendary)
    soul_reaper = Item.new({
        id = "soul_reaper", name = "영혼 수확자", description = "영혼을 거두는 낫 형태의 검",
        gridW = 1, gridH = 4, rarity = "legendary", slot = "weapon",
        icon = ")", color = {0.6, 0.1, 0.8},
        stats = {atk = 22, crit = 18, spd = 2}, element = "holy",
        passive = {type = "lifesteal", value = 25, desc = "공격 데미지의 25% HP 흡수"},
    }),
    holy_mace = Item.new({
        id = "holy_mace", name = "성스러운 메이스", description = "신성한 힘이 깃든 둔기",
        gridW = 1, gridH = 3, rarity = "rare", slot = "weapon",
        icon = "!", color = {1.0, 1.0, 0.7},
        stats = {atk = 9, hp = 5}, element = "holy",
    }),
    ice_stiletto = Item.new({
        id = "ice_stiletto", name = "얼음 단도", description = "얼어붙은 날의 단도",
        gridW = 1, gridH = 2, rarity = "rare", slot = "weapon",
        icon = "-", color = {0.4, 0.8, 1.0},
        stats = {atk = 7, crit = 12, spd = 3}, element = "ice",
        passive = {type = "stun", value = 10, desc = "공격 시 10% 확률로 적 1턴 빙결"},
    }),

    -- =============================================
    -- 무기: 양손
    -- =============================================
    -- 고급
    long_sword = Item.new({
        id = "long_sword", name = "장검", description = "긴 양손 검",
        gridW = 1, gridH = 4, rarity = "uncommon", slot = "weapon",
        twoHanded = true,
        icon = "|", color = {0.6, 0.8, 1.0},
        stats = {atk = 7, crit = 5}, element = "slash",
    }),
    war_hammer = Item.new({
        id = "war_hammer", name = "전쟁 망치", description = "무거운 양손 망치",
        gridW = 2, gridH = 3, rarity = "uncommon", slot = "weapon",
        twoHanded = true,
        icon = "m", color = {0.6, 0.5, 0.4},
        stats = {atk = 8}, element = "strike",
    }),
    -- 희귀
    battle_axe = Item.new({
        id = "battle_axe", name = "전투도끼", description = "무거운 양손 도끼",
        gridW = 2, gridH = 3, rarity = "rare", slot = "weapon",
        twoHanded = true,
        icon = "P", color = {0.9, 0.5, 0.2},
        stats = {atk = 12, crit = 10}, element = "slash",
        passive = {type = "armor_break", value = 30, desc = "적 방어력 30% 무시"},
    }),
    frost_halberd = Item.new({
        id = "frost_halberd", name = "빙결 할버드", description = "얼음이 깃든 양손 무기",
        gridW = 2, gridH = 4, rarity = "rare", slot = "weapon",
        twoHanded = true,
        icon = "T", color = {0.3, 0.7, 1.0},
        stats = {atk = 14, def = 3}, element = "ice",
        passive = {type = "stun", value = 20, desc = "공격 시 20% 확률로 적 1턴 기절"},
    }),
    -- 영웅
    inferno_greatsword = Item.new({
        id = "inferno_greatsword", name = "지옥불 대검", description = "지옥의 불꽃으로 단조된 대검",
        gridW = 2, gridH = 4, rarity = "epic", slot = "weapon",
        twoHanded = true,
        icon = "†", color = {1.0, 0.3, 0.0},
        stats = {atk = 20, crit = 12}, element = "fire",
        passive = {type = "burn", value = 5, desc = "공격 시 40% 확률로 5턴간 화상 (턴당 3뎀)"},
    }),
    -- 전설
    dragon_blade = Item.new({
        id = "dragon_blade", name = "용의 검", description = "드래곤의 비늘로 만든 양손 검",
        gridW = 2, gridH = 5, rarity = "legendary", slot = "weapon",
        twoHanded = true,
        icon = "†", color = {1.0, 0.4, 0.1},
        stats = {atk = 28, crit = 18}, element = "fire",
        passive = {type = "double_hit", value = 25, desc = "25% 확률로 연속 공격"},
    }),
    abyssal_scythe = Item.new({
        id = "abyssal_scythe", name = "심연의 낫", description = "심연에서 건져올린 거대한 낫",
        gridW = 2, gridH = 5, rarity = "legendary", slot = "weapon",
        twoHanded = true,
        icon = "}", color = {0.4, 0.0, 0.6},
        stats = {atk = 25, crit = 20, spd = 3}, element = "slash",
        passive = {type = "lifesteal", value = 20, desc = "공격 데미지의 20% HP 흡수"},
    }),
    silver_spear = Item.new({
        id = "silver_spear", name = "은빛 창", description = "신성한 은으로 만든 긴 창",
        gridW = 1, gridH = 4, rarity = "uncommon", slot = "weapon",
        twoHanded = true,
        icon = "|", color = {0.9, 0.9, 1.0},
        stats = {atk = 8, crit = 4}, element = "holy",
    }),
    storm_staff = Item.new({
        id = "storm_staff", name = "폭풍 지팡이", description = "번개가 맴도는 마법 지팡이",
        gridW = 1, gridH = 4, rarity = "rare", slot = "weapon",
        twoHanded = true,
        icon = "/", color = {1.0, 1.0, 0.25},
        stats = {atk = 9, spd = 4, crit = 6}, element = "lightning",
        passive = {type = "stun", value = 12, desc = "공격 시 12% 확률로 적 1턴 기절"},
    }),
    glacier_staff = Item.new({
        id = "glacier_staff", name = "빙하 지팡이", description = "차가운 룬이 새겨진 지팡이",
        gridW = 1, gridH = 4, rarity = "rare", slot = "weapon",
        twoHanded = true,
        icon = "/", color = {0.35, 0.8, 1.0},
        stats = {atk = 10, def = 2}, element = "ice",
        passive = {type = "stun", value = 14, desc = "공격 시 14% 확률로 적 1턴 빙결"},
    }),
    bone_wand = Item.new({
        id = "bone_wand", name = "뼈 지팡이", description = "금지된 의식에 쓰이는 지팡이",
        gridW = 1, gridH = 3, rarity = "rare", slot = "weapon",
        icon = "/", color = {0.6, 0.9, 0.55},
        stats = {atk = 7, crit = 8}, element = "poison",
        passive = {type = "poison", value = 3, desc = "공격 시 30% 확률로 3턴간 독"},
    }),
    moon_katana = Item.new({
        id = "moon_katana", name = "월광도", description = "달빛을 머금은 예리한 검",
        gridW = 1, gridH = 4, rarity = "epic", slot = "weapon",
        twoHanded = true,
        icon = "/", color = {0.8, 0.85, 1.0},
        stats = {atk = 17, crit = 18, spd = 3}, element = "slash",
        passive = {type = "crit_boost", value = 8, desc = "치명타 +8%"},
    }),

    -- =============================================
    -- 방패
    -- =============================================
    wooden_shield = Item.new({
        id = "wooden_shield", name = "나무 방패", description = "기본 나무 방패",
        gridW = 2, gridH = 2, rarity = "common", slot = "weapon",
        icon = "]", color = {0.6, 0.45, 0.2},
        stats = {def = 3},
    }),
    iron_shield = Item.new({
        id = "iron_shield", name = "철 방패", description = "튼튼한 철 방패",
        gridW = 2, gridH = 2, rarity = "uncommon", slot = "weapon",
        icon = "]", color = {0.5, 0.5, 0.6},
        stats = {def = 6, hp = 5},
    }),
    thorn_shield = Item.new({
        id = "thorn_shield", name = "가시 방패", description = "가시가 박힌 방패",
        gridW = 2, gridH = 2, rarity = "rare", slot = "weapon",
        icon = "]", color = {0.4, 0.6, 0.3},
        stats = {def = 8, hp = 8},
        passive = {type = "thorns", value = 3, desc = "피격 시 공격자에게 3 데미지 반사"},
    }),
    mirror_shield = Item.new({
        id = "mirror_shield", name = "거울 방패", description = "데미지를 반사하는 방패",
        gridW = 2, gridH = 2, rarity = "epic", slot = "weapon",
        icon = "]", color = {0.8, 0.8, 1.0},
        stats = {def = 12, hp = 10},
        passive = {type = "reflect", value = 20, desc = "피격 데미지의 20% 반사"},
    }),
    dragon_shield = Item.new({
        id = "dragon_shield", name = "용린 방패", description = "용의 비늘로 만든 방패",
        gridW = 2, gridH = 3, rarity = "legendary", slot = "weapon",
        icon = "]", color = {1.0, 0.3, 0.1},
        stats = {def = 18, hp = 25},
        passive = {type = "reflect", value = 30, desc = "피격 데미지의 30% 반사"},
    }),

    -- =============================================
    -- 방어구
    -- =============================================
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
    plate_armor = Item.new({
        id = "plate_armor", name = "판금 갑옷", description = "단단한 판금 갑옷",
        gridW = 2, gridH = 3, rarity = "rare", slot = "armor",
        icon = "A", color = {0.6, 0.6, 0.8},
        stats = {def = 12, hp = 15},
        passive = {type = "thorns", value = 2, desc = "피격 시 공격자에게 2 데미지 반사"},
    }),
    shadow_robe = Item.new({
        id = "shadow_robe", name = "그림자 로브", description = "그림자로 짠 로브",
        gridW = 2, gridH = 3, rarity = "epic", slot = "armor",
        icon = "R", color = {0.3, 0.2, 0.5},
        stats = {def = 10, hp = 12, spd = 5},
        passive = {type = "dodge_boost", value = 10, desc = "회피율 +10%"},
    }),
    dragon_armor = Item.new({
        id = "dragon_armor", name = "용린 갑옷", description = "용의 비늘로 만든 갑옷",
        gridW = 2, gridH = 3, rarity = "legendary", slot = "armor",
        icon = "D", color = {1.0, 0.3, 0.1},
        stats = {def = 22, hp = 35},
        passive = {type = "regen", value = 2, desc = "매 턴 HP 2 회복"},
    }),
    silk_robe = Item.new({
        id = "silk_robe", name = "비단 로브", description = "가벼운 마법사용 로브",
        gridW = 2, gridH = 3, rarity = "common", slot = "armor",
        icon = "R", color = {0.75, 0.65, 1.0},
        stats = {def = 2, hp = 4, spd = 3},
    }),
    inferno_robe = Item.new({
        id = "inferno_robe", name = "화염 로브", description = "뜨거운 룬이 수놓인 로브",
        gridW = 2, gridH = 3, rarity = "rare", slot = "armor",
        icon = "R", color = {1.0, 0.25, 0.05},
        stats = {def = 5, hp = 8, atk = 3}, 
        passive = {type = "burn", value = 2, desc = "공격 시 20% 확률로 화상"},
    }),
    frost_mail = Item.new({
        id = "frost_mail", name = "서리 사슬갑옷", description = "냉기가 흐르는 사슬갑옷",
        gridW = 2, gridH = 3, rarity = "rare", slot = "armor",
        icon = "M", color = {0.35, 0.75, 1.0},
        stats = {def = 10, hp = 12},
        passive = {type = "reflect", value = 8, desc = "피격 데미지의 8% 반사"},
    }),
    templar_plate = Item.new({
        id = "templar_plate", name = "성전사 판금갑옷", description = "신성 문장이 새겨진 판금갑옷",
        gridW = 2, gridH = 3, rarity = "epic", slot = "armor",
        icon = "A", color = {1.0, 0.95, 0.65},
        stats = {def = 16, hp = 18},
        passive = {type = "regen", value = 1, desc = "매 턴 HP 1 회복"},
    }),
    necro_robe = Item.new({
        id = "necro_robe", name = "강령 로브", description = "죽은 자의 속삭임이 맴도는 로브",
        gridW = 2, gridH = 3, rarity = "epic", slot = "armor",
        icon = "R", color = {0.35, 0.6, 0.35},
        stats = {def = 8, hp = 10, atk = 4},
        passive = {type = "lifesteal", value = 8, desc = "공격 데미지의 8% HP 흡수"},
    }),

    -- =============================================
    -- 투구
    -- =============================================
    iron_helmet = Item.new({
        id = "iron_helmet", name = "철 투구", description = "기본 철 투구",
        gridW = 2, gridH = 2, rarity = "common", slot = "helmet",
        icon = "H", color = {0.6, 0.6, 0.7},
        stats = {def = 2, hp = 3},
    }),
    mage_hat = Item.new({
        id = "mage_hat", name = "마법사 모자", description = "마력이 깃든 모자",
        gridW = 2, gridH = 2, rarity = "uncommon", slot = "helmet",
        icon = "^", color = {0.4, 0.3, 0.8},
        stats = {def = 1, hp = 5},
        passive = {type = "exp_boost", value = 10, desc = "경험치 획득량 +10%"},
    }),
    berserker_helm = Item.new({
        id = "berserker_helm", name = "광전사 투구", description = "전투 의지를 불태우는 투구",
        gridW = 2, gridH = 2, rarity = "rare", slot = "helmet",
        icon = "H", color = {0.9, 0.3, 0.2},
        stats = {def = 5, hp = 10, atk = 3},
        passive = {type = "crit_boost", value = 8, desc = "치명타 +8%"},
    }),
    royal_crown = Item.new({
        id = "royal_crown", name = "왕관", description = "고대 왕의 왕관",
        gridW = 2, gridH = 2, rarity = "epic", slot = "helmet",
        icon = "W", color = {1.0, 0.85, 0.0},
        stats = {def = 8, hp = 15, crit = 5},
        passive = {type = "gold_boost", value = 20, desc = "골드 획득량 +20%"},
    }),
    dragon_helm = Item.new({
        id = "dragon_helm", name = "용뿔 투구", description = "용의 뿔로 만든 투구",
        gridW = 2, gridH = 2, rarity = "legendary", slot = "helmet",
        icon = "H", color = {1.0, 0.4, 0.0},
        stats = {def = 12, hp = 20, atk = 5},
        passive = {type = "regen", value = 1, desc = "매 턴 HP 1 회복"},
    }),

    -- =============================================
    -- 신발
    -- =============================================
    leather_boots = Item.new({
        id = "leather_boots", name = "가죽 장화", description = "가벼운 장화",
        gridW = 2, gridH = 2, rarity = "common", slot = "boots",
        icon = "B", color = {0.5, 0.35, 0.2},
        stats = {def = 1, spd = 2},
    }),
    iron_greaves = Item.new({
        id = "iron_greaves", name = "철 각반", description = "튼튼한 철 각반",
        gridW = 2, gridH = 2, rarity = "uncommon", slot = "boots",
        icon = "B", color = {0.5, 0.5, 0.6},
        stats = {def = 3, spd = 1, hp = 5},
    }),
    swift_boots = Item.new({
        id = "swift_boots", name = "신속의 장화", description = "바람처럼 빠른 장화",
        gridW = 2, gridH = 2, rarity = "rare", slot = "boots",
        icon = "S", color = {0.3, 0.9, 0.9},
        stats = {def = 3, spd = 8},
        passive = {type = "dodge_boost", value = 8, desc = "회피율 +8%"},
    }),
    shadow_boots = Item.new({
        id = "shadow_boots", name = "그림자 장화", description = "발소리 없는 장화",
        gridW = 2, gridH = 2, rarity = "epic", slot = "boots",
        icon = "S", color = {0.3, 0.2, 0.4},
        stats = {def = 5, spd = 12},
        passive = {type = "dodge_boost", value = 12, desc = "회피율 +12%"},
    }),
    dragon_boots = Item.new({
        id = "dragon_boots", name = "용린 장화", description = "용의 비늘로 만든 장화",
        gridW = 2, gridH = 2, rarity = "legendary", slot = "boots",
        icon = "B", color = {1.0, 0.4, 0.0},
        stats = {def = 8, spd = 10, hp = 15},
        passive = {type = "regen", value = 1, desc = "매 턴 HP 1 회복"},
    }),

    -- =============================================
    -- 반지
    -- =============================================
    copper_ring = Item.new({
        id = "copper_ring", name = "구리 반지", description = "단순한 반지",
        gridW = 1, gridH = 1, rarity = "common", slot = "ring",
        icon = "o", color = {0.8, 0.5, 0.3},
        stats = {atk = 1},
    }),
    silver_ring = Item.new({
        id = "silver_ring", name = "은 반지", description = "은으로 된 반지",
        gridW = 1, gridH = 1, rarity = "uncommon", slot = "ring",
        icon = "o", color = {0.8, 0.8, 0.9},
        stats = {atk = 2, def = 1},
    }),
    emerald_ring = Item.new({
        id = "emerald_ring", name = "에메랄드 반지", description = "녹색 보석이 박힌 반지",
        gridW = 1, gridH = 1, rarity = "rare", slot = "ring",
        icon = "O", color = {0.2, 0.9, 0.4},
        stats = {atk = 3, hp = 8},
        passive = {type = "regen", value = 1, desc = "매 턴 HP 1 회복"},
    }),
    ruby_ring = Item.new({
        id = "ruby_ring", name = "루비 반지", description = "붉은 보석이 박힌 반지",
        gridW = 1, gridH = 1, rarity = "epic", slot = "ring",
        icon = "O", color = {1.0, 0.2, 0.2},
        stats = {atk = 5, crit = 10},
        passive = {type = "crit_boost", value = 10, desc = "치명타 +10%"},
    }),
    ring_of_power = Item.new({
        id = "ring_of_power", name = "힘의 반지", description = "고대 마법이 깃든 반지",
        gridW = 1, gridH = 1, rarity = "legendary", slot = "ring",
        icon = "O", color = {1.0, 0.8, 0.0},
        stats = {atk = 8, crit = 12, hp = 10},
        passive = {type = "lifesteal", value = 10, desc = "공격 데미지의 10% HP 흡수"},
    }),

    -- =============================================
    -- 목걸이
    -- =============================================
    silver_amulet = Item.new({
        id = "silver_amulet", name = "은 목걸이", description = "은으로 된 목걸이",
        gridW = 1, gridH = 1, rarity = "uncommon", slot = "amulet",
        icon = "V", color = {0.8, 0.8, 0.9},
        stats = {hp = 10, def = 2},
    }),
    healing_pendant = Item.new({
        id = "healing_pendant", name = "회복의 펜던트", description = "은은한 빛이 나는 펜던트",
        gridW = 1, gridH = 1, rarity = "rare", slot = "amulet",
        icon = "V", color = {0.3, 1.0, 0.5},
        stats = {hp = 15, def = 3},
        passive = {type = "regen", value = 2, desc = "매 턴 HP 2 회복"},
    }),
    amulet_of_fury = Item.new({
        id = "amulet_of_fury", name = "분노의 목걸이", description = "전투 본능을 깨우는 목걸이",
        gridW = 1, gridH = 1, rarity = "epic", slot = "amulet",
        icon = "V", color = {1.0, 0.3, 0.2},
        stats = {atk = 6, crit = 8},
        passive = {type = "crit_boost", value = 8, desc = "치명타 +8%"},
    }),
    amulet_of_eternity = Item.new({
        id = "amulet_of_eternity", name = "영원의 목걸이", description = "불멸의 힘이 깃든 목걸이",
        gridW = 1, gridH = 1, rarity = "legendary", slot = "amulet",
        icon = "V", color = {1.0, 0.9, 0.3},
        stats = {hp = 30, def = 5, atk = 5},
        passive = {type = "regen", value = 3, desc = "매 턴 HP 3 회복"},
    }),
    cursed_chalice = Item.new({
        id = "cursed_chalice", name = "저주받은 성배", description = "강력하지만 귀환 전까지 해제 불가",
        gridW = 1, gridH = 1, rarity = "legendary", slot = "amulet",
        icon = "V", color = {0.8, 0.1, 0.2},
        stats = {atk = 15, hp = 30, crit = 15},
        cursed = true,
        passive = {type = "lifesteal", value = 15, desc = "공격 데미지의 15% HP 흡수"},
    }),

    -- =============================================
    -- 소비 아이템
    -- =============================================
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
    return_scroll = Item.new({
        id = "return_scroll", name = "귀환 주문서", description = "3턴 대기 후 마을로 귀환 (피격 시 취소)",
        gridW = 1, gridH = 1, rarity = "uncommon", slot = nil,
        icon = "~", color = {0.8, 0.6, 1.0},
        stackable = true,
    }),

    -- =============================================
    -- 재료
    -- =============================================
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
