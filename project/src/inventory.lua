--[[
    inventory.lua — 그리드 기반 인벤토리 (타르코프/익스트랙션 스타일)

    - NxM 그리드에서 아이템이 크기(gridW x gridH)만큼 칸을 차지
    - 마우스로 아이템 드래그 & 드롭
    - 아이템 우클릭으로 장착/사용
]]

local Inventory = {}
Inventory.__index = Inventory

local CELL_SIZE = 48

--- 인벤토리 생성
-- @param cols  그리드 가로 칸 수
-- @param rows  그리드 세로 칸 수
function Inventory.new(cols, rows)
    local self = setmetatable({}, Inventory)
    self.cols = cols or 10
    self.rows = rows or 6
    self.cellSize = CELL_SIZE
    self.grid = {}       -- grid[row][col] = item 또는 nil
    self.items = {}      -- 인벤토리에 있는 아이템 리스트
    self.x = 0           -- 화면상 인벤토리 위치
    self.y = 0

    -- 그리드 초기화
    for r = 1, self.rows do
        self.grid[r] = {}
        for c = 1, self.cols do
            self.grid[r][c] = nil
        end
    end

    return self
end

--- 특정 위치에 아이템을 놓을 수 있는지 확인
function Inventory:canPlace(item, col, row)
    if col < 1 or row < 1 then return false end
    if col + item.gridW - 1 > self.cols then return false end
    if row + item.gridH - 1 > self.rows then return false end

    for r = row, row + item.gridH - 1 do
        for c = col, col + item.gridW - 1 do
            if self.grid[r][c] ~= nil and self.grid[r][c] ~= item then
                return false
            end
        end
    end
    return true
end

--- 아이템을 그리드에 배치
function Inventory:placeItem(item, col, row)
    if not self:canPlace(item, col, row) then
        return false
    end

    for r = row, row + item.gridH - 1 do
        for c = col, col + item.gridW - 1 do
            self.grid[r][c] = item
        end
    end

    item._gridCol = col
    item._gridRow = row
    item._inventory = self

    -- 아이템 리스트에 없으면 추가
    local found = false
    for _, it in ipairs(self.items) do
        if it == item then found = true; break end
    end
    if not found then
        table.insert(self.items, item)
    end

    return true
end

--- 아이템을 그리드에서 제거
function Inventory:removeItem(item)
    if not item._gridCol or not item._gridRow then return end

    for r = item._gridRow, item._gridRow + item.gridH - 1 do
        for c = item._gridCol, item._gridCol + item.gridW - 1 do
            if r >= 1 and r <= self.rows and c >= 1 and c <= self.cols then
                if self.grid[r][c] == item then
                    self.grid[r][c] = nil
                end
            end
        end
    end

    for i, it in ipairs(self.items) do
        if it == item then
            table.remove(self.items, i)
            break
        end
    end

    item._gridCol = nil
    item._gridRow = nil
    item._inventory = nil
end

--- 빈 자리를 찾아서 아이템 자동 배치
function Inventory:autoPlace(item)
    for r = 1, self.rows do
        for c = 1, self.cols do
            if self:canPlace(item, c, r) then
                return self:placeItem(item, c, r)
            end
        end
    end
    return false
end

--- 화면 좌표 → 그리드 좌표 변환
function Inventory:screenToGrid(sx, sy)
    local col = math.floor((sx - self.x) / self.cellSize) + 1
    local row = math.floor((sy - self.y) / self.cellSize) + 1
    return col, row
end

--- 화면 좌표에 있는 아이템 가져오기
function Inventory:getItemAt(sx, sy)
    local col, row = self:screenToGrid(sx, sy)
    if col >= 1 and col <= self.cols and row >= 1 and row <= self.rows then
        return self.grid[row][col]
    end
    return nil
end

--- 모든 아이템 리스트 반환
function Inventory:getAllItems()
    return self.items
end

--- 인벤토리 그리기
function Inventory:draw(font)
    local cs = self.cellSize

    -- 배경
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", self.x - 4, self.y - 28, self.cols * cs + 8, self.rows * cs + 36)

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.print("인벤토리", self.x, self.y - 24)

    -- 빈 그리드 칸 그리기
    for r = 1, self.rows do
        for c = 1, self.cols do
            local cx = self.x + (c - 1) * cs
            local cy = self.y + (r - 1) * cs

            love.graphics.setColor(0.15, 0.15, 0.2)
            love.graphics.rectangle("fill", cx, cy, cs, cs)
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.rectangle("line", cx, cy, cs, cs)
        end
    end

    -- 아이템 그리기
    local drawn = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            local item = self.grid[r][c]
            if item and not drawn[item] then
                drawn[item] = true
                self:drawItem(item)
            end
        end
    end
end

