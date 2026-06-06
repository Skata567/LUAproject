-- project/tests/main.lua
-- 테스트 진입점 스크립트. "lovec project/tests" 명령어로 독립 실행 가능.

local test_inventory = require("test_inventory")

function love.load()
    print("=== 시작: 테스트 슈트 실행 ===")
    
    local passed = 0
    local failed = 0
    
    local function run(testFunc, name)
        local status, err = pcall(testFunc)
        if status then
            print("[PASS] " .. name)
            passed = passed + 1
        else
            print("[FAIL] " .. name .. " - Error: " .. tostring(err))
            failed = failed + 1
        end
    end
    
    -- 인벤토리 테스트 실행
    run(test_inventory.test_add_item, "test_inventory.test_add_item")
    run(test_inventory.test_remove_item, "test_inventory.test_remove_item")
    
    print("=== 완료: " .. passed .. " Passed, " .. failed .. " Failed ===")
    
    -- 테스트 완료 후 자동 종료
    love.event.quit()
end

function love.draw()
    love.graphics.print("Tests are running in console...", 10, 10)
end
