local Constants = require("data.constants")
local TILE_WATER = Constants.TILE_WATER
local Quest = require("systems.quest")

local Combat = {}

local ctx = {}
function Combat.init(context)
    ctx = context
end

local getPlayerAtk = function() return Combat.getPlayerAtk() end
local getPlayerDef = function() return Combat.getPlayerDef() end
local getPlayerEvasion = function() return Combat.getPlayerEvasion() end
local getPlayerAccuracy = function() return Combat.getPlayerAccuracy() end
local getPlayerCritChance = function() return Combat.getPlayerCritChance() end
local getPlayerCritMult = function() return Combat.getPlayerCritMult() end
local getPlayerMaxHp = function() return Combat.getPlayerMaxHp() end
local getPlayerMaxMana = function() return Combat.getPlayerMaxMana() end
local getPlayerManaRegen = function() return Combat.getPlayerManaRegen() end
local getEquipPassives = function() return Combat.getEquipPassives() end
local getPassiveValue = function(t) return Combat.getPassiveValue(t) end
local getPlayerEvasionFull = function() return Combat.getPlayerEvasionFull() end
local getPlayerCritFull = function() return Combat.getPlayerCritFull() end
local getPlayerElement = function() return Combat.getPlayerElement() end
local getPlayerElementDefense = function(e) return Combat.getPlayerElementDefense(e) end
local dealPlayerAttack = function(e) return Combat.dealPlayerAttack(e) end
local getElementMult = function(e, r) return ctx.getElementMult(e, r) end
local rollDrop = function() return ctx.rollDrop() end
local getProficiencyBonus = function(e) return Combat.getProficiencyBonus(e) end
local getSkillManaCost = function(s) return Combat.getSkillManaCost(s) end
local hasBuff = function(b) return Combat.hasBuff(b) end
local addPassives = function(d) return Combat.addPassives(d) end
local applyBuff = function(b, n, d, s) return Combat.applyBuff(b, n, d, s) end
local tickBuffs = function() return Combat.tickBuffs() end
local tickSkillCooldowns = function() return Combat.tickSkillCooldowns() end
local recoverMana = function(a) return Combat.recoverMana(a) end
local useSkill = function(i, t) return Combat.useSkill(i, t) end
local gainExp = function(a) return Combat.gainExp(a) end
local checkLevelUp = function() return Combat.checkLevelUp() end
local attackEnemy = function(e) return Combat.attackEnemy(e) end
local enemyAttack = function(e) return Combat.enemyAttack(e) end
local gainProficiency = function(e) return Combat.gainProficiency(e) end

local getBuffStatBonus

--- 장비 스탯 포함 최종 스탯 계산
function Combat.getPlayerAtk()
    local bonus = ctx.equip and ctx.equip:getTotalStats().atk or 0
    local strBonus = math.floor(ctx.player.str / 3)
    return ctx.player.baseAtk + bonus + strBonus + getBuffStatBonus("atk")
end

function Combat.getPlayerDef()
    local bonus = ctx.equip and ctx.equip:getTotalStats().def or 0
    local conBonus = math.floor(ctx.player.con / 5)
    return ctx.player.baseDef + bonus + conBonus + getBuffStatBonus("def")
end

--- 회피율 (DEX + LCK 기반)
function Combat.getPlayerEvasion()
    local eqSpd = ctx.equip and ctx.equip:getTotalStats().spd or 0
    return 5 + ctx.player.dex * 1.5 + ctx.player.lck * 0.5 + eqSpd + getBuffStatBonus("evasion")
end

--- 명중률 (DEX 기반)
function Combat.getPlayerAccuracy()
    return 70 + ctx.player.dex * 2 + ctx.player.lck * 0.5 + getBuffStatBonus("accuracy")
end

--- 치명타 확률 (DEX + LCK 기반)
function Combat.getPlayerCritChance()
    local eqCrit = ctx.equip and ctx.equip:getTotalStats().crit or 0
    return 5 + ctx.player.dex * 0.5 + ctx.player.lck * 1.0 + eqCrit + getBuffStatBonus("crit")
end

--- 치명타 배율
function Combat.getPlayerCritMult()
    return 1.5 + ctx.player.str * 0.02
end

