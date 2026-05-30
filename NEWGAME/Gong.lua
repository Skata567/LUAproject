local config = {
    windowWidth = 800,
    windowHeight = 600,
    boxWidth = 230,
    boxHeight = 230,
    boxLineWidth = 5,
    buttonRadius = 34,
    buttonEdgeMargin = 18,
    ballRadius = 14,
    gravity = 0,
    launchSpeed = 520,
    launchSideSpeed = 180,
    restitution = 1,
    damping = 1,
    rotationSpeed = math.rad(95),
    maxBallSpeed = 760,
}

local box = {
    x = 400,
    y = 285,
    angle = 0,
}

local ball = {
    x = 400,
    y = 285,
    vx = 0,
    vy = 0,
    isReleased = false,
}

local buttons = {
    left = { x = 0, y = 0, direction = -1, isDown = false },
    right = { x = 0, y = 0, direction = 1, isDown = false },
}

local font
local smallFont

local function rotatePoint(x, y, angle)
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    return x * cosAngle - y * sinAngle, x * sinAngle + y * cosAngle
end

local function worldToBoxLocal(x, y)
    return rotatePoint(x - box.x, y - box.y, -box.angle)
end

local function boxLocalToWorld(x, y)
    local worldX, worldY = rotatePoint(x, y, box.angle)

    return worldX + box.x, worldY + box.y
end

local function getRotatedBoxCorners()
    local halfWidth = config.boxWidth * 0.5
    local halfHeight = config.boxHeight * 0.5
    local corners = {
        { x = -halfWidth, y = -halfHeight },
        { x = halfWidth, y = -halfHeight },
        { x = halfWidth, y = halfHeight },
        { x = -halfWidth, y = halfHeight },
    }

    for _, corner in ipairs(corners) do
        corner.x, corner.y = boxLocalToWorld(corner.x, corner.y)
    end

    return corners
end

local function resetBall()
    ball.x = box.x
    ball.y = box.y
    ball.vx = 0
    ball.vy = 0
    ball.isReleased = false
end

local function releaseBall()
    if ball.isReleased then
        return
    end

    ball.isReleased = true
    -- 중력 없이도 바로 튕기는 느낌이 나도록 처음에만 빠른 속도를 준다.
    ball.vx = config.launchSideSpeed
    ball.vy = config.launchSpeed
end

local function reflectVelocity(normalX, normalY)
    local dot = ball.vx * normalX + ball.vy * normalY

    -- 공이 벽 안쪽으로 들어갈 때만 반사해서 떨림을 줄인다.
    if dot >= 0 then
        return
    end

    ball.vx = (ball.vx - 2 * dot * normalX) * config.restitution
    ball.vy = (ball.vy - 2 * dot * normalY) * config.restitution
end

local function clampBallSpeed()
    local speedSquared = ball.vx * ball.vx + ball.vy * ball.vy
    local maxSpeedSquared = config.maxBallSpeed * config.maxBallSpeed

    if speedSquared <= maxSpeedSquared then
        return
    end

    local speed = math.sqrt(speedSquared)
    local scale = config.maxBallSpeed / speed
    ball.vx = ball.vx * scale
    ball.vy = ball.vy * scale
end

local function resolveBoxCollision()
    local localX, localY = worldToBoxLocal(ball.x, ball.y)
    local halfWidth = config.boxWidth * 0.5
    local halfHeight = config.boxHeight * 0.5
    local limitX = halfWidth - config.ballRadius
    local limitY = halfHeight - config.ballRadius
    local collisionNormalX
    local collisionNormalY

    if localX < -limitX then
        localX = -limitX
        collisionNormalX = 1
        collisionNormalY = 0
    elseif localX > limitX then
        localX = limitX
        collisionNormalX = -1
        collisionNormalY = 0
    end

    if localY < -limitY then
        localY = -limitY
        collisionNormalX = 0
        collisionNormalY = 1
    elseif localY > limitY then
        localY = limitY
        collisionNormalX = 0
        collisionNormalY = -1
    end

    if not collisionNormalX then
        return
    end

    -- 박스가 회전해도 해당 벽의 법선을 월드 좌표로 변환해 입사각/반사각을 맞춘다.
    ball.x, ball.y = boxLocalToWorld(localX, localY)
    local worldNormalX, worldNormalY = rotatePoint(collisionNormalX, collisionNormalY, box.angle)
    reflectVelocity(worldNormalX, worldNormalY)
