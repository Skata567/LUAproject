-- project/tests/test_inventory.lua

local test_inventory = {}

-- 상위 src/ 디렉토리 모듈을 불러오기 위한 경로 설정
package.path = package.path .. ";../src/?.lua"

function test_inventory.test_add_item()
    -- Arrange: 테스트를 위한 초기 상태 구성
    local inventory = {}
    local item = { name = "HP Potion", id = 101 }
    
    -- Act: 테스트할 행동 실행
    table.insert(inventory, item)
    
    -- Assert: 결과 검증
    assert(#inventory == 1, "아이템이 인벤토리에 추가되지 않았습니다.")
    assert(inventory[1].name == "HP Potion", "추가된 아이템의 정보가 일치하지 않습니다.")
end

function test_inventory.test_remove_item()
    -- Arrange
    local inventory = { { name = "HP Potion", id = 101 } }
    
    -- Act
    table.remove(inventory, 1)
    
    -- Assert
    assert(#inventory == 0, "아이템이 인벤토리에서 제거되지 않았습니다.")
end

return test_inventory