--- 최대 HP (CON 기반)
function Combat.getPlayerMaxHp()
    local eqHp = ctx.equip and ctx.equip:getTotalStats().hp or 0
    local base = 30 + (ctx.player.level - 1) * 5
    local raceHp = ctx.player.hpBonus or 0
    return base + ctx.player.con * 3 + eqHp + raceHp + getBuffStatBonus("hp")
end

function Combat.getPlayerMaxMana()
    local base = 12 + ctx.player.level * 2
    return math.max(0, base + ctx.player.int * 5 + math.floor(ctx.player.lck / 2) + getBuffStatBonus("mana"))
end

function Combat.getPlayerManaRegen()
    return math.max(1, 1 + math.floor(ctx.player.int / 6))
end

--- 장비 패시브 효과 수집
function Combat.getEquipPassives()
    local passives = {}
    if not ctx.equip then return passives end
    for _, item in pairs(ctx.equip.slots) do
        if item and item.passive then
            table.insert(passives, item.passive)
        end
    end
    return passives
end

--- 특정 패시브 합산
function Combat.getPassiveValue(pType)
    local total = 0
    for _, p in ipairs(getEquipPassives()) do
        if p.type == pType then
            total = total + p.value
        end
    end
    return total
end

--- 패시브 보정된 회피율
function Combat.getPlayerEvasionFull()
    local ev = getPlayerEvasion() + getPassiveValue("dodge_boost")
    if ctx.map and ctx.map[ctx.player.y] and ctx.map[ctx.player.y][ctx.player.x] == TILE_WATER then
        ev = ev - 15
    end
    return ev
end

--- 패시브 보정된 치명타
function Combat.getPlayerCritFull()
    return getPlayerCritChance() + getPassiveValue("crit_boost")
end

--- 장착 무기의 공격 속성
function Combat.getPlayerElement()
    if not ctx.equip then return "physical" end
    local w1 = ctx.equip:getItem("weapon1")
    if w1 and w1.element then return w1.element end
    return "physical"
end

--- 숙련도 보너스 데미지 배율
function Combat.getProficiencyBonus(element)
    if not ctx.player.proficiency then return 1.0 end
    local prof = ctx.player.proficiency[element] or 0
    return 1.0 + prof * 0.03  -- 숙련도 1당 3% 데미지 증가
end

--- 무기 사용 시 숙련도 경험치 증가
function Combat.gainProficiency(element)
    if not ctx.player.proficiency or not element or element == "physical" then return end
    local cur = ctx.player.proficiency[element] or 0
    if cur < 20 then  -- 최대 20
        ctx.player.proficiency[element] = cur + 0.2
    end
end

--- 플레이어 속성 저항/약점 적용 (적 공격 → 플레이어)
function Combat.getPlayerElementDefense(element)
    if not element or element == "physical" then return 1.0 end
    if ctx.player.resist and ctx.player.resist[element] then
        local r = ctx.player.resist[element]
        if r >= 1.0 then return 0 end
        return 1.0 - r
    end
    if ctx.player.weak and ctx.player.weak[element] then
        return 1.0 + ctx.player.weak[element]
    end
    return 1.0
end

--- 활성 버프 체크
function Combat.hasBuff(buffId)
    if not ctx.player.buffs then return false end
    for _, b in ipairs(ctx.player.buffs) do
        if b.id == buffId and b.duration > 0 then return true end
    end
    return false
end

getBuffStatBonus = function(stat)
    local total = 0
    if ctx.player.buffs then
        for _, b in ipairs(ctx.player.buffs) do
            if b.duration > 0 and b.statBonus and b.statBonus[stat] then
                total = total + b.statBonus[stat]
            end
        end
    end
    
    -- 패시브 스킬 합산
    if ctx.player.unlockedSkills and ctx.SKILLS_DB then
        local rData = ctx.SKILLS_DB.races[ctx.player.raceId]
        local cData = ctx.SKILLS_DB.classes[ctx.player.classId]
        
        function Combat.addPassives(data)
            if not data then return end
            local tiers = {data.tier1, data.tier2, data.tier3}
            for t=1, 3 do
                if tiers[t] then
                    for _, s in ipairs(tiers[t]) do
                        if ctx.player.unlockedSkills[s.id] and s.statBonus then
                            -- skills_db.lua의 key와 main.lua의 stat name 매핑
                            local mappedKey = stat
                            if stat == "hp" and s.statBonus.maxHp then total = total + s.statBonus.maxHp end
                            if stat == "def" and s.statBonus.def then total = total + s.statBonus.def end
                            if stat == "evasion" and s.statBonus.ev then total = total + s.statBonus.ev end
                            if stat == "crit" and s.statBonus.critChance then total = total + s.statBonus.critChance end
                            if s.statBonus[stat] then total = total + s.statBonus[stat] end
                        end
                    end
                end
            end
        end
        addPassives(rData)
        addPassives(cData)
    end
    
    return total