end

local function isPointInsideButton(x, y, button)
    local dx = x - button.x
    local dy = y - button.y

    return dx * dx + dy * dy <= config.buttonRadius * config.buttonRadius
end

local function updateLayout()
    local width, height = love.graphics.getDimensions()
    box.x = width * 0.5
    box.y = height * 0.47

    buttons.left.x = config.buttonRadius + config.buttonEdgeMargin
    buttons.left.y = height * 0.5
    buttons.right.x = width - config.buttonRadius - config.buttonEdgeMargin
    buttons.right.y = height * 0.5

    if not ball.isReleased then
        resetBall()
    end
end

local function getRotationDirection()
    local direction = 0

    if love.keyboard.isDown("left", "a", "q") or buttons.left.isDown then
        direction = direction - 1
    end

    if love.keyboard.isDown("right", "d", "e") or buttons.right.isDown then
        direction = direction + 1
    end

    return direction
end

local function updateBoxRotation(dt)
    local direction = getRotationDirection()

    if direction == 0 then
        return
    end

    box.angle = box.angle + direction * config.rotationSpeed * dt

    -- 회전 중 벽이 공을 파고드는 상황을 즉시 보정한다.
    resolveBoxCollision()
end

local function updateBall(dt)
    if not ball.isReleased then
        return
    end

    ball.vy = ball.vy + config.gravity * dt
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt
    ball.vx = ball.vx * config.damping
    ball.vy = ball.vy * config.damping

    clampBallSpeed()
    resolveBoxCollision()
end

local function drawButton(button, label)
    local isActive = button.isDown
    love.graphics.setColor(isActive and 0.2 or 0.12, isActive and 0.62 or 0.42, isActive and 0.95 or 0.78)
    love.graphics.circle("fill", button.x, button.y, config.buttonRadius)
    love.graphics.setColor(0.95, 0.98, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", button.x, button.y, config.buttonRadius)
    love.graphics.setFont(font)
    love.graphics.printf(label, button.x - config.buttonRadius, button.y - 13, config.buttonRadius * 2, "center")
end

local function drawBox()
    local corners = getRotatedBoxCorners()
    love.graphics.setLineWidth(config.boxLineWidth)
    love.graphics.setColor(0.92, 0.95, 1)
    love.graphics.polygon(
        "line",
        corners[1].x,
        corners[1].y,
        corners[2].x,
        corners[2].y,
        corners[3].x,
        corners[3].y,
        corners[4].x,
        corners[4].y
    )
end

local function drawBall()
    love.graphics.setColor(1, 0.74, 0.2)
    love.graphics.circle("fill", ball.x, ball.y, config.ballRadius)
    love.graphics.setColor(1, 0.93, 0.58)
    love.graphics.circle("line", ball.x, ball.y, config.ballRadius)
end

local function drawGuideText()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.76, 0.82, 0.9)

    local status = ball.isReleased and "R: Reset ball" or "Space: Launch ball"
    love.graphics.printf(status, 0, 32, love.graphics.getWidth(), "center")
    love.graphics.printf("A/D or Left/Right: Rotate box", 0, love.graphics.getHeight() - 42, love.graphics.getWidth(), "center")
end

function love.load()
    love.window.setMode(config.windowWidth, config.windowHeight, {
        resizable = true,
        minwidth = 480,
        minheight = 360,
    })
    love.window.setTitle("Rotating Box Ball")

    font = love.graphics.newFont(24)
    smallFont = love.graphics.newFont(15)

    love.graphics.setBackgroundColor(0.055, 0.065, 0.085)
    updateLayout()
end

function love.resize()
    updateLayout()
end

function love.update(dt)
    updateBoxRotation(dt)
    updateBall(dt)
end

function love.draw()
    drawGuideText()
    drawBox()
    drawBall()
    drawButton(buttons.left, "<")
    drawButton(buttons.right, ">")
end

function love.keypressed(key)
    if key == "space" then
        releaseBall()
    elseif key == "r" then
        resetBall()
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if isPointInsideButton(x, y, buttons.left) then
        buttons.left.isDown = true
    elseif isPointInsideButton(x, y, buttons.right) then
        buttons.right.isDown = true
    end
end

function love.mousereleased(_, _, button)
    if button ~= 1 then
        return
    end

    buttons.left.isDown = false
    buttons.right.isDown = false
end
