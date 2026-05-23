--[[
    equipment.lua — 장비 장착 시스템

    - 무기칸 2개 (주무기/보조무기)
    - 양손 무기: 두 칸 모두 차지
    - 한손 무기/방패: 각각 한 칸씩
    - 방어구, 투구, 신발, 반지, 목걸이 슬롯
    - 장착/해제 시 스탯 자동 계산
]]

local Equipment = {}
Equipment.__index = Equipment

local SLOT_SIZE = 56

-- 슬롯 레이아웃 정의
local SLOT_LAYOUT = {
    {slot = "helmet",  label = "투구",     offsetX = 0,    offsetY = -70},
    {slot = "amulet",  label = "목걸이",   offsetX = 80,   offsetY = -35},
    {slot = "weapon1", label = "주무기",   offsetX = -80,  offsetY = 0},
    {slot = "armor",   label = "방어구",   offsetX = 0,    offsetY = 0},
    {slot = "weapon2", label = "보조",     offsetX = 80,   offsetY = 0},
    {slot = "ring",    label = "반지",     offsetX = -80,  offsetY = 70},
    {slot = "boots",   label = "신발",     offsetX = 0,    offsetY = 70},
}

function Equipment.new()
    local self = setmetatable({}, Equipment)
    self.slots = {
        weapon1 = nil,   -- 주무기
        weapon2 = nil,   -- 보조무기 (한손무기/방패)
        armor   = nil,
        helmet  = nil,
        boots   = nil,
        ring    = nil,
        amulet  = nil,
    }
    self.x = 0
    self.y = 0
    self.slotSize = SLOT_SIZE
    return self
end

--- 무기 장착 가능 여부 확인
-- 양손 무기: weapon1에만 장착, weapon2는 비워야 함
-- 한손 무기/방패: weapon1 또는 weapon2에 장착 가능
function Equipment:canEquipWeapon(item, targetSlot)
    if not item or item.slot ~= "weapon" then return false end

    if item.twoHanded then
        -- 양손 무기는 weapon1에만 장착
        if targetSlot ~= "weapon1" then return false end
        return true
    else
        -- 한손 무기: weapon1 또는 weapon2
        if targetSlot ~= "weapon1" and targetSlot ~= "weapon2" then return false end
        -- weapon1에 양손 무기가 있으면 weapon2에 장착 불가
        if targetSlot == "weapon2" then
            local w1 = self.slots.weapon1
            if w1 and w1.twoHanded then return false end
        end
        return true
    end
end

--- 아이템 장착 (기존 아이템 리스트 반환)
function Equipment:equip(item, targetSlot)
    if not item or not item.slot then return {} end

    local removed = {}

    if item.slot == "weapon" then
        -- 무기 장착 로직
        if not targetSlot then
            -- 자동 슬롯 결정
            if item.twoHanded then
                targetSlot = "weapon1"
            else
                -- 빈 슬롯 우선
                if not self.slots.weapon1 then
                    targetSlot = "weapon1"
                elseif not self.slots.weapon2 then
                    -- weapon1이 양손이면 weapon2 불가
                    if self.slots.weapon1 and self.slots.weapon1.twoHanded then
                        targetSlot = "weapon1"
                    else
                        targetSlot = "weapon2"
                    end
                else
                    targetSlot = "weapon1"
                end
            end
        end

        if not self:canEquipWeapon(item, targetSlot) then return {} end

        if item.twoHanded then
            -- 양손 무기: 양쪽 다 해제
            if self.slots.weapon1 then
                table.insert(removed, self.slots.weapon1)
            end
            if self.slots.weapon2 then
                table.insert(removed, self.slots.weapon2)
            end
            self.slots.weapon1 = item
            self.slots.weapon2 = nil
        else
            -- 한손 무기/방패
            if self.slots[targetSlot] then
                table.insert(removed, self.slots[targetSlot])
            end
            -- weapon1에 양손 무기가 있고 weapon1에 한손 넣으면 양손 해제
            if targetSlot == "weapon1" and self.slots.weapon1 and self.slots.weapon1.twoHanded then
                -- 양손 무기가 빠짐 (이미 removed에 추가됨)
            end
            self.slots[targetSlot] = item
        end
    else
        -- 무기 외 장비
        local slotName = item.slot
        if self.slots[slotName] ~= nil or slotName == "armor" or slotName == "helmet"
           or slotName == "boots" or slotName == "ring" or slotName == "amulet" then
            if self.slots[slotName] then
                table.insert(removed, self.slots[slotName])
            end
            self.slots[slotName] = item
        end
    end

    return removed
end

--- 슬롯 해제 (아이템 반환)
function Equipment:unequip(slotName)
    local item = self.slots[slotName]
    if not item then return nil end

    self.slots[slotName] = nil

    -- 양손 무기 해제 시 weapon1 기준으로만 해제 (weapon2는 이미 nil)
    return item
end

--- 장착된 아이템 가져오기
function Equipment:getItem(slotName)
    return self.slots[slotName]
end

