local Religion = {}

local GOD_WAR = "WAR"
local GOD_SHADOW = "SHADOW"
local GOD_MAGIC = "MAGIC"

Religion.GOD_WAR = GOD_WAR
Religion.GOD_SHADOW = GOD_SHADOW
Religion.GOD_MAGIC = GOD_MAGIC

Religion.NAMES = {
    [GOD_WAR] = "피와 전쟁의 신 (크롬)",
    [GOD_SHADOW] = "그림자와 기만의 신 (녹티스)",
    [GOD_MAGIC] = "지식과 마력의 신 (오그마)"
}

Religion.COLORS = {
    [GOD_WAR] = {1.0, 0.2, 0.2},
    [GOD_SHADOW] = {0.5, 0.2, 0.8},
    [GOD_MAGIC] = {0.2, 0.6, 1.0}
}

Religion.DESCRIPTIONS = {
    [GOD_WAR] = "축복: 공격력 +50%, 적 처치시 HP 흡혈\n패널티: 자연 체력 재생 불가, 방어력 -30%",
    [GOD_SHADOW] = "축복: 회피율 +30%, 크리티컬 +20%\n패널티: 최대 체력 -30% (유리 대포)",
    [GOD_MAGIC] = "축복: 시야 반경 +3, 마법(스크롤) 데미지 2배, 마나 재생 증가\n패널티: 물리 공격력 -50%"
}

-- 스탯에 종교 버프/패널티를 적용해주는 헬퍼 함수들
function Religion.applyAtkMod(baseAtk, currentReligion)
    if currentReligion == GOD_WAR then
        return math.floor(baseAtk * 1.5)
    elseif currentReligion == GOD_MAGIC then
        return math.floor(baseAtk * 0.5)
    end
    return baseAtk
end

function Religion.applyDefMod(baseDef, currentReligion)
    if currentReligion == GOD_WAR then
        return math.floor(baseDef * 0.7)
    end
    return baseDef
end

function Religion.applyHpMod(baseHp, currentReligion)
    if currentReligion == GOD_SHADOW then
        return math.floor(baseHp * 0.7)
    end
    return baseHp
end

function Religion.applyEvasionMod(baseEvasion, currentReligion)
    if currentReligion == GOD_SHADOW then
        return baseEvasion + 30
    end
    return baseEvasion
end

function Religion.applyCritMod(baseCrit, currentReligion)
    if currentReligion == GOD_SHADOW then
        return baseCrit + 20
    end
    return baseCrit
end

function Religion.applyFovMod(baseFov, currentReligion)
    if currentReligion == GOD_MAGIC then
        return baseFov + 3
    end
    return baseFov
end

function Religion.applyMagicDmgMod(baseDmg, currentReligion)
    if currentReligion == GOD_MAGIC then
        return math.floor(baseDmg * 2.0)
    end
    return baseDmg
end

-- 이벤트 트리거
function Religion.onKillEnemy(player, enemy)
    if player.religion == GOD_WAR then
        local heal = math.max(1, math.floor(enemy.maxHp * 0.2))
        player.hp = math.min(player.maxHp, player.hp + heal)
        player.piety = player.piety + 1
        return heal
    end
    return 0
end

return Religion
