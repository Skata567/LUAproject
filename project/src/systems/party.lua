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
        str = companionData.race.stats.str + companionData.class.statBonus.str,
        dex = companionData.race.stats.dex + companionData.class.statBonus.dex,
        int = companionData.race.stats.int + companionData.class.statBonus.int,
        con = companionData.race.stats.con + companionData.class.statBonus.con,
        lck = companionData.race.stats.lck + companionData.class.statBonus.lck,
        baseAtk = 3 + companionData.level,
        baseDef = 0,
        skills = {},
        unlockedSkills = {},
        buffs = {},
        alive = true,
        x = ctx.player and ctx.player.x or 1,
        y = ctx.player and ctx.player.y or 1
    }
    
    -- 기본 체력 및 마나 연산 (combat 시스템이 묶어주거나, 자체 연산)
    comp.maxHp = 30 + (comp.level - 1) * 5 + comp.con * 3 + (companionData.race.hpBonus or 0)
    comp.hp = comp.maxHp
    comp.maxMana = 12 + comp.level * 2 + comp.int * 5 + math.floor(comp.lck / 2)
    comp.mana = comp.maxMana

    -- 고유 인벤토리 및 장비 세팅
    comp.inv = ctx.Inventory.new(5, 6)
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

local AI = require("systems.ai")

-- 동료 턴 행동 (AI)
function Party.takeTurns()
    if not ctx.party then return end
    
    local MAP_WIDTH = ctx.map and #ctx.map[1] or 100
    local MAP_HEIGHT = ctx.map and #ctx.map or 100
    
    for _, comp in ipairs(ctx.party) do
        if comp.alive then
            -- 기존 세이브나 에러로 인해 좌표가 없을 경우 복구
            if not comp.x or not comp.y then
                comp.x = ctx.player and ctx.player.x or 1
                comp.y = ctx.player and ctx.player.y or 1
            end

            -- 1. 가장 가까운 적 탐색 (플레이어가 친 적을 우선)
            local target = nil
            local minDist = 9999
            
            -- 플레이어가 마지막으로 때린 적이 주변에 있으면 최우선 타겟
            if ctx.lastAttackedEnemy and ctx.lastAttackedEnemy.alive then
                local dist = math.abs(comp.x - ctx.lastAttackedEnemy.x) + math.abs(comp.y - ctx.lastAttackedEnemy.y)
                if dist <= 5 then -- 5칸 이내면 최우선 타겟
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
                if ctx.dealCompanionAttack then
                    ctx.dealCompanionAttack(comp, target)
                end
            else
                -- 2. 이동 AI (타겟이 있으면 타겟으로, 아이템이 있으면 아이템으로, 없으면 플레이어 따라가기)
                local tx, ty = ctx.player.x, ctx.player.y
                local stopDist = 1 -- 플레이어를 따라갈 때는 1칸 거리를 둔다 (길막 방지)
                
                if target then
                    tx, ty = target.x, target.y
                    stopDist = 0 -- 적을 공격할 때는 딱 붙어야 함
                else
                    -- 적이 없으면 주변 아이템 탐색
                    local targetItem = nil
                    local minItemDist = 9999
                    if ctx.getGroundItems then
                        local items = ctx.getGroundItems()
                        for _, gi in ipairs(items) do
                            if not gi.picked then
                                local dist = math.abs(comp.x - gi.x) + math.abs(comp.y - gi.y)
                                if dist <= 3 and dist < minItemDist then
                                    minItemDist = dist
                                    targetItem = gi
                                end
                            end
                        end
                    end
                    
                    if targetItem then
                        tx, ty = targetItem.x, targetItem.y
                        stopDist = 0 -- 아이템을 먹으려면 딱 붙어야 함
                    end
                end
                
                if comp.x and comp.y and tx and ty then
                    local distToDest = math.abs(comp.x - tx) + math.abs(comp.y - ty)
                    if distToDest > stopDist then
                        local ax, ay = AI.findPathAStar(comp.x, comp.y, tx, ty, ctx.map, MAP_WIDTH, MAP_HEIGHT, ctx.enemies, ctx.party)
                        if ax and ay then
                            -- 최종적으로 가려는 칸이 occupied 되지 않았는지 (동료가 이미 있는지) 확인
                            if not Party.isOccupied(ax, ay) then
                                comp.x = ax
                                comp.y = ay
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
