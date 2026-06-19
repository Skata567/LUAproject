-- project/src/systems/virtual_resolution.lua
-- 가상 해상도 및 스케일링 관리 모듈

local VirtualResolution = {}

local BASE_WIDTH = 1280
local BASE_HEIGHT = 720

-- 기존 LÖVE 함수 보관
local orig_getWidth = love.graphics.getWidth
local orig_getHeight = love.graphics.getHeight
local orig_getPosition = love.mouse.getPosition
local orig_getX = love.mouse.getX
local orig_getY = love.mouse.getY

-- 현재 스케일과 오프셋을 계산하는 함수
function VirtualResolution.getTransform()
    local windowW, windowH = orig_getWidth(), orig_getHeight()
    local scale = math.min(windowW / BASE_WIDTH, windowH / BASE_HEIGHT)
    local tx = (windowW - BASE_WIDTH * scale) / 2
    local ty = (windowH - BASE_HEIGHT * scale) / 2
    return scale, tx, ty
end

-- 물리 좌표(화면) -> 가상 좌표(게임) 변환
function VirtualResolution.screenToVirtual(x, y)
    local scale, tx, ty = VirtualResolution.getTransform()
    local vx = (x - tx) / scale
    local vy = (y - ty) / scale
    return vx, vy
end

-- 가상 좌표(게임) -> 물리 좌표(화면) 변환
function VirtualResolution.virtualToScreen(vx, vy)
    local scale, tx, ty = VirtualResolution.getTransform()
    local x = vx * scale + tx
    local y = vy * scale + ty
    return x, y
end

-- LÖVE 엔진 전역 함수 오버라이드
function VirtualResolution.applyHooks()
    love.graphics.getWidth = function() return BASE_WIDTH end
    love.graphics.getHeight = function() return BASE_HEIGHT end

    love.mouse.getPosition = function()
        local x, y = orig_getPosition()
        return VirtualResolution.screenToVirtual(x, y)
    end
    love.mouse.getX = function()
        local x, y = orig_getPosition()
        local vx, vy = VirtualResolution.screenToVirtual(x, y)
        return vx
    end
    love.mouse.getY = function()
        local x, y = orig_getPosition()
        local vx, vy = VirtualResolution.screenToVirtual(x, y)
        return vy
    end
end

-- draw 시 호출할 변환 적용 함수
function VirtualResolution.push()
    local scale, tx, ty = VirtualResolution.getTransform()
    love.graphics.push()
    love.graphics.translate(tx, ty)
    love.graphics.scale(scale, scale)
    
    -- 레터박스 영역 바깥(화면 남는 여백)은 그리지 않도록 클리핑 (옵션)
    -- love.graphics.setScissor(tx, ty, BASE_WIDTH * scale, BASE_HEIGHT * scale)
end

function VirtualResolution.pop()
    -- love.graphics.setScissor()
    love.graphics.pop()
    
    -- 레터박스 여백을 검은색으로 가리기
    local scale, tx, ty = VirtualResolution.getTransform()
    local windowW, windowH = orig_getWidth(), orig_getHeight()
    love.graphics.setColor(0, 0, 0)
    -- 좌측, 우측
    if tx > 0 then
        love.graphics.rectangle("fill", 0, 0, tx, windowH)
        love.graphics.rectangle("fill", windowW - tx, 0, tx, windowH)
    end
    -- 상단, 하단
    if ty > 0 then
        love.graphics.rectangle("fill", 0, 0, windowW, ty)
        love.graphics.rectangle("fill", 0, windowH - ty, windowW, ty)
    end
    love.graphics.setColor(1, 1, 1) -- 색상 초기화
end

return VirtualResolution
