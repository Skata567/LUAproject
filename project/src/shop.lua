--[[
    shop.lua — 상점 시스템

    - 아이템 구매/판매
    - 상점 재고는 방문 시 랜덤 갱신
    - 아이템 가격은 등급에 따라 결정
    - 판매 가격은 구매 가격의 50%
]]

local Item = require("item")

local Shop = {}
Shop.__index = Shop

-- 등급별 기본 가격 배율
local RARITY_PRICE = {
    common    = 1.0,
    uncommon  = 2.0,
    rare      = 4.0,
    epic      = 8.0,
    legendary = 20.0,
}

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

function Shop.new()
    local self = setmetatable({}, Shop)
    self.stock = {}        -- {item=Item, price=number}
    self.maxStock = 8
    self.x = 0
    self.y = 0
    self.slotW = 300
    self.slotH = 44
    self.scroll = 0
    self.selectedBuy = nil    -- 선택한 구매 아이템 인덱스
    self.selectedSell = nil   -- 선택한 판매 아이템 인덱스
    self.mode = "buy"         -- "buy" or "sell"
    return self
end

--- 상점 재고 갱신
function Shop:refresh()
    self.stock = {}
    self.scroll = 0
    self.selectedBuy = nil
    self.selectedSell = nil

    -- 가중치 기반 랜덤 선택
    local totalWeight = 0
    for _, entry in ipairs(SHOP_POOL) do
        totalWeight = totalWeight + entry.weight
    end

    local used = {}
    local count = 0
    local attempts = 0
    while count < self.maxStock and attempts < 50 do
        attempts = attempts + 1
        local roll = math.random() * totalWeight
        local cumulative = 0
        for i, entry in ipairs(SHOP_POOL) do
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
                        local price = entry.basePrice
                        -- 약간의 가격 변동
                        price = math.floor(price * (0.9 + math.random() * 0.2))
                        table.insert(self.stock, {item = item, price = price})
                        used[entry.id] = true
                        count = count + 1
                    end
                end
                break
            end
        end
    end
end

--- 아이템 판매 가격 계산
function Shop:getSellPrice(item)
    if not item then return 0 end
    -- 기본 가격 찾기
    for _, entry in ipairs(SHOP_POOL) do
        if entry.id == item.id then
            local price = math.floor(entry.basePrice * 0.5)
            if item.stackable then
                price = price * item.count
            end
            return math.max(1, price)
        end
    end
    -- 풀에 없는 아이템은 등급으로 계산
    local mult = RARITY_PRICE[item.rarity] or 1
    local base = math.max(1, (item.gridW * item.gridH) * 5)
    return math.floor(base * mult)
end

--- 구매 클릭 처리
function Shop:getBuySlotAt(sx, sy)
    if self.mode ~= "buy" then return nil end
    for i, entry in ipairs(self.stock) do
        local slotY = self.y + 60 + (i - 1) * (self.slotH + 4) - self.scroll
        if sx >= self.x and sx <= self.x + self.slotW and
           sy >= slotY and sy <= slotY + self.slotH then
            return i
        end
    end
    return nil
end

--- 판매 모드에서 인벤토리 아이템 선택 (인벤토리 쪽에서 처리)

