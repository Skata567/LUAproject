local M = {}

-- ===== 설정 =====
M.TILE_SIZE = 16
M.MAP_WIDTH = 100
M.MAP_HEIGHT = 100
M.MAX_ROOMS = 25
M.MIN_ROOM_SIZE = 4
M.MAX_ROOM_SIZE = 10
M.MAX_ENEMIES_PER_ROOM = 4
M.MAX_ITEMS_PER_ROOM = 2

-- 스탯 포인트 배분 상태
M.statAlloc = nil   -- {points=N, sel=1}  레벨업 시 활성화

-- 타일 종류
M.TILE_WALL = 0
M.TILE_FLOOR = 1
M.TILE_STAIR_DOWN = 2
M.TILE_STAIR_UP = 3
M.TILE_WATER = 4
M.TILE_LAVA = 5
M.TILE_GRASS = 6
M.TILE_DIRT = 7
M.TILE_LOCKED_CHEST = 8
M.TILE_OPEN_CHEST = 9

-- 색상
M.COLOR_WALL     = {0.3, 0.3, 0.4}
M.COLOR_FLOOR    = {0.6, 0.6, 0.5}
M.COLOR_WATER    = {0.1, 0.4, 0.8}
M.COLOR_LAVA     = {0.9, 0.3, 0.1}
M.COLOR_GRASS    = {0.2, 0.6, 0.3}
M.COLOR_DIRT     = {0.5, 0.4, 0.2}
M.COLOR_PLAYER   = {1, 1, 0}
M.COLOR_STAIR    = {1, 0.8, 0}
M.COLOR_CHEST_LOCKED = {0.8, 0.6, 0.2}
M.COLOR_CHEST_OPEN = {0.4, 0.3, 0.1}
M.COLOR_HUD_BG   = {0.1, 0.1, 0.15, 0.9}
M.COLOR_HP_BAR   = {0.8, 0.1, 0.1}
M.COLOR_HP_BG    = {0.3, 0.1, 0.1}
M.COLOR_MP_BAR   = {0.15, 0.35, 0.95}
M.COLOR_MP_BG    = {0.08, 0.12, 0.3}
M.COLOR_WHITE    = {1, 1, 1}
M.COLOR_GRAY     = {0.5, 0.5, 0.5}
M.COLOR_GOLD     = {1, 0.85, 0}


return M