end

--- 버프 적용
function Combat.applyBuff(buffId, name, duration, statBonus)
    if not ctx.player.buffs then ctx.player.buffs = {} end
    for _, b in ipairs(ctx.player.buffs) do
        if b.id == buffId then
            b.duration = duration
            b.statBonus = statBonus
            return
        end
    end
    table.insert(ctx.player.buffs, {id=buffId, name=name, duration=duration, statBonus=statBonus})
end

--- 버프 턴 감소
function Combat.tickBuffs()
    if not ctx.player.buffs then return end
    local newBuffs = {}
    for _, b in ipairs(ctx.player.buffs) do
        if b.id == "regenerate" then
            ctx.player.hp = math.min(ctx.player.hp + 3, Combat.getPlayerMaxHp())
            ctx.addMessage("  ♥ 재생! +3 HP")
        end
        b.duration = b.duration - 1
        if b.duration > 0 then
            table.insert(newBuffs, b)
        else
            ctx.addMessage("  [" .. b.name .. "] 효과 종료")
        end
    end
    ctx.player.buffs = newBuffs
end

--- 스킬 쿨다운 감소
function Combat.tickSkillCooldowns()
    if not ctx.player.skills then return end
    for _, s in ipairs(ctx.player.skills) do
        if s.currentCd > 0 then
            s.currentCd = s.currentCd - 1
        end
    end
end

function Combat.getSkillManaCost(skill)
    if not skill then return 0 end
    if skill.manaCost then return skill.manaCost end
    if skill.type == "attack" then
        return 7 + math.floor((skill.cooldown or 0) / 2)
    elseif skill.type == "heal" then
        return 10 + math.floor((skill.cooldown or 0) / 2)
    elseif skill.type == "buff" then
        return 6 + math.floor((skill.duration or 0) / 2)
    elseif skill.type == "nextAtk" then
        return 5
    end
    return 0
end

function Combat.recoverMana(amount)
    if not ctx.player.maxMana or ctx.player.maxMana <= 0 then return end
    ctx.player.mana = math.min(ctx.player.maxMana, (ctx.player.mana or 0) + amount)
end

