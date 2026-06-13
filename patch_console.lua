local file = io.open("project/src/main.lua", "r")
local content = file:read("*a")
file:close()

local utf8Require = "local utf8 = require(\"utf8\")\n"
if not string.find(content, "require%(\"utf8\"%)") then
    content = string.gsub(content, "local ConfigManager = require%(\"config_manager\"%)\n", "local ConfigManager = require(\"config_manager\")\n" .. utf8Require)
end

local consoleVars = [[
local dungeonRun = 0        -- 던전 탐험 횟수

-- ===== 개발자 콘솔 상태 =====
local showConsole = false
local consoleInput = ""
local consoleLogs = {}

local function addConsoleLog(msg)
    table.insert(consoleLogs, msg)
    if #consoleLogs > 15 then table.remove(consoleLogs, 1) end
end

local function executeConsoleCommand(cmdStr)
    addConsoleLog("> " .. cmdStr)
    local args = {}
    for w in string.gmatch(cmdStr, "%S+") do table.insert(args, w) end
    if #args == 0 then return end
    local cmd = args[1]:lower()

    if cmd == "/coin" then
        local amt = tonumber(args[2]) or 1000
        player.gold = player.gold + amt
        addConsoleLog("골드를 " .. amt .. " 만큼 획득했습니다.")
    elseif cmd == "/getitem" then
        local id = args[2]
        local amt = tonumber(args[3]) or 1
        if not id or not Item.ITEMS[id] then
            addConsoleLog("오류: 존재하지 않는 아이템 ID 입니다.")
            return
        end
        local given = 0
        for i=1, amt do
            local item = Item.new(id)
            if inv:autoPlace(item) then given = given + 1 end
        end
        addConsoleLog(Item.ITEMS[id].name .. " " .. given .. "개 획득했습니다.")
    elseif cmd == "/clearinv" then
        for i=1, inv.cols do
            for j=1, inv.rows do
                inv.grid[j][i] = nil
            end
        end
        addConsoleLog("인벤토리를 비웠습니다.")
    elseif cmd == "/heal" then
        player.hp = Combat.getPlayerMaxHp()
        player.mana = Combat.getPlayerMaxMana()
        if party then
            for _, comp in ipairs(party) do
                if comp.alive then comp.hp = comp.maxHp end
            end
        end
        addConsoleLog("파티 전원 HP/MP 100% 회복!")
    elseif cmd == "/level" then
        local amt = tonumber(args[2]) or 1
        for i=1, amt do
            player.level = player.level + 1
            player.baseAtk = player.baseAtk + 1
            player.skillPoints = (player.skillPoints or 0) + 1
            player.statPoints = (player.statPoints or 0) + 3
        end
        addConsoleLog("레벨이 " .. amt .. " 만큼 상승했습니다! (현재: " .. player.level .. ")")
    elseif cmd == "/floor" then
        local amt = tonumber(args[2])
        if amt then
            floor = amt - 1
            gameState = "playing"
            nextFloor()
            addConsoleLog("강제로 " .. amt .. " 층으로 이동합니다.")
        end
    elseif cmd == "/spawn" then
        local id = args[2]
        if not id or not Monster.DB[id] then
            addConsoleLog("오류: 존재하지 않는 몬스터 ID 입니다.")
            return
        end
        local mx, my = love.mouse.getPosition()
        local tx = math.floor((mx + camera.x) / TILE_SIZE)
        local ty = math.floor((my + camera.y) / TILE_SIZE)
        if map[ty] and map[ty][tx] then
            local e = Monster.new(id, tx, ty, floor)
            table.insert(enemies, e)
            addConsoleLog(e.name .. " 몬스터를 커서 위치에 소환했습니다!")
        else
            addConsoleLog("오류: 올바르지 않은 위치입니다.")
        end
    elseif cmd == "/god" then
        player.godMode = not player.godMode
        addConsoleLog("무적 모드: " .. (player.godMode and "ON" or "OFF"))
    elseif cmd == "/clear" then
        consoleLogs = {}
    else
        addConsoleLog("알 수 없는 명령어입니다.")
    end
end

function love.textinput(t)
    if showConsole then
        consoleInput = consoleInput .. t
    end
end
]]
content = string.gsub(content, "local dungeonRun = 0        %-%- 던전 탐험 횟수", consoleVars)

local keypressedMod = [[
function love.keypressed(key)
    if key == "`" then
        showConsole = not showConsole
        return
    end
    if showConsole then
        if key == "escape" then
            showConsole = false
            return
        elseif key == "backspace" then
            local byteoffset = utf8.offset(consoleInput, -1)
            if byteoffset then
                consoleInput = string.sub(consoleInput, 1, byteoffset - 1)
            end
            return
        elseif key == "return" or key == "kpenter" then
            if consoleInput ~= "" then
                executeConsoleCommand(consoleInput)
                consoleInput = ""
            end
            return
        end
        return
    end
]]
content = string.gsub(content, "function love%.keypressed%(key%)", keypressedMod)

local drawMod = [[
    love.graphics.pop()
    
    -- ===== 개발자 콘솔 렌더링 =====
    if showConsole then
        local sw, sh = love.graphics.getDimensions()
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, sw, 300)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("=== Developer Console ===", 10, 10)
        
        -- 로그 출력
        local logY = 40
        for i, logMsg in ipairs(consoleLogs) do
            love.graphics.print(logMsg, 10, logY)
            logY = logY + 15
        end
        
        -- 입력창 출력
        love.graphics.setColor(0.3, 1, 0.3, 1)
        love.graphics.print("> " .. consoleInput .. (math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""), 10, 270)
        love.graphics.setColor(1, 1, 1, 1)
    end
end]]
content = string.gsub(content, "    love%.graphics%.pop%(%)\nend", drawMod)

local fw = io.open("project/src/main.lua", "w")
fw:write(content)
fw:close()