--- weapon2가 양손무기에 의해 잠겨있는지 확인
function Equipment:isSlotLocked(slotName)
    if slotName == "weapon2" then
        local w1 = self.slots.weapon1
        return w1 ~= nil and w1.twoHanded
    end
    return false
end

--- 전체 장비 스탯 합산
function Equipment:getTotalStats()
    local total = {atk = 0, def = 0, hp = 0, spd = 0, crit = 0}
    for _, item in pairs(self.slots) do
        if item then
            for stat, val in pairs(item.stats) do
                total[stat] = (total[stat] or 0) + val
            end
        end
    end
    return total
end

--- 화면 좌표에서 슬롯 찾기
function Equipment:getSlotAt(sx, sy)
    local hs = self.slotSize / 2
    for _, layout in ipairs(SLOT_LAYOUT) do
        local cx = self.x + layout.offsetX
        local cy = self.y + layout.offsetY
        if sx >= cx - hs and sx <= cx + hs and
           sy >= cy - hs and sy <= cy + hs then
            return layout.slot
        end
    end
    return nil
end

--- 슬롯 이름 → item.slot 매핑
local function slotToItemSlot(slotName)
    if slotName == "weapon1" or slotName == "weapon2" then
        return "weapon"
    end
    return slotName
end

--- 드래그 아이템이 해당 슬롯에 놓을 수 있는지 확인
function Equipment:canDropToSlot(item, slotName)
    if not item or not item.slot then return false end

    if slotName == "weapon1" or slotName == "weapon2" then
        if item.slot ~= "weapon" then return false end
        return self:canEquipWeapon(item, slotName)
    end

    return item.slot == slotName
end

--- 장비 패널 그리기
function Equipment:draw(font)
    local ss = self.slotSize
    local hs = ss / 2

    -- 배경
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", self.x - 120, self.y - 110, 240, 230, 8, 8)

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.print("장비", self.x - 14, self.y - 106)

    -- 캐릭터 실루엣
    love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
    love.graphics.circle("fill", self.x, self.y, 20)
    love.graphics.setColor(0.4, 0.4, 0.45, 0.5)
    love.graphics.circle("line", self.x, self.y, 20)

    -- 각 슬롯 그리기
    for _, layout in ipairs(SLOT_LAYOUT) do
        local cx = self.x + layout.offsetX - hs
        local cy = self.y + layout.offsetY - hs
        local item = self.slots[layout.slot]
        local locked = self:isSlotLocked(layout.slot)

        -- 슬롯 배경
        if locked then
            love.graphics.setColor(0.1, 0.05, 0.05)
        else
            love.graphics.setColor(0.15, 0.15, 0.2)
        end
        love.graphics.rectangle("fill", cx, cy, ss, ss, 4, 4)

        if locked then
            -- 잠긴 슬롯 (양손 무기 때문에)
            love.graphics.setColor(0.4, 0.15, 0.15, 0.8)
            love.graphics.rectangle("line", cx, cy, ss, ss, 4, 4)
            love.graphics.setColor(0.5, 0.2, 0.2)
            love.graphics.print("X", cx + ss / 2 - 4, cy + ss / 2 - 8)
            love.graphics.setColor(0.4, 0.2, 0.2)
            love.graphics.print("양손", cx + ss / 2 - 13, cy + ss - 16)
        elseif item then
            -- 장착된 아이템
            local rc = item:getRarityColor()
            love.graphics.setColor(rc[1] * 0.25, rc[2] * 0.25, rc[3] * 0.25, 0.8)
            love.graphics.rectangle("fill", cx + 1, cy + 1, ss - 2, ss - 2, 4, 4)

            love.graphics.setColor(rc[1], rc[2], rc[3], 0.9)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cx + 1, cy + 1, ss - 2, ss - 2, 4, 4)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(item.color[1], item.color[2], item.color[3])
            love.graphics.print(item.icon, cx + ss / 2 - 6, cy + ss / 2 - 8)
        else
            -- 빈 슬롯
            love.graphics.setColor(0.3, 0.3, 0.35, 0.5)
            love.graphics.rectangle("line", cx, cy, ss, ss, 4, 4)

            love.graphics.setColor(0.4, 0.4, 0.45)
            local lw = font:getWidth(layout.label)
            love.graphics.print(layout.label, cx + (ss - lw) / 2, cy + ss / 2 - 7)
        end
    end
end

--- 스탯 패널 그리기
function Equipment:drawStats(x, y)
    local stats = self:getTotalStats()

    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", x - 4, y - 4, 160, 110, 4, 4)

    love.graphics.setColor(1, 0.85, 0)
    love.graphics.print("장비 스탯", x, y)

    local yy = y + 22
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("공격력: " .. stats.atk, x + 4, yy)
    yy = yy + 16
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("방어력: " .. stats.def, x + 4, yy)
    yy = yy + 16
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("체  력: " .. stats.hp, x + 4, yy)
    yy = yy + 16
    love.graphics.setColor(0.4, 1, 1)
    love.graphics.print("속  도: " .. stats.spd, x + 4, yy)
    yy = yy + 16
    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print("치명타: " .. stats.crit .. "%", x + 4, yy)
end

return Equipment
