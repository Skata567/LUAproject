local MercenaryShop = {}
local ctx = {}

function MercenaryShop.init(context)
    ctx = context
end

function MercenaryShop.generateMercenaries()
    if not ctx.RacesData or not ctx.ClassesData then return {} end
    
    local mercs = {}
    local raceKeys = {}
    for k, v in pairs(ctx.RacesData.PLAYER_RACES) do table.insert(raceKeys, k) end
    
    local classKeys = {}
    for k, v in pairs(ctx.ClassesData.PLAYER_CLASSES) do table.insert(classKeys, k) end

    local names = {"아르토리우스", "베른하르트", "실비아", "카엘", "로잘린", "드라코", "고르도", "펜리르", "에이다", "루시안"}

    local levelBase = ctx.player and ctx.player.level or 1

    for i = 1, 3 do
        local rKey = raceKeys[math.random(#raceKeys)]
        local cKey = classKeys[math.random(#classKeys)]
        
        local raceData = ctx.RacesData.PLAYER_RACES[rKey]
        local classData = ctx.ClassesData.PLAYER_CLASSES[cKey]
        
        -- 종족별 금지 직업 필터
        local restrict = ctx.RacesData.RACE_RESTRICTIONS[raceData.id]
        while restrict and restrict.forbiddenClasses and restrict.forbiddenClasses[classData.id] do
            cKey = classKeys[math.random(#classKeys)]
            classData = ctx.ClassesData.PLAYER_CLASSES[cKey]
        end

        local mLevel = math.max(1, levelBase + math.random(-1, 1))
        local mCost = mLevel * 150 + math.random(50, 100)
        
        table.insert(mercs, {
            name = names[math.random(#names)] .. " (" .. i .. ")",
            race = ctx.RacesData.PLAYER_RACES[rKey],
            class = ctx.ClassesData.PLAYER_CLASSES[cKey],
            level = mLevel,
            cost = mCost
        })
    end
    
    return mercs
end

return MercenaryShop
