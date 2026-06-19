-- data/enemy_db.lua
-- 몬스터 데이터베이스 (DCSS 스타일 + 종족)
-- main.lua에서 분리된 적/보스 데이터 모듈

local M = {}

-- ===== 일반 몬스터 데이터베이스 =====
M.ENEMY_DB = {
    -- 1층: 약한 적
    {name="쥐",         char="r", hp=3,  atk=1, def=0, spd=1.2, exp=3,  ev=15, color={0.5,0.4,0.3}, floors={1,2}, race="beast", atkElement="pierce", aiType="coward"},
    {name="고블린",      char="g", hp=6,  atk=2, def=0, spd=1.0, exp=6,  ev=10, color={0,0.8,0},     floors={1,2,3}, race="goblinoid", atkElement="slash"},
    {name="코볼트",      char="k", hp=5,  atk=2, def=1, spd=1.1, exp=5,  ev=12, color={0.6,0.5,0.2}, floors={1,2}, race="goblinoid", atkElement="pierce", biomes={"dungeon", "forest"}},
    {name="박쥐",        char="b", hp=3,  atk=1, def=0, spd=1.5, exp=3,  ev=25, color={0.4,0.3,0.5}, floors={1,2,3}, race="beast", atkElement="pierce", biomes={"dungeon", "ice_cave"}},
    {name="좀비",        char="z", hp=10, atk=2, def=2, spd=0.5, exp=8,  ev=0,  color={0.3,0.5,0.2}, floors={1,2,3}, race="undead", atkElement="strike", biomes={"dungeon"}},
    -- 2층: 중간 적
    {name="오크",        char="o", hp=12, atk=4, def=2, spd=1.0, exp=12, ev=8,  color={0.5,0.8,0.2}, floors={2,3,4}, race="orc", atkElement="slash", biomes={"forest", "volcano"}},
    {name="스켈레톤",    char="s", hp=8,  atk=3, def=4, spd=0.8, exp=10, ev=5,  color={0.9,0.9,0.8}, floors={2,3}, race="undead", atkElement="slash", biomes={"dungeon", "ice_cave"}},
    {name="독거미",      char="S", hp=7,  atk=3, def=0, spd=1.3, exp=10, ev=18, color={0.2,0.7,0.2}, floors={2,3}, race="insect", atkElement="poison", biomes={"forest"}},
    {name="늑대",        char="w", hp=9,  atk=4, def=1, spd=1.4, exp=10, ev=15, color={0.5,0.5,0.5}, floors={2,3}, race="beast", atkElement="pierce", biomes={"forest", "ice_cave"}},
    {name="오크전사",    char="O", hp=18, atk=5, def=3, spd=0.9, exp=18, ev=8,  color={0.5,0.6,0.2}, floors={2,3,4}, race="orc", atkElement="strike", biomes={"forest", "volcano"}},
    -- 3층: 강한 적
    {name="트롤",        char="T", hp=25, atk=7, def=3, spd=0.7, exp=25, ev=5,  color={0.3,0.6,0.3}, floors={3,4}, race="troll", atkElement="strike", biomes={"forest"}},
    {name="가고일",      char="G", hp=20, atk=5, def=8, spd=0.6, exp=22, ev=3,  color={0.5,0.5,0.5}, floors={3,4}, race="construct", atkElement="strike", biomes={"dungeon", "volcano"}},
    {name="리자드맨",    char="L", hp=18, atk=6, def=4, spd=1.1, exp=20, ev=12, color={0.2,0.6,0.4}, floors={3,4}, race="reptile", atkElement="slash", biomes={"forest", "ice_cave"}},
    {name="미노타우로스",char="M", hp=30, atk=8, def=4, spd=1.0, exp=30, ev=6,  color={0.6,0.3,0.1}, floors={3,4,5}, race="beast", atkElement="strike"},
    {name="워록",        char="W", hp=15, atk=9, def=2, spd=0.8, exp=28, ev=10, color={0.5,0.2,0.7}, floors={3,4,5}, race="human", atkElement="fire", biomes={"dungeon", "ice_cave"}, aiType="mage"},
    -- 4층: 엘리트
    {name="오우거",      char="F", hp=35, atk=10,def=5, spd=0.6, exp=35, ev=3,  color={0.7,0.4,0.2}, floors={4,5}, race="troll", atkElement="strike", biomes={"forest", "volcano"}},
    {name="다크엘프",    char="e", hp=20, atk=8, def=3, spd=1.3, exp=30, ev=20, color={0.3,0.2,0.5}, floors={4,5}, race="elf", atkElement="lightning", biomes={"dungeon", "forest"}, aiType="assassin"},
    {name="네크로맨서",  char="N", hp=22, atk=10,def=3, spd=0.9, exp=35, ev=12, color={0.4,0.1,0.4}, floors={4,5}, race="human", atkElement="poison", biomes={"dungeon", "ice_cave"}, aiType="mage"},
    {name="석상",        char="X", hp=40, atk=6, def=12,spd=0.4, exp=30, ev=0,  color={0.6,0.6,0.65},floors={4,5}, race="construct", atkElement="strike", biomes={"dungeon", "volcano"}},
    {name="화염마",      char="E", hp=25, atk=12,def=4, spd=1.0, exp=40, ev=15, color={1.0,0.3,0.1}, floors={4,5}, race="demon", atkElement="fire", biomes={"volcano"}},
    -- 5층: 보스급
    {name="드래곤",      char="D", hp=60, atk=15,def=8, spd=0.8, exp=80, ev=10, color={1,0.2,0},     floors={5}, race="dragon", atkElement="fire", biomes={"volcano"}},
    {name="리치",        char="$", hp=40, atk=14,def=5, spd=0.7, exp=70, ev=12, color={0.3,0.8,0.3}, floors={5}, race="undead", atkElement="ice", biomes={"ice_cave"}, aiType="mage"},
    {name="골렘",        char="#", hp=70, atk=12,def=15,spd=0.3, exp=60, ev=0,  color={0.5,0.4,0.3}, floors={5}, race="construct", atkElement="strike", biomes={"dungeon"}},
    {name="악마",        char="&", hp=50, atk=16,def=6, spd=1.2, exp=90, ev=18, color={0.8,0.1,0.1}, floors={5}, race="demon", atkElement="fire"},
    {name="고대용",      char="@", hp=100,atk=20,def=10,spd=0.9, exp=150,ev=8,  color={1.0,0.8,0.0}, floors={5}, race="dragon", atkElement="fire"},
}

-- ===== 층별 보스 데이터베이스 =====
M.BOSS_DB = {
    [2] = {name="고블린 왕", char="K", hp=45, atk=7, def=4, spd=0.9, exp=70, ev=10, color={0.2,1.0,0.2}, race="goblinoid", atkElement="slash"},
    [3] = {name="거미 여왕", char="Q", hp=70, atk=10, def=5, spd=1.1, exp=110, ev=16, color={0.4,0.9,0.3}, race="insect", atkElement="poison"},
    [4] = {name="룬 골렘", char="R", hp=95, atk=13, def=14, spd=0.5, exp=160, ev=2, color={0.6,0.7,1.0}, race="construct", atkElement="lightning"},
    [5] = {name="심연의 고대용", char="A", hp=150, atk=22, def=12, spd=0.8, exp=300, ev=8, color={1.0,0.15,0.15}, race="dragon", atkElement="fire"},
}

return M