--- 스킬 사용
function Combat.useSkill(skillIndex, targetEnemy)
    if not ctx.player.skills or not ctx.player.skills[skillIndex] then return false end
    local s = ctx.player.skills[skillIndex]
    if not ctx.canUseSkillByRestriction(s) then return false end
    if s.currentCd > 0 then
        ctx.addMessage(s.name .. " 쿨다운 중! (남은 " .. s.currentCd .. "턴)")
        return false
    end
    local manaCost = getSkillManaCost(s)
    if (ctx.player.mana or 0) < manaCost then
        ctx.addMessage(s.name .. " 사용 실패! 마나 부족 (" .. (ctx.player.mana or 0) .. "/" .. manaCost .. ")")
        return false
    end

    s.currentCd = s.cooldown
    ctx.player.mana = ctx.player.mana - manaCost

    if s.type == "buff" then
        applyBuff(s.id, s.name, s.duration, s.statBonus)
        ctx.addMessage("★ " .. s.name .. " 발동! (" .. s.duration .. "턴, MP -" .. manaCost .. ")")
        return true
    elseif s.type == "heal" then
        local healAmt = (s.value or 0) + math.floor(ctx.player.int * (s.healScale or 3))
        ctx.player.hp = math.min(ctx.player.hp + healAmt, getPlayerMaxHp())
        ctx.addMessage("★ " .. s.name .. "! HP +" .. healAmt .. " 회복! (MP -" .. manaCost .. ")")
        return true
    elseif s.type == "attack" then
        local isAoE = (s.id == "chain_spark" or s.id == "dragon_breath" or s.id == "shock_mine" or s.id == "tidal_chill" or s.id == "inferno_bolt")
        
        if not isAoE and not targetEnemy then
            ctx.addMessage("대상이 없습니다!")
            ctx.player.mana = ctx.player.mana + manaCost
            s.currentCd = 0
            return false
        end
        
        local targets = {}
        if isAoE then
            for _, e in ipairs(ctx.enemies) do
                if e.alive and math.abs(e.x - ctx.player.x) <= 1 and math.abs(e.y - ctx.player.y) <= 1 then
                    table.insert(targets, e)
                end
            end
            if #targets == 0 then
                ctx.addMessage("주변에 대상이 없습니다!")
                ctx.player.mana = ctx.player.mana + manaCost
                s.currentCd = 0
                return false
            end
        else
            table.insert(targets, targetEnemy)
        end

        local dmgBase = math.max(1, math.floor((s.value or 0) + ctx.player.int * (s.attackScale or 2) + ctx.player.level * 2))
        local elem = s.element or "physical"
        
        for _, enemy in ipairs(targets) do
            local dmg = dmgBase
            local elemMult = ctx.getElementMult(elem, enemy.race)
            if s.id == "holy_smite" and (enemy.race == "undead" or enemy.race == "demon") then
                dmg = dmg * 2
            end
            dmg = math.max(1, math.floor(dmg * elemMult))
            if elemMult == 0 then
                ctx.addMessage(enemy.name .. "은(는) 면역!")
            else
                enemy.hp = enemy.hp - dmg
                local elemName = ctx.Item.ELEMENT_NAMES[elem] or elem
                ctx.addMessage("★ " .. s.name .. "! " .. enemy.name .. "에게 " .. dmg .. " " .. elemName .. " 데미지!")
                if s.id == "drain_life" or s.id == "soul_siphon" or s.id == "blood_drain" then
                    local heal = math.floor(dmg * 0.5)
                    ctx.player.hp = math.min(ctx.player.hp + heal, Combat.getPlayerMaxHp())
                    ctx.addMessage("  HP +" .. heal .. " 흡수!")
                end
            end
        end
        return true
    elseif s.type == "nextAtk" then
        ctx.player.nextAtkBonus = {name=s.name, mult=s.value, id=s.id}
        ctx.addMessage("★ " .. s.name .. " 준비! 다음 공격에 적용됩니다. (MP -" .. manaCost .. ")")
        return true
    end
    return false
end

--- 경험치 획득 (종족 보너스 적용)
function Combat.gainExp(amount)
    local bonus = ctx.player.expBonus or 0
    local finalExp = math.max(1, math.floor(amount * (1 + bonus / 100)))
    ctx.player.exp = ctx.player.exp + finalExp
    return finalExp
end

-- ===== 레벨업 =====
function Combat.checkLevelUp()
    while ctx.player.exp >= ctx.player.nextExp do
        ctx.player.exp = ctx.player.exp - ctx.player.nextExp
        ctx.player.level = ctx.player.level + 1
        ctx.player.baseAtk = ctx.player.baseAtk + 1
        ctx.player.skillPoints = (ctx.player.skillPoints or 0) + 1
        ctx.player.nextExp = math.floor(ctx.player.nextExp * 1.5)

        ctx.player.statPoints = (ctx.player.statPoints or 0) + 3
        ctx.addMessage("레벨 업! (Lv." .. ctx.player.level .. ") 스탯 포인트 3점 및 스킬 포인트 1점 획득!", {1.0, 1.0, 0.0})
        
        if ctx.setStatAlloc then ctx.setStatAlloc({points = 3, sel = 1}) end
        if ctx.setGameState then ctx.setGameState("levelup") end

        -- maxHp 재계산 + 풀HP
        ctx.player.maxHp = getPlayerMaxHp()
        ctx.player.hp = ctx.player.maxHp
    end
end

-- ===== 부활 =====
function Combat.revive()
    ctx.player.hp = math.floor(Combat.getPlayerMaxHp() * 0.5)
    ctx.player.mana = math.floor(Combat.getPlayerMaxMana() * 0.5)
    ctx.player.buffs = {}
    ctx.addMessage("부활하였습니다...", {1, 0, 0})
end

-- ===== 전투 (DCSS 스타일 공식 + 패시브 효과) =====

