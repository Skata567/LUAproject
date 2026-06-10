local M = {}

M.activeQuests = {}

-- 퀘스트 종류 정의
-- rewardItems: 보상으로 줄 아이템 ID의 배열
M.QUEST_TYPES = {
    -- 몬스터 처치 퀘스트
    { type = "kill", target = "슬라임", name = "슬라임 토벌", desc = "슬라임을 5마리 처치하세요.", count = 5, exp = 20, gold = 50 },
    { type = "kill", target = "스켈레톤", name = "해골 정화", desc = "스켈레톤을 5마리 처치하세요.", count = 5, exp = 30, gold = 80 },
    { type = "kill", target = "고블린", name = "고블린 사냥", desc = "고블린을 3마리 처치하세요.", count = 3, exp = 25, gold = 60 },
    
    -- 층수 도달 퀘스트
    { type = "reach", target = 3, name = "지하 3층 정찰", desc = "던전 3층에 도달하세요.", count = 1, exp = 50, gold = 100 },
    
    -- 특수 보상 퀘스트 (열쇠, 주문서 지급)
    { type = "reach", target = 5, name = "지하 5층 탐사", desc = "던전 5층에 도달하세요.", count = 1, exp = 100, gold = 200, rewardItems = {"dungeon_key"} },
    { type = "kill", target = "고블린 왕", name = "고블린 왕 토벌", desc = "고블린 왕을 처치하세요.", count = 1, exp = 150, gold = 300, rewardItems = {"secret_scroll"} },
}

function M.init(ctx)
    M.ctx = ctx
end

-- 던전 시작 시 새로운 퀘스트 발급
function M.generateQuests()
    M.activeQuests = {}
    local numQuests = math.random(2, 3)
    local available = {}
    for i, q in ipairs(M.QUEST_TYPES) do table.insert(available, q) end

    for i = 1, numQuests do
        if #available == 0 then break end
        local idx = math.random(1, #available)
        local q = available[idx]
        table.remove(available, idx)
        
        table.insert(M.activeQuests, {
            type = q.type,
            target = q.target,
            name = q.name,
            desc = q.desc,
            targetCount = q.count,
            currentCount = 0,
            exp = q.exp or 0,
            gold = q.gold or 0,
            rewardItems = q.rewardItems or {},
            isCompleted = false,
            isRewarded = false
        })
    end
end

-- 적 처치 시 퀘스트 갱신
function M.updateKill(enemyName)
    if not enemyName then return end
    for _, q in ipairs(M.activeQuests) do
        if q.type == "kill" and q.target == enemyName and not q.isCompleted then
            q.currentCount = q.currentCount + 1
            if q.currentCount >= q.targetCount then
                q.isCompleted = true
                if M.ctx and M.ctx.addMessage then
                    M.ctx.addMessage("퀘스트 완료: " .. q.name .. "!", {0.2, 1.0, 0.2})
                end
            end
        end
    end
end

-- 새로운 층수 도달 시 퀘스트 갱신
function M.updateReach(floorNum)
    for _, q in ipairs(M.activeQuests) do
        if q.type == "reach" and q.target == floorNum and not q.isCompleted then
            q.currentCount = 1
            q.isCompleted = true
            if M.ctx and M.ctx.addMessage then
                M.ctx.addMessage("퀘스트 완료: " .. q.name .. "!", {0.2, 1.0, 0.2})
            end
        end
    end
end

-- 마을로 귀환 시 완료된 퀘스트 보상 정산
function M.claimRewards()
    if not M.ctx or not M.ctx.player then return false end
    
    local totalExp = 0
    local totalGold = 0
    local givenItems = {}
    local rewardedAny = false

    for _, q in ipairs(M.activeQuests) do
        if q.isCompleted and not q.isRewarded then
            totalExp = totalExp + q.exp
            totalGold = totalGold + q.gold
            
            -- 아이템 보상 지급 로직
            if q.rewardItems and M.ctx.inventory and M.ctx.Item then
                for _, itemId in ipairs(q.rewardItems) do
                    local itemData = M.ctx.Item.DATABASE[itemId]
                    if itemData then
                        local newItem = M.ctx.Item.new(itemData)
                        if M.ctx.inventory:addItem(newItem) then
                            table.insert(givenItems, newItem.name)
                        else
                            -- 인벤토리가 꽉 찼다면 어떻게 할지? 일단 바닥에 떨구거나 메시지만 출력
                            if M.ctx.addMessage then
                                M.ctx.addMessage("인벤토리가 가득 차 " .. newItem.name .. " 획득 실패!", {1.0, 0.2, 0.2})
                            end
                        end
                    end
                end
            end
            
            q.isRewarded = true
            rewardedAny = true
        end
    end
    
    if rewardedAny then
        M.ctx.player.exp = M.ctx.player.exp + totalExp
        M.ctx.player.gold = (M.ctx.player.gold or 0) + totalGold
        
        if M.ctx.addMessage then
            M.ctx.addMessage("====== 퀘스트 보상 정산 ======", {1.0, 1.0, 0.2})
            if totalExp > 0 or totalGold > 0 then
                M.ctx.addMessage("경험치 +" .. totalExp .. " / 골드 +" .. totalGold, {1.0, 1.0, 0.2})
            end
            for _, itemName in ipairs(givenItems) do
                M.ctx.addMessage("특별 보상: [" .. itemName .. "] 획득!", {1.0, 0.5, 0.2})
            end
            M.ctx.addMessage("==============================", {1.0, 1.0, 0.2})
        end
        return true
    end
    
    return false
end

-- 현재 진행 중인 퀘스트 문자열 목록 반환 (UI 표시용)
function M.getActiveQuestStrings()
    local list = {}
    for _, q in ipairs(M.activeQuests) do
        if q.isCompleted and not q.isRewarded then
            table.insert(list, q.name .. " [완료]")
        elseif not q.isRewarded then
            table.insert(list, q.name .. " [" .. q.currentCount .. "/" .. q.targetCount .. "]")
        end
    end
    return list
end

return M