--- 상점 그리기
function Shop:draw(font, playerGold, invItems)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 전체 배경
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 상점 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("상 점", 0, 15, sw, "center")

    -- 모드 탭
    local tabW = 120
    local tabH = 28
    local tabY = 40

    -- 구매 탭
    local buyTabX = sw / 2 - tabW - 5
    if self.mode == "buy" then
        love.graphics.setColor(0.3, 0.5, 0.3)
    else
        love.graphics.setColor(0.2, 0.2, 0.25)
    end
    love.graphics.rectangle("fill", buyTabX, tabY, tabW, tabH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("구매", buyTabX, tabY + 6, tabW, "center")

    -- 판매 탭
    local sellTabX = sw / 2 + 5
    if self.mode == "sell" then
        love.graphics.setColor(0.5, 0.3, 0.3)
    else
        love.graphics.setColor(0.2, 0.2, 0.25)
    end
    love.graphics.rectangle("fill", sellTabX, tabY, tabW, tabH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("판매", sellTabX, tabY + 6, tabW, "center")

    -- 골드 표시
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("골드: " .. playerGold, 0, tabY + 6, sw - 30, "right")

    -- 리스트 영역
    local listX = sw / 2 - self.slotW / 2
    local listY = 80
    self.x = listX
    self.y = listY - 60

    love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
    love.graphics.rectangle("fill", listX - 10, listY - 5, self.slotW + 20, sh - listY - 50, 6, 6)

    if self.mode == "buy" then
        self:drawBuyList(font, listX, listY, playerGold)
    else
        self:drawSellList(font, listX, listY, invItems)
    end

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 선택 | 우클릭: 구매/판매 | Esc: 나가기", 0, sh - 30, sw, "center")
end

local COLOR_GRAY = {0.5, 0.5, 0.5}

function Shop:drawBuyList(font, listX, listY, playerGold)
    if #self.stock == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("상점에 물건이 없습니다", listX, listY + 20, self.slotW, "center")
        return
    end

    for i, entry in ipairs(self.stock) do
        local item = entry.item
        local price = entry.price
        local sy = listY + (i - 1) * (self.slotH + 4) - self.scroll

        -- 선택 하이라이트
        if self.selectedBuy == i then
            love.graphics.setColor(0.3, 0.4, 0.3, 0.8)
        else
            love.graphics.setColor(0.15, 0.15, 0.2)
        end
        love.graphics.rectangle("fill", listX, sy, self.slotW, self.slotH, 4, 4)

        -- 등급 테두리
        local rc = item:getRarityColor()
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.6)
        love.graphics.rectangle("line", listX, sy, self.slotW, self.slotH, 4, 4)

        -- 아이콘
        love.graphics.setColor(item.color[1], item.color[2], item.color[3])
        love.graphics.print(item.icon, listX + 8, sy + 12)

        -- 이름
        love.graphics.setColor(rc[1], rc[2], rc[3])
        love.graphics.print(item.name, listX + 28, sy + 4)

        -- 스탯
        love.graphics.setColor(0.6, 0.6, 0.6)
        local statsText = item:getStatsText()
        if #statsText > 35 then statsText = statsText:sub(1, 35) .. ".." end
        love.graphics.print(statsText, listX + 28, sy + 22)

        -- 수량 (스택 가능 아이템)
        if item.stackable and item.count > 1 then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("x" .. item.count, listX + 180, sy + 4)
        end

        -- 가격
        if playerGold >= price then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(0.6, 0.3, 0.3)
        end
        love.graphics.printf(price .. "G", listX, sy + 12, self.slotW - 10, "right")
    end
end

function Shop:drawSellList(font, listX, listY, invItems)
    if not invItems or #invItems == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("판매할 아이템이 없습니다", listX, listY + 20, self.slotW, "center")
        return
    end

    for i, item in ipairs(invItems) do
        local price = self:getSellPrice(item)
        local sy = listY + (i - 1) * (self.slotH + 4) - self.scroll

        -- 선택 하이라이트
        if self.selectedSell == i then
            love.graphics.setColor(0.4, 0.3, 0.3, 0.8)
        else
            love.graphics.setColor(0.15, 0.15, 0.2)
        end
        love.graphics.rectangle("fill", listX, sy, self.slotW, self.slotH, 4, 4)

        -- 등급 테두리
        local rc = item:getRarityColor()
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.6)
        love.graphics.rectangle("line", listX, sy, self.slotW, self.slotH, 4, 4)

        -- 아이콘
        love.graphics.setColor(item.color[1], item.color[2], item.color[3])
        love.graphics.print(item.icon, listX + 8, sy + 12)

        -- 이름
        love.graphics.setColor(rc[1], rc[2], rc[3])
        love.graphics.print(item.name, listX + 28, sy + 4)

        -- 스탯
        love.graphics.setColor(0.6, 0.6, 0.6)
        local statsText = item:getStatsText()
        if #statsText > 35 then statsText = statsText:sub(1, 35) .. ".." end
        love.graphics.print(statsText, listX + 28, sy + 22)

        -- 수량
        if item.stackable and item.count > 1 then
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print("x" .. item.count, listX + 180, sy + 4)
        end

        -- 판매 가격
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.printf(price .. "G", listX, sy + 12, self.slotW - 10, "right")
    end
end

--- 탭 클릭 확인
function Shop:getTabAt(sx, sy)
    local sw = love.graphics.getWidth()
    local tabW = 120
    local tabH = 28
    local tabY = 40

    local buyTabX = sw / 2 - tabW - 5
    if sx >= buyTabX and sx <= buyTabX + tabW and sy >= tabY and sy <= tabY + tabH then
        return "buy"
    end

    local sellTabX = sw / 2 + 5
    if sx >= sellTabX and sx <= sellTabX + tabW and sy >= tabY and sy <= tabY + tabH then
        return "sell"
    end

    return nil
end

--- 판매 리스트에서 아이템 선택
function Shop:getSellSlotAt(sx, sy, invItems)
    if self.mode ~= "sell" then return nil end
    if not invItems then return nil end
    local listY = 80
    for i, _ in ipairs(invItems) do
        local slotY = listY + (i - 1) * (self.slotH + 4) - self.scroll
        if sx >= self.x and sx <= self.x + self.slotW and
           sy >= slotY and sy <= slotY + self.slotH then
            return i
        end
    end
    return nil
end

return Shop