--- 플레이어 → 적 한 번 공격 (내부 함수)
function Combat.dealPlayerAttack(enemy)
    local accuracy = getPlayerAccuracy()
    local hitRoll = math.random(1, 100)
    local evade = enemy.ev or 0

    -- 정밀 사격 등 다음 공격 보너스 (명중 보정)
    local atkBonus = ctx.player.nextAtkBonus
    if atkBonus and atkBonus.id == "precise_shot" then
        accuracy = 999
    end

    if hitRoll > accuracy - evade then
        ctx.addMessage(enemy.name .. "이(가) 공격을 회피했다!")
        return 0
    end

    local atk = getPlayerAtk()
    -- 광폭화 버프: 공격력 2배
    if hasBuff("berserk") then atk = atk * 2 end
    -- 전쟁 함성 버프: 공격력 +30%
    if hasBuff("war_cry") then atk = math.floor(atk * 1.3) end

    local enemyDef = enemy.def or 0

    -- 방어관통 패시브
    local armorBreak = getPassiveValue("armor_break")
    if armorBreak > 0 then
        enemyDef = math.floor(enemyDef * (1 - armorBreak / 100))
    end
    -- 정밀 사격: 방어 무시
    if atkBonus and atkBonus.id == "precise_shot" then
        enemyDef = 0
    end

    local dmgReduction = math.floor(enemyDef * 0.6)
    local baseDmg = math.max(1, atk - dmgReduction)

    local variance = math.floor(baseDmg * 0.2)
    local dmg = baseDmg + math.random(-variance, variance)

    -- 치명타 판정 (패시브 보정)
    local critChance = getPlayerCritFull()
    local isCrit = math.random(1, 100) <= critChance
    -- 급소 찌르기: 치명타 확정
    if atkBonus and atkBonus.id == "backstab" then
        isCrit = true
    end
    if isCrit then
        local critMult = getPlayerCritMult()
        if atkBonus and atkBonus.id == "backstab" then critMult = 3.0 end
        dmg = math.floor(dmg * critMult)
    end
    dmg = math.max(1, dmg)

    -- 다음 공격 데미지 배율 (강타 등)
    if atkBonus then
        if atkBonus.mult and atkBonus.mult > 1 then
            dmg = math.floor(dmg * atkBonus.mult)
        end
        ctx.addMessage("  [" .. atkBonus.name .. "] 적용!")
        ctx.player.nextAtkBonus = nil
    end

    -- 속성 상성 적용
    local pElement = getPlayerElement()
    local elemMult = getElementMult(pElement, enemy.race)
    if elemMult == 0 then
        ctx.addMessage(enemy.name .. "이(가) " .. (ctx.Item.ELEMENT_NAMES[pElement] or pElement) .. " 공격에 저항했습니다!")
        return 0
    end
    dmg = math.max(1, math.floor(dmg * elemMult))

    -- 숙련도 보너스 적용
    local profMult = getProficiencyBonus(pElement)
    dmg = math.max(1, math.floor(dmg * profMult))
    gainProficiency(pElement)

    enemy.hp = enemy.hp - dmg
    local msg = enemy.name .. "에게 " .. dmg .. " 데미지!"
    if isCrit then msg = "★ 치명타! " .. msg end
    if elemMult > 1.0 then
        msg = msg .. " (약점!)"
    elseif elemMult < 1.0 then
        msg = msg .. " (저항)"
    end
    ctx.addMessage(msg)

    -- 흡혈 패시브
    local lifesteal = getPassiveValue("lifesteal")
    if lifesteal > 0 then
        local heal = math.max(1, math.floor(dmg * lifesteal / 100))
        ctx.player.hp = math.min(ctx.player.maxHp, ctx.player.hp + heal)
        ctx.addMessage("  ♥ 흡혈 +" .. heal .. " HP")
    end

    -- 마나 흡수 패시브
    local manaSteal = getPassiveValue("mana_steal")
    if manaSteal > 0 then
        local mpHeal = math.max(1, math.floor(dmg * manaSteal / 100))
        local maxMana = Combat.getPlayerMaxMana()
        ctx.player.mana = math.min(maxMana, (ctx.player.mana or 0) + mpHeal)
        ctx.addMessage("  마나 흡수 +" .. mpHeal .. " MP", {0.3, 0.5, 1.0})
    end

    -- 처형 패시브
    local executeThreshold = getPassiveValue("execute")
    if executeThreshold > 0 and not enemy.isBoss and enemy.hp > 0 then
        local hpPercent = (enemy.hp / enemy.maxHp) * 100
        if hpPercent <= executeThreshold then
            enemy.hp = 0
            ctx.addMessage("  처형 발동! " .. enemy.name .. " 즉사!", {0.8, 0.1, 0.1})
        end
    end

    -- 화상 패시브
    local burnVal = getPassiveValue("burn")
    if burnVal > 0 and math.random(1, 100) <= 35 then
        enemy.burn = (enemy.burn or 0) + burnVal
        ctx.addMessage("  🔥 " .. enemy.name .. " 화상! (" .. burnVal .. "턴)")
    end

    -- 독 패시브
    local poisonVal = getPassiveValue("poison")
    if poisonVal > 0 and math.random(1, 100) <= 25 then
        enemy.poison = (enemy.poison or 0) + poisonVal
        ctx.addMessage("  ☠ " .. enemy.name .. " 중독! (" .. poisonVal .. "턴)")
    end

    -- 기절 패시브
    local stunVal = getPassiveValue("stun")
    if stunVal > 0 and math.random(1, 100) <= stunVal then
        enemy.stunned = true
        ctx.addMessage("  ⚡ " .. enemy.name .. " 기절!")
    end

    return dmg
