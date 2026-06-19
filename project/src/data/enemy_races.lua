-- data/enemy_races.lua
-- 종족 데이터베이스 및 상성 계산
-- main.lua에서 분리된 모듈

local M = {}

-- 종족 데이터베이스
M.RACE_DB = {
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
function M.getElementMult(element, race)
    if not race or not M.RACE_DB[race] then return 1.0 end
    local raceData = M.RACE_DB[race]

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

return M
