--[[
    shop.lua — 그리드 기반 상점 시스템

    - 상점 인벤토리(그리드)에 아이템이 배치됨
    - 상점→인벤토리 드래그 = 자동 구매 (골드 차감)
    - 인벤토리→상점 드래그 = 자동 판매 (골드 획득)
    - 골드 부족 시 아이템 원위치
    - 재고는 던전 클리어/사망 시에만 갱신
]]

local Item = require("item")
local Inventory = require("inventory")

local Shop = {}
Shop.__index = Shop

-- 상점에 등장할 수 있는 아이템 풀
local SHOP_POOL = {
    {id = "health_potion", basePrice = 15,  weight = 30},
    {id = "large_potion",  basePrice = 40,  weight = 15},
    {id = "short_sword",   basePrice = 25,  weight = 20},
    {id = "dagger",        basePrice = 35,  weight = 15},
    {id = "long_sword",    basePrice = 60,  weight = 10},
    {id = "battle_axe",    basePrice = 100, weight = 5},
    {id = "wooden_shield", basePrice = 20,  weight = 20},
    {id = "iron_shield",   basePrice = 50,  weight = 10},
    {id = "leather_armor", basePrice = 30,  weight = 18},
    {id = "chain_mail",    basePrice = 70,  weight = 8},
    {id = "iron_helmet",   basePrice = 25,  weight = 18},
    {id = "royal_crown",   basePrice = 150, weight = 3},
    {id = "leather_boots", basePrice = 20,  weight = 18},
    {id = "swift_boots",   basePrice = 80,  weight = 5},
    {id = "copper_ring",   basePrice = 15,  weight = 15},
    {id = "ruby_ring",     basePrice = 120, weight = 3},
    {id = "silver_amulet", basePrice = 40,  weight = 10},
}

-- 등급별 기본 가격 배율 (풀에 없는 아이템용)
local RARITY_PRICE = {
    common    = 1.0,
    uncommon  = 2.0,
    rare      = 4.0,
    epic      = 8.0,
    legendary = 20.0,
}

function Shop.new()
    local self = setmetatable({}, Shop)
    self.grid = Inventory.new(10, 6)  -- 상점 그리드
    self.prices = {}                   -- item -> price 매핑
    self.needsRefresh = true           -- 첫 방문 시 갱신 필요
    return self
end

--- 아이템 가격 조회
function Shop:getPrice(item)
    if not item then return 0 end
    return self.prices[item] or 0
end

--- 아이템 판매 가격 계산
function Shop:getSellPrice(item)
    if not item then return 0 end
    for _, entry in ipairs(SHOP_POOL) do
        if entry.id == item.id then
            local price = math.floor(entry.basePrice * 0.5)
            if item.stackable then
                price = price * item.count
            end
            return math.max(1, price)
        end
    end
    local mult = RARITY_PRICE[item.rarity] or 1
    local base = math.max(1, (item.gridW * item.gridH) * 5)
    return math.floor(base * mult)
end

--- 상점 재고 갱신
function Shop:refresh()
    self.grid = Inventory.new(10, 6)
    self.prices = {}

    local totalWeight = 0
    for _, entry in ipairs(SHOP_POOL) do
        totalWeight = totalWeight + entry.weight
    end

    local used = {}
    local count = 0
    local maxItems = 8
    local attempts = 0
    while count < maxItems and attempts < 50 do
        attempts = attempts + 1
        local roll = math.random() * totalWeight
        local cumulative = 0
        for _, entry in ipairs(SHOP_POOL) do
            cumulative = cumulative + entry.weight
            if roll <= cumulative then
                if not used[entry.id] or entry.id == "health_potion" or entry.id == "large_potion" then
                    local item = Item.create(entry.id)
                    if item then
                        if item.stackable and item.id == "health_potion" then
                            item.count = math.random(1, 3)
                        elseif item.stackable and item.id == "large_potion" then
                            item.count = math.random(1, 2)
                        end
                        local price = math.floor(entry.basePrice * (0.9 + math.random() * 0.2))
                        if self.grid:autoPlace(item) then
                            self.prices[item] = price
                            used[entry.id] = true
                            count = count + 1
                        end
                    end
                end
                break
            end
        end
    end

    self.needsRefresh = false
end

--- 상점에서 아이템 제거 (구매 시)
function Shop:removeItem(item)
    self.grid:removeItem(item)
    self.prices[item] = nil
end

--- 상점에 아이템 추가 (판매 시)
function Shop:addItem(item, price)
    if self.grid:autoPlace(item) then
        self.prices[item] = price
        return true
    end
    return false
end

--- 상점 그리드에서 아이템 가져오기
function Shop:getItemAt(sx, sy)
    return self.grid:getItemAt(sx, sy)
end

--- 상점 그리드 좌표 변환
function Shop:screenToGrid(sx, sy)
    return self.grid:screenToGrid(sx, sy)
end

--- 상점에 아이템 배치 가능한지
function Shop:canPlace(item, col, row)
    return self.grid:canPlace(item, col, row)
end

--- 상점에 아이템 배치
function Shop:placeItem(item, col, row, price)
    if self.grid:placeItem(item, col, row) then
        if price then
            self.prices[item] = price
        end
        return true
    end
    return false
end

--- 상점 그리기
function Shop:draw(font, playerGold)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 전체 배경
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("상 점", 0, 8, sw, "center")

    -- 골드 표시
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("골드: " .. playerGold, 0, 8, sw - 20, "right")

    -- 상점 그리드 라벨
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print("상점 재고", self.grid.x, self.grid.y - 20)

    -- 상점 그리드 그리기
    self.grid:draw(font)

    -- 가격 표시 (각 아이템 위에)
    for _, item in ipairs(self.grid.items) do
        local price = self.prices[item] or 0
        local ix = self.grid.x + (item._gridCol - 1) * self.grid.cellSize
        local iy = self.grid.y + (item._gridRow - 1) * self.grid.cellSize

        -- 가격 배경
        love.graphics.setColor(0, 0, 0, 0.7)
        local priceText = price .. "G"
        local tw = font:getWidth(priceText)
        love.graphics.rectangle("fill", ix, iy, tw + 4, 14)

        -- 가격 텍스트
        if playerGold >= price then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(0.7, 0.3, 0.3)
        end
        love.graphics.print(priceText, ix + 2, iy)
    end
end

return Shop
