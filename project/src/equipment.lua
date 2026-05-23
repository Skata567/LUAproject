--[[
    equipment.lua — 장비 장착 시스템

    - 무기, 방어구, 투구, 신발, 반지, 목걸이 슬롯
    - 장착/해제 시 스탯 자동 계산
    - 장착 슬롯 UI 그리기
]]

local Equipment = {}
Equipment.__index = Equipment

local SLOT_SIZE = 56

-- 슬롯 레이아웃 정의 (캐릭터 주변 배치)
local SLOT_LAYOUT = {
    {slot = "helmet",  label = "투구",   offsetX = 0,    offsetY = -70},
    {slot = "amulet",  label = "목걸이", offsetX = 70,   offsetY = -35},
    {slot = "weapon",  label = "무기",   offsetX = -70,  offsetY = 0},
    {slot = "armor",   label = "방어구", offsetX = 0,    offsetY = 0},
    {slot = "ring",    label = "반지",   offsetX = 70,   offsetY = 35},
    {slot = "boots",   label = "신발",   offsetX = 0,    offsetY = 70},
}

function Equipment.new()
    local self = setmetatable({}, Equipment)
    self.slots = {
        weapon = nil,
        armor  = nil,
        helmet = nil,
        boots  = nil,
        ring   = nil,
        amulet = nil,
    }
    self.x = 0
    self.y = 0
    self.slotSize = SLOT_SIZE
    return self
end

--- 장착 가능 여부 확인
function Equipment:canEquip(item)
    if not item or not item.slot then return false end
    return self.slots[item.slot] ~= nil or item.slot ~= nil
end

--- 아이템 장착 (기존 아이템 반환)
function Equipment:equip(item)
    if not item or not item.slot then return nil end
    local prev = self.slots[item.slot]
    self.slots[item.slot] = item
    return prev
end

--- 슬롯 해제 (아이템 반환)
function Equipment:unequip(slotName)
    local item = self.slots[slotName]
    self.slots[slotName] = nil
    return item
end

--- 장착된 아이템 가져오기
function Equipment:getItem(slotName)
    return self.slots[slotName]
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

--- 장비 패널 그리기
function Equipment:draw(font)
    local ss = self.slotSize
    local hs = ss / 2

    -- 배경
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", self.x - 110, self.y - 110, 220, 220, 8, 8)

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

        -- 슬롯 배경
        love.graphics.setColor(0.15, 0.15, 0.2)
        love.graphics.rectangle("fill", cx, cy, ss, ss, 4, 4)

        if item then
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
