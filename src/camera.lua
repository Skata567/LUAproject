--[[
1. 유니티의 orthographic camera를 루아로 구현해보자.
2. 0,0 을 기준으로 카메라를 이동시켜보자.
3. 유니티의 orthoSize를 구현해보자.
]]

local Camera = {}
Camera.__index = Camera

function Camera.new(x, y, orthoSize, rotation)
    local self = setmetatable({}, Camera)
    self.x = x or 0
    self.y = y or 0
    self.orthoSize = orthoSize or 5 -- Default to 5 (pixel-perfect for 540p vertical height)
    self.rotation = rotation or 0
    self.zoom = nil                 -- Will be lazily initialized on first apply/set
    return self
end

function Camera:apply()
    -- Lazy initialization of zoom when love.graphics is fully ready
    if not self.zoom then
        local height = love.graphics.getHeight()
        if height == 0 then height = 600 end
        self.zoom = height / (2 * self.orthoSize)
    end

    -- Keep self.zoom dynamically in sync in case the window height has changed
    self.zoom = love.graphics.getHeight() / (2 * self.orthoSize)

    love.graphics.push()
    love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
    love.graphics.rotate(-self.rotation)

    local currentZoom = self.zoom
    love.graphics.scale(currentZoom, -currentZoom)
    love.graphics.translate(-self.x, -self.y)
end

function Camera:reset()
    love.graphics.pop()
end

function Camera:move(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
end

function Camera:setPosition(x, y)
    self.x = x
    self.y = y
end

function Camera:setZoom(zoom)
    self.zoom = zoom
    self.orthoSize = love.graphics.getHeight() / (2 * zoom)
end

function Camera:setOrthoSize(size)
    self.orthoSize = size
    self.zoom = love.graphics.getHeight() / (2 * size)
end

function Camera:getOrthoSize()
    return self.orthoSize
end

function Camera:setRotation(rotation)
    self.rotation = rotation
end

function Camera:handleMousePress(x, y, button)
    if button == 3 then -- 가운데 버튼 (마우스 휠 클릭)
        self.isDragging = true
        self.dragStartX = x
        self.dragStartY = y
        self.cameraStartX = self.x
        self.cameraStartY = self.y
    end
end

function Camera:handleMouseRelease(x, y, button)
    if button == 3 then
        self.isDragging = false
    end
end

function Camera:handleMouseMove(x, y)
    if self.isDragging then
        local dx = (x - self.dragStartX) / self.zoom
        local dy = (y - self.dragStartY) / self.zoom
        self.x = self.cameraStartX - dx
        self.y = self.cameraStartY + dy -- Y축이 반전되어 있어서 +
    end
end

function Camera:handleWheel(x, y)
    local zoomSpeed = 0.1
    if y > 0 then
        -- 휠 위로 올리면 축소 (줌 아웃)
        self.orthoSize = math.max(0.1, self.orthoSize - zoomSpeed)
    elseif y < 0 then
        -- 휠 아래로 내리면 확대 (줌 인)
        self.orthoSize = self.orthoSize + zoomSpeed
    end
    self.zoom = love.graphics.getHeight() / (2 * self.orthoSize)
end

-- 스크린 좌표 → 월드 좌표 변환
function Camera:screenToWorld(sx, sy)
    local sw, sh = love.graphics.getDimensions()
    if not self.zoom then
        self.zoom = sh / (2 * self.orthoSize)
    end
    return (sx - sw / 2) / self.zoom + self.x,
        -(sy - sh / 2) / self.zoom + self.y    -- Y축이 반전되어 있어서 -
end

-- 월드 좌표 → 스크린 좌표 변환
function Camera:worldToScreen(wx, wy)
    local sw, sh = love.graphics.getDimensions()
    if not self.zoom then
        self.zoom = sh / (2 * self.orthoSize)
    end
    return (wx - self.x) * self.zoom + sw / 2,
        -(wy - self.y) * self.zoom + sh / 2    -- Y축이 반전되어 있어서 -
end

--- 카메라의 현재 정보(위치, orthoSize, zoom, 회전각)를 화면에 오버레이로 표시합니다.
-- @param x 표시할 화면 좌측 X 좌표 (기본값: 10)
-- @param y 표시할 화면 상단 Y 좌표 (기본값: 10)
function Camera:drawInfo(x, y)
    x = x or 10
    y = y or 10

    -- 현재 그리기 색상 저장
    local r, g, b, a = love.graphics.getColor()

    -- 디버그 정보 문자열 생성
    local rotation_deg = math.deg(self.rotation)
    local info = string.format(
        "Camera Information\n" ..
        "-------------------\n" ..
        "Position  : (%.2f, %.2f)\n" ..
        "Ortho Size: %.1f\n" ..
        "Zoom      : %.4f\n" ..
        "Rotation  : %.1f° (%.3f rad)",
        self.x, self.y,
        self.orthoSize,
        self.zoom or 0,
        rotation_deg, self.rotation
    )

    -- 폰트 정보 획득 및 배경 상자 크기 계산
    local font = love.graphics.getFont()
    local textWidth = font:getWidth("Camera Information   ")
    local textHeight = font:getHeight() * 7 + 10

    -- 반투명 어두운 배경 상자 그리기
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x - 8, y - 8, textWidth + 16, textHeight + 6, 4, 4) -- 약간의 둥근 모서리 적용

    -- 개발자 콘솔 느낌의 세련된 민트색상으로 텍스트 그리기
    love.graphics.setColor(0.2, 1, 0.8, 1)
    love.graphics.print(info, x, y)

    -- 원래 그리기 색상 복원
    love.graphics.setColor(r, g, b, a)
end

return Camera