end

function Combat.attackEnemy(enemy)
    local totalDmg = dealPlayerAttack(enemy)

    -- 연속타격 패시브
    if enemy.alive and enemy.hp > 0 then
        local doubleHit = getPassiveValue("double_hit")
        if doubleHit > 0 and math.random(1, 100) <= doubleHit then
            ctx.addMessage("  >> 연속 타격!")
            totalDmg = totalDmg + dealPlayerAttack(enemy)
        end
    end

    if enemy.hp <= 0 then
        enemy.alive = false
        Quest.updateKill(enemy.name)

        -- 경험치 (exp_boost 패시브)
        local expBoost = getPassiveValue("exp_boost")
        local totalExp = math.floor(enemy.exp * (1 + expBoost / 100))
        local splitExp = totalExp
        if ctx.party and #ctx.party > 0 then
            splitExp = math.floor(totalExp / (#ctx.party + 1))
            for _, comp in ipairs(ctx.party) do
                if comp.alive then
                    comp.exp = comp.exp + splitExp
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
            end
        end
        ctx.player.exp = ctx.player.exp + splitExp
        ctx.addMessage(enemy.name .. " 처치! (+" .. splitExp .. " 경험치)")
        if enemy.isBoss then
            ctx.addMessage("★ 보스를 쓰러뜨렸습니다! 계단이 안정되었습니다.")
        end

        -- 아이템 드롭 (40% + LCK 보정)
        local dropChance = enemy.isBoss and 1.0 or (0.4 + ctx.player.lck * 0.01)
        if math.random() < dropChance then
            local drop = rollDrop()
            if drop then
                table.insert(ctx.groundItems, {
                    x = enemy.x, y = enemy.y,
                    item = drop,
                    picked = false,
                })
                ctx.addMessage("  → " .. drop.name .. " 드롭!")
            end
        end

        -- 골드 드롭 (gold_boost 패시브)
        local goldBoost = getPassiveValue("gold_boost")
        local goldDrop = math.random(1, 5) + ctx.floor * 2
        if enemy.isBoss then
            goldDrop = goldDrop + ctx.floor * 25
        end
        goldDrop = math.floor(goldDrop * (1 + goldBoost / 100))
        ctx.player.gold = ctx.player.gold + goldDrop
        ctx.addMessage("  → " .. goldDrop .. "G 획득!")

        checkLevelUp()
    end
end

function Combat.enemyAttack(enemy)
    -- 기절 체크
    if enemy.stunned then
        enemy.stunned = false
        ctx.addMessage(enemy.name .. "은(는) 기절에서 깨어났다!")
        return
    end

    local evasion = getPlayerEvasionFull()
    local hitRoll = math.random(1, 100)
    local enemyAcc = 60 + (enemy.atk or 0) * 2

    -- 행운의 회피 버프
    if hasBuff("lucky_dodge") then
        ctx.addMessage("  ★ 행운의 회피! " .. enemy.name .. "의 공격을 피했다!")
        return
    end

    if hitRoll > enemyAcc - evasion then
        ctx.addMessage(enemy.name .. "의 공격을 회피했다!")
        return
    end

    local def = getPlayerDef()
    -- 광폭화: 방어력 0
    if hasBuff("berserk") then def = 0 end
    -- 바위 피부: 방어력 +5
    if hasBuff("stone_skin") then def = def + 5 end
    -- 마나 실드: 데미지 20% 감소 (아래에서 적용)

    local dmg = math.max(1, (enemy.atk or 0) - math.floor(def * 0.6))
    local variance = math.floor(dmg * 0.15)
    dmg = dmg + math.random(-variance, variance)
    dmg = math.max(1, dmg)

    -- 마나 실드 데미지 감소
    if hasBuff("mana_shield") then
        dmg = math.max(1, math.floor(dmg * 0.8))
    end

    -- 플레이어 속성 저항/약점 적용
    local eElem = enemy.atkElement or "physical"
    local pDefMult = getPlayerElementDefense(eElem)
    if pDefMult == 0 then
        ctx.addMessage(enemy.name .. "의 " .. (ctx.Item.ELEMENT_NAMES[eElem] or eElem) .. " 공격에 저항했습니다!")
        return
    end
    dmg = math.max(1, math.floor(dmg * pDefMult))

    ctx.player.hp = ctx.player.hp - dmg
    if ctx.interruptChanneling then
        ctx.interruptChanneling()
    end
    local elemName = ctx.Item.ELEMENT_NAMES[eElem] or eElem
    if eElem ~= "physical" then
        local extra = ""
        if pDefMult > 1.0 then extra = " (약점!)" end
        if pDefMult < 1.0 then extra = " (저항)" end
        ctx.addMessage(enemy.name .. "이(가) " .. dmg .. " " .. elemName .. " 데미지!" .. extra)
    else
        ctx.addMessage(enemy.name .. "이(가) " .. dmg .. " 데미지!")
    end

    -- 가시/반사 패시브
    local thorns = getPassiveValue("thorns")
    if thorns > 0 then
        e.hp = e.hp - thorns
        ctx.addMessage("  ◆ 가시 반사 " .. thorns .. " 데미지!")
        if e.hp <= 0 then
            e.alive = false
            Quest.updateKill(e.name)
            
            local totalExp = e.exp
            local splitExp = totalExp
            if ctx.party and #ctx.party > 0 then
                splitExp = math.floor(totalExp / (#ctx.party + 1))
                for _, comp in ipairs(ctx.party) do
                    if comp.alive then
                        comp.exp = comp.exp + splitExp
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
                end
            end
            ctx.player.exp = ctx.player.exp + splitExp
            ctx.addMessage(e.name .. " 처치! (+" .. splitExp .. " 경험치)")
            ctx.checkLevelUp()
        end
    end

    local reflect = getPassiveValue("reflect")
    if reflect > 0 then
        local refDmg = math.max(1, math.floor(dmg * reflect / 100))
        enemy.hp = enemy.hp - refDmg
        ctx.addMessage("  ◆ 반사 " .. refDmg .. " 데미지!")
        if enemy.hp <= 0 and enemy.alive then
            enemy.alive = false
            Quest.updateKill(enemy.name)
            gainExp(enemy.exp)
            ctx.addMessage(enemy.name .. " 처치! (반사)")
            checkLevelUp()
        end
    end

    -- 반격 패시브
    local counter = getPassiveValue("counter_attack")
    if counter > 0 and enemy.alive and enemy.hp > 0 then
        if math.random(1, 100) <= counter then
            ctx.addMessage("  반격 발동! 즉시 되돌려칩니다!", {1.0, 0.4, 0.4})
            dealPlayerAttack(enemy)
        end
    end

    if ctx.player.hp <= 0 then
        -- 부활 패시브 확인
        local revived = false
        if ctx.equip then
            for slot, item in pairs(ctx.equip.slots) do
                if item and item.passive and item.passive.type == "revive" then
                    local reviveVal = item.passive.value
                    local maxHp = Combat.getPlayerMaxHp()
                    ctx.player.hp = math.max(1, math.floor(maxHp * reviveVal / 100))
                    ctx.addMessage("  불사조의 기운! [" .. item.name .. "] 이(가) 파괴되며 부활했습니다!", {1.0, 0.8, 0.2})
                    ctx.equip.slots[slot] = nil -- 장착 파괴
                    revived = true
                    break
                end
            end
        end

        if not revived then
            if ctx.setGameState then ctx.setGameState("gameover") end
            ctx.addMessage("** 사망했습니다! **")
        end
    end
end

-- ===== 아이템 줍기 (인벤토리로) =====

return Combat
