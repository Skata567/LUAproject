--[[
    camera.lua — Unity 스타일 Orthographic Camera (LÖVE2D)

    1. 유니티의 orthographic camera를 루아로 구현
    2. (0, 0)을 기준으로 카메라 이동 가능

    사용법:
        local Camera = require("camera")
        local cam = Camera.new()

        function love.update(dt)
            -- 방향키로 카메라 이동
            cam:handleInput(dt)
            -- 또는 직접 위치 설정
            cam:setPosition(100, 200)
        end

        function love.draw()
            cam:attach()       -- 카메라 변환 시작
            -- 여기서 월드 오브젝트를 그린다
            cam:detach()       -- 카메라 변환 해제
            cam:drawDebug()    -- (선택) 디버그 정보 표시
        end

        function love.wheelmoved(x, y)
            cam:zoom(y * 0.1)  -- 마우스 휠로 줌
        end
]]

local Camera = {}
Camera.__index = Camera

--- 새 카메라 생성
-- @param x      초기 X 위치 (기본 0)
-- @param y      초기 Y 위치 (기본 0)
-- @param scale  초기 줌 배율 (기본 1)
function Camera.new(x, y, scale)
    local self = setmetatable({}, Camera)
    self.x = x or 0
    self.y = y or 0
    self.scale = scale or 1
    self.rotation = 0
    self.minScale = 0.1
    self.maxScale = 10
    self.moveSpeed = 200
    return self
end

--- 카메라 위치 설정
function Camera:setPosition(x, y)
    self.x = x
    self.y = y
end

--- 카메라 위치 가져오기
function Camera:getPosition()
    return self.x, self.y
end

--- 카메라 이동 (델타만큼)
function Camera:move(dx, dy)
    self.x = self.x + (dx or 0)
    self.y = self.y + (dy or 0)
end

--- 줌 설정 (orthographic size 개념)
-- Unity의 orthographicSize와 유사: 값이 클수록 더 많은 영역이 보임
function Camera:setScale(s)
    self.scale = math.max(self.minScale, math.min(self.maxScale, s))
end

--- 줌 인/아웃 (델타만큼)
function Camera:zoom(delta)
    self:setScale(self.scale + (delta or 0))
end

--- 줌 배율 가져오기
function Camera:getScale()
    return self.scale
end

--- 회전 설정 (라디안)
function Camera:setRotation(r)
    self.rotation = r
end

--- 회전값 가져오기
function Camera:getRotation()
    return self.rotation
end

--- 카메라 변환 적용 (draw 시작 전에 호출)
-- Unity의 카메라처럼 (0, 0)이 화면 중앙에 오도록 변환
function Camera:attach()
    love.graphics.push()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- 화면 중앙으로 이동 → (0,0)이 화면 중앙
    love.graphics.translate(w / 2, h / 2)
    -- 줌 적용
    love.graphics.scale(self.scale, self.scale)
    -- 회전 적용
    love.graphics.rotate(-self.rotation)
    -- 카메라 위치만큼 반대로 이동 (카메라가 오른쪽으로 가면 월드는 왼쪽으로)
    love.graphics.translate(-self.x, -self.y)
end

--- 카메라 변환 해제 (draw 끝난 후 호출)
function Camera:detach()
    love.graphics.pop()
end

--- 화면 좌표 → 월드 좌표 변환
-- 마우스 클릭 위치를 월드 좌표로 변환할 때 사용
function Camera:screenToWorld(sx, sy)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local wx = (sx - w / 2) / self.scale + self.x
    local wy = (sy - h / 2) / self.scale + self.y
    return wx, wy
end

--- 월드 좌표 → 화면 좌표 변환
function Camera:worldToScreen(wx, wy)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local sx = (wx - self.x) * self.scale + w / 2
    local sy = (wy - self.y) * self.scale + h / 2
    return sx, sy
end

--- 카메라가 보는 영역(AABB) 반환
-- @return left, top, right, bottom (월드 좌표)
function Camera:getVisibleArea()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local halfW = (w / 2) / self.scale
    local halfH = (h / 2) / self.scale
    return self.x - halfW, self.y - halfH, self.x + halfW, self.y + halfH
end

--- 방향키/WASD로 카메라 이동 + 마우스 휠 줌 (기본 입력 처리)
function Camera:handleInput(dt)
    local speed = self.moveSpeed / self.scale
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        self:move(-speed * dt, 0)
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        self:move(speed * dt, 0)
    end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        self:move(0, -speed * dt)
    end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        self:move(0, speed * dt)
    end
end

--- 디버그 정보 표시 (HUD, 카메라 변환 밖에서 호출)
function Camera:drawDebug()
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print(string.format(
        "카메라: (%.1f, %.1f)  줌: %.2fx  회전: %.1f°",
        self.x, self.y, self.scale, math.deg(self.rotation)
    ), 10, 10)
end

--- 원점(0,0) 기준 십자선 + 격자 그리기 (카메라 변환 안에서 호출)
function Camera:drawGrid(gridSize, gridRange)
    gridSize = gridSize or 50
    gridRange = gridRange or 1000

    -- 격자선
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    for x = -gridRange, gridRange, gridSize do
        love.graphics.line(x, -gridRange, x, gridRange)
    end
    for y = -gridRange, gridRange, gridSize do
        love.graphics.line(-gridRange, y, gridRange, y)
    end

    -- X축 (빨간색)
    love.graphics.setColor(1, 0, 0, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(-gridRange, 0, gridRange, 0)

    -- Y축 (녹색)
    love.graphics.setColor(0, 1, 0, 0.8)
    love.graphics.line(0, -gridRange, 0, gridRange)

    -- 원점 표시
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", 0, 0, 4 / self.scale)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("(0,0)", 5, 5)

    love.graphics.setLineWidth(1)
end

return Camera