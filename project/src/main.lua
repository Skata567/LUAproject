--[[
    main.lua — 익스트랙션 RPG 인벤토리 데모

    - 그리드 기반 인벤토리 (타르코프 스타일)
    - 아이템 드래그 & 드롭
    - 장비 장착 슬롯
    - 아이템 툴팁
]]

local Item = require("item")
local Inventory = require("inventory")
local Equipment = require("equipment")

local inv = nil        -- 인벤토리
local equip = nil      -- 장비 슬롯
local font = nil

-- 드래그 상태
local drag = {
    item = nil,        -- 드래그 중인 아이템
    fromInv = nil,     -- 인벤토리에서 꺼냈는지
    fromSlot = nil,    -- 장비 슬롯에서 꺼냈는지
}

-- 호버 상태
local hoverItem = nil

function love.load()
    love.window.setTitle("Extraction RPG - Inventory System")
    love.window.setMode(1050, 620, {resizable = false})

    font = love.graphics.newFont("NanumGothicCoding.ttf", 13)
    love.graphics.setFont(font)

    math.randomseed(os.time())

    -- 인벤토리 생성 (10x8 그리드)
    inv = Inventory.new(10, 8)
    inv.x = 40
    inv.y = 60

    -- 장비 패널 위치
    equip = Equipment.new()
    equip.x = 680
    equip.y = 180

    -- 테스트 아이템 추가
    local testItems = {
        "short_sword", "long_sword", "battle_axe",
        "leather_armor", "chain_mail",
        "iron_helmet", "royal_crown",
        "leather_boots", "swift_boots",
        "copper_ring", "ruby_ring",
        "silver_amulet",
        "health_potion", "health_potion", "large_potion",
        "gold_coin", "dragon_scale",
    }

    for _, id in ipairs(testItems) do
        local item = Item.create(id)
        if item then
            if item.stackable and item.id == "health_potion" then
                item.count = math.random(1, 5)
            elseif item.stackable and item.id == "gold_coin" then
                item.count = math.random(10, 50)
            end
            inv:autoPlace(item)
        end
    end
end

function love.update(dt)
    -- 호버 아이템 업데이트
    if not drag.item then
        local mx, my = love.mouse.getPosition()
        hoverItem = inv:getItemAt(mx, my)

        -- 장비 슬롯 호버
        if not hoverItem then
            local slot = equip:getSlotAt(mx, my)
            if slot then
                hoverItem = equip:getItem(slot)
            end
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- 좌클릭: 드래그 시작
        local item = inv:getItemAt(x, y)
        if item then
            drag.item = item
            drag.fromInv = true
            drag.fromSlot = nil
            inv:removeItem(item)
            hoverItem = nil
            return
        end

        -- 장비 슬롯에서 드래그
        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                drag.item = eqItem
                drag.fromInv = false
                drag.fromSlot = slot
                hoverItem = nil
                return
            end
        end

    elseif button == 2 then
        -- 우클릭: 장착 / 해제
        local item = inv:getItemAt(x, y)
        if item and item.slot then
            -- 인벤토리 → 장착
            inv:removeItem(item)
            local prev = equip:equip(item)
            if prev then
                inv:autoPlace(prev)
            end
            return
        end

        -- 장비 슬롯 우클릭: 해제
        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                if not inv:autoPlace(eqItem) then
                    equip:equip(eqItem)
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 and drag.item then
        local item = drag.item

        -- 인벤토리 위에 드롭 시도
        local col, row = inv:screenToGrid(x, y)
        col = col - math.floor(item.gridW / 2)
        row = row - math.floor(item.gridH / 2)

        if inv:canPlace(item, col, row) then
            inv:placeItem(item, col, row)
            drag.item = nil
            return
        end

        -- 장비 슬롯 위에 드롭 시도
        local slot = equip:getSlotAt(x, y)
        if slot and item.slot == slot then
            local prev = equip:equip(item)
            if prev then
                inv:autoPlace(prev)
            end
            drag.item = nil
            return
        end

        -- 드롭 실패 → 원래 위치로
        if drag.fromInv then
            if not inv:autoPlace(item) then
                -- 인벤토리 꽉 참 (비상)
            end
        elseif drag.fromSlot then
            equip:equip(item)
        end

        drag.item = nil
    end
end

function love.draw()
    -- 배경
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.print("EXTRACTION RPG - INVENTORY", 40, 15)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("좌클릭: 드래그 | 우클릭: 장착/해제 | 아이템 위에 마우스: 툴팁", 40, 35)

    -- 인벤토리 그리기
    inv:draw(font)

    -- 장비 패널 그리기
    equip:draw(font)

    -- 장비 스탯 그리기
    equip:drawStats(610, 330)

    -- 드래그 중인 아이템
    if drag.item then
        local mx, my = love.mouse.getPosition()

        -- 배치 프리뷰
        inv:drawPlacePreview(drag.item, mx, my)

        -- 드래그 아이템
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end
end
