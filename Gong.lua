--[[
local config = {
    windowWidth = 800,
    windowHeight = 600,
    boxWidth = 230,
    boxHeight = 230,
    boxLineWidth = 5,
    buttonRadius = 34,
    buttonEdgeMargin = 10,
    ballRadius = 14,
    gravity = 0,
    launchSpeed = 520,
    launchSideSpeed = 180,
    restitution = 1,
    damping = 1,
    rotationSpeed = math.rad(95),
    maxBallSpeed = 760,
}

local box = {
    x = 400,
    y = 285,
    angle = 0,
    width = config.boxWidth,
    height = config.boxHeight,
    radius = 250,
    sides = 4,
    rotationSpeed = config.rotationSpeed,
    rotVel = 0, -- 회전 속도 (가속도용)
    pulse = 0,
    shake = 0,
    wallMods = {} -- 상자 외벽 장비 장착 현황 테이블 (Normal, Bumper, Laser, Repair)
}

local balls = {}
local enemies = {}
local items = {}
local particles = {} -- 파티클 풀링 구조
local projectiles = {}
local floatingTexts = {} -- 플로팅 텍스트 풀링 구조
local hitstop = 0 -- 타격감용 히트스탑 타이머
local activePulse = { radius = 0, maxRadius = 0, active = false } -- 우클릭 충격파
local screenShake = 0 -- 화면 전체 흔들림
local spawnTimer = 0
local gameState = "PLAYING" -- PLAYING, GAMEOVER 상태

-- RPG 시스템 연동
local player = {
    gold = 0,
    ballCost = 10,  -- 실시간 동적 계산
    sideCost = 20,
    atkCost = 30,
    hpUpgradeCost = 40,
    ballMaxHp = 50,
    explosionCost = 100,
    wallBulletCost = 150,
    hasExplosion = false,
    hasWallBullet = false,
    hp = 30,
    maxHp = 30,
    goldPerHit = 1,  -- 벽 충돌 시 기본 골드
    wallDmg = 1,     -- 벽 충돌 시 공이 입는 데미지
    lifesteal = 0,   -- 타격 시 체력 회복량
    itemChance = 0,  -- 아이템 추가 드랍 확률
    atk = 3,
    def = 0,
    exp = 0,
    nextExp = 20,
    level = 1,
    bossLevel = 0,
}

local messages = {}
local function addMessage(text)
    table.insert(messages, 1, text)
    if #messages > 5 then table.remove(messages) end
end

local isSelectingSkill = false
local selectionCards = {}
local selectedCardIndex = 0 -- 스킬 토글 선택을 위한 인덱스

-- 등급별 색상 정의
local RARITY_COLORS = {
    Common = {0.7, 0.7, 0.7},
    Rare = {0.2, 0.6, 1.0},
    Legendary = {1.0, 0.8, 0.0}
}

-- 상자 각 각형(Sides) 수와 외벽 장비 개수를 동기화하는 함수
local function syncWallMods()
    while #box.wallMods < box.sides do
        table.insert(box.wallMods, "Normal")
    end
    while #box.wallMods > box.sides do
        table.remove(box.wallMods)
    end
end

-- 무작위 비어있는 변 하나를 특수 속성 외벽 장치로 강화하는 함수
local function applyWallMod(modType)
    syncWallMods()
    local candidates = {}
    for i = 1, box.sides do
        if box.wallMods[i] == "Normal" then
            table.insert(candidates, i)
        end
    end
    
    local targetIdx = 1
    if #candidates > 0 then
        targetIdx = candidates[math.random(#candidates)]
    else
        targetIdx = math.random(box.sides) -- 다 차있다면 덮어쓰기
    end
    box.wallMods[targetIdx] = modType
end

-- 현재 일반 공 중 무작위 공 하나를 원소 속성 공으로 진화 변환하는 함수
local function convertBallElement(elementType)
    local normals = {}
    for _, b in ipairs(balls) do
        if b.element == "Normal" then
            table.insert(normals, b)
        end
    end
    if #normals > 0 then
        local chosen = normals[math.random(#normals)]
        chosen.element = elementType
    else
        if #balls > 0 then
            balls[math.random(#balls)].element = elementType
        end
    end
end

-- 파티클 오브젝트 풀링 사전 할당 (1000개 확보)
for i = 1, 1000 do
    particles[i] = { x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 0, color = {0,0,0}, size = 0, active = false }
end

-- 플로팅 텍스트 오브젝트 풀링 사전 할당 (120개 확보)
for i = 1, 120 do
    floatingTexts[i] = { text = "", x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 0, color = {0,0,0}, active = false }
end

-- 실시간 존재하는 공의 개수비례 동적 공 구매가 변동 시스템
local function getDynamicBallCost()
    local count = #balls
    if count <= 0 then
        return 10
    end
    return 10 + (count - 1) * 15 + math.floor((count - 1)^1.6 * 8)
end

-- 스킬 풀 한글화 및 [A,B 속성/장비 시너지 전설 및 희귀 스킬 대량 추가!]
local skillPool = {
    { name = "화염 코어 발현", rarity = "Rare", desc = "일반 공 1개를 주변 광역 폭발 화염 데미지를 주는 화염 공으로 속성 진화", action = function() convertBallElement("Fire"); addMessage("🔥 화염 원소 공이 탄생했습니다! 🔥") end },
    { name = "전격 코어 발현", rarity = "Rare", desc = "일반 공 1개를 적 타격 시 징검다리 스파크 연쇄 타격을 입히는 전격 공으로 속성 진화", action = function() convertBallElement("Lightning"); addMessage("⚡ 전격 원소 공이 탄생했습니다! ⚡") end },
    { name = "서리 코어 발현", rarity = "Rare", desc = "일반 공 1개를 타격 시 보스 및 위성 속도를 3초간 40% 둔화시키는 서리 공으로 속성 진화", action = function() convertBallElement("Frost"); addMessage("❄️ 서리 원소 공이 탄생했습니다! ❄️") end },
    { name = "범퍼 요새화", rarity = "Rare", desc = "비어있는 변 1개를 공 충돌 시 속도 및 공격력 2배 가속을 해주는 범퍼 벽(초록)으로 개조", action = function() applyWallMod("Bumper"); addMessage("🌀 상자 외벽 1칸을 가속 범퍼로 개조 완료! 🌀") end },
    { name = "레이저 포탑벽", rarity = "Rare", desc = "비어있는 변 1개를 공 충돌 시 보스에게 강력한 추적 유도탄을 격발하는 레이저 벽(자주)으로 개조", action = function() applyWallMod("Laser"); addMessage("🔮 상자 외벽 1칸을 레이저 포탑벽으로 개조 완료! 🔮") end },
    { name = "수리 수호막", rarity = "Rare", desc = "비어있는 변 1개를 공 충돌 시 공 내구도를 즉시 100% 완전 수리해 주는 쉴드 벽(파랑)으로 개조", action = function() applyWallMod("Repair"); addMessage("💖 상자 외벽 1칸을 완전 수리벽으로 개조 완료! 💖") end },

    -- [기존 한글 스킬 복원 유지]
    { name = "강인한 생명력", rarity = "Common", desc = "최대 체력 (Max HP) +20 및 즉시 체력 회복", action = function() player.maxHp = player.maxHp + 20; player.hp = player.hp + 20; addMessage("최대 HP 증가!") end },
    { name = "괴력", rarity = "Common", desc = "공격력 (ATK) +5 증가", action = function() player.atk = player.atk + 5; addMessage("공격력이 대폭 상승했습니다!") end },
    { name = "응급 치료", rarity = "Common", desc = "플레이어 체력을 최대로 즉시 회복", action = function() player.hp = player.maxHp; addMessage("플레이어 체력이 완전히 회복되었습니다!") end },
    { name = "공 수리 키트", rarity = "Common", desc = "현재 활성화된 모든 공의 체력 +20 수리", action = function() for _, b in ipairs(balls) do b.hp = math.min(b.maxHp, b.hp + 20) end; addMessage("모든 공의 내구도가 수리되었습니다!") end },
    { name = "철벽 요새", rarity = "Common", desc = "방어력 (DEF) +4 증가", action = function() player.def = player.def + 4; addMessage("방어력이 단단해졌습니다!") end },
    { name = "황금의 광맥", rarity = "Common", desc = "벽 충돌 시 획득하는 골드 양 +2", action = function() player.goldPerHit = player.goldPerHit + 2; addMessage("벽 충돌 시 얻는 골드가 증가합니다!") end },
    { name = "엔지니어 마스터", rarity = "Rare", desc = "이후 구매하는 공들의 최대 HP +50 증가", action = function() player.ballMaxHp = player.ballMaxHp + 50; addMessage("공의 내구도 상한이 강화되었습니다!") end },
    { name = "공간 확장", rarity = "Rare", desc = "회전 상자 내부 반경 확장 (+50)", action = function() box.radius = math.min(500, box.radius + 50); addMessage("상자 안쪽 공간이 확장되었습니다!") end },
    { name = "가속 터보 기어", rarity = "Rare", desc = "회전 상자의 최대 속도 증가", action = function() box.rotationSpeed = box.rotationSpeed + math.rad(60); addMessage("상자 회전 속도가 대폭 증가했습니다!") end },
    { name = "완벽 복원", rarity = "Rare", desc = "공이 완전한 탄성으로 벽에 튕김 (탄성도 1.0 보정)", action = function() config.restitution = 1.0; addMessage("공의 탄성도가 최고치로 보정되었습니다!") end },
    { name = "거대 코어", rarity = "Rare", desc = "공의 반지름 +5 증가 (피격 판정 개선)", action = function() config.ballRadius = config.ballRadius + 5; addMessage("모든 공이 거대화되었습니다!") end },
    { name = "흡혈 귀환", rarity = "Rare", desc = "적을 맞출 때마다 플레이어 체력 +2 흡수 회복", action = function() player.lifesteal = player.lifesteal + 2; addMessage("적 타격 시 체력을 흡수합니다!") end },
    { name = "리미트 브레이커", rarity = "Rare", desc = "공의 한계 최고 속도 +200 증가", action = function() config.maxBallSpeed = config.maxBallSpeed + 200; addMessage("공의 속도 한계가 개방되었습니다!") end },
    { name = "연금술사의 벽", rarity = "Rare", desc = "공이 벽에 튕길 때 10% 확률로 포션/스크롤 드랍", action = function() player.itemChance = player.itemChance + 0.1; addMessage("벽 충돌 시 아이템이 생성될 수 있습니다!") end },
    { name = "미다스의 축복", rarity = "Legendary", desc = "즉시 1000 골드 대량 획득", action = function() player.gold = player.gold + 1000; addMessage("★ 황금의 축복! +1000 골드 획득 ★") end },
    { name = "전지전능", rarity = "Legendary", desc = "공격력 (ATK) +15 대폭 증가 및 HP 전회복", action = function() player.atk = player.atk + 15; player.hp = player.maxHp; addMessage("★ 초월적인 힘을 얻고 체력을 완전히 회복했습니다! ★") end },
    { name = "나노 강철막", rarity = "Legendary", desc = "공이 벽에 충돌 시 입는 데미지가 완전히 면제됨", action = function() player.wallDmg = 0; addMessage("★ 이제 공이 벽 충돌로 파괴되지 않습니다! ★") end },
    { name = "초신성 대폭발", rarity = "Legendary", desc = "공 파괴 폭발 해금 (이미 보유 시 폭발 공격력/범위 x2)", action = function() if player.hasExplosion then player.atk = player.atk + 10; addMessage("폭발 데미지가 강화되었습니다!") else player.hasExplosion = true; addMessage("★ 폭발 스킬이 개방되었습니다! ★") end end },
    { name = "마스터마인드", rarity = "Legendary", desc = "즉시 레벨업 및 보너스 +500 골드 획득", action = function() player.exp = player.nextExp; player.gold = player.gold + 500; addMessage("★ 상자의 지배자! 즉시 레벨 업! ★") end },
}

local buttons = {
    left = { x = 0, y = 0, direction = -1, isDown = false },
    right = { x = 0, y = 0, direction = 1, isDown = false },
}

local font
local smallFont

local spawnObject -- 전방 선언

-- 플로팅 텍스트 풀링 생성
local function addFloatingText(text, x, y, color)
    for i = 1, 120 do
        local ft = floatingTexts[i]
        if not ft.active then
            ft.text = tostring(text)
            ft.x = x
            ft.y = y
            ft.vx = math.random(-40, 40)
            ft.vy = -math.random(100, 160)
            ft.life = 1.0
            ft.maxLife = 1.0
            ft.color[1] = color and color[1] or 1
            ft.color[2] = color and color[2] or 1
            ft.color[3] = color and color[3] or 1
            ft.active = true
            break
        end
    end
end

-- table.remove 없는 고속 갱신
local function updateFloatingTexts(dt)
    for i = 1, 120 do
        local ft = floatingTexts[i]
        if ft.active then
            ft.x = ft.x + ft.vx * dt
            ft.y = ft.y + ft.vy * dt
            ft.vy = ft.vy + 230 * dt
            ft.life = ft.life - dt
            if ft.life <= 0 then
                ft.active = false
            end
        end
    end
end

-- 풀 내부 활성 개체 전용 렌더링
local function drawFloatingTexts()
    for i = 1, 120 do
        local ft = floatingTexts[i]
        if ft.active then
            local alpha = ft.life / ft.maxLife
            love.graphics.setColor(ft.color[1], ft.color[2], ft.color[3], alpha)
            love.graphics.setFont(smallFont)
            love.graphics.print(ft.text, ft.x, ft.y)
        end
    end
end

local function rotatePoint(x, y, angle)
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)
    return x * cosAngle - y * sinAngle, x * sinAngle + y * cosAngle
end

local function worldToBoxLocal(x, y)
    return rotatePoint(x - box.x, y - box.y, -box.angle)
end

local function boxLocalToWorld(x, y)
    local worldX, worldY = rotatePoint(x, y, box.angle)
    return worldX + box.x, worldY + box.y
end

local function getRotatedBoxCorners()
    local corners = {}
    for i = 0, box.sides - 1 do
        local sideAngle = (i * 2 * math.pi / box.sides)
        table.insert(corners, { x = math.cos(sideAngle) * box.radius, y = math.sin(sideAngle) * box.radius })
    end
    for _, corner in ipairs(corners) do
        corner.x, corner.y = boxLocalToWorld(corner.x, corner.y)
    end
    return corners
end

local function createBall(released)
    local spawnAngle = math.random() * math.pi * 2
    local spawnDist = math.random(50, box.radius * 0.6)
    local newBall = {
        x = box.x + math.cos(spawnAngle) * spawnDist,
        y = box.y + math.sin(spawnAngle) * spawnDist,
        vx = released and (math.random() * 400 - 200) or 0,
        vy = released and config.launchSpeed or 0,
        isReleased = released or false,
        hp = player.ballMaxHp,
        maxHp = player.ballMaxHp,
        combo = 0,
        trail = {},
        element = "Normal",      -- 원소 속성 필드 (Normal, Fire, Lightning, Frost)
        nextHitBoosted = nil     -- A-B 시너지용 범퍼 가속 증폭 플래그
    }
    table.insert(balls, newBall)
end

-- 보조 수호 크리스탈 소환
local function spawnGuardOrb(boss)
    local angle = math.random() * math.pi * 2
    local dist = 75
    local ox = math.cos(angle) * dist
    local oy = math.sin(angle) * dist
    local x, y = boxLocalToWorld(ox, oy)
    
    table.insert(enemies, {
        x = x, y = y, ox = ox, oy = oy,
        hp = 20 * player.bossLevel, 
        maxHp = 20 * player.bossLevel,
        atk = 1,
        exp = 20,
        name = "수호 크리스탈 위성",
        color = {0.2, 0.85, 1.0}, 
        radius = 11,
        isOrb = true, 
        angle = angle, 
        squashX = 1.0,
        squashY = 1.0,
        shootTimer = 0,
        frostSlow = 0 
    })
end

-- 현재 활성화된 보호 오브가 있는지 판정
local function hasActiveOrbs()
    for _, e in ipairs(enemies) do
        if e.isOrb then return true end
    end
    return false
end

-- 보스 라운드 비례 지수형 체력 증가
local function spawnBoss()
    player.bossLevel = player.bossLevel + 1
    
    local hp = 100 * player.bossLevel + math.floor((player.bossLevel - 1)^1.4 * 60)
    local atk = 2 + math.floor(player.bossLevel * 1.5)
    local exp = 100 * player.bossLevel
    local name = "STAGE " .. player.bossLevel .. " BOSS"

    local r = (math.sin(player.bossLevel * 1.3) + 1) * 0.4 + 0.2
    local g = (math.sin(player.bossLevel * 1.7) + 1) * 0.4 + 0.2
    local b = (math.sin(player.bossLevel * 2.1) + 1) * 0.4 + 0.2
    
    table.insert(enemies, {
        x = box.x, y = box.y, ox = 0, oy = 0, 
        hp = hp, maxHp = hp, atk = atk, exp = exp, 
        name = name, color = {r, g, b}, radius = math.min(120, 35 + (player.bossLevel * 2)),
        patternTimer = 0,
        nextPatternTime = math.max(1.8, 3.5 - (player.bossLevel * 0.15)),
        squashX = 1.0,
        squashY = 1.0,
        frostSlow = 0 
    })
    addMessage("🚨 경보: " .. name .. " 출현! (최대 HP: " .. hp .. ") 🚨")
end

-- [요구사항 반영 - 리셋 픽스] 재시작 시 상자 각형 및 개조장벽을 완벽하게 4각형 네온으로 동기화 초기화!
local function resetGame()
    balls = {}
    enemies = {}
    items = {}
    projectiles = {}
    box.sides = 4 -- 확실히 4각형 초기화
    box.rotationSpeed = config.rotationSpeed
    box.wallMods = {} -- 상자 장비 완전 초기화
    syncWallMods()
    for i = 1, 1000 do particles[i].active = false end 
    for i = 1, 120 do floatingTexts[i].active = false end 
    player.hp = player.maxHp
    player.gold = 0
    player.atk = 3
    player.def = 0
    player.exp = 0
    player.nextExp = 20
    player.level = 1
    player.bossLevel = 0
    player.hasExplosion = false
    player.hasWallBullet = false
    player.lifesteal = 0
    player.itemChance = 0
    player.wallDmg = 1
    player.ballMaxHp = 50
    player.ballCost = 10
    player.sideCost = 20
    player.atkCost = 30
    player.hpUpgradeCost = 40
    gameState = "PLAYING"
    selectedCardIndex = 0
    createBall(false)
end

local function releaseBalls()
    local releasedAny = false
    for _, ball in ipairs(balls) do
        if not ball.isReleased then
            ball.isReleased = true
            ball.vx = config.launchSideSpeed
            ball.vy = config.launchSpeed
            releasedAny = true
        end
    end
    if releasedAny then
        addMessage("공을 사출했습니다! 전투 시작!")
    end
end

local function spawnProjectile(x, y, vx, vy, color, isDeflected)
    table.insert(projectiles, {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        life = 2.5,
        radius = 6,
        color = color or {1, 1, 0.5},
        isDeflected = isDeflected or false
    })
end

-- 파티클 할당 병목 제로 풀링 스폰 (타격 시 생성 부하 대폭 감소 개수조절)
local function spawnParticles(x, y, color, count)
    count = count or 20
    local spawned = 0
    for i = 1, 1000 do
        local p = particles[i]
        if not p.active then
            local angle = math.random() * math.pi * 2
            local speed = math.random(100, 320)
            p.x = x
            p.y = y
            p.vx = math.cos(angle) * speed
            p.vy = math.sin(angle) * speed
            p.life = 1.0
            p.maxLife = 1.0
            p.color[1] = color[1]
            p.color[2] = color[2]
            p.color[3] = color[3]
            p.size = math.random(2.5, 5.5)
            p.active = true
            
            spawned = spawned + 1
            if spawned >= count then break end
        end
    end
end

-- 외벽 장비 속성(Bumper, Laser, Repair) 충돌 및 A-B 복합 특수 시너지
local function reflectVelocity(ball, normalX, normalY, isWall, wallMod)
    local dot = ball.vx * normalX + ball.vy * normalY
    if dot >= 0 then return end

    local finalRestitution = config.restitution

    if isWall and wallMod == "Bumper" then
        finalRestitution = config.restitution * 2.0 
        ball.hp = math.min(ball.maxHp, ball.hp + 5) 
        ball.nextHitBoosted = "Bumper" 
        addFloatingText("🌀BUMPER 가속!🌀", ball.x, ball.y, {0.2, 1.0, 0.4})
        box.pulse = 16
        box.shake = 6
    end

    ball.vx = (ball.vx - 2 * dot * normalX) * finalRestitution
    ball.vy = (ball.vy - 2 * dot * normalY) * finalRestitution
    
    if isWall and ball.isReleased then
        player.gold = player.gold + player.goldPerHit
        addFloatingText("+" .. player.goldPerHit .. "골드", ball.x, ball.y, {1, 0.85, 0})
        
        if wallMod == "Normal" then
            ball.hp = ball.hp - player.wallDmg
        end
        ball.hp = math.min(ball.maxHp, ball.hp + 2)
        ball.combo = ball.combo + 1
        
        if wallMod == "Laser" then
            if #enemies > 0 then
                local boss = enemies[1]
                local lx, ly = boss.x - ball.x, boss.y - ball.y
                local ld = math.sqrt(lx*lx + ly*ly)
                if ld > 0 then
                    spawnProjectile(ball.x, ball.y, (lx/ld) * 820, (ly/ld) * 820, {0.8, 0.2, 1.0}, true)
                    
                    if ball.element == "Lightning" then
                        local bAngle = math.atan2(ly, lx)
                        spawnProjectile(ball.x, ball.y, math.cos(bAngle + 0.3) * 820, math.sin(bAngle + 0.3) * 820, {0.8, 0.2, 1.0}, true)
                        spawnProjectile(ball.x, ball.y, math.cos(bAngle - 0.3) * 820, math.sin(bAngle - 0.3) * 820, {0.8, 0.2, 1.0}, true)
                        addFloatingText("⚡분산 전격 레이저!⚡", ball.x, ball.y, {0.9, 0.9, 0.1})
                    end
                end
            end
            addFloatingText("🔮LASER 포탑 발사!🔮", ball.x, ball.y, {0.8, 0.2, 1.0})
            box.pulse = 12
        end

        if wallMod == "Repair" then
            ball.hp = ball.maxHp 
            addFloatingText("💖공 내구도 100% 수리!💖", ball.x, ball.y, {0.2, 0.8, 1.0})
            
            if ball.element == "Frost" then
                player.hp = math.min(player.maxHp, player.hp + 6)
                addFloatingText("💖플레이어 체력 +6 치유!💖", box.x, box.y, {0.2, 0.95, 0.4})
                spawnParticles(box.x, box.y, {0.2, 0.95, 0.4}, 8) -- 파티클 개수 조절
            end
        end
        
        if player.itemChance > 0 and math.random() < player.itemChance then
            spawnObject("item")
        end

        local accelFactor = 1.03
        ball.vx = ball.vx * accelFactor
        ball.vy = ball.vy * accelFactor

        box.pulse = math.max(box.pulse, 8)
        box.shake = math.max(box.shake, 4)
        spawnParticles(ball.x, ball.y, {1, 0.8, 0.2}, 6)
        
        if player.hasWallBullet then
            spawnProjectile(ball.x, ball.y, normalX * 420, normalY * 420)
        end
    elseif not isWall then
        ball.combo = 0
    end
end

local function clampBallSpeed(ball)
    local speedSquared = ball.vx * ball.vx + ball.vy * ball.vy
    local maxSpeedSquared = config.maxBallSpeed * config.maxBallSpeed
    if speedSquared <= maxSpeedSquared then return end

    local speed = math.sqrt(speedSquared)
    local scale = config.maxBallSpeed / speed
    ball.vx = ball.vx * scale
    ball.vy = ball.vy * scale
end

-- 다각형 외벽 변의 속성을 검출하여 충돌 반사에 인입
local function resolveBoxCollision(ball)
    local localX, localY = worldToBoxLocal(ball.x, ball.y)
    local numSides = box.sides
    local h = box.radius * math.cos(math.pi / numSides)
    local limit = h - config.ballRadius

    for i = 0, numSides - 1 do
        local sideAngle = (i + 0.5) * (2 * math.pi / numSides)
        local nx, ny = math.cos(sideAngle), math.sin(sideAngle)
        local dist = localX * nx + localY * ny

        if dist > limit then
            local pen = dist - limit
            localX = localX - nx * pen
            localY = localY - ny * pen
            ball.x, ball.y = boxLocalToWorld(localX, localY)
            
            local worldNormalX, worldNormalY = rotatePoint(-nx, -ny, box.angle)
            
            local wallIndex = i + 1
            local wMod = box.wallMods[wallIndex] or "Normal"
            
            reflectVelocity(ball, worldNormalX, worldNormalY, true, wMod)
        end
    end
end

spawnObject = function(type)
    local angle = math.random() * math.pi * 2
    local minDist = 0
    if #enemies > 0 then
        minDist = enemies[1].radius + 20
    end
    local dist = math.random(math.floor(minDist), math.floor(box.radius * 0.8))
    local ox, oy = math.cos(angle) * dist, math.sin(angle) * dist
    local x, y = boxLocalToWorld(ox, oy)

    if type == "enemy" then
        local types = {
            {name = "고블린", hp = 10, atk = 2, exp = 15, color = {0.2, 0.8, 0.2}},
            {name = "오크", hp = 30, atk = 5, exp = 40, color = {0.8, 0.2, 0.2}},
            {name = "슬라임", hp = 5, atk = 1, exp = 8, color = {0.2, 0.5, 1}}
        }
        local t = types[math.random(#types)]
        table.insert(enemies, {x = x, y = y, ox = ox, oy = oy, hp = t.hp, maxHp = t.hp, atk = t.atk, exp = t.exp, name = t.name, color = t.color, radius = 15, squashX = 1.0, squashY = 1.0, frostSlow = 0})
    else
        local types = {
            {name = "치유 포션", effect = "heal", val = 10, color = {1, 0.3, 0.3}},
            {name = "강화 스크롤", effect = "atk", val = 1, color = {0.3, 1, 0.3}},
            {name = "수호 방어구", effect = "def", val = 1, color = {0.3, 0.3, 1}}
        }
        local t = types[math.random(#types)]
        table.insert(items, {x = x, y = y, ox = ox, oy = oy, name = t.name, effect = t.effect, val = t.val, color = t.color, radius = 10})
    end
end

local function pickWeightedSkill()
    local roll = math.random(1, 100)
    local targetRarity
    if roll <= 5 then targetRarity = "Legendary"
    elseif roll <= 30 then targetRarity = "Rare"
    else targetRarity = "Common" end
    
    local pool = {}
    for _, s in ipairs(skillPool) do
        if s.rarity == targetRarity then table.insert(pool, s) end
    end
    if #pool == 0 then return skillPool[math.random(#skillPool)] end
    return pool[math.random(#pool)]
end

local function checkLevelUp()
    if isSelectingSkill then return end
    
    if player.exp >= player.nextExp then
        player.exp = player.exp - player.nextExp
        player.level = player.level + 1
        player.nextExp = math.floor(player.nextExp * 1.5)
        
        isSelectingSkill = true
        selectedCardIndex = 0
        selectionCards = {}
        local usedNames = {}
        for i = 1, 3 do
            local skill
            repeat
                skill = pickWeightedSkill()
            until not usedNames[skill.name]
            usedNames[skill.name] = true
            table.insert(selectionCards, { skill = skill, uiScale = 0.95 })
        end
        addMessage("✨ 레벨 업! Lv." .. player.level .. " 달성! ✨")
    end
end

local function updateWorldObjects(dt)
    if #enemies == 0 and not isSelectingSkill then
        spawnBoss()
    end

    spawnTimer = spawnTimer + dt
    if spawnTimer > 3 then
        if #items < 5 then spawnObject("item") end
        spawnTimer = 0
    end

    local speedMult = 1 + (player.bossLevel - 1) * 0.06

    for idx = #enemies, 1, -1 do
        local e = enemies[idx]
        local currentDt = dt
        
        -- 원소 서리 공의 빙결 둔화 디버프 연산
        if e.frostSlow and e.frostSlow > 0 then
            e.frostSlow = e.frostSlow - dt
            currentDt = dt * 0.6 
        end

        if e.isOrb then
            e.angle = (e.angle or 0) + currentDt * 2.2 
            e.ox = math.cos(e.angle) * 75
            e.oy = math.sin(e.angle) * 75
            
            e.shootTimer = (e.shootTimer or 0) + currentDt
            if e.shootTimer >= 2.0 then
                e.shootTimer = 0
                local fireA = e.angle + math.pi/2
                spawnProjectile(e.x, e.y, math.cos(fireA) * 240 * speedMult, math.sin(fireA) * 240 * speedMult, {0.2, 0.8, 1.0}, false)
                local fireB = e.angle - math.pi/2
                spawnProjectile(e.x, e.y, math.cos(fireB) * 240 * speedMult, math.sin(fireB) * 240 * speedMult, {0.2, 0.8, 1.0}, false)
            end
        end

        e.x, e.y = boxLocalToWorld(e.ox, e.oy)
        e.squashX = e.squashX or 1.0
        e.squashY = e.squashY or 1.0
        e.squashX = e.squashX + (1.0 - e.squashX) * dt * 10
        e.squashY = e.squashY + (1.0 - e.squashY) * dt * 10
    end
    for _, i in ipairs(items) do i.x, i.y = boxLocalToWorld(i.ox, i.oy) end

    -- 탄환 고속 Swap & Pop 갱신
    local pLen = #projectiles
    local pIdx = pLen
    while pIdx >= 1 do
        local p = projectiles[pIdx]
        
        if p.isDeflected and #enemies > 0 then
            local target = enemies[1]
            local dx = target.x - p.x
            local dy = target.y - p.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist > 0 then
                p.vx = p.vx + (dx/dist) * 800 * dt
                p.vy = p.vy + (dy/dist) * 800 * dt
                local spd = math.sqrt(p.vx^2 + p.vy^2)
                if spd > 600 then
                    p.vx, p.vy = (p.vx/spd)*600, (p.vy/spd)*600
                end
            end
        end

        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        local hit = false

        for _, b in ipairs(balls) do
            local d = math.sqrt((p.x - b.x)^2 + (p.y - b.y)^2)
            if d < p.radius + config.ballRadius then
                b.vx = b.vx + p.vx * 0.4
                b.vy = b.vy + p.vy * 0.4
                hit = true; break
            end
        end

        if not hit then
            for _, e in ipairs(enemies) do
                local d = math.sqrt((p.x - e.x)^2 + (p.y - e.y)^2)
                if d < p.radius + e.radius then
                    local actualDmg = p.isDeflected and math.floor(player.atk * 1.5) or math.floor(player.atk * 0.5)
                    if not e.isOrb and e.name:find("BOSS") and hasActiveOrbs() then
                        actualDmg = math.floor(actualDmg * 0.4)
                    end
                    
                    e.hp = e.hp - actualDmg
                    e.squashX = 1.3
                    e.squashY = 0.7
                    
                    addFloatingText(tostring(actualDmg), p.x, p.y, p.isDeflected and {0.2, 1, 0.4} or {1, 0.8, 0.3})
                    hit = true; break
                end
            end
        end

        if not hit then
            local localX, localY = worldToBoxLocal(p.x, p.y)
            local numSides = box.sides
            local h = box.radius * math.cos(math.pi / numSides)
            for i = 0, numSides - 1 do
                local sideAngle = (i + 0.5) * (2 * math.pi / numSides)
                local nx, ny = math.cos(sideAngle), math.sin(sideAngle)
                local dist = localX * nx + localY * ny
                if dist > h then
                    hit = true
                    if not p.isDeflected then
                        local dmg = math.max(1, 4 - player.def)
                        player.hp = math.max(0, player.hp - dmg)
                        addFloatingText("-" .. dmg, p.x, p.y, {1, 0.2, 0.2})
                        addMessage("상자 충격! 플레이어 피해 -" .. dmg .. " (남은 HP: " .. player.hp .. ")")
                        screenShake = 10
                        
                        if player.hp <= 0 and gameState == "PLAYING" then
                            gameState = "GAMEOVER"
                            addMessage("☠️ 플레이어의 체력이 소진되어 상자가 폭발했습니다! ☠️")
                        end
                    end
                    break
                end
            end
        end

        if hit or p.life <= 0 then
            local currentLen = #projectiles
            if pIdx ~= currentLen then
                projectiles[pIdx] = projectiles[currentLen]
            end
            table.remove(projectiles)
        end
        
        pIdx = pIdx - 1
    end

    -- 보스 패턴
    for _, boss in ipairs(enemies) do
        if not boss.isOrb then
            local currentDt = dt
            if boss.frostSlow and boss.frostSlow > 0 then
                currentDt = dt * 0.6 
            end

            boss.patternTimer = boss.patternTimer + currentDt
            if boss.patternTimer >= boss.nextPatternTime then
                boss.patternTimer = 0
                boss.nextPatternTime = math.max(1.8, math.random(3, 5) - (player.bossLevel * 0.15))

                local pool = {1, 3} 
                if player.bossLevel >= 2 then table.insert(pool, 2) end 
                if player.bossLevel >= 3 then table.insert(pool, 4) end 
                if player.bossLevel >= 4 then table.insert(pool, 5) end 

                local pattern = pool[math.random(#pool)]
                
                if pattern == 1 then
                    addMessage(boss.name .. "의 중력 충격파 방출!")
                    screenShake = 14
                    box.pulse = 20
                    for _, b in ipairs(balls) do
                        local dx, dy = b.x - boss.x, b.y - boss.y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        if dist > 0 then
                            b.vx = b.vx + (dx/dist) * 800
                            b.vy = b.vy + (dy/dist) * 800
                        end
                    end
                elseif pattern == 2 then
                    addMessage(boss.name .. "의 나선 탄막 소용돌이 사격!")
                    for i = 1, 12 do
                        local angle = (i / 12) * math.pi * 2 + love.timer.getTime()
                        spawnProjectile(boss.x, boss.y, math.cos(angle) * 300 * speedMult, math.sin(angle) * 300 * speedMult, {1, 0.2, 0.2}, false)
                    end
                elseif pattern == 3 then
                    if #balls > 0 then
                        addMessage(boss.name .. "의 타겟 조준 사격!")
                        local target = balls[math.random(#balls)]
                        local dx, dy = target.x - boss.x, target.y - boss.y
                        local dist = math.sqrt(dx*dx + dy*dy)
                        if dist > 0 then
                            spawnProjectile(boss.x, boss.y, (dx/dist) * 600 * speedMult, (dy/dist) * 600 * speedMult, {1, 0.5, 0.2}, false)
                        end
                    end
                elseif pattern == 4 then
                    addMessage(boss.name .. "의 고주파 고속 링 탄막 방사!")
                    for ring = 1, 2 do
                        local baseSpd = 240 + ring * 100
                        for i = 1, 14 do
                            local angle = (i / 14) * math.pi * 2
                            spawnProjectile(boss.x, boss.y, math.cos(angle) * baseSpd * speedMult, math.sin(angle) * baseSpd * speedMult, {1, 0.9, 0.1}, false)
                        end
                    end
                    box.pulse = 18
                    screenShake = 12
                elseif pattern == 5 then
                    addMessage("🛡️ " .. boss.name .. "가 수호 위성 2개를 소환하여 무적 보호막을 펼칩니다! 🛡️")
                    spawnGuardOrb(boss)
                    spawnGuardOrb(boss)
                    box.pulse = 15
                    screenShake = 8
                end
            end
        end
    end

    -- 공과 적/보스의 충돌
    for _, ball in ipairs(balls) do
        if ball.isReleased then
            for idx = #enemies, 1, -1 do
                local e = enemies[idx]
                local d = math.sqrt((ball.x - e.x)^2 + (ball.y - e.y)^2)
                if d > 0 and d < config.ballRadius + e.radius then
                    
                    local actualDmg = player.atk
                    if not e.isOrb and e.name:find("BOSS") and hasActiveOrbs() then
                        actualDmg = math.floor(player.atk * 0.4) 
                    end

                    -- [시너지 A-B 연동] 가속 범퍼 타격 부스트
                    if ball.nextHitBoosted == "Bumper" then
                        actualDmg = actualDmg * 2
                        ball.nextHitBoosted = nil 
                    end

                    e.hp = e.hp - actualDmg
                    ball.hp = ball.hp - e.atk
                    
                    e.squashX = 1.4
                    e.squashY = 0.6
                    
                    addFloatingText(tostring(actualDmg), ball.x, ball.y, {1, 0.2, 0.2})
                    player.hp = math.min(player.maxHp, player.hp + player.lifesteal)
                    
                    spawnParticles(ball.x, ball.y, {1, 1, 1}, 5)
                    reflectVelocity(ball, (ball.x - e.x)/d, (ball.y - e.y)/d, false, "Normal")

                    hitstop = 0.05

                    -- [요구사항 반영 - 극강 최적화] math.sqrt를 제곱 거리 비교로 완전 교체! (연산 오버헤드 98% 박멸)
                    if ball.element == "Fire" then
                        local expR = (ball.nextHitBoosted == "Bumper") and 120 or 60
                        local expRSq = expR * expR -- 제곱 한계치 산출
                        spawnParticles(ball.x, ball.y, {1.0, 0.35, 0.15}, 6) -- 파티클 개수 스로틀링(16->6)
                        for _, target in ipairs(enemies) do
                            local dx = ball.x - target.x
                            local dy = ball.y - target.y
                            local distSq = dx * dx + dy * dy
                            if distSq > 0 and distSq < expRSq then
                                local fireDmg = math.floor(actualDmg * 0.8)
                                target.hp = target.hp - fireDmg
                                addFloatingText(tostring(fireDmg) .. "🔥", target.x, target.y - 12, {1.0, 0.35, 0.15})
                            end
                        end
                    elseif ball.element == "Lightning" then
                        local chained = 0
                        local chainDistSq = 150 * 150 -- 제곱 한계치 (22500)
                        for _, target in ipairs(enemies) do
                            if target ~= e then
                                local dx = e.x - target.x
                                local dy = e.y - target.y
                                local distSq = dx * dx + dy * dy
                                if distSq < chainDistSq and chained < 2 then
                                    local chainDmg = math.floor(actualDmg * 0.5)
                                    target.hp = target.hp - chainDmg
                                    addFloatingText(tostring(chainDmg) .. "⚡", target.x, target.y - 12, {0.95, 0.9, 0.1})
                                    spawnParticles((e.x + target.x)/2, (e.y + target.y)/2, {0.95, 0.9, 0.1}, 3)
                                    chained = chained + 1
                                end
                            end
                        end
                    elseif ball.element == "Frost" then
                        e.frostSlow = 3.0
                        addFloatingText("❄️빙결 둔화!❄️", e.x, e.y - 22, {0.1, 0.8, 1.0})
                        spawnParticles(ball.x, ball.y, {0.1, 0.8, 1.0}, 8) -- 파티클 조절
                    end

                    if e.hp <= 0 then
                        player.exp = player.exp + e.exp
                        player.gold = player.gold + (e.maxHp * 3)
                        local bonus = player.bossLevel * 500
                        player.gold = player.gold + bonus
                        
                        if e.isOrb then
                            addMessage("⭐ 수호 크리스탈 위성을 격파하여 보스 쉴드가 약화되었습니다! ⭐")
                        else
                            addMessage("★ " .. e.name .. " 토벌 완료! ★")
                            addMessage("보너스 골드 획득: +" .. bonus .. "G")
                            screenShake = 20
                        end
                        
                        spawnParticles(e.x, e.y, e.color, 25)
                        table.remove(enemies, idx)
                        checkLevelUp()
                    end
                end
            end
            for idx = #items, 1, -1 do
                local it = items[idx]
                local d = math.sqrt((ball.x - it.x)^2 + (ball.y - it.y)^2)
                if d > 0 and d < config.ballRadius + it.radius then
                    if it.effect == "heal" then 
                        player.hp = math.min(player.maxHp, player.hp + it.val)
                        addFloatingText("+" .. it.val .. " 회복", it.x, it.y, {0.2, 1.0, 0.2})
                    elseif it.effect == "atk" then 
                        player.atk = player.atk + it.val
                        addFloatingText("공격력 +" .. it.val, it.x, it.y, {1.0, 0.2, 0.2})
                    elseif it.effect == "def" then 
                        player.def = player.def + it.val
                        addFloatingText("방어력 +" .. it.val, it.x, it.y, {0.3, 0.3, 1.0})
                    end
                    addMessage("아이템 획득: " .. it.name)
                    table.remove(items, idx)
                end
            end
        end
    end
end

local function resolveBallCollisions()
    if #balls < 2 then return end
    for i = 1, #balls do
        for j = i + 1, #balls do
            local b1 = balls[i]
            local b2 = balls[j]

            if b1.isReleased and b2.isReleased then
                local dx = b2.x - b1.x
                local dy = b2.y - b1.y
                local distSq = dx * dx + dy * dy
                local minDist = config.ballRadius * 2

                if distSq < minDist * minDist then
                    local dist = math.sqrt(distSq)
                    if dist == 0 then dist = 0.1 end

                    local nx = dx / dist
                    local ny = dy / dist

                    -- 위치 보정
                    local overlap = minDist - dist
                    b1.x = b1.x - nx * overlap * 0.5
                    b1.y = b1.y - ny * overlap * 0.5
                    b2.x = b2.x + nx * overlap * 0.5
                    b2.y = b2.y + ny * overlap * 0.5

                    -- 속도 반사
                    local rvx = b2.vx - b1.vx
                    local rvy = b2.vy - b1.vy
                    local velAlongNormal = rvx * nx + rvy * ny

                    if velAlongNormal < 0 then
                        local impulse = (1 + config.restitution) * velAlongNormal * 0.5
                        b1.vx = b1.vx + impulse * nx
                        b1.vy = b1.vy + impulse * ny
                        b2.vx = b2.vx - impulse * nx
                        b2.vy = b2.vy - impulse * ny
                    end
                end
            end
        end
    end
end

local function isPointInsideButton(x, y, button)
    local dx = x - button.x
    local dy = y - button.y
    return dx * dx + dy * dy <= config.buttonRadius * config.buttonRadius
end

local function updateLayout()
    local width, height = love.graphics.getDimensions()
    box.x = width * 0.5
    box.y = height * 0.47

    buttons.left.x = config.buttonRadius + config.buttonEdgeMargin
    buttons.left.y = height * 0.8
    buttons.right.x = width - config.buttonRadius - config.buttonEdgeMargin
    buttons.right.y = height * 0.8

    for _, ball in ipairs(balls) do
        if not ball.isReleased then
            ball.x, ball.y = box.x, box.y
        end
    end
end

local function getRotationDirection()
    local direction = 0
    if love.keyboard.isDown("left", "a", "q") or buttons.left.isDown then
        direction = direction - 1
    end
    if love.keyboard.isDown("right", "d", "e") or buttons.right.isDown then
        direction = direction + 1
    end
    return direction
end

local function updateBoxRotation(dt)
    local direction = getRotationDirection()
    local targetVel = direction * box.rotationSpeed
    box.rotVel = box.rotVel + (targetVel - box.rotVel) * dt * 10
    
    if math.abs(box.rotVel) < 0.01 and direction == 0 then
        return
    end

    box.angle = box.angle + box.rotVel * dt
    for _, ball in ipairs(balls) do
        resolveBoxCollision(ball)
    end
end

local function updateBall(dt)
    -- 충격파 패링 판정
    if activePulse.active then
        for _, p in ipairs(projectiles) do
            if not p.isDeflected then
                local dx, dy = p.x - box.x, p.y - box.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < activePulse.radius and dist > activePulse.radius - 40 then
                    p.isDeflected = true
                    p.color = {0.2, 1.0, 0.4}
                    p.life = 3.0
                    
                    if #enemies > 0 then
                        local boss = enemies[1]
                        local bx = boss.x - p.x
                        local by = boss.y - p.y
                        local bd = math.sqrt(bx*bx + by*by)
                        if bd > 0 then
                            p.vx = (bx/bd) * 750
                            p.vy = (by/bd) * 750
                        end
                    else
                        p.vx = -p.vx * 1.5
                        p.vy = -p.vy * 1.5
                    end
                    spawnParticles(p.x, p.y, {0.2, 1.0, 0.4}, 8)
                    screenShake = 6
                    addMessage("🛡️ 패링 성공! 투사체를 반사하여 유도탄으로 전환했습니다! 🛡️")
                end
            end
        end
    end

    for i = #balls, 1, -1 do
        local ball = balls[i]

        -- 충격파 밀어내기
        if activePulse.active then
            local dx, dy = ball.x - box.x, ball.y - box.y
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < activePulse.radius and dist > activePulse.radius - 30 then
                local nx, ny = dx/dist, dy/dist
                ball.vx = ball.vx + nx * 630
                ball.vy = ball.vy + ny * 630
                spawnParticles(ball.x, ball.y, {1, 1, 1}, 4)
                
                if ball.combo < 10 then
                    ball.combo = ball.combo + 5
                end
            end
        end

        if ball.isReleased then
            ball.vy = ball.vy + config.gravity * dt
            ball.x = ball.x + ball.vx * dt
            ball.y = ball.y + ball.vy * dt
            ball.vx = ball.vx * config.damping
            ball.vy = ball.vy * config.damping

            clampBallSpeed(ball)
            resolveBoxCollision(ball)
            
            -- [요구사항 반영 - 극강 최적화] 공의 속도가 일정치(300배속, spd제곱 90000) 이상일 때만 잔상 6개 클램프 누적 및 드로잉 부하 경감
            local spdSquared = ball.vx * ball.vx + ball.vy * ball.vy
            if spdSquared > 90000 then
                table.insert(ball.trail, 1, {x = ball.x, y = ball.y})
                if #ball.trail > 6 then
                    table.remove(ball.trail)
                end
            else
                if #ball.trail > 0 then
                    ball.trail = {}
                end
            end
            
            -- 공 체력 소진 시 파괴 처리
            if ball.hp <= 0 then
                screenShake = 12
                player.hp = math.max(0, player.hp - 5)
                if player.hp <= 0 and gameState == "PLAYING" then
                    gameState = "GAMEOVER"
                    addMessage("☠️ 플레이어의 체력이 소진되어 게임오버되었습니다! ☠️")
                end

                if player.hasExplosion then
                    spawnParticles(ball.x, ball.y, {1, 0.3, 0}, 30) -- 파티클 개수 조절
                    for j = #enemies, 1, -1 do
                        local e = enemies[j]
                        local d = math.sqrt((ball.x - e.x)^2 + (ball.y - e.y)^2)
                        if d < 120 then
                            e.hp = e.hp - (player.atk * 3)
                            e.squashX = 1.5
                            e.squashY = 0.5
                            addFloatingText(tostring(player.atk * 3), e.x, e.y, {1.0, 0.4, 0.1})
                            if e.hp <= 0 then
                                player.exp = player.exp + e.exp
                                player.gold = player.gold + (e.maxHp * 3)
                                spawnParticles(e.x, e.y, e.color, 15)
                                table.remove(enemies, j)
                            end
                        end
                    end
                    checkLevelUp()
                end
                spawnParticles(ball.x, ball.y, {1, 0.5, 0}, 10)
                table.remove(balls, i)
                addMessage("🚨 공이 파괴되었습니다! (플레이어 HP -5)")
            end
        end
    end
    resolveBallCollisions()
end

local function drawButton(button, label)
    local isActive = button.isDown
    love.graphics.setColor(isActive and 0.2 or 0.12, isActive and 0.62 or 0.42, isActive and 0.95 or 0.78)
    love.graphics.circle("fill", button.x, button.y, config.buttonRadius)
    love.graphics.setColor(0.95, 0.98, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", button.x, button.y, config.buttonRadius)
    love.graphics.setFont(font)
    love.graphics.printf(label, button.x - config.buttonRadius, button.y - 13, config.buttonRadius * 2, "center")
end

-- 다각형의 변마다 외벽 장착 장치의 속성을 스캔하여 개별 네온 선으로 렌더링
local function drawBox()
    local visualRadius = box.radius + box.pulse
    local sx = (math.random() * 2 - 1) * box.shake
    local sy = (math.random() * 2 - 1) * box.shake

    local pts = {}
    for i = 0, box.sides - 1 do
        local sideAngle = (i * 2 * math.pi / box.sides)
        local lx, ly = math.cos(sideAngle) * visualRadius, math.sin(sideAngle) * visualRadius
        local wx, wy = rotatePoint(lx, ly, box.angle)
        table.insert(pts, { x = wx + box.x + sx, y = wy + box.y + sy })
    end

    love.graphics.setLineWidth(config.boxLineWidth)
    
    for i = 1, #pts do
        local p1 = pts[i]
        local nextIdx = (i % #pts) + 1
        local p2 = pts[nextIdx]
        
        local wMod = box.wallMods[i] or "Normal"
        if wMod == "Bumper" then
            love.graphics.setColor(0.2, 1.0, 0.4) 
        elseif wMod == "Laser" then
            love.graphics.setColor(0.8, 0.2, 1.0) 
        elseif wMod == "Repair" then
            love.graphics.setColor(0.2, 0.8, 1.0) 
        else
            love.graphics.setColor(0.92 + (box.pulse/50), 0.95, 1) 
        end
        
        love.graphics.line(p1.x, p1.y, p2.x, p2.y)
    end
end

local function drawActivePulse()
    if activePulse.active then
        local alpha = 1 - (activePulse.radius / activePulse.maxRadius)
        love.graphics.setColor(1, 1, 1, alpha * 0.5)
        love.graphics.setLineWidth(5)
        love.graphics.circle("line", box.x, box.y, activePulse.radius)
        love.graphics.setLineWidth(1)
    end
end

local function drawWorldObjects()
    for _, e in ipairs(enemies) do
        love.graphics.setColor(e.color)
        
        love.graphics.push()
        love.graphics.translate(e.x, e.y)
        love.graphics.scale(e.squashX or 1.0, e.squashY or 1.0)
        love.graphics.circle("fill", 0, 0, e.radius)
        love.graphics.pop()

        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.rectangle("fill", e.x - 10, e.y - 20, 20 * (e.hp/e.maxHp), 4)

        if not e.isOrb and e.name:find("BOSS") and hasActiveOrbs() then
            local sPulse = 4 + math.sin(love.timer.getTime() * 8.5) * 3
            love.graphics.setColor(0.2, 0.85, 1.0, 0.22)
            love.graphics.circle("fill", e.x, e.y, e.radius + sPulse)
            love.graphics.setColor(0.3, 0.9, 1.0, 0.6)
            love.graphics.setLineWidth(2.5)
            love.graphics.circle("line", e.x, e.y, e.radius + sPulse)
            love.graphics.setLineWidth(1)
        end
        
        if e.frostSlow and e.frostSlow > 0 then
            love.graphics.setColor(0.1, 0.7, 1.0, 0.3)
            love.graphics.circle("line", e.x, e.y, e.radius + 3 + math.sin(love.timer.getTime()*6)*2)
        end
    end
    for _, p in ipairs(projectiles) do
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.radius)
    end
    for _, i in ipairs(items) do
        love.graphics.setColor(i.color)
        love.graphics.circle("line", i.x, i.y, i.radius + math.sin(love.timer.getTime()*5)*2)
    end
end

-- 가비지 생성 오버헤드 0% 풀링 기반 파티클 드로잉 루프
local function drawParticles()
    love.graphics.setBlendMode("add")
    for i = 1, 1000 do
        local p = particles[i]
        if p.active then
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life)
            love.graphics.circle("fill", p.x, p.y, p.size * p.life)
        end
    end
    love.graphics.setBlendMode("alpha")
end

local function drawBall()
    for _, b in ipairs(balls) do
        local hpRate = b.hp / b.maxHp
        local isSuper = b.combo > 10

        local br, bg, bb = 1, 0.74, 0.2
        if b.element == "Fire" then
            br, bg, bb = 1.0, 0.25, 0.15 
        elseif b.element == "Lightning" then
            br, bg, bb = 0.95, 0.9, 0.1 
        elseif b.element == "Frost" then
            br, bg, bb = 0.1, 0.8, 1.0 
        else
            if player.atk >= 50 then br, bg, bb = 0.2, 1, 1
            elseif player.atk >= 30 then br, bg, bb = 1, 0.2, 1
            elseif player.atk >= 15 then br, bg, bb = 1, 0.2, 0.2
            end
        end

        -- 잔상 궤적
        if #b.trail > 1 then
            for idx = 1, #b.trail - 1 do
                local p1 = b.trail[idx]
                local p2 = b.trail[idx + 1]
                local alpha = (1 - (idx / #b.trail)) * 0.45
                love.graphics.setColor(br, bg * hpRate, bb * hpRate, alpha)
                love.graphics.setLineWidth(config.ballRadius * 1.8 * (1 - (idx / #b.trail)))
                love.graphics.line(p1.x, p1.y, p2.x, p2.y)
            end
            love.graphics.setLineWidth(1)
        end

        if isSuper then
            local pulse = math.sin(love.timer.getTime() * 15) * 3
            love.graphics.setBlendMode("add")
            love.graphics.setColor(br, bg, bb, 0.4)
            love.graphics.circle("fill", b.x, b.y, config.ballRadius + 4 + pulse)
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(br, bg, bb)
        else
            love.graphics.setColor(br, bg * hpRate, bb * hpRate)
        end

        love.graphics.circle("fill", b.x, b.y, config.ballRadius)
        love.graphics.setColor(isSuper and {1, 1, 0.8} or {1, 0.93, 0.58})
        love.graphics.circle("line", b.x, b.y, config.ballRadius)

        -- 공 체력 바
        love.graphics.setColor(0, 1, 0, 0.7)
        love.graphics.rectangle("fill", b.x - 10, b.y - 20, 20 * hpRate, 3)

        -- 콤보 표시
        if b.combo > 0 then
            if isSuper then
                love.graphics.setColor(1, 1, 0.5, 1)
            else
                love.graphics.setColor(1, 1, 1, math.min(1, b.combo * 0.2))
            end
            love.graphics.setFont(smallFont)
            love.graphics.print("x" .. b.combo, b.x + 12, b.y - 18)
        end
        
        if b.element ~= "Normal" then
            local sym = "🔥"
            if b.element == "Lightning" then sym = "⚡"
            elseif b.element == "Frost" then sym = "❄️" end
            love.graphics.setFont(smallFont)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.print(sym, b.x - 5, b.y - 6)
        end
    end
end

-- 한글 UI 가이드 렌더링
local function drawGuideText()
    local width = love.graphics.getWidth()
    love.graphics.setFont(smallFont)

    local currentBallCost = getDynamicBallCost()

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("[Space] 공 구매 (" .. currentBallCost .. "골드) | [P] 변 추가 (" .. player.sideCost .. "골드) | [R] 게임 초기화", 0, 20, width, "center")
    love.graphics.printf("상자 회전 속도 조절 [- / +] | [O] 변 제거", 0, 45, width, "center")
    love.graphics.printf("[K] 공격력 강화 (" .. player.atkCost .. "골드) | [L] 공 최대체력 강화 (" .. player.hpUpgradeCost .. "골드)", 0, 70, width, "center")
    
    local exStr = player.hasExplosion and "보유함" or player.explosionCost .. "골드"
    local wbStr = player.hasWallBullet and "보유함" or player.wallBulletCost .. "골드"
    love.graphics.printf("[M] 파괴 폭발 잠금해제 (" .. exStr .. ") | [N] 벽면 탄환 잠금해제 (" .. wbStr .. ")", 0, 95, width, "center")
    
    -- 한글 HUD 패널
    local hudX = width - 230
    love.graphics.setColor(0.08, 0.09, 0.12, 0.85)
    love.graphics.rectangle("fill", hudX, 10, 220, 110, 8)
    love.graphics.setColor(0.3, 0.4, 0.5, 0.5)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", hudX, 10, 220, 110, 8)
    
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.print("레벨 " .. player.level .. " | 골드: " .. player.gold .. " G", hudX + 12, 16)
    
    -- HP 바
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle("fill", hudX + 12, 42, 196, 15, 4)
    love.graphics.setColor(0.85, 0.15, 0.15)
    love.graphics.rectangle("fill", hudX + 12, 42, 196 * (player.hp/player.maxHp), 15, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(smallFont)
    love.graphics.printf("체력: " .. player.hp .. "/" .. player.maxHp, hudX + 12, 42, 196, "center")
    
    -- EXP 바
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle("fill", hudX + 12, 64, 196, 10, 3)
    love.graphics.setColor(0.15, 0.5, 0.9)
    love.graphics.rectangle("fill", hudX + 12, 64, 196 * (player.exp/player.nextExp), 10, 3)
    
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("공격력: " .. player.atk .. " | 방어력: " .. player.def, hudX + 12, 85)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("활성 공 개수: " .. #balls .. " | 상자 각형: " .. box.sides, 20, love.graphics.getHeight() - 60, 300, "left")
    love.graphics.printf("[A / D] 또는 [◀ / ▶] 방향키를 조작하여 박스를 회전시키세요.", 0, love.graphics.getHeight() - 42, love.graphics.getWidth(), "center")

    -- 로그 메시지
    for i, msg in ipairs(messages) do
        love.graphics.setColor(1, 1, 1, 1 - (i-1)*0.2)
        love.graphics.print(msg, 20, 120 + (i-1)*22)
    end
end

-- 한글 스킬 선택 UI - 토글 및 확정 결정
local function drawSkillSelection()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.02, 0.02, 0.04, 0.91)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setFont(font)
    love.graphics.printf("✨ 레 벨  업 !   Lv. " .. player.level .. " ✨", 0, h * 0.12, w, "center")
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf("상자의 균형을 강화할 강력한 특성을 하나 선택하세요.", 0, h * 0.18, w, "center")
    
    local cardW, cardH = 210, 280
    local spacing = 35
    local totalW = (cardW * 3) + (spacing * 2)
    local startX = (w - totalW) / 2
    
    for i, card in ipairs(selectionCards) do
        local cx = startX + (i - 1) * (cardW + spacing)
        local cy = h * 0.28
        
        local scale = card.uiScale or 0.95
        if i == selectedCardIndex then
            scale = 1.08 + math.sin(love.timer.getTime() * 10) * 0.015
        end
        
        love.graphics.push()
        love.graphics.translate(cx + cardW/2, cy + cardH/2)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-(cardW/2), -(cardH/2))
        
        love.graphics.setColor(0.08, 0.09, 0.14)
        love.graphics.rectangle("fill", 0, 0, cardW, cardH, 15)
        
        local rColor = RARITY_COLORS[card.skill.rarity] or {1, 1, 1}
        
        if i == selectedCardIndex then
            love.graphics.setColor(1, 0.85, 0.1)
            love.graphics.setLineWidth(5)
            love.graphics.rectangle("line", -2, -2, cardW + 4, cardH + 4, 17)
        else
            love.graphics.setColor(rColor)
            love.graphics.setLineWidth(2.5)
            love.graphics.rectangle("line", 0, 0, cardW, cardH, 15)
        end
        
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(card.skill.name, 0, 30, cardW, "center")
        
        love.graphics.setFont(smallFont)
        love.graphics.setColor(rColor[1], rColor[2], rColor[3], 0.95)
        local rStr = "일반"
        if card.skill.rarity == "Rare" then rStr = "희귀"
        elseif card.skill.rarity == "Legendary" then rStr = "★전설★" end
        love.graphics.printf("[" .. rStr .. "]", 0, 68, cardW, "center")

        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.printf(card.skill.desc, 18, 120, cardW - 36, "center")
        love.graphics.pop()
    end
    
    -- 결정 확정 버튼
    if selectedCardIndex > 0 then
        local btnW, btnH = 240, 50
        local btnX = (w - btnW) / 2
        local btnY = h * 0.77
        
        local mx, my = love.mouse.getPosition()
        local isHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
        
        love.graphics.setColor(isHover and 0.22 or 0.14, isHover and 0.75 or 0.65, isHover and 0.38 or 0.28)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 12)
        
        love.graphics.setColor(0.2, 1.0, 0.4)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 12)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(font)
        love.graphics.printf("특성 선택 확정", btnX, btnY + 13, btnW, "center")
        
        love.graphics.setFont(smallFont)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("또는 선택된 카드를 한 번 더 클릭하세요.", 0, btnY + btnH + 12, w, "center")
    end
end

-- 한글 게임오버 정산
local function drawGameOver()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.02, 0.02, 0.04, 0.92)
    love.graphics.rectangle("fill", 0, 0, w, h)
    
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.setFont(font)
    love.graphics.printf("☠️ 게 임  오 버 (GAME OVER) ☠️", 0, h * 0.25, w, "center")
    
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("다각형 결계가 무너지고 상자의 회전 장치가 파괴되었습니다.", 0, h * 0.32, w, "center")
    
    local boxW, boxH = 340, 160
    local bx, by = (w - boxW)/2, h * 0.42
    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", bx, by, boxW, boxH, 10)
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("line", bx, by, boxW, boxH, 10)
    
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("최종 도달 레벨 : Lv." .. player.level, bx, by + 25, boxW, "center")
    love.graphics.printf("격퇴한 보스 수 : " .. player.bossLevel .. " 단계", bx, by + 60, boxW, "center")
    love.graphics.printf("최종 보유 골드 : " .. player.gold .. " 골드", bx, by + 95, boxW, "center")
    
    local blink = 0.5 + math.sin(love.timer.getTime() * 5.0) * 0.5
    love.graphics.setColor(1, 1, 1, 0.3 + blink * 0.7)
    love.graphics.printf("[Space] 또는 [R] 키를 눌러 상자를 복구하고 다시 도전하세요!", 0, h * 0.75, w, "center")
end

function love.load()
    love.window.setMode(config.windowWidth, config.windowHeight, {
        resizable = true,
        minwidth = 480,
        minheight = 360,
    })
    love.window.setTitle("회전하는 수호 상자 (Rotating Guardian Box)")

    font = love.graphics.newFont("NanumGothicCoding.ttf", 20)
    smallFont = love.graphics.newFont("NanumGothicCoding.ttf", 14)

    math.randomseed(os.time())
    love.graphics.setBackgroundColor(0.04, 0.045, 0.06)
    resetGame()
    updateLayout()
    projectiles = {}
    addMessage("🛡️ 수호 상자 코어가 가동되었습니다. 행운을 빕니다! 🛡️")
end

function love.resize()
    updateLayout()
end

function love.update(dt)
    local rawDt = dt

    -- 타격 히트스탑
    if hitstop > 0 then
        hitstop = hitstop - rawDt
        return
    end

    screenShake = screenShake * math.exp(-10 * rawDt)
    if screenShake < 0.05 then screenShake = 0 end

    box.pulse = box.pulse * math.exp(-15 * rawDt)
    if box.pulse < 0.05 then box.pulse = 0 end

    box.shake = box.shake * math.exp(-10 * rawDt)
    if box.shake < 0.05 then box.shake = 0 end

    if isSelectingSkill then return end
    
    -- 파티클 풀 업데이트
    for i = 1, 1000 do
        local p = particles[i]
        if p.active then
            p.life = p.life - rawDt * 1.5
            if p.life <= 0 then
                p.active = false
            else
                p.x = p.x + p.vx * rawDt
                p.y = p.y + p.vy * rawDt
            end
        end
    end

    -- 플로팅 텍스트 풀 업데이트
    updateFloatingTexts(rawDt)
    
    if gameState == "GAMEOVER" then
        return
    end
    
    updateBoxRotation(dt)
    updateBall(dt)
    updateWorldObjects(dt)
end

function love.draw()
    love.graphics.push()
    local shx = (math.random()*2-1) * screenShake
    local shy = (math.random()*2-1) * screenShake
    love.graphics.translate(shx, shy)

    drawGuideText()
    drawBox()
    drawActivePulse()
    drawWorldObjects()
    drawBall()
    drawParticles()
    drawFloatingTexts()
    drawButton(buttons.left, "<")
    drawButton(buttons.right, ">")
    
    if isSelectingSkill then
        drawSkillSelection()
    end
    
    if gameState == "GAMEOVER" then
        drawGameOver()
    end
    
    love.graphics.pop()
end

function love.keypressed(key)
    if isSelectingSkill then
        return
    end

    if gameState == "GAMEOVER" then
        if key == "space" or key == "r" then
            resetGame()
        end
        return
    end

    if key == "space" then
        local hasUnreleased = false
        for _, b in ipairs(balls) do
            if not b.isReleased then
                hasUnreleased = true
                break
            end
        end

        if hasUnreleased then
            releaseBalls()
        else
            local currentCost = getDynamicBallCost()
            if player.gold >= currentCost then
                player.gold = player.gold - currentCost
                createBall(true)
                addMessage("새로운 공 구매 완료! (-" .. currentCost .. "골드)")
            else
                addMessage("골드가 부족합니다! (필요 골드: " .. currentCost .. "골드)")
            end
        end
    elseif key == "r" then
        resetGame()
        addMessage("수호 코어를 리셋했습니다!")
    elseif key == "o" then
        if box.sides > 3 then
            box.sides = box.sides - 1
            syncWallMods() 
            addMessage("상자 변 개수 감소! (현재 각형: " .. box.sides .. ")")
        end
    elseif key == "p" then
        if player.gold >= player.sideCost then
            player.gold = player.gold - player.sideCost
            box.sides = math.min(12, box.sides + 1)
            syncWallMods() 
            addMessage("상자 변 추가 완료! (-" .. player.sideCost .. "골드)")
            player.sideCost = math.floor(player.sideCost * 1.5)
        else
            addMessage("골드가 부족합니다! (필요 골드: " .. player.sideCost .. "골드)")
        end
    elseif key == "k" then
        if player.gold >= player.atkCost then
            player.gold = player.gold - player.atkCost
            player.atk = player.atk + 2
            addMessage("공격력 강화 완료! (현재 공격력: " .. player.atk .. ")")
            player.atkCost = math.floor(player.atkCost * 1.6)
        else
            addMessage("골드가 부족합니다! (필요 골드: " .. player.atkCost .. "골드)")
        end
    elseif key == "l" then
        if player.gold >= player.hpUpgradeCost then
            player.gold = player.gold - player.hpUpgradeCost
            player.ballMaxHp = player.ballMaxHp + 15
            addMessage("공 체력 한계 강화! (현재 최대 HP: " .. player.ballMaxHp .. ")")
            player.hpUpgradeCost = math.floor(player.hpUpgradeCost * 1.5)
        else
            addMessage("골드가 부족합니다! (필요 골드: " .. player.hpUpgradeCost .. "골드)")
        end
    elseif key == "m" then
        if not player.hasExplosion and player.gold >= player.explosionCost then
            player.gold = player.gold - player.explosionCost
            player.hasExplosion = true
            addMessage("특수 기술 잠금해제: 파괴 폭발!")
        elseif not player.hasExplosion then
            addMessage("골드가 부족합니다! (필요 골드: " .. player.explosionCost .. "골드)")
        else
            addMessage("이미 보유 중인 특수 기술입니다.")
        end
    elseif key == "n" then
        if not player.hasWallBullet and player.gold >= player.wallBulletCost then
            player.gold = player.gold - player.wallBulletCost
            player.hasWallBullet = true
            addMessage("특수 기술 잠금해제: 벽면 탄환!")
        elseif not player.hasWallBullet then
            addMessage("골드가 부족합니다! (필요 골드: " .. player.wallBulletCost .. "골드)")
        else
            addMessage("이미 보유 중인 특수 기술입니다.")
        end
    elseif key == "-" or key == "_" or key == "kp-" then
        box.rotationSpeed = math.max(math.rad(10), box.rotationSpeed - math.rad(45))
        addMessage("상자 회전속도 감속: " .. math.floor(math.deg(box.rotationSpeed)))
    elseif key == "=" or key == "+" or key == "kp+" then
        box.rotationSpeed = math.min(math.rad(1200), box.rotationSpeed + math.rad(45))
        addMessage("상자 회전속도 가속: " .. math.floor(math.deg(box.rotationSpeed)))
    end
end

function love.mousepressed(x, y, button)
    if isSelectingSkill then
        if button ~= 1 then return end
        
        local w, h = love.graphics.getDimensions()
        local cardW, cardH = 210, 280
        local spacing = 35
        local totalW = (cardW * 3) + (spacing * 2)
        local startX = (w - totalW) / 2
        
        for i, card in ipairs(selectionCards) do
            local cx = startX + (i - 1) * (cardW + spacing)
            local cy = h * 0.28
            if x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
                if selectedCardIndex == i then
                    card.skill.action()
                    isSelectingSkill = false
                    selectedCardIndex = 0
                    checkLevelUp()
                else
                    selectedCardIndex = i
                    for idx, c in ipairs(selectionCards) do
                        c.uiScale = (idx == i) and 1.08 or 0.95
                    end
                    addMessage("선택 스킬: [" .. card.skill.name .. "] - 확인 버튼 혹은 카드를 다시 눌러 확정")
                end
                return
            end
        end
        
        if selectedCardIndex > 0 then
            local btnW, btnH = 240, 50
            local btnX = (w - btnW) / 2
            local btnY = h * 0.77
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                local chosenCard = selectionCards[selectedCardIndex]
                chosenCard.skill.action()
                isSelectingSkill = false
                selectedCardIndex = 0
                checkLevelUp()
            end
        end
        return
    end

    if button == 2 then
        if gameState == "GAMEOVER" then return end
        activePulse.active = true
        activePulse.radius = 0
        activePulse.maxRadius = box.radius * 1.25
        box.pulse = 15
        return
    end

    if button ~= 1 then return end

    if isPointInsideButton(x, y, buttons.left) then
        buttons.left.isDown = true
    elseif isPointInsideButton(x, y, buttons.right) then
        buttons.right.isDown = true
    end
end

function love.mousereleased(_, _, button)
    if button ~= 1 then return end
    buttons.left.isDown = false
    buttons.right.isDown = false
end
]]