--- 개별 아이템 그리기
function Inventory:drawItem(item)
    if not item._gridCol or not item._gridRow then return end

    local cs = self.cellSize
    local cx = self.x + (item._gridCol - 1) * cs
    local cy = self.y + (item._gridRow - 1) * cs
    local w = item.gridW * cs
    local h = item.gridH * cs

    -- 아이템 배경
    local rc = item:getRarityColor()
    love.graphics.setColor(rc[1] * 0.2, rc[2] * 0.2, rc[3] * 0.2, 0.8)
    love.graphics.rectangle("fill", cx + 1, cy + 1, w - 2, h - 2)

    -- 등급 테두리
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx + 1, cy + 1, w - 2, h - 2)
    love.graphics.setLineWidth(1)

    -- 아이콘
    love.graphics.setColor(item.color[1], item.color[2], item.color[3])
    local iconX = cx + w / 2 - 6
    local iconY = cy + h / 2 - 8
    love.graphics.print(item.icon, iconX, iconY)

    -- 아이템 이름 (작은 텍스트)
    love.graphics.setColor(1, 1, 1, 0.9)
    local nameW = love.graphics.getFont():getWidth(item.name)
    if nameW < w - 4 then
        love.graphics.print(item.name, cx + 2, cy + 2)
    end

    -- 스택 수량
    if item.stackable and item.count > 1 then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("x" .. item.count, cx + w - 24, cy + h - 16)
    end
end

--- 드래그 중인 아이템 그리기 (마우스 위치에)
function Inventory:drawDragItem(item, mx, my)
    local cs = self.cellSize
    local w = item.gridW * cs
    local h = item.gridH * cs
    local dx = mx - w / 2
    local dy = my - h / 2

    -- 반투명 배경
    local rc = item:getRarityColor()
    love.graphics.setColor(rc[1] * 0.3, rc[2] * 0.3, rc[3] * 0.3, 0.6)
    love.graphics.rectangle("fill", dx, dy, w, h)

    -- 테두리
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dx, dy, w, h)
    love.graphics.setLineWidth(1)

    -- 아이콘
    love.graphics.setColor(item.color[1], item.color[2], item.color[3], 0.8)
    love.graphics.print(item.icon, dx + w / 2 - 6, dy + h / 2 - 8)
end

--- 배치 가능 여부 프리뷰 그리기
function Inventory:drawPlacePreview(item, mx, my)
    local col, row = self:screenToGrid(mx, my)
    -- 아이템 중앙 기준으로 보정
    col = col - math.floor(item.gridW / 2)
    row = row - math.floor(item.gridH / 2)

    local cs = self.cellSize
    local canPlace = self:canPlace(item, col, row)

    for r = row, row + item.gridH - 1 do
        for c = col, col + item.gridW - 1 do
            local cx = self.x + (c - 1) * cs
            local cy = self.y + (r - 1) * cs

            if canPlace then
                love.graphics.setColor(0, 1, 0, 0.3)
            else
                love.graphics.setColor(1, 0, 0, 0.3)
            end
            love.graphics.rectangle("fill", cx, cy, cs, cs)
        end
    end

    return col, row, canPlace
end

--- 마우스 아래의 아이템 툴팁 그리기
function Inventory:drawTooltip(item, mx, my)
    if not item then return end

    local lines = {}
    table.insert(lines, item.name)
    table.insert(lines, item:getRarityName())
    if item:getSlotName() then
        table.insert(lines, "부위: " .. item:getSlotName())
    end
    local statsText = item:getStatsText()
    if statsText ~= "" then
        table.insert(lines, statsText)
    end
    if item.description ~= "" then
        table.insert(lines, item.description)
    end
    if item.slot then
        table.insert(lines, "[우클릭: 장착]")
    end

    local font = love.graphics.getFont()
    local lineH = font:getHeight() + 2
    local maxW = 0
    for _, line in ipairs(lines) do
        local lw = font:getWidth(line)
        if lw > maxW then maxW = lw end
    end

    local tw = maxW + 16
    local th = #lines * lineH + 12
    local tx = mx + 16
    local ty = my

    -- 화면 밖으로 나가지 않도록
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    if tx + tw > sw then tx = mx - tw - 8 end
    if ty + th > sh then ty = sh - th end

    -- 배경
    love.graphics.setColor(0.05, 0.05, 0.1, 0.95)
    love.graphics.rectangle("fill", tx, ty, tw, th, 4, 4)
    local rc = item:getRarityColor()
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.8)
    love.graphics.rectangle("line", tx, ty, tw, th, 4, 4)

    -- 텍스트
    local yy = ty + 6
    for i, line in ipairs(lines) do
        if i == 1 then
            love.graphics.setColor(rc[1], rc[2], rc[3])
        elseif i == 2 then
            love.graphics.setColor(rc[1] * 0.8, rc[2] * 0.8, rc[3] * 0.8)
        elseif line:find("%[") then
            love.graphics.setColor(0.5, 0.8, 1)
        else
            love.graphics.setColor(0.9, 0.9, 0.9)
        end
        love.graphics.print(line, tx + 8, yy)
        yy = yy + lineH
    end
end

return Inventory
