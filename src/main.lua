local Camera = require("camera")
local WorldAxis = require("worldAxis")
local cam
local circlePos = { x = 0, y = 0 }
local targetPos = { x = 0, y = 0 }

function love.load()
    -- 화면 높이의 절반을 orthoSize로 설정하여 1유닛 = 1픽셀 매핑을 기본으로 지정합니다.
    local height = love.graphics.getHeight()
    cam = Camera.new(0, 0, 5)
end

function love.update(dt)
    -- 원을 타겟 위치로 부드럽게 이동 (lerp)
    local lerpSpeed = 5
    circlePos.x = circlePos.x + (targetPos.x - circlePos.x) * lerpSpeed * dt
    circlePos.y = circlePos.y + (targetPos.y - circlePos.y) * lerpSpeed * dt
end

local function drawScreenAxis()
    local gr = love.graphics

    gr.setLineWidth(4)

    -- X 축
    gr.setColor(1, 0, 0)
    gr.line(0, 0, 30, 0)

    -- Y 축
    gr.setColor(0, 1, 0)
    gr.line(0, 0, 0, 30)

    gr.setLineWidth(1)
end

function love.draw()
    -- 1. 카메라 좌표계 내에서 월드 축 그리기 (+x, +y)
    cam:apply()
    WorldAxis.drawGrid(10, 1, 1)
    WorldAxis.draw(cam, 3, 4)

    -- 월드좌표에 원 그리기
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", circlePos.x, circlePos.y, 0.1)

    cam:reset()

    drawScreenAxis()

    -- 2. 스크린 기준 카메라 정보 출력
    cam:drawInfo(10, 10)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    cam:handleMousePress(x, y, button)

    -- 좌클릭 시 원의 타겟 위치 설정
    if button == 1 then
        local worldX, worldY = cam:screenToWorld(x, y)
        targetPos.x = worldX
        targetPos.y = worldY
    end
end

function love.mousereleased(x, y, button)
    cam:handleMouseRelease(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    cam:handleMouseMove(x, y)
end

function love.wheelmoved(x, y)
    cam:handleWheel(x, y)
end
