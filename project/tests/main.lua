-- project/tests/main.lua
-- 테스트 진입점 스크립트. "lovec project/tests" 명령어로 독립 실행 가능.

-- src/ 모듈을 불러올 수 있도록 경로 설정
package.path = package.path .. ";../src/?.lua;../src/?/init.lua"

function love.load()
    print("=== 시작: 테스트 슈트 실행 ===")

    local totalPassed = 0
    local totalFailed = 0

    -- 테스트 모듈 목록
    local testModules = {
        { name = "test_inventory",      mod = require("test_inventory") },
        { name = "test_ai",             mod = require("test_ai") },
        { name = "test_party",          mod = require("test_party") },
        { name = "test_ai_algorithms",  mod = require("test_ai_algorithms") },
        { name = "test_auto_repeat",    mod = require("test_auto_repeat") },
        { name = "test_religion",       mod = require("test_religion") },
        { name = "qa_simulation",       mod = require("qa_simulation") },
        { name = "test_pathfinding",    mod = require("test_pathfinding") },
        { name = "test_combat",         mod = require("test_combat") },
        { name = "test_fov",            mod = require("test_fov") },
    }

    for _, entry in ipairs(testModules) do
        print("")
        print("--- [" .. entry.name .. "] ---")

        if type(entry.mod) == "table" then
            local hasTests = false
            for k, func in pairs(entry.mod) do
                if type(func) == "function" and (k:match("^test_") or k == "run") then
                    hasTests = true
                    local ok, err = pcall(func)
                    if ok then
                        print("[PASS] " .. k)
                        totalPassed = totalPassed + 1
                    else
                        print("[FAIL] " .. k .. " - " .. tostring(err))
                        totalFailed = totalFailed + 1
                    end
                end
            end
            if not hasTests then
                print("[SKIP] " .. entry.name .. " (no test functions found)")
            end
        else
            print("[SKIP] " .. entry.name .. " (module did not return a table)")
        end
    end

    print("")
    print("=== 완료: " .. totalPassed .. " Passed, " .. totalFailed .. " Failed (총 " .. (totalPassed + totalFailed) .. " 테스트) ===")

    -- 테스트 완료 후 자동 종료
    love.event.quit(totalFailed > 0 and 1 or 0)
end

function love.draw()
    love.graphics.print("Tests are running in console...", 10, 10)
end
