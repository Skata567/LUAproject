--[[
    main.lua — Orthographic Camera 데모

    1. (0, 0) 위치에 X축, Y축을 그린다
    2. 각 축 색은 빨간색(X), 녹색(Y)
    3. 화면 정중앙에 하얀색 원을 그린다
    4. 원의 반지름 = min(width, height) / 8
]]

local Camera = require("camera")
local cam = Camera.new()

function love.load()
    love.window.setTitle("Orthographic Camera Demo")
end

function love.update(dt)
    cam:handleInput(dt)
end

function love.draw()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- ===== 카메라 변환 시작 =====
    cam:attach()

    -- 격자 (참고용)
    cam:drawGrid(50, 500)

    -- 1. X축 (빨간색)
    love.graphics.setColor(1, 0, 0)
    love.graphics.setLineWidth(2)
    love.graphics.line(-w, 0, w, 0)

    -- 2. Y축 (녹색)
    love.graphics.setColor(0, 1, 0)
    love.graphics.line(0, -h, 0, h)

    love.graphics.setLineWidth(1)

    -- 3. 화면 정중앙에 하얀색 원
    --    카메라 원점(0,0)이 화면 중앙이므로 (0,0)에 그린다
    local radius = math.min(w, h) / 8
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 0, 0, radius)

    -- 원점 텍스트
    love.graphics.setColor(1, 1, 0)
    love.graphics.print("(0, 0)", 5, 5)

    -- ===== 카메라 변환 해제 =====
    cam:detach()

    -- HUD (카메라 변환 밖)
    cam:drawDebug()

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("방향키/WASD: 카메라 이동  |  마우스 휠: 줌", 10, 30)
end

function love.wheelmoved(x, y)
    cam:zoom(y * 0.1)
end
