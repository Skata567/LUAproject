local Party = {}
local ctx = {}

function Party.init(context)
    ctx = context
end

-- 동료 고용 (머서너리 상점에서 호출)
function Party.recruit(companionData)
    if not ctx.party then ctx.party = {} end
    if #ctx.party >= 3 then
        return false, "파티가 꽉 찼습니다 (최대 3명)."
    end

    local comp = {
        id = "comp_" .. tostring(math.random(10000, 99999)),
        name = companionData.name,
        raceId = companionData.race.id,
        classId = companionData.class.id,
        raceName = companionData.race.name,
        className = companionData.class.name,
        char = "P",
        level = companionData.level,
        exp = 0,
        nextExp = 20 * (1.5 ^ (companionData.level - 1)),
        str = companionData.race.stats.str + companionData.class.stats.str,
        dex = companionData.race.stats.dex + companionData.class.stats.dex,
        int = companionData.race.stats.int + companionData.class.stats.int,
        con = companionData.race.stats.con + companionData.class.stats.con,
        lck = companionData.race.stats.lck + companionData.class.stats.lck,
        baseAtk = 3 + companionData.level,
        baseDef = 0,
        skills = {},
        unlockedSkills = {},
        buffs = {},
        alive = true
    }
    
    -- 기본 체력 및 마나 연산 (combat 시스템이 묶어주거나, 자체 연산)
    comp.maxHp = 30 + (comp.level - 1) * 5 + comp.con * 3 + (companionData.race.hpBonus or 0)
    comp.hp = comp.maxHp
    comp.maxMana = 12 + comp.level * 2 + comp.int * 5 + math.floor(comp.lck / 2)
    comp.mana = comp.maxMana

    -- 고유 인벤토리 및 장비 세팅
    comp.inv = ctx.Inventory.new(5, 5)
    comp.equip = ctx.Equipment.new()

    -- 무기 시작 장비 지급 (직업 기본 무기)
    if companionData.class.startWeapon then
        local w = ctx.Item.create(companionData.class.startWeapon)
        comp.equip:equip(w)
    end

    table.insert(ctx.party, comp)
    return true, comp.name .. " 님이 파티에 합류했습니다!"
end

function Party.removeDead()
    if not ctx.party then return end
    for i = #ctx.party, 1, -1 do
        local comp = ctx.party[i]
        if comp.hp <= 0 then
            comp.alive = false
            ctx.addMessage(comp.name .. " 님이 전사했습니다...", {1, 0, 0})
            -- 장착 중인 아이템과 인벤토리를 바닥에 떨어뜨릴 수도 있음 (추후 구현)
            table.remove(ctx.party, i)
        end
    end
end

function Party.distributeExp(totalExp)
    if not ctx.party then return totalExp end
    local count = 1 + #ctx.party
    local splitExp = math.floor(totalExp / count)
    
    -- 동료 경험치 분배
    for _, comp in ipairs(ctx.party) do
        comp.exp = comp.exp + splitExp
        -- 레벨업 체크
        while comp.exp >= comp.nextExp do
            comp.exp = comp.exp - comp.nextExp
            comp.level = comp.level + 1
            comp.baseAtk = comp.baseAtk + 1
            comp.str = comp.str + 1
            comp.con = comp.con + 1
            comp.nextExp = math.floor(comp.nextExp * 1.5)
            comp.maxHp = 30 + (comp.level - 1) * 5 + comp.con * 3
            comp.hp = comp.maxHp
            ctx.addMessage("동료 " .. comp.name .. " 레벨 업! (Lv." .. comp.level .. ")", {1, 1, 0})
        end
    end

    return splitExp -- 플레이어 몫 반환
end

-- 동료 턴 행동 (AI)
function Party.takeTurns()
    if not ctx.party then return end
    for _, comp in ipairs(ctx.party) do
        if comp.alive and comp.hp > 0 then
            -- 1. 가장 가까운 적 탐색 (플레이어가 친 적을 우선)
            local target = nil
            local minDist = 9999
            
            -- 플레이어가 마지막으로 때린 적이 주변에 있으면 최우선 타겟
            if ctx.lastAttackedEnemy and ctx.lastAttackedEnemy.alive then
                local dist = math.abs(comp.x - ctx.lastAttackedEnemy.x) + math.abs(comp.y - ctx.lastAttackedEnemy.y)
                if dist <= 3 then -- 너무 멀면 무시
                    target = ctx.lastAttackedEnemy
                    minDist = dist
                end
            end

            -- 그 외 주변 3칸 이내 가장 가까운 적 탐색
            if not target then
                for _, enemy in ipairs(ctx.enemies) do
                    if enemy.alive then
                        local dist = math.abs(comp.x - enemy.x) + math.abs(comp.y - enemy.y)
                        if dist <= 3 and dist < minDist then
                            minDist = dist
                            target = enemy
                        end
                    end
                end
            end

            -- 공격 행동
            if target and minDist <= 1 then
                -- 근접 공격 로직 (Combat 시스템을 호출하거나 자체 계산)
                if ctx.dealCompanionAttack then
                    ctx.dealCompanionAttack(comp, target)
                else
                    -- 임시 연산
                    local dmg = math.max(1, comp.baseAtk - (target.def or 0))
                    target.hp = target.hp - dmg
                    ctx.addMessage(comp.name .. "의 공격! " .. target.name .. "에게 " .. dmg .. " 데미지!")
                    if target.hp <= 0 then
                        target.alive = false
                        local splitExp = Party.distributeExp(target.exp)
                        ctx.player.exp = ctx.player.exp + splitExp
                        ctx.addMessage(target.name .. " 처치! (+" .. splitExp .. " 경험치)")
                        if ctx.checkLevelUp then ctx.checkLevelUp() end
                    end
                end
            else
                -- 2. 플레이어 따라가기 이동 AI
                if comp.x and comp.y and ctx.player.x and ctx.player.y then
                    local distToPlayer = math.abs(comp.x - ctx.player.x) + math.abs(comp.y - ctx.player.y)
                    if distToPlayer > 1 then
                        local dx, dy = 0, 0
                        if comp.x < ctx.player.x then dx = 1 elseif comp.x > ctx.player.x then dx = -1 end
                        if comp.y < ctx.player.y then dy = 1 elseif comp.y > ctx.player.y then dy = -1 end

                        -- 한 축씩 이동 시도 (대각선 방지 및 장애물 회피)
                        local nx, ny = comp.x + dx, comp.y
                        if dx ~= 0 and ctx.map[ny] and ctx.map[ny][nx] ~= ctx.TILE_WALL and not Party.isOccupied(nx, ny) then
                            comp.x = nx
                            comp.y = ny
                        else
                            nx, ny = comp.x, comp.y + dy
                            if dy ~= 0 and ctx.map[ny] and ctx.map[ny][nx] ~= ctx.TILE_WALL and not Party.isOccupied(nx, ny) then
                                comp.x = nx
                                comp.y = ny
                            end
                        end
                    end
                end
            end
        end
    end
end

-- 타일 충돌 방지 체크 (동료들끼리, 혹은 몬스터와 겹치지 않게)
function Party.isOccupied(x, y)
    if ctx.player.x == x and ctx.player.y == y then return true end
    for _, e in ipairs(ctx.enemies) do
        if e.alive and e.x == x and e.y == y then return true end
    end
    for _, c in ipairs(ctx.party) do
        if c.alive and c.x == x and c.y == y then return true end
    end
    return false
end

return Party
