-- Roguelike + Extraction RPG Inventory (LÖVE2D)
-- 기존 로그라이크 던전 + 그리드 기반 인벤토리 + 장비 시스템

local Item = require("item")
local Inventory = require("inventory")
local Equipment = require("equipment")
local Shop = require("shop")

-- ===== 설정 =====
local TILE_SIZE = 16
local MAP_WIDTH = 50
local MAP_HEIGHT = 35
local MAX_ROOMS = 10
local MIN_ROOM_SIZE = 4
local MAX_ROOM_SIZE = 10
local MAX_ENEMIES_PER_ROOM = 4
local MAX_ITEMS_PER_ROOM = 2

-- 스탯 포인트 배분 상태
local statAlloc = nil   -- {points=N, sel=1}  레벨업 시 활성화

-- 타일 종류
local TILE_WALL = 0
local TILE_FLOOR = 1
local TILE_STAIR_DOWN = 2
local TILE_STAIR_UP = 3

-- 색상
local COLOR_WALL     = {0.3, 0.3, 0.4}
local COLOR_FLOOR    = {0.6, 0.6, 0.5}
local COLOR_PLAYER   = {1, 1, 0}
local COLOR_STAIR    = {1, 0.8, 0}
local COLOR_HUD_BG   = {0.1, 0.1, 0.15, 0.9}
local COLOR_HP_BAR   = {0.8, 0.1, 0.1}
local COLOR_HP_BG    = {0.3, 0.1, 0.1}
local COLOR_MP_BAR   = {0.15, 0.35, 0.95}
local COLOR_MP_BG    = {0.08, 0.12, 0.3}
local COLOR_WHITE    = {1, 1, 1}
local COLOR_GRAY     = {0.5, 0.5, 0.5}
local COLOR_GOLD     = {1, 0.85, 0}

-- 게임 상태
local gameState = "charselect" -- charselect, playing, inventory, town, shop, stash, gameover, levelup, bestiary
local map = {}
local rooms = {}
local player = {}
local enemies = {}
local groundItems = {}  -- 바닥에 있는 아이템
local messages = {}
local turn = 0
local floor = 1
local floorStates = {}
local font = nil
local messageScroll = 0
local MAX_VISIBLE_MESSAGES = 8

-- 캐릭터 선택 상태
local charSelect = {
    phase = "race",  -- "race" or "class"
    raceSel = 1,
    classSel = 1,
    chosenRace = nil,
    chosenClass = nil,
}

-- ===== 플레이어 종족 =====
local PLAYER_RACES = {
    {
        id = "human", name = "인간", char = "@", color = {1, 1, 0.8},
        desc = "균형 잡힌 종족. 모든 무기와 마법을 고르게 배울 수 있다.",
        stats = {str=5, dex=5, int=5, con=5, lck=5},
        resist = {},
        weak = {},
        profBonus = {},  -- 숙련도 보너스 없음 (균등)
        hpBonus = 0, expBonus = 0,
        skills = {},
    },
    {
        id = "elf", name = "엘프", char = "@", color = {0.6, 0.9, 1.0},
        desc = "마법에 뛰어난 종족. INT/DEX가 높지만 CON이 낮다.",
        stats = {str=3, dex=7, int=8, con=3, lck=5},
        resist = {fire=0.1, ice=0.1, lightning=0.1},
        weak = {strike=0.2},
        profBonus = {fire=2, ice=2, lightning=2, holy=2},
        hpBonus = -5, expBonus = 0,
        skills = {{id="mana_shield", name="마나 실드", desc="피격 데미지 20% 감소 (3턴)", cooldown=8, duration=3, type="buff"}},
    },
    {
        id = "dwarf", name = "드워프", char = "@", color = {0.8, 0.6, 0.3},
        desc = "강인한 대장장이 종족. STR/CON이 높고 타격/참격에 능하다.",
        stats = {str=7, dex=4, int=3, con=8, lck=4},
        resist = {fire=0.15, poison=0.2},
        weak = {lightning=0.2},
        profBonus = {strike=3, slash=2},
        hpBonus = 10, expBonus = 0,
        skills = {{id="stone_skin", name="바위 피부", desc="방어력 +5 (5턴)", cooldown=10, duration=5, type="buff"}},
    },
    {
        id = "orc_p", name = "오크", char = "@", color = {0.5, 0.8, 0.2},
        desc = "호전적인 전사 종족. STR이 매우 높지만 INT가 낮다.",
        stats = {str=9, dex=4, int=2, con=6, lck=4},
        resist = {strike=0.1},
        weak = {holy=0.2, lightning=0.15},
        profBonus = {strike=3, slash=2},
        hpBonus = 5, expBonus = 0,
        skills = {{id="war_cry", name="전쟁 함성", desc="공격력 +30% (4턴)", cooldown=10, duration=4, type="buff"}},
    },
    {
        id = "halfling", name = "하플링", char = "@", color = {0.9, 0.8, 0.5},
        desc = "작지만 민첩하고 운이 좋은 종족. DEX/LCK가 매우 높다.",
        stats = {str=3, dex=8, int=4, con=4, lck=9},
        resist = {poison=0.2},
        weak = {strike=0.15},
        profBonus = {pierce=3},
        hpBonus = -5, expBonus = 10,
        skills = {{id="lucky_dodge", name="행운의 회피", desc="다음 공격 100% 회피", cooldown=8, duration=1, type="buff"}},
    },
    {
        id = "troll_p", name = "트롤", char = "@", color = {0.4, 0.7, 0.3},
        desc = "강력한 재생력의 거인. STR/CON 극도로 높지만 INT/DEX가 낮다.",
        stats = {str=10, dex=2, int=1, con=10, lck=3},
        resist = {poison=0.3},
        weak = {fire=0.4},
        profBonus = {strike=4},
        hpBonus = 20, expBonus = -10,
        skills = {{id="regenerate", name="재생", desc="매 턴 HP 3 회복 (6턴)", cooldown=12, duration=6, type="buff"}},
    },
    {
        id = "undead_p", name = "언데드", char = "@", color = {0.5, 0.7, 0.5},
        desc = "죽음에서 돌아온 자. 독 면역, 화염/신성에 약하다.",
        stats = {str=6, dex=4, int=6, con=6, lck=3},
        resist = {poison=1.0, ice=0.3},
        weak = {fire=0.4, holy=0.5},
        profBonus = {slash=2, ice=2},
        hpBonus = 5, expBonus = 0,
        skills = {{id="drain_life", name="생명력 흡수", desc="적에게 데미지 + HP 흡수", cooldown=6, duration=0, type="attack", value=15}},
    },
    {
        id = "dragonkin", name = "용인", char = "@", color = {1.0, 0.45, 0.15},
        desc = "용의 피를 이은 종족. 화염에 강하고 화염 마법에 뛰어나다.",
        stats = {str=7, dex=4, int=7, con=6, lck=3},
        resist = {fire=0.4, slash=0.1},
        weak = {ice=0.25},
        profBonus = {fire=4, slash=1},
        hpBonus = 8, expBonus = -5,
        skills = {{id="dragon_breath", name="용의 숨결", desc="인접 적에게 강한 화염 데미지", cooldown=7, duration=0, type="attack", value=8, element="fire", attackScale=2.4}},
    },
    {
        id = "fae", name = "페이", char = "@", color = {1.0, 0.55, 1.0},
        desc = "장난스러운 요정 종족. 회피와 행운이 높지만 체력이 낮다.",
        stats = {str=2, dex=9, int=8, con=2, lck=8},
        resist = {holy=0.2, lightning=0.15},
        weak = {strike=0.25},
        profBonus = {lightning=3, holy=2},
        hpBonus = -10, expBonus = 10,
        skills = {{id="fae_glimmer", name="요정의 잔광", desc="회피 +18, 치명 +8 (4턴)", cooldown=9, duration=4, type="buff", statBonus={evasion=18, crit=8}}},
    },
    {
        id = "gnome", name = "노움", char = "@", color = {0.7, 0.6, 1.0},
        desc = "작고 영리한 발명가. 지능과 번개 숙련이 높다.",
        stats = {str=3, dex=6, int=9, con=3, lck=6},
        resist = {lightning=0.35},
        weak = {strike=0.2},
        profBonus = {lightning=4},
        hpBonus = -5, expBonus = 5,
        skills = {{id="spark_trap", name="전기 덫", desc="인접 적에게 번개 데미지", cooldown=5, duration=0, type="attack", value=4, element="lightning", attackScale=2.2}},
    },
    {
        id = "kobold_p", name = "코볼트", char = "@", color = {0.85, 0.55, 0.25},
        desc = "작지만 교활한 터널 사냥꾼. 민첩과 운이 좋다.",
        stats = {str=4, dex=8, int=4, con=4, lck=8},
        resist = {poison=0.15},
        weak = {holy=0.15},
        profBonus = {pierce=3, poison=2},
        hpBonus = -3, expBonus = 8,
        skills = {{id="dirty_trick", name="비열한 술수", desc="다음 공격 데미지 1.8배", cooldown=6, duration=0, type="nextAtk", value=1.8}},
    },
    {
        id = "angelborn", name = "천족", char = "@", color = {1.0, 0.95, 0.65},
        desc = "빛의 피를 타고난 종족. 신성에 강하고 독과 어둠에 흔들리지 않는다.",
        stats = {str=5, dex=5, int=8, con=5, lck=6},
        resist = {holy=0.5, poison=0.2},
        weak = {fire=0.15},
        profBonus = {holy=5},
        hpBonus = 0, expBonus = -5,
        skills = {{id="radiant_grace", name="찬란한 은총", desc="HP 회복", cooldown=6, duration=0, type="heal", value=10, healScale=3.5}},
    },
    {
        id = "demonborn", name = "마족", char = "@", color = {0.9, 0.15, 0.25},
        desc = "지옥의 피를 가진 종족. 화염과 독에 강하지만 신성에 약하다.",
        stats = {str=7, dex=5, int=7, con=5, lck=3},
        resist = {fire=0.35, poison=0.35},
        weak = {holy=0.4},
        profBonus = {fire=3, poison=3},
        hpBonus = 5, expBonus = 0,
        skills = {{id="hell_pact", name="지옥 계약", desc="공격 +8, 방어 -2 (5턴)", cooldown=10, duration=5, type="buff", statBonus={atk=8, def=-2}}},
    },
    {
        id = "lizardfolk", name = "리자드맨", char = "@", color = {0.25, 0.8, 0.45},
        desc = "습지의 사냥꾼. 체력과 독 저항이 좋다.",
        stats = {str=6, dex=6, int=3, con=8, lck=4},
        resist = {poison=0.45, pierce=0.1},
        weak = {ice=0.3},
        profBonus = {pierce=2, poison=3},
        hpBonus = 10, expBonus = 0,
        skills = {{id="scale_guard", name="비늘 방어", desc="방어 +7 (5턴)", cooldown=9, duration=5, type="buff", statBonus={def=7}}},
    },
    {
        id = "merfolk", name = "인어", char = "@", color = {0.25, 0.85, 1.0},
        desc = "물과 얼음에 친숙한 종족. 빙결 마법에 강하다.",
        stats = {str=4, dex=6, int=8, con=5, lck=5},
        resist = {ice=0.45, poison=0.1},
        weak = {lightning=0.35},
        profBonus = {ice=5},
        hpBonus = 0, expBonus = 0,
        skills = {{id="tidal_chill", name="해일 냉기", desc="인접 적에게 빙결 데미지", cooldown=5, duration=0, type="attack", value=5, element="ice", attackScale=2.1}},
    },
    {
        id = "vampire", name = "흡혈귀", char = "@", color = {0.75, 0.05, 0.15},
        desc = "피를 갈망하는 밤의 귀족. 생명 흡수에 특화됐다.",
        stats = {str=6, dex=7, int=6, con=4, lck=5},
        resist = {poison=0.7, ice=0.2},
        weak = {holy=0.45, fire=0.2},
        profBonus = {slash=2, poison=2},
        hpBonus = -3, expBonus = 0,
        skills = {{id="blood_drain", name="피의 흡수", desc="적에게 데미지 + HP 흡수", cooldown=5, duration=0, type="attack", value=10, element="poison", attackScale=1.8}},
    },
    {
        id = "golem_p", name = "골렘", char = "@", color = {0.55, 0.55, 0.6},
        desc = "돌과 룬으로 움직이는 존재. 매우 튼튼하지만 느리다.",
        stats = {str=8, dex=2, int=4, con=11, lck=2},
        resist = {poison=1.0, slash=0.25, pierce=0.25},
        weak = {lightning=0.45, strike=0.2},
        profBonus = {strike=4},
        hpBonus = 25, expBonus = -10,
        skills = {{id="rune_plate", name="룬 장갑", desc="방어 +10, 회피 -8 (6턴)", cooldown=12, duration=6, type="buff", statBonus={def=10, evasion=-8}}},
    },
    {
        id = "shadowkin", name = "그림자족", char = "@", color = {0.35, 0.25, 0.55},
        desc = "어둠 속에서 움직이는 종족. 회피와 치명이 높다.",
        stats = {str=4, dex=9, int=6, con=3, lck=7},
        resist = {poison=0.2},
        weak = {holy=0.35},
        profBonus = {pierce=3, slash=2},
        hpBonus = -8, expBonus = 5,
        skills = {{id="shadow_step", name="그림자 걸음", desc="회피 +25 (3턴)", cooldown=8, duration=3, type="buff", statBonus={evasion=25}}},
    },
    {
        id = "sylph", name = "실프", char = "@", color = {0.75, 0.95, 1.0},
        desc = "바람의 정령에 가까운 종족. 번개와 민첩에 강하다.",
        stats = {str=3, dex=10, int=7, con=2, lck=6},
        resist = {lightning=0.45},
        weak = {strike=0.3},
        profBonus = {lightning=4, pierce=1},
        hpBonus = -10, expBonus = 5,
        skills = {{id="wind_blessing", name="바람의 축복", desc="명중 +20, 회피 +15 (4턴)", cooldown=8, duration=4, type="buff", statBonus={accuracy=20, evasion=15}}},
    },
    {
        id = "automaton", name = "자동인형", char = "@", color = {0.7, 0.7, 0.75},
        desc = "태엽과 마도공학으로 움직이는 종족. 독에 면역이고 번개에 약하다.",
        stats = {str=6, dex=5, int=6, con=8, lck=2},
        resist = {poison=1.0, fire=0.15},
        weak = {lightning=0.5},
        profBonus = {strike=2, lightning=2},
        hpBonus = 12, expBonus = -5,
        skills = {{id="overclock", name="오버클럭", desc="공격 +5, 명중 +15 (4턴)", cooldown=9, duration=4, type="buff", statBonus={atk=5, accuracy=15}}},
    },
}

-- ===== 플레이어 직업 =====
local PLAYER_CLASSES = {
    {
        id = "fighter", name = "전사", color = {1, 0.4, 0.3},
        desc = "근접 전투의 달인. 참격/타격 무기에 능하고 방어력이 높다.",
        statBonus = {str=3, dex=1, int=0, con=3, lck=0},
        profBonus = {slash=3, strike=2},
        startWeapon = "steel_sword",
        startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {{id="power_strike", name="강타", desc="다음 공격 데미지 2배", cooldown=6, duration=0, type="nextAtk", value=2.0}},
    },
    {
        id = "rogue", name = "도적", color = {0.5, 1, 0.5},
        desc = "은밀한 암살자. 찌르기 무기에 능하고 치명타가 높다.",
        statBonus = {str=0, dex=4, int=0, con=1, lck=3},
        profBonus = {pierce=4},
        startWeapon = "dagger",
        startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {{id="backstab", name="급소 찌르기", desc="다음 공격 치명타 확정 (3배)", cooldown=8, duration=0, type="nextAtk", value=3.0}},
    },
    {
        id = "mage", name = "마법사", color = {0.4, 0.6, 1},
        desc = "원소 마법의 대가. 화염/빙결/번개 마법 무기에 능하다.",
        statBonus = {str=0, dex=1, int=5, con=1, lck=1},
        profBonus = {fire=3, ice=3, lightning=3},
        startWeapon = "flame_dagger",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="fireball", name="화염구", desc="적에게 INT 기반 화염 데미지", cooldown=4, duration=0, type="attack", value=0, element="fire"}},
    },
    {
        id = "paladin", name = "성기사", color = {1, 1, 0.5},
        desc = "신의 전사. 신성 무기에 능하고 언데드/악마에 강하다.",
        statBonus = {str=2, dex=0, int=2, con=3, lck=1},
        profBonus = {holy=5, strike=2},
        startWeapon = "holy_mace",
        startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {{id="holy_smite", name="신성한 강타", desc="적에게 신성 데미지 (언데드/악마 2배)", cooldown=5, duration=0, type="attack", value=0, element="holy"}},
    },
    {
        id = "ranger", name = "궁수", color = {0.3, 0.8, 0.3},
        desc = "민첩한 사냥꾼. 찌르기 무기에 능하고 회피가 높다.",
        statBonus = {str=1, dex=4, int=1, con=1, lck=2},
        profBonus = {pierce=4, slash=1},
        startWeapon = "dagger",
        startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {{id="precise_shot", name="정밀 사격", desc="다음 공격 명중 100% + 방어 무시", cooldown=6, duration=0, type="nextAtk", value=1.5}},
    },
    {
        id = "priest", name = "사제", color = {1, 1, 0.8},
        desc = "신성한 치유사. 신성 마법에 능하고 HP 회복 능력이 뛰어나다.",
        statBonus = {str=0, dex=1, int=4, con=3, lck=1},
        profBonus = {holy=4, strike=1},
        startWeapon = "holy_mace",
        startArmor = nil,
        startItems = {"health_potion", "health_potion", "health_potion"},
        skills = {{id="heal", name="치유", desc="HP를 INT*3 만큼 회복", cooldown=5, duration=0, type="heal"}},
    },
    {
        id = "berserker", name = "광전사", color = {1, 0.2, 0.1},
        desc = "분노의 전사. 양손 무기에 능하고 광폭화 시 초강력 공격.",
        statBonus = {str=5, dex=0, int=0, con=3, lck=0},
        profBonus = {slash=3, strike=3},
        startWeapon = "long_sword",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="berserk", name="광폭화", desc="공격력 2배, 방어 0 (5턴)", cooldown=15, duration=5, type="buff"}},
    },
    {
        id = "cryomancer", name = "빙결술사", color = {0.35, 0.8, 1.0},
        desc = "얼음 마법 전문가. 빙결 데미지와 방어형 주문에 능하다.",
        statBonus = {str=0, dex=1, int=5, con=2, lck=0},
        profBonus = {ice=5},
        startWeapon = "glacier_staff",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="ice_lance", name="얼음 창", desc="적에게 강한 빙결 데미지", cooldown=4, duration=0, type="attack", value=6, element="ice", attackScale=2.4}},
    },
    {
        id = "stormcaller", name = "폭풍술사", color = {1.0, 1.0, 0.35},
        desc = "번개를 부르는 마법사. 명중과 번개 숙련이 높다.",
        statBonus = {str=0, dex=2, int=5, con=1, lck=1},
        profBonus = {lightning=5},
        startWeapon = "storm_staff",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="chain_spark", name="연쇄 번개", desc="인접 적에게 번개 데미지", cooldown=4, duration=0, type="attack", value=5, element="lightning", attackScale=2.3}},
    },
    {
        id = "pyromancer", name = "화염술사", color = {1.0, 0.35, 0.1},
        desc = "화염 마법에 모든 것을 건 주문사.",
        statBonus = {str=0, dex=1, int=6, con=1, lck=0},
        profBonus = {fire=6},
        startWeapon = "flame_dagger",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="inferno_bolt", name="지옥불 화살", desc="적에게 큰 화염 데미지", cooldown=5, duration=0, type="attack", value=10, element="fire", attackScale=2.5}},
    },
    {
        id = "necromancer", name = "강령술사", color = {0.45, 0.8, 0.45},
        desc = "생명력을 빼앗는 어둠의 마법사.",
        statBonus = {str=0, dex=1, int=5, con=2, lck=1},
        profBonus = {poison=3, ice=2},
        startWeapon = "bone_wand",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="soul_siphon", name="영혼 착취", desc="적에게 데미지 + HP 흡수", cooldown=6, duration=0, type="attack", value=12, element="poison", attackScale=2.0}},
    },
    {
        id = "monk", name = "수도승", color = {1.0, 0.75, 0.45},
        desc = "몸과 정신을 단련한 전사. 타격과 회피에 능하다.",
        statBonus = {str=2, dex=3, int=1, con=2, lck=1},
        profBonus = {strike=4, holy=1},
        startWeapon = "war_hammer",
        startArmor = nil,
        startItems = {"health_potion", "health_potion"},
        skills = {{id="inner_focus", name="내면 집중", desc="명중 +20, 치명 +10 (4턴)", cooldown=8, duration=4, type="buff", statBonus={accuracy=20, crit=10}}},
    },
    {
        id = "samurai", name = "검객", color = {0.9, 0.9, 0.95},
        desc = "한 번의 베기에 집중하는 검사. 참격과 치명타에 능하다.",
        statBonus = {str=3, dex=3, int=0, con=1, lck=1},
        profBonus = {slash=5},
        startWeapon = "moon_katana",
        startArmor = "leather_armor",
        startItems = {"health_potion"},
        skills = {{id="iai_slash", name="발도", desc="다음 공격 데미지 2.4배", cooldown=7, duration=0, type="nextAtk", value=2.4}},
    },
    {
        id = "alchemist", name = "연금술사", color = {0.4, 1.0, 0.45},
        desc = "독과 회복 물약을 다루는 전술가.",
        statBonus = {str=0, dex=2, int=4, con=2, lck=2},
        profBonus = {poison=5},
        startWeapon = "venom_blade",
        startArmor = nil,
        startItems = {"health_potion", "large_potion"},
        skills = {{id="acid_flask", name="산성 플라스크", desc="적에게 독 데미지", cooldown=4, duration=0, type="attack", value=8, element="poison", attackScale=2.0}},
    },
    {
        id = "druid", name = "드루이드", color = {0.35, 0.9, 0.35},
        desc = "자연의 힘으로 회복과 독 저항을 다룬다.",
        statBonus = {str=1, dex=1, int=4, con=3, lck=1},
        profBonus = {poison=2, holy=2},
        startWeapon = nil,
        startArmor = "silk_robe",
        startItems = {"health_potion", "health_potion"},
        skills = {{id="nature_mend", name="자연 치유", desc="HP 대량 회복", cooldown=6, duration=0, type="heal", value=15, healScale=3.2}},
    },
    {
        id = "warlock", name = "흑마법사", color = {0.6, 0.2, 0.9},
        desc = "위험한 계약으로 폭발적인 마력을 얻는다.",
        statBonus = {str=0, dex=1, int=6, con=0, lck=2},
        profBonus = {fire=2, poison=3},
        startWeapon = "bone_wand",
        startArmor = nil,
        startItems = {"health_potion"},
        skills = {{id="dark_bargain", name="어둠의 거래", desc="공격 +10, 치명 +12 (4턴)", cooldown=10, duration=4, type="buff", statBonus={atk=10, crit=12}}},
    },
    {
        id = "spellblade", name = "마검사", color = {0.5, 0.6, 1.0},
        desc = "검술과 원소 마법을 함께 쓰는 전투 마법사.",
        statBonus = {str=2, dex=2, int=3, con=1, lck=0},
        profBonus = {slash=2, fire=2, lightning=2},
        startWeapon = "steel_sword",
        startArmor = "leather_armor",
        startItems = {"health_potion"},
        skills = {{id="arcane_edge", name="비전 칼날", desc="다음 공격 데미지 2배", cooldown=6, duration=0, type="nextAtk", value=2.0}},
    },
    {
        id = "guardian", name = "수호자", color = {0.55, 0.7, 1.0},
        desc = "방패와 방어 주문으로 버티는 탱커.",
        statBonus = {str=1, dex=0, int=1, con=5, lck=0},
        profBonus = {strike=2, holy=2},
        startWeapon = "iron_shield",
        startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {{id="aegis", name="수호 방벽", desc="방어 +12, HP +15 (5턴)", cooldown=12, duration=5, type="buff", statBonus={def=12, hp=15}}},
    },
    {
        id = "shaman", name = "주술사", color = {0.8, 0.55, 1.0},
        desc = "정령의 힘으로 공격과 회복을 오간다.",
        statBonus = {str=1, dex=1, int=4, con=2, lck=2},
        profBonus = {lightning=2, poison=2, holy=1},
        startWeapon = "holy_mace",
        startArmor = nil,
        startItems = {"health_potion", "health_potion"},
        skills = {{id="spirit_bolt", name="영혼 화살", desc="적에게 신성 데미지", cooldown=4, duration=0, type="attack", value=6, element="holy", attackScale=2.1}},
    },
    {
        id = "engineer", name = "기술자", color = {0.75, 0.75, 0.65},
        desc = "장비와 함정을 활용하는 실용주의 전투원.",
        statBonus = {str=1, dex=3, int=3, con=2, lck=1},
        profBonus = {strike=2, lightning=3},
        startWeapon = "war_hammer",
        startArmor = "iron_helmet",
        startItems = {"health_potion"},
        skills = {{id="shock_mine", name="충격 지뢰", desc="인접 적에게 번개 데미지", cooldown=5, duration=0, type="attack", value=9, element="lightning", attackScale=1.8}},
    },
}

-- 인벤토리 & 장비
local inv = nil
local equip = nil

-- 드래그 상태
local drag = {
    item = nil,
    fromInv = nil,
    fromSlot = nil,
}
local hoverItem = nil

-- 상점 & 마을
local shop = nil
local stash = nil           -- 보관함 (마을 인벤토리)
local townMenuSel = 1       -- 마을 메뉴 선택
local TOWN_MENU = {"상점", "보관함", "도감", "던전 출발", "저장"}
local bestiaryScroll = 0
local dungeonRun = 0        -- 던전 탐험 횟수

-- 바닥 아이템 드롭 테이블 (층별 가중치)
local DROP_TABLE = {
    -- 소비/재료
    {id = "health_potion", weight = 30, minFloor = 1},
    {id = "large_potion",  weight = 10, minFloor = 2},
    {id = "gold_coin",     weight = 25, minFloor = 1},
    -- 일반 무기
    {id = "short_sword",   weight = 15, minFloor = 1},
    {id = "rusty_sword",   weight = 18, minFloor = 1},
    -- 고급 무기
    {id = "dagger",        weight = 10, minFloor = 1},
    {id = "steel_sword",   weight = 8,  minFloor = 2},
    {id = "long_sword",    weight = 7,  minFloor = 2},
    -- 희귀 무기
    {id = "flame_dagger",  weight = 4,  minFloor = 3},
    {id = "venom_blade",   weight = 4,  minFloor = 3},
    {id = "battle_axe",    weight = 4,  minFloor = 3},
    {id = "frost_halberd", weight = 3,  minFloor = 3},
    -- 영웅 무기
    {id = "vampiric_blade",     weight = 2, minFloor = 4},
    {id = "thunder_sword",      weight = 2, minFloor = 4},
    {id = "inferno_greatsword", weight = 2, minFloor = 4},
    -- 희귀 무기 (추가)
    {id = "holy_mace",     weight = 3,  minFloor = 3},
    {id = "ice_stiletto",  weight = 3,  minFloor = 3},
    {id = "silver_spear",  weight = 4,  minFloor = 2},
    {id = "storm_staff",   weight = 3,  minFloor = 3},
    {id = "glacier_staff", weight = 3,  minFloor = 3},
    {id = "bone_wand",     weight = 3,  minFloor = 3},
    {id = "moon_katana",   weight = 2,  minFloor = 4},
    -- 고급 양손 (추가)
    {id = "war_hammer",    weight = 6,  minFloor = 2},
    -- 전설 무기
    {id = "dragon_blade",   weight = 1, minFloor = 5},
    {id = "soul_reaper",    weight = 1, minFloor = 5},
    {id = "abyssal_scythe", weight = 1, minFloor = 5},
    -- 방패
    {id = "wooden_shield", weight = 12, minFloor = 1},
    {id = "iron_shield",   weight = 6,  minFloor = 2},
    {id = "thorn_shield",  weight = 3,  minFloor = 3},
    {id = "mirror_shield", weight = 2,  minFloor = 4},
    {id = "dragon_shield", weight = 1,  minFloor = 5},
    -- 방어구
    {id = "leather_armor", weight = 12, minFloor = 1},
    {id = "chain_mail",    weight = 6,  minFloor = 2},
    {id = "plate_armor",   weight = 3,  minFloor = 3},
    {id = "shadow_robe",   weight = 2,  minFloor = 4},
    {id = "dragon_armor",  weight = 1,  minFloor = 5},
    {id = "silk_robe",     weight = 10, minFloor = 1},
    {id = "inferno_robe",  weight = 3,  minFloor = 3},
    {id = "frost_mail",    weight = 3,  minFloor = 3},
    {id = "templar_plate", weight = 2,  minFloor = 4},
    {id = "necro_robe",    weight = 2,  minFloor = 4},
    -- 투구
    {id = "iron_helmet",     weight = 10, minFloor = 1},
    {id = "mage_hat",        weight = 6,  minFloor = 2},
    {id = "berserker_helm",  weight = 3,  minFloor = 3},
    {id = "royal_crown",     weight = 2,  minFloor = 4},
    {id = "dragon_helm",     weight = 1,  minFloor = 5},
    -- 신발
    {id = "leather_boots",  weight = 10, minFloor = 1},
    {id = "iron_greaves",   weight = 6,  minFloor = 2},
    {id = "swift_boots",    weight = 3,  minFloor = 3},
    {id = "shadow_boots",   weight = 2,  minFloor = 4},
    {id = "dragon_boots",   weight = 1,  minFloor = 5},
    -- 반지
    {id = "copper_ring",    weight = 8,  minFloor = 1},
    {id = "silver_ring",    weight = 5,  minFloor = 2},
    {id = "emerald_ring",   weight = 3,  minFloor = 3},
    {id = "ruby_ring",      weight = 2,  minFloor = 4},
    {id = "ring_of_power",  weight = 1,  minFloor = 5},
    -- 목걸이
    {id = "silver_amulet",      weight = 6, minFloor = 2},
    {id = "healing_pendant",    weight = 3, minFloor = 3},
    {id = "amulet_of_fury",     weight = 2, minFloor = 4},
    {id = "amulet_of_eternity", weight = 1, minFloor = 5},
    -- 재료
    {id = "dragon_scale",  weight = 1,  minFloor = 5},
}

local addMessage

-- ===== 종족별 금기 규칙 =====
local RACE_RESTRICTIONS = {
    undead_p = {
        forbiddenClasses = {paladin=true, priest=true, shaman=true, guardian=true},
        forbiddenElements = {holy=true},
        forbiddenItems = {holy_mace=true, soul_reaper=true, silver_spear=true, templar_plate=true},
        reason = "언데드는 신성한 직업/마법/무기를 사용할 수 없습니다.",
    },
    lizardfolk = {
        forbiddenClasses = {pyromancer=true},
        forbiddenElements = {fire=true},
        forbiddenItems = {inferno_robe=true},
        reason = "리자드맨은 화염 마법과 화염 무기를 다루지 못합니다.",
    },
    merfolk = {
        forbiddenClasses = {stormcaller=true},
        forbiddenElements = {lightning=true},
        reason = "인어는 번개 계열 힘을 피합니다.",
    },
    demonborn = {
        forbiddenClasses = {paladin=true, priest=true},
        forbiddenElements = {holy=true},
        forbiddenItems = {holy_mace=true, silver_spear=true, templar_plate=true},
        reason = "마족은 신성한 힘을 거부합니다.",
    },
    angelborn = {
        forbiddenClasses = {necromancer=true, warlock=true},
        forbiddenElements = {poison=true},
        forbiddenItems = {vampiric_blade=true, abyssal_scythe=true, venom_blade=true, bone_wand=true, necro_robe=true},
        reason = "천족은 타락/독 계열 힘을 사용할 수 없습니다.",
    },
    golem_p = {
        forbiddenClasses = {rogue=true, ranger=true},
        forbiddenItems = {leather_armor=true, shadow_robe=true, swift_boots=true, shadow_boots=true},
        reason = "골렘은 은밀하거나 가벼운 장비 운용에 맞지 않습니다.",
    },
    troll_p = {
        forbiddenClasses = {mage=true, cryomancer=true, stormcaller=true},
        reason = "트롤은 정교한 학파 마법을 배우기 어렵습니다.",
    },
    vampire = {
        forbiddenClasses = {paladin=true, priest=true},
        forbiddenElements = {holy=true},
        forbiddenItems = {holy_mace=true, silver_spear=true, templar_plate=true},
        reason = "흡혈귀는 신성 계열 힘을 사용할 수 없습니다.",
    },
    sylph = {
        forbiddenItems = {plate_armor=true, dragon_armor=true},
        reason = "실프는 너무 무거운 갑옷을 입지 못합니다.",
    },
    fae = {
        forbiddenItems = {war_hammer=true, battle_axe=true, inferno_greatsword=true, dragon_blade=true},
        reason = "페이는 지나치게 무거운 무기를 다루지 못합니다.",
    },
}

local function getRaceRestriction(raceId)
    return RACE_RESTRICTIONS[raceId or (player and player.raceId)] or {}
end

local function isElementForbiddenForRace(raceId, element)
    if not element or element == "physical" then return false end
    local rule = getRaceRestriction(raceId)
    return rule.forbiddenElements and rule.forbiddenElements[element] == true
end

local function isItemForbiddenForRace(raceId, item)
    if not item then return false, nil end
    local rule = getRaceRestriction(raceId)
    if rule.forbiddenItems and rule.forbiddenItems[item.id] then
        return true, rule.reason
    end
    if item.slot == "weapon" and isElementForbiddenForRace(raceId, item.element) then
        return true, rule.reason
    end
    return false, nil
end

local function isClassAllowedForRace(race, class)
    if not race or not class then return true, nil end
    local rule = getRaceRestriction(race.id)
    if rule.forbiddenClasses and rule.forbiddenClasses[class.id] then
        return false, rule.reason
    end
    for _, skill in ipairs(class.skills or {}) do
        if isElementForbiddenForRace(race.id, skill.element) then
            return false, rule.reason
        end
    end
    if class.startWeapon then
        local startWeapon = Item.create(class.startWeapon)
        local blocked, reason = isItemForbiddenForRace(race.id, startWeapon)
        if blocked then return false, reason end
    end
    return true, nil
end

local function canUseSkillByRestriction(skill)
    if not skill then return true end
    if isElementForbiddenForRace(player.raceId, skill.element) then
        local rule = getRaceRestriction(player.raceId)
        addMessage(rule.reason or "이 종족은 해당 속성의 기술을 사용할 수 없습니다.")
        return false
    end
    return true
end

local function canEquipItemByRestriction(item)
    local blocked, reason = isItemForbiddenForRace(player and player.raceId, item)
    if blocked then
        addMessage(reason or "이 종족은 해당 장비를 사용할 수 없습니다.")
        return false
    end
    return true
end

-- ===== 유틸리티 =====
addMessage = function(text)
    table.insert(messages, 1, text)
    messageScroll = 0
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

local function hasAliveBoss()
    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.isBoss then
            return true
        end
    end
    return false
end

local function saveFloorState()
    floorStates[floor] = {
        map = map,
        rooms = rooms,
        enemies = enemies,
        groundItems = groundItems,
        upX = floorStates[floor] and floorStates[floor].upX or nil,
        upY = floorStates[floor] and floorStates[floor].upY or nil,
        downX = floorStates[floor] and floorStates[floor].downX or nil,
        downY = floorStates[floor] and floorStates[floor].downY or nil,
    }
end

local function loadFloorState(targetFloor)
    local state = floorStates[targetFloor]
    if not state then return false end
    map = state.map
    rooms = state.rooms
    enemies = state.enemies
    groundItems = state.groundItems
    return true
end

local function setPlayerAtFloorEntry(direction)
    local state = floorStates[floor]
    if not state then return end

    if direction == "down" and state.upX then
        player.x, player.y = state.upX, state.upY
    elseif direction == "up" and state.downX then
        player.x, player.y = state.downX, state.downY
    elseif rooms[1] then
        player.x, player.y = rooms[1].cx, rooms[1].cy
    end
end

--- 드롭 테이블에서 랜덤 아이템 생성
local function rollDrop()
    local available = {}
    local totalWeight = 0
    for _, entry in ipairs(DROP_TABLE) do
        if floor >= entry.minFloor then
            table.insert(available, entry)
            totalWeight = totalWeight + entry.weight
        end
    end
    if #available == 0 then return nil end

    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, entry in ipairs(available) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            local item = Item.create(entry.id)
            if item and item.stackable then
                if item.id == "gold_coin" then
                    item.count = math.random(5, 15 + floor * 5)
                elseif item.id == "health_potion" then
                    item.count = math.random(1, 2)
                end
            end
            return item
        end
    end
    return nil
end

-- ===== 맵 생성 =====
local function carveRoomShape(room, shape)
    local x, y, w, h = room.x, room.y, room.w, room.h
    for ry = y, y + h - 1 do
        for rx = x, x + w - 1 do
            local carve = false
            if shape == "rect" then
                carve = true
            elseif shape == "cross" then
                carve = (math.abs(rx - room.cx) <= 1) or (math.abs(ry - room.cy) <= 1)
            elseif shape == "round" then
                local nx = (rx - room.cx) / math.max(1, w / 2)
                local ny = (ry - room.cy) / math.max(1, h / 2)
                carve = nx * nx + ny * ny <= 1.05
            elseif shape == "chamber" then
                carve = true
                if math.random() < 0.18 and not (rx == room.cx and ry == room.cy) then
                    carve = false
                end
            end

            if carve then
                map[ry][rx] = TILE_FLOOR
            end
        end
    end
    map[room.cy][room.cx] = TILE_FLOOR
end

local function carveCorridor(x1, y1, x2, y2)
    if math.random() < 0.5 then
        for cx = math.min(x1, x2), math.max(x1, x2) do
            map[y1][cx] = TILE_FLOOR
        end
        for cy = math.min(y1, y2), math.max(y1, y2) do
            map[cy][x2] = TILE_FLOOR
        end
    else
        for cy = math.min(y1, y2), math.max(y1, y2) do
            map[cy][x1] = TILE_FLOOR
        end
        for cx = math.min(x1, x2), math.max(x1, x2) do
            map[y2][cx] = TILE_FLOOR
        end
    end
end

local function createMap()
    map = {}
    rooms = {}
    enemies = {}
    groundItems = {}

    for y = 1, MAP_HEIGHT do
        map[y] = {}
        for x = 1, MAP_WIDTH do
            map[y][x] = TILE_WALL
        end
    end

    local roomAttempts = MAX_ROOMS + math.random(0, 4)
    for i = 1, roomAttempts do
        local w = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local h = math.random(MIN_ROOM_SIZE, MAX_ROOM_SIZE)
        local x = math.random(2, MAP_WIDTH - w - 1)
        local y = math.random(2, MAP_HEIGHT - h - 1)

        local overlap = false
        for _, room in ipairs(rooms) do
            if x <= room.x + room.w + 1 and x + w + 1 >= room.x and
               y <= room.y + room.h + 1 and y + h + 1 >= room.y then
                overlap = true
                break
            end
        end

        if not overlap then
            local room = {x = x, y = y, w = w, h = h,
                          cx = math.floor(x + w / 2),
                          cy = math.floor(y + h / 2)}
            local shapes = {"rect", "rect", "cross", "round", "chamber"}
            carveRoomShape(room, shapes[math.random(1, #shapes)])
            table.insert(rooms, room)

            if #rooms > 1 then
                local prev = rooms[#rooms - 1]
                carveCorridor(prev.cx, prev.cy, room.cx, room.cy)
            end
        end
    end

    -- 가끔 떨어진 방끼리 추가 연결해 순환 구조를 만든다.
    for _ = 1, math.random(1, 3) do
        if #rooms >= 3 then
            local a = rooms[math.random(1, #rooms)]
            local b = rooms[math.random(1, #rooms)]
            if a ~= b then
                carveCorridor(a.cx, a.cy, b.cx, b.cy)
            end
        end
    end

    if #rooms > 1 then
        local firstRoom = rooms[1]
        local lastRoom = rooms[#rooms]
        if floor > 1 then
            map[firstRoom.cy][firstRoom.cx] = TILE_STAIR_UP
            floorStates[floor] = floorStates[floor] or {}
            floorStates[floor].upX = firstRoom.cx
            floorStates[floor].upY = firstRoom.cy
        end
        map[lastRoom.cy][lastRoom.cx] = TILE_STAIR_DOWN
        floorStates[floor] = floorStates[floor] or {}
        floorStates[floor].downX = lastRoom.cx
        floorStates[floor].downY = lastRoom.cy
    end
end

local function getRandomFloorInRoom(room)
    for _ = 1, 30 do
        local x = math.random(room.x + 1, room.x + room.w - 2)
        local y = math.random(room.y + 1, room.y + room.h - 2)
        if map[y] and map[y][x] == TILE_FLOOR then
            return x, y
        end
    end
    return room.cx, room.cy
end

-- ===== 종족/속성 시스템 =====

-- 종족 데이터베이스
local RACE_DB = {
    human = {
        name = "인간", desc = "균형 잡힌 종족. 특별한 약점이나 저항이 없다.",
        color = {0.9, 0.8, 0.7},
        resist = {},  -- 저항 없음
        weak = {},    -- 약점 없음
    },
    beast = {
        name = "야수", desc = "야생의 동물. 빠르지만 마법에 약하다.",
        color = {0.7, 0.5, 0.3},
        resist = {pierce = 0.2},
        weak = {fire = 0.3, lightning = 0.2},
    },
    goblinoid = {
        name = "고블린류", desc = "작고 교활한 종족. 독에 강하지만 신성에 약하다.",
        color = {0.2, 0.7, 0.2},
        resist = {poison = 0.3},
        weak = {holy = 0.3},
    },
    undead = {
        name = "언데드", desc = "죽은 자. 독/빙결 면역이지만 화염/신성에 매우 약하다.",
        color = {0.4, 0.5, 0.3},
        resist = {poison = 1.0, ice = 0.5, slash = 0.3},
        weak = {fire = 0.5, holy = 0.5, strike = 0.3},
    },
    demon = {
        name = "악마", desc = "지옥의 존재. 화염에 강하지만 신성/빙결에 약하다.",
        color = {0.8, 0.1, 0.2},
        resist = {fire = 0.5, poison = 0.3},
        weak = {holy = 0.5, ice = 0.3},
    },
    dragon = {
        name = "용족", desc = "고대의 비늘 전사. 화염에 강하고 참격에 저항한다.",
        color = {1.0, 0.5, 0.1},
        resist = {fire = 0.5, slash = 0.3},
        weak = {ice = 0.3, pierce = 0.2},
    },
    construct = {
        name = "구조체", desc = "무기물/인공물. 독/화염 면역. 번개/타격에 약하다.",
        color = {0.6, 0.6, 0.6},
        resist = {poison = 1.0, fire = 0.3, slash = 0.3, pierce = 0.3},
        weak = {lightning = 0.5, strike = 0.5},
    },
    insect = {
        name = "곤충", desc = "작은 다지류. 독에 강하지만 화염에 매우 약하다.",
        color = {0.3, 0.6, 0.2},
        resist = {poison = 0.5},
        weak = {fire = 0.5, strike = 0.3},
    },
    reptile = {
        name = "파충류", desc = "냉혈 생물. 독에 저항하지만 빙결에 약하다.",
        color = {0.2, 0.6, 0.4},
        resist = {poison = 0.3},
        weak = {ice = 0.4},
    },
    orc = {
        name = "오크", desc = "강인한 전사 종족. 타격에 강하지만 마법에 약하다.",
        color = {0.5, 0.7, 0.2},
        resist = {strike = 0.2},
        weak = {lightning = 0.2, fire = 0.15},
    },
    troll = {
        name = "트롤", desc = "재생력이 뛰어난 거인. 화염에 매우 약하다.",
        color = {0.3, 0.6, 0.3},
        resist = {strike = 0.2, poison = 0.2},
        weak = {fire = 0.5},
    },
    elf = {
        name = "엘프", desc = "마법 친화적 종족. 마법에 저항하지만 물리에 약하다.",
        color = {0.4, 0.3, 0.7},
        resist = {fire = 0.2, ice = 0.2, lightning = 0.2},
        weak = {strike = 0.3, slash = 0.15},
    },
}

--- 속성 상성 데미지 배율 계산
local function getElementMult(element, race)
    if not race or not RACE_DB[race] then return 1.0 end
    local raceData = RACE_DB[race]

    -- 저항 체크 (데미지 감소)
    local resist = raceData.resist[element]
    if resist then
        if resist >= 1.0 then return 0 end  -- 면역
        return 1.0 - resist
    end

    -- 약점 체크 (데미지 증가)
    local weak = raceData.weak[element]
    if weak then
        return 1.0 + weak
    end

    return 1.0
end

-- ===== 몬스터 데이터베이스 (DCSS 스타일 + 종족) =====
local ENEMY_DB = {
    -- 1층: 약한 적
    {name="쥐",         char="r", hp=3,  atk=1, def=0, spd=1.2, exp=3,  ev=15, color={0.5,0.4,0.3}, floors={1,2}, race="beast", atkElement="pierce"},
    {name="고블린",      char="g", hp=6,  atk=2, def=0, spd=1.0, exp=6,  ev=10, color={0,0.8,0},     floors={1,2,3}, race="goblinoid", atkElement="slash"},
    {name="코볼트",      char="k", hp=5,  atk=2, def=1, spd=1.1, exp=5,  ev=12, color={0.6,0.5,0.2}, floors={1,2}, race="goblinoid", atkElement="pierce"},
    {name="박쥐",        char="b", hp=3,  atk=1, def=0, spd=1.5, exp=3,  ev=25, color={0.4,0.3,0.5}, floors={1,2,3}, race="beast", atkElement="pierce"},
    {name="좀비",        char="z", hp=10, atk=2, def=2, spd=0.5, exp=8,  ev=0,  color={0.3,0.5,0.2}, floors={1,2,3}, race="undead", atkElement="strike"},
    -- 2층: 중간 적
    {name="오크",        char="o", hp=12, atk=4, def=2, spd=1.0, exp=12, ev=8,  color={0.5,0.8,0.2}, floors={2,3,4}, race="orc", atkElement="slash"},
    {name="스켈레톤",    char="s", hp=8,  atk=3, def=4, spd=0.8, exp=10, ev=5,  color={0.9,0.9,0.8}, floors={2,3}, race="undead", atkElement="slash"},
    {name="독거미",      char="S", hp=7,  atk=3, def=0, spd=1.3, exp=10, ev=18, color={0.2,0.7,0.2}, floors={2,3}, race="insect", atkElement="poison"},
    {name="늑대",        char="w", hp=9,  atk=4, def=1, spd=1.4, exp=10, ev=15, color={0.5,0.5,0.5}, floors={2,3}, race="beast", atkElement="pierce"},
    {name="오크전사",    char="O", hp=18, atk=5, def=3, spd=0.9, exp=18, ev=8,  color={0.5,0.6,0.2}, floors={2,3,4}, race="orc", atkElement="strike"},
    -- 3층: 강한 적
    {name="트롤",        char="T", hp=25, atk=7, def=3, spd=0.7, exp=25, ev=5,  color={0.3,0.6,0.3}, floors={3,4}, race="troll", atkElement="strike"},
    {name="가고일",      char="G", hp=20, atk=5, def=8, spd=0.6, exp=22, ev=3,  color={0.5,0.5,0.5}, floors={3,4}, race="construct", atkElement="strike"},
    {name="리자드맨",    char="L", hp=18, atk=6, def=4, spd=1.1, exp=20, ev=12, color={0.2,0.6,0.4}, floors={3,4}, race="reptile", atkElement="slash"},
    {name="미노타우로스",char="M", hp=30, atk=8, def=4, spd=1.0, exp=30, ev=6,  color={0.6,0.3,0.1}, floors={3,4,5}, race="beast", atkElement="strike"},
    {name="워록",        char="W", hp=15, atk=9, def=2, spd=0.8, exp=28, ev=10, color={0.5,0.2,0.7}, floors={3,4,5}, race="human", atkElement="fire"},
    -- 4층: 엘리트
    {name="오우거",      char="F", hp=35, atk=10,def=5, spd=0.6, exp=35, ev=3,  color={0.7,0.4,0.2}, floors={4,5}, race="troll", atkElement="strike"},
    {name="다크엘프",    char="e", hp=20, atk=8, def=3, spd=1.3, exp=30, ev=20, color={0.3,0.2,0.5}, floors={4,5}, race="elf", atkElement="lightning"},
    {name="네크로맨서",  char="N", hp=22, atk=10,def=3, spd=0.9, exp=35, ev=12, color={0.4,0.1,0.4}, floors={4,5}, race="human", atkElement="poison"},
    {name="석상",        char="X", hp=40, atk=6, def=12,spd=0.4, exp=30, ev=0,  color={0.6,0.6,0.65},floors={4,5}, race="construct", atkElement="strike"},
    {name="화염마",      char="E", hp=25, atk=12,def=4, spd=1.0, exp=40, ev=15, color={1.0,0.3,0.1}, floors={4,5}, race="demon", atkElement="fire"},
    -- 5층: 보스급
    {name="드래곤",      char="D", hp=60, atk=15,def=8, spd=0.8, exp=80, ev=10, color={1,0.2,0},     floors={5}, race="dragon", atkElement="fire"},
    {name="리치",        char="$", hp=40, atk=14,def=5, spd=0.7, exp=70, ev=12, color={0.3,0.8,0.3}, floors={5}, race="undead", atkElement="ice"},
    {name="골렘",        char="#", hp=70, atk=12,def=15,spd=0.3, exp=60, ev=0,  color={0.5,0.4,0.3}, floors={5}, race="construct", atkElement="strike"},
    {name="악마",        char="&", hp=50, atk=16,def=6, spd=1.2, exp=90, ev=18, color={0.8,0.1,0.1}, floors={5}, race="demon", atkElement="fire"},
    {name="고대용",      char="@", hp=100,atk=20,def=10,spd=0.9, exp=150,ev=8,  color={1.0,0.8,0.0}, floors={5}, race="dragon", atkElement="fire"},
}

local BOSS_DB = {
    [2] = {name="고블린 왕", char="K", hp=45, atk=7, def=4, spd=0.9, exp=70, ev=10, color={0.2,1.0,0.2}, race="goblinoid", atkElement="slash"},
    [3] = {name="거미 여왕", char="Q", hp=70, atk=10, def=5, spd=1.1, exp=110, ev=16, color={0.4,0.9,0.3}, race="insect", atkElement="poison"},
    [4] = {name="룬 골렘", char="R", hp=95, atk=13, def=14, spd=0.5, exp=160, ev=2, color={0.6,0.7,1.0}, race="construct", atkElement="lightning"},
    [5] = {name="심연의 고대용", char="A", hp=150, atk=22, def=12, spd=0.8, exp=300, ev=8, color={1.0,0.15,0.15}, race="dragon", atkElement="fire"},
}

local function spawnBoss()
    local btype = BOSS_DB[floor]
    if not btype or #rooms < 2 then return end

    local room = rooms[#rooms]
    local bx, by = getRandomFloorInRoom(room)
    local hpVal = btype.hp + floor * 8
    table.insert(enemies, {
        x = bx,
        y = by,
        name = btype.name,
        char = btype.char,
        hp = hpVal,
        maxHp = hpVal,
        atk = btype.atk + floor,
        def = btype.def,
        ev = btype.ev,
        spd = btype.spd or 1.0,
        exp = btype.exp,
        color = btype.color,
        alive = true,
        race = btype.race or "human",
        atkElement = btype.atkElement or "physical",
        isBoss = true,
    })
    addMessage("보스 출현: " .. btype.name)
end

-- ===== 적 생성 =====
local function spawnEnemies()
    local available = {}
    for _, e in ipairs(ENEMY_DB) do
        for _, f in ipairs(e.floors) do
            if f == floor then
                table.insert(available, e)
                break
            end
        end
    end
    if #available == 0 then return end

    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(1, MAX_ENEMIES_PER_ROOM)
        for j = 1, count do
            local ex, ey = getRandomFloorInRoom(room)

            local etype = available[math.random(1, #available)]

            -- 층별 스케일링
            local scale = 1 + (floor - 1) * 0.15
            local hpVal  = math.floor(etype.hp * scale)
            local atkVal = math.floor(etype.atk * scale)
            local defVal = math.floor(etype.def * scale)

            table.insert(enemies, {
                x = ex, y = ey,
                name = etype.name,
                char = etype.char,
                hp = hpVal,
                maxHp = hpVal,
                atk = atkVal,
                def = defVal,
                ev = etype.ev,
                spd = etype.spd or 1.0,
                exp = math.floor(etype.exp * scale),
                color = etype.color,
                alive = true,
                race = etype.race or "human",
                atkElement = etype.atkElement or "physical",
            })
        end
    end
    spawnBoss()
end

-- ===== 바닥 아이템 생성 =====
local function spawnGroundItems()
    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(0, MAX_ITEMS_PER_ROOM)
        for j = 1, count do
            local ix, iy = getRandomFloorInRoom(room)
            local item = rollDrop()
            if item then
                table.insert(groundItems, {
                    x = ix, y = iy,
                    item = item,
                    picked = false,
                })
            end
        end
    end
end

-- ===== 플레이어 초기화 =====
local function initPlayer(keepStats)
    local startRoom = rooms[1]
    if keepStats then
        if startRoom then
            player.x = startRoom.cx
            player.y = startRoom.cy
        end
    else
        local race = charSelect.chosenRace or PLAYER_RACES[1]
        local class = charSelect.chosenClass or PLAYER_CLASSES[1]

        -- 기본 스탯 = 종족 기본 + 직업 보너스
        local baseStr = race.stats.str + class.statBonus.str
        local baseDex = race.stats.dex + class.statBonus.dex
        local baseInt = race.stats.int + class.statBonus.int
        local baseCon = race.stats.con + class.statBonus.con
        local baseLck = race.stats.lck + class.statBonus.lck

        -- 무기 숙련도 초기값 (종족 + 직업)
        local prof = {}
        local profElements = {"slash", "pierce", "strike", "fire", "ice", "lightning", "poison", "holy"}
        for _, e in ipairs(profElements) do
            prof[e] = (race.profBonus[e] or 0) + (class.profBonus[e] or 0)
        end

        -- 스킬 목록 (종족 + 직업)
        local skills = {}
        local function cloneSkill(s)
            return {
                id = s.id,
                name = s.name,
                desc = s.desc,
                cooldown = s.cooldown,
                currentCd = 0,
                duration = s.duration,
                type = s.type,
                value = s.value,
                element = s.element,
                statBonus = s.statBonus,
                attackScale = s.attackScale,
                healScale = s.healScale,
                range = s.range,
                active = 0
            }
        end
        for _, s in ipairs(race.skills) do
            table.insert(skills, cloneSkill(s))
        end
        for _, s in ipairs(class.skills) do
            table.insert(skills, cloneSkill(s))
        end

        -- 종족/직업 저항/약점 합산
        local pResist = {}
        local pWeak = {}
        for k, v in pairs(race.resist) do pResist[k] = v end
        for k, v in pairs(race.weak) do pWeak[k] = v end

        player = {
            x = startRoom and startRoom.cx or 1,
            y = startRoom and startRoom.cy or 1,
            char = race.char or "@",
            hp = 30,
            maxHp = 30,
            mana = 0,
            maxMana = 0,
            baseAtk = 3,
            baseDef = 0,
            exp = 0,
            nextExp = 20,
            level = 1,
            gold = 0,
            str = baseStr,
            dex = baseDex,
            int = baseInt,
            con = baseCon,
            lck = baseLck,
            raceName = race.name,
            raceId = race.id,
            className = class.name,
            classId = class.id,
            raceColor = race.color,
            classColor = class.color,
            proficiency = prof,
            skills = skills,
            resist = pResist,
            weak = pWeak,
            hpBonus = race.hpBonus or 0,
            expBonus = race.expBonus or 0,
            buffs = {},  -- {id, name, duration, ...}
            nextAtkBonus = nil,  -- 다음 공격 보너스 (강타/급소 등)
        }
    end
end

local getBuffStatBonus

--- 장비 스탯 포함 최종 스탯 계산
local function getPlayerAtk()
    local bonus = equip and equip:getTotalStats().atk or 0
    local strBonus = math.floor(player.str / 3)
    return player.baseAtk + bonus + strBonus + getBuffStatBonus("atk")
end

local function getPlayerDef()
    local bonus = equip and equip:getTotalStats().def or 0
    local conBonus = math.floor(player.con / 5)
    return player.baseDef + bonus + conBonus + getBuffStatBonus("def")
end

--- 회피율 (DEX + LCK 기반)
local function getPlayerEvasion()
    local eqSpd = equip and equip:getTotalStats().spd or 0
    return 5 + player.dex * 1.5 + player.lck * 0.5 + eqSpd + getBuffStatBonus("evasion")
end

--- 명중률 (DEX 기반)
local function getPlayerAccuracy()
    return 70 + player.dex * 2 + player.lck * 0.5 + getBuffStatBonus("accuracy")
end

--- 치명타 확률 (DEX + LCK 기반)
local function getPlayerCritChance()
    local eqCrit = equip and equip:getTotalStats().crit or 0
    return 5 + player.dex * 0.5 + player.lck * 1.0 + eqCrit + getBuffStatBonus("crit")
end

--- 치명타 배율
local function getPlayerCritMult()
    return 1.5 + player.str * 0.02
end

--- 최대 HP (CON 기반)
local function getPlayerMaxHp()
    local eqHp = equip and equip:getTotalStats().hp or 0
    local base = 30 + (player.level - 1) * 5
    local raceHp = player.hpBonus or 0
    return base + player.con * 3 + eqHp + raceHp + getBuffStatBonus("hp")
end

local function getPlayerMaxMana()
    local base = 12 + player.level * 2
    return math.max(0, base + player.int * 5 + math.floor(player.lck / 2) + getBuffStatBonus("mana"))
end

local function getPlayerManaRegen()
    return math.max(1, 1 + math.floor(player.int / 6))
end

--- 장비 패시브 효과 수집
local function getEquipPassives()
    local passives = {}
    if not equip then return passives end
    for _, item in pairs(equip.slots) do
        if item and item.passive then
            table.insert(passives, item.passive)
        end
    end
    return passives
end

--- 특정 패시브 합산
local function getPassiveValue(pType)
    local total = 0
    for _, p in ipairs(getEquipPassives()) do
        if p.type == pType then
            total = total + p.value
        end
    end
    return total
end

--- 패시브 보정된 회피율
local function getPlayerEvasionFull()
    return getPlayerEvasion() + getPassiveValue("dodge_boost")
end

--- 패시브 보정된 치명타
local function getPlayerCritFull()
    return getPlayerCritChance() + getPassiveValue("crit_boost")
end

--- 장착 무기의 공격 속성
local function getPlayerElement()
    if not equip then return "physical" end
    local w1 = equip:getItem("weapon1")
    if w1 and w1.element then return w1.element end
    return "physical"
end

--- 숙련도 보너스 데미지 배율
local function getProficiencyBonus(element)
    if not player.proficiency then return 1.0 end
    local prof = player.proficiency[element] or 0
    return 1.0 + prof * 0.03  -- 숙련도 1당 3% 데미지 증가
end

--- 무기 사용 시 숙련도 경험치 증가
local function gainProficiency(element)
    if not player.proficiency or not element or element == "physical" then return end
    local cur = player.proficiency[element] or 0
    if cur < 20 then  -- 최대 20
        player.proficiency[element] = cur + 0.2
    end
end

--- 플레이어 속성 저항/약점 적용 (적 공격 → 플레이어)
local function getPlayerElementDefense(element)
    if not element or element == "physical" then return 1.0 end
    if player.resist and player.resist[element] then
        local r = player.resist[element]
        if r >= 1.0 then return 0 end
        return 1.0 - r
    end
    if player.weak and player.weak[element] then
        return 1.0 + player.weak[element]
    end
    return 1.0
end

--- 활성 버프 체크
local function hasBuff(buffId)
    if not player.buffs then return false end
    for _, b in ipairs(player.buffs) do
        if b.id == buffId and b.duration > 0 then return true end
    end
    return false
end

getBuffStatBonus = function(stat)
    local total = 0
    if not player.buffs then return total end
    for _, b in ipairs(player.buffs) do
        if b.duration > 0 and b.statBonus and b.statBonus[stat] then
            total = total + b.statBonus[stat]
        end
    end
    return total
end

--- 버프 적용
local function applyBuff(buffId, name, duration, statBonus)
    if not player.buffs then player.buffs = {} end
    for _, b in ipairs(player.buffs) do
        if b.id == buffId then
            b.duration = duration
            b.statBonus = statBonus
            return
        end
    end
    table.insert(player.buffs, {id=buffId, name=name, duration=duration, statBonus=statBonus})
end

--- 버프 턴 감소
local function tickBuffs()
    if not player.buffs then return end
    local newBuffs = {}
    for _, b in ipairs(player.buffs) do
        b.duration = b.duration - 1
        if b.duration > 0 then
            table.insert(newBuffs, b)
        else
            addMessage("  [" .. b.name .. "] 효과 종료")
        end
    end
    player.buffs = newBuffs
end

--- 스킬 쿨다운 감소
local function tickSkillCooldowns()
    if not player.skills then return end
    for _, s in ipairs(player.skills) do
        if s.currentCd > 0 then
            s.currentCd = s.currentCd - 1
        end
    end
end

local function getSkillManaCost(skill)
    if not skill then return 0 end
    if skill.manaCost then return skill.manaCost end
    if skill.type == "attack" then
        return 7 + math.floor((skill.cooldown or 0) / 2)
    elseif skill.type == "heal" then
        return 10 + math.floor((skill.cooldown or 0) / 2)
    elseif skill.type == "buff" then
        return 6 + math.floor((skill.duration or 0) / 2)
    elseif skill.type == "nextAtk" then
        return 5
    end
    return 0
end

local function recoverMana(amount)
    if not player.maxMana or player.maxMana <= 0 then return end
    player.mana = math.min(player.maxMana, (player.mana or 0) + amount)
end

--- 스킬 사용
local function useSkill(skillIndex, targetEnemy)
    if not player.skills or not player.skills[skillIndex] then return false end
    local s = player.skills[skillIndex]
    if not canUseSkillByRestriction(s) then return false end
    if s.currentCd > 0 then
        addMessage(s.name .. " 쿨다운 중! (남은 " .. s.currentCd .. "턴)")
        return false
    end
    local manaCost = getSkillManaCost(s)
    if (player.mana or 0) < manaCost then
        addMessage(s.name .. " 사용 실패! 마나 부족 (" .. (player.mana or 0) .. "/" .. manaCost .. ")")
        return false
    end

    s.currentCd = s.cooldown
    player.mana = player.mana - manaCost

    if s.type == "buff" then
        applyBuff(s.id, s.name, s.duration, s.statBonus)
        addMessage("★ " .. s.name .. " 발동! (" .. s.duration .. "턴, MP -" .. manaCost .. ")")
        return true
    elseif s.type == "heal" then
        local healAmt = (s.value or 0) + math.floor(player.int * (s.healScale or 3))
        player.hp = math.min(player.hp + healAmt, getPlayerMaxHp())
        addMessage("★ " .. s.name .. "! HP +" .. healAmt .. " 회복! (MP -" .. manaCost .. ")")
        return true
    elseif s.type == "attack" then
        if not targetEnemy then
            addMessage("대상이 없습니다!")
            player.mana = player.mana + manaCost
            s.currentCd = 0
            return false
        end
        local dmg = math.max(1, math.floor((s.value or 0) + player.int * (s.attackScale or 2) + player.level * 2))
        local elem = s.element or "physical"
        local elemMult = getElementMult(elem, targetEnemy.race)
        if s.id == "holy_smite" and (targetEnemy.race == "undead" or targetEnemy.race == "demon") then
            dmg = dmg * 2
        end
        dmg = math.max(1, math.floor(dmg * elemMult))
        if elemMult == 0 then
            addMessage(targetEnemy.name .. "은(는) 면역!")
            return true
        end
        targetEnemy.hp = targetEnemy.hp - dmg
        local elemName = Item.ELEMENT_NAMES[elem] or elem
        addMessage("★ " .. s.name .. "! " .. targetEnemy.name .. "에게 " .. dmg .. " " .. elemName .. " 데미지! (MP -" .. manaCost .. ")")
        if s.id == "drain_life" then
            local heal = math.floor(dmg * 0.5)
            player.hp = math.min(player.hp + heal, getPlayerMaxHp())
            addMessage("  HP +" .. heal .. " 흡수!")
        end
        return true
    elseif s.type == "nextAtk" then
        player.nextAtkBonus = {name=s.name, mult=s.value, id=s.id}
        addMessage("★ " .. s.name .. " 준비! 다음 공격에 적용됩니다. (MP -" .. manaCost .. ")")
        return true
    end
    return false
end

--- 경험치 획득 (종족 보너스 적용)
local function gainExp(amount)
    local bonus = player.expBonus or 0
    local finalExp = math.max(1, math.floor(amount * (1 + bonus / 100)))
    player.exp = player.exp + finalExp
    return finalExp
end

-- ===== 레벨업 =====
local function checkLevelUp()
    while player.exp >= player.nextExp do
        player.exp = player.exp - player.nextExp
        player.level = player.level + 1
        player.baseAtk = player.baseAtk + 1
        player.nextExp = math.floor(player.nextExp * 1.5)

        -- 스탯 포인트 3점 배분
        statAlloc = {points = 3, sel = 1}
        gameState = "levelup"

        -- maxHp 재계산 + 풀HP
        player.maxHp = getPlayerMaxHp()
        player.hp = player.maxHp

        addMessage("** 레벨 업! Lv." .. player.level .. " — 스탯 포인트 3점을 배분하세요! **")
    end
end

-- ===== 전투 (DCSS 스타일 공식 + 패시브 효과) =====

--- 플레이어 → 적 한 번 공격 (내부 함수)
local function dealPlayerAttack(enemy)
    local accuracy = getPlayerAccuracy()
    local hitRoll = math.random(1, 100)
    local evade = enemy.ev or 0

    -- 정밀 사격 등 다음 공격 보너스 (명중 보정)
    local atkBonus = player.nextAtkBonus
    if atkBonus and atkBonus.id == "precise_shot" then
        accuracy = 999
    end

    if hitRoll > accuracy - evade then
        addMessage(enemy.name .. "이(가) 공격을 회피했다!")
        return 0
    end

    local atk = getPlayerAtk()
    -- 광폭화 버프: 공격력 2배
    if hasBuff("berserk") then atk = atk * 2 end
    -- 전쟁 함성 버프: 공격력 +30%
    if hasBuff("war_cry") then atk = math.floor(atk * 1.3) end

    local enemyDef = enemy.def or 0

    -- 방어관통 패시브
    local armorBreak = getPassiveValue("armor_break")
    if armorBreak > 0 then
        enemyDef = math.floor(enemyDef * (1 - armorBreak / 100))
    end
    -- 정밀 사격: 방어 무시
    if atkBonus and atkBonus.id == "precise_shot" then
        enemyDef = 0
    end

    local dmgReduction = math.floor(enemyDef * 0.6)
    local baseDmg = math.max(1, atk - dmgReduction)

    local variance = math.floor(baseDmg * 0.2)
    local dmg = baseDmg + math.random(-variance, variance)

    -- 치명타 판정 (패시브 보정)
    local critChance = getPlayerCritFull()
    local isCrit = math.random(1, 100) <= critChance
    -- 급소 찌르기: 치명타 확정
    if atkBonus and atkBonus.id == "backstab" then
        isCrit = true
    end
    if isCrit then
        local critMult = getPlayerCritMult()
        if atkBonus and atkBonus.id == "backstab" then critMult = 3.0 end
        dmg = math.floor(dmg * critMult)
    end
    dmg = math.max(1, dmg)

    -- 다음 공격 데미지 배율 (강타 등)
    if atkBonus then
        if atkBonus.id == "power_strike" or atkBonus.id == "precise_shot" then
            dmg = math.floor(dmg * atkBonus.mult)
        end
        addMessage("  [" .. atkBonus.name .. "] 적용!")
        player.nextAtkBonus = nil
    end

    -- 속성 상성 적용
    local pElement = getPlayerElement()
    local elemMult = getElementMult(pElement, enemy.race)
    if elemMult == 0 then
        addMessage(enemy.name .. "은(는) " .. (Item.ELEMENT_NAMES[pElement] or pElement) .. " 면역!")
        return 0
    end
    dmg = math.max(1, math.floor(dmg * elemMult))

    -- 숙련도 보너스 적용
    local profMult = getProficiencyBonus(pElement)
    dmg = math.max(1, math.floor(dmg * profMult))
    gainProficiency(pElement)

    enemy.hp = enemy.hp - dmg
    local msg = enemy.name .. "에게 " .. dmg .. " 데미지!"
    if isCrit then msg = "★ 치명타! " .. msg end
    if elemMult > 1.0 then
        msg = msg .. " (약점!)"
    elseif elemMult < 1.0 then
        msg = msg .. " (저항)"
    end
    addMessage(msg)

    -- 흡혈 패시브
    local lifesteal = getPassiveValue("lifesteal")
    if lifesteal > 0 then
        local heal = math.max(1, math.floor(dmg * lifesteal / 100))
        player.hp = math.min(player.maxHp, player.hp + heal)
        addMessage("  ♥ 흡혈 +" .. heal .. " HP")
    end

    -- 화상 패시브
    local burnVal = getPassiveValue("burn")
    if burnVal > 0 and math.random(1, 100) <= 35 then
        enemy.burn = (enemy.burn or 0) + burnVal
        addMessage("  🔥 " .. enemy.name .. " 화상! (" .. burnVal .. "턴)")
    end

    -- 독 패시브
    local poisonVal = getPassiveValue("poison")
    if poisonVal > 0 and math.random(1, 100) <= 25 then
        enemy.poison = (enemy.poison or 0) + poisonVal
        addMessage("  ☠ " .. enemy.name .. " 중독! (" .. poisonVal .. "턴)")
    end

    -- 기절 패시브
    local stunVal = getPassiveValue("stun")
    if stunVal > 0 and math.random(1, 100) <= stunVal then
        enemy.stunned = true
        addMessage("  ⚡ " .. enemy.name .. " 기절!")
    end

    return dmg
end

local function attackEnemy(enemy)
    local totalDmg = dealPlayerAttack(enemy)

    -- 연속타격 패시브
    if enemy.alive and enemy.hp > 0 then
        local doubleHit = getPassiveValue("double_hit")
        if doubleHit > 0 and math.random(1, 100) <= doubleHit then
            addMessage("  >> 연속 타격!")
            totalDmg = totalDmg + dealPlayerAttack(enemy)
        end
    end

    if enemy.hp <= 0 then
        enemy.alive = false

        -- 경험치 (exp_boost 패시브)
        local expBoost = getPassiveValue("exp_boost")
        local expGain = math.floor(enemy.exp * (1 + expBoost / 100))
        player.exp = player.exp + expGain
        addMessage(enemy.name .. " 처치! (+" .. expGain .. " 경험치)")
        if enemy.isBoss then
            addMessage("★ 보스를 쓰러뜨렸습니다! 계단이 안정되었습니다.")
        end

        -- 아이템 드롭 (40% + LCK 보정)
        local dropChance = enemy.isBoss and 1.0 or (0.4 + player.lck * 0.01)
        if math.random() < dropChance then
            local drop = rollDrop()
            if drop then
                table.insert(groundItems, {
                    x = enemy.x, y = enemy.y,
                    item = drop,
                    picked = false,
                })
                addMessage("  → " .. drop.name .. " 드롭!")
            end
        end

        -- 골드 드롭 (gold_boost 패시브)
        local goldBoost = getPassiveValue("gold_boost")
        local goldDrop = math.random(1, 5) + floor * 2
        if enemy.isBoss then
            goldDrop = goldDrop + floor * 25
        end
        goldDrop = math.floor(goldDrop * (1 + goldBoost / 100))
        player.gold = player.gold + goldDrop
        addMessage("  → " .. goldDrop .. "G 획득!")

        checkLevelUp()
    end
end

local function enemyAttack(enemy)
    -- 기절 체크
    if enemy.stunned then
        enemy.stunned = false
        addMessage(enemy.name .. "은(는) 기절에서 깨어났다!")
        return
    end

    local evasion = getPlayerEvasionFull()
    local hitRoll = math.random(1, 100)
    local enemyAcc = 60 + (enemy.atk or 0) * 2

    -- 행운의 회피 버프
    if hasBuff("lucky_dodge") then
        addMessage("  ★ 행운의 회피! " .. enemy.name .. "의 공격을 피했다!")
        return
    end

    if hitRoll > enemyAcc - evasion then
        addMessage(enemy.name .. "의 공격을 회피했다!")
        return
    end

    local def = getPlayerDef()
    -- 광폭화: 방어력 0
    if hasBuff("berserk") then def = 0 end
    -- 바위 피부: 방어력 +5
    if hasBuff("stone_skin") then def = def + 5 end
    -- 마나 실드: 데미지 20% 감소 (아래에서 적용)

    local dmg = math.max(1, (enemy.atk or 0) - math.floor(def * 0.6))
    local variance = math.floor(dmg * 0.15)
    dmg = dmg + math.random(-variance, variance)
    dmg = math.max(1, dmg)

    -- 마나 실드 데미지 감소
    if hasBuff("mana_shield") then
        dmg = math.max(1, math.floor(dmg * 0.8))
    end

    -- 플레이어 속성 저항/약점 적용
    local eElem = enemy.atkElement or "physical"
    local pDefMult = getPlayerElementDefense(eElem)
    if pDefMult == 0 then
        addMessage(enemy.name .. "의 " .. (Item.ELEMENT_NAMES[eElem] or eElem) .. " 공격 면역!")
        return
    end
    dmg = math.max(1, math.floor(dmg * pDefMult))

    player.hp = player.hp - dmg
    local elemName = Item.ELEMENT_NAMES[eElem] or eElem
    if eElem ~= "physical" then
        local extra = ""
        if pDefMult > 1.0 then extra = " (약점!)" end
        if pDefMult < 1.0 then extra = " (저항)" end
        addMessage(enemy.name .. "이(가) " .. dmg .. " " .. elemName .. " 데미지!" .. extra)
    else
        addMessage(enemy.name .. "이(가) " .. dmg .. " 데미지!")
    end

    -- 가시/반사 패시브
    local thorns = getPassiveValue("thorns")
    if thorns > 0 then
        enemy.hp = enemy.hp - thorns
        addMessage("  ◆ 가시 반사 " .. thorns .. " 데미지!")
        if enemy.hp <= 0 then
            enemy.alive = false
            gainExp(enemy.exp)
            addMessage(enemy.name .. " 처치! (가시 반사)")
            checkLevelUp()
        end
    end

    local reflect = getPassiveValue("reflect")
    if reflect > 0 then
        local refDmg = math.max(1, math.floor(dmg * reflect / 100))
        enemy.hp = enemy.hp - refDmg
        addMessage("  ◆ 반사 " .. refDmg .. " 데미지!")
        if enemy.hp <= 0 and enemy.alive then
            enemy.alive = false
            gainExp(enemy.exp)
            addMessage(enemy.name .. " 처치! (반사)")
            checkLevelUp()
        end
    end

    if player.hp <= 0 then
        gameState = "gameover"
        addMessage("** 사망했습니다! **")
    end
end

-- ===== 아이템 줍기 (인벤토리로) =====
local function pickupItem()
    for _, gi in ipairs(groundItems) do
        if not gi.picked and gi.x == player.x and gi.y == player.y then
            if inv:autoPlace(gi.item) then
                gi.picked = true
                addMessage(gi.item.name .. " 획득! (인벤토리)")
            else
                addMessage("인벤토리가 꽉 찼습니다!")
            end
        end
    end
end

-- ===== 아이템 버리기 =====
local function dropItemAtPlayer(item)
    if not item or not player.x or not player.y then
        return false
    end

    -- 버린 아이템은 즉시 줍기 루프에 다시 먹히지 않도록 바닥 아이템 상태만 새로 만든다.
    item._gridCol = nil
    item._gridRow = nil
    item._inventory = nil
    table.insert(groundItems, {
        x = player.x,
        y = player.y,
        item = item,
        picked = false
    })
    addMessage(item.name .. " 버림. (현재 위치 바닥)")
    return true
end

local function discardHoveredInventoryItem()
    if gameState ~= "inventory" or not inv then
        return false
    end

    local mx, my = love.mouse.getPosition()
    local item = inv:getItemAt(mx, my)
    if not item then
        addMessage("버릴 인벤토리 아이템에 마우스를 올리세요.")
        return false
    end

    inv:removeItem(item)
    hoverItem = nil
    return dropItemAtPlayer(item)
end

-- ===== 마을로 귀환 =====
local function goToTown()
    gameState = "town"
    townMenuSel = 1
    dungeonRun = dungeonRun + 1
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana
    shop.needsRefresh = true
    addMessage("** 마을에 도착했습니다! (HP/MP 회복) **")
end

-- ===== 던전 출발 =====
local function startDungeon()
    floor = 1
    turn = 0
    floorStates = {}
    gameState = "playing"
    addMessage(">> 던전 " .. (dungeonRun + 1) .. "번째 탐험 출발! <<")
    createMap()
    spawnEnemies()
    spawnGroundItems()
    saveFloorState()
    initPlayer(true)
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana
end

-- ===== 계단 =====
local function checkStair()
    if not map[player.y] then return end
    local tile = map[player.y][player.x]

    if tile == TILE_STAIR_DOWN then
        if hasAliveBoss() then
            addMessage("보스의 힘 때문에 아래 계단이 봉인되어 있습니다.")
            return
        end
        saveFloorState()
        floor = floor + 1
        if floor > 5 then
            addMessage("** 던전 클리어! 마을로 귀환합니다 **")
            goToTown()
            return
        end
        addMessage(">> " .. floor .. "층으로 이동 <<")
        if not loadFloorState(floor) then
            createMap()
            spawnEnemies()
            spawnGroundItems()
            saveFloorState()
        end
        initPlayer(true)
        setPlayerAtFloorEntry("down")
        player.maxMana = getPlayerMaxMana()
        player.mana = math.min(player.mana or player.maxMana, player.maxMana)
    elseif tile == TILE_STAIR_UP then
        if floor <= 1 then return end
        saveFloorState()
        floor = floor - 1
        addMessage("<< " .. floor .. "층으로 올라감 >>")
        loadFloorState(floor)
        initPlayer(true)
        setPlayerAtFloorEntry("up")
        player.maxMana = getPlayerMaxMana()
        player.mana = math.min(player.mana or player.maxMana, player.maxMana)
    end
end

-- ===== 턴 상태효과 처리 =====
local function processStatusEffects()
    -- 적 화상/독 처리
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            if enemy.burn and enemy.burn > 0 then
                local burnDmg = 2
                enemy.hp = enemy.hp - burnDmg
                enemy.burn = enemy.burn - 1
                addMessage("  " .. enemy.name .. " 화상 " .. burnDmg .. " 데미지! (남은 " .. enemy.burn .. "턴)")
                if enemy.hp <= 0 then
                    enemy.alive = false
                    gainExp(enemy.exp)
                    addMessage(enemy.name .. " 처치! (화상)")
                    checkLevelUp()
                end
            end
            if enemy.poison and enemy.poison > 0 then
                local poisonDmg = 3
                enemy.hp = enemy.hp - poisonDmg
                enemy.poison = enemy.poison - 1
                addMessage("  " .. enemy.name .. " 독 " .. poisonDmg .. " 데미지! (남은 " .. enemy.poison .. "턴)")
                if enemy.hp <= 0 and enemy.alive then
                    enemy.alive = false
                    gainExp(enemy.exp)
                    addMessage(enemy.name .. " 처치! (중독)")
                    checkLevelUp()
                end
            end
        end
    end

    -- 플레이어 재생 패시브
    local regen = getPassiveValue("regen")
    if regen > 0 and player.hp < player.maxHp then
        player.hp = math.min(player.maxHp, player.hp + regen)
        addMessage("재생 +" .. regen .. " HP")
    end

    -- 트롤 재생 버프
    if hasBuff("regenerate") and player.hp < getPlayerMaxHp() then
        local healAmt = 3
        player.hp = math.min(getPlayerMaxHp(), player.hp + healAmt)
        addMessage("  ★ 재생 +" .. healAmt .. " HP")
    end

    local manaBefore = player.mana or 0
    recoverMana(getPlayerManaRegen())
    if player.mana and player.mana > manaBefore then
        addMessage("마나 +" .. (player.mana - manaBefore))
    end

    -- 버프/스킬 쿨다운 처리
    tickBuffs()
    tickSkillCooldowns()
end

-- ===== 적 AI =====
local function moveEnemies()
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            local dist = distance(enemy.x, enemy.y, player.x, player.y)
            if dist <= 1 then
                enemyAttack(enemy)
            elseif dist <= 8 then
                local dx, dy = 0, 0
                if enemy.x < player.x then dx = 1
                elseif enemy.x > player.x then dx = -1 end
                if enemy.y < player.y then dy = 1
                elseif enemy.y > player.y then dy = -1 end

                if math.random() > 0.5 then dy = 0 else dx = 0 end

                local nx, ny = enemy.x + dx, enemy.y + dy
                if ny >= 1 and ny <= MAP_HEIGHT and nx >= 1 and nx <= MAP_WIDTH then
                    if map[ny][nx] ~= TILE_WALL then
                        local blocked = false
                        for _, other in ipairs(enemies) do
                            if other ~= enemy and other.alive and other.x == nx and other.y == ny then
                                blocked = true
                                break
                            end
                        end
                        if nx == player.x and ny == player.y then
                            blocked = true
                        end
                        if not blocked then
                            enemy.x = nx
                            enemy.y = ny
                        end
                    end
                end
            end
        end
    end
end

-- ===== 플레이어 이동 =====
local function movePlayer(dx, dy)
    if gameState ~= "playing" then return end

    local nx = player.x + dx
    local ny = player.y + dy

    if ny < 1 or ny > MAP_HEIGHT or nx < 1 or nx > MAP_WIDTH then return end
    if map[ny][nx] == TILE_WALL then return end

    for _, enemy in ipairs(enemies) do
        if enemy.alive and enemy.x == nx and enemy.y == ny then
            attackEnemy(enemy)
            turn = turn + 1
            processStatusEffects()
            moveEnemies()
            return
        end
    end

    player.x = nx
    player.y = ny
    turn = turn + 1

    pickupItem()
    checkStair()
    processStatusEffects()
    moveEnemies()
end

-- ===== LÖVE2D 콜백 =====
--- 캐릭터 생성 완료 → 마을로 이동
local function finishCharCreation()
    -- 인벤토리 & 장비 & 상점 & 보관함 초기화
    inv = Inventory.new(10, 6)
    equip = Equipment.new()
    shop = Shop.new()
    stash = Inventory.new(10, 6)

    dungeonRun = 0
    initPlayer()
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    player.maxMana = getPlayerMaxMana()
    player.mana = player.maxMana

    -- 직업별 시작 장비
    local cls = charSelect.chosenClass or PLAYER_CLASSES[1]
    if cls.startWeapon then
        local w = Item.create(cls.startWeapon)
        if w and canEquipItemByRestriction(w) then inv:autoPlace(w) end
    end
    if cls.startArmor then
        local a = Item.create(cls.startArmor)
        if a and canEquipItemByRestriction(a) then inv:autoPlace(a) end
    end
    if cls.startItems then
        for _, itemId in ipairs(cls.startItems) do
            local it = Item.create(itemId)
            if it then inv:autoPlace(it) end
        end
    end

    gameState = "town"
    townMenuSel = 1
    addMessage("마을에 오신 것을 환영합니다!")
    addMessage(player.raceName .. " " .. player.className .. "(으)로 모험을 시작합니다!")
    addMessage("상점에서 아이템을 사고팔 수 있습니다.")
end

local function resetAfterDeath()
    inv = nil
    equip = nil
    shop = nil
    stash = nil
    player = {}
    enemies = {}
    groundItems = {}
    map = {}
    rooms = {}
    floorStates = {}
    floor = 1
    turn = 0
    dungeonRun = 0
    statAlloc = nil
    drag.item = nil
    drag.fromInv = nil
    drag.fromSlot = nil
    hoverItem = nil
    charSelect = {
        phase = "race",
        raceSel = 1,
        classSel = 1,
        chosenRace = nil,
        chosenClass = nil,
    }
    messages = {}
    messageScroll = 0
    addMessage("사망했습니다. 캐릭터와 인벤토리가 모두 사라졌습니다.")
    addMessage("새 종족과 직업을 선택하세요.")
    gameState = "charselect"
end

function love.load()
    love.window.setTitle("Extraction Roguelike")
    love.window.setMode(MAP_WIDTH * TILE_SIZE + 270, MAP_HEIGHT * TILE_SIZE + 10, {resizable = false})

    font = love.graphics.newFont("NanumGothicCoding.ttf", 13)
    love.graphics.setFont(font)

    math.randomseed(os.time())

    -- 캐릭터 선택 화면으로 시작
    gameState = "charselect"
    charSelect.phase = "race"
    charSelect.raceSel = 1
    charSelect.classSel = 1
end

function love.update(dt)
    if gameState == "charselect" then return end
    if gameState == "inventory" or gameState == "stash" or gameState == "shop" then
        if not drag.item then
            local mx, my = love.mouse.getPosition()
            hoverItem = inv:getItemAt(mx, my)
            if not hoverItem then
                local slot = equip:getSlotAt(mx, my)
                if slot then
                    hoverItem = equip:getItem(slot)
                end
            end
            if not hoverItem and gameState == "stash" then
                hoverItem = stash:getItemAt(mx, my)
            end
            if not hoverItem and gameState == "shop" then
                hoverItem = shop:getItemAt(mx, my)
            end
        end
    end
end

function love.keypressed(key)
    -- 캐릭터 선택 화면
    if gameState == "charselect" then
        if charSelect.phase == "race" then
            if key == "up" or key == "w" then
                charSelect.raceSel = math.max(1, charSelect.raceSel - 1)
            elseif key == "down" or key == "s" then
                charSelect.raceSel = math.min(#PLAYER_RACES, charSelect.raceSel + 1)
            elseif key == "return" or key == "space" then
                charSelect.chosenRace = PLAYER_RACES[charSelect.raceSel]
                charSelect.phase = "class"
            end
        elseif charSelect.phase == "class" then
            if key == "up" or key == "w" then
                charSelect.classSel = math.max(1, charSelect.classSel - 1)
            elseif key == "down" or key == "s" then
                charSelect.classSel = math.min(#PLAYER_CLASSES, charSelect.classSel + 1)
            elseif key == "return" or key == "space" then
                local selectedClass = PLAYER_CLASSES[charSelect.classSel]
                local ok, reason = isClassAllowedForRace(charSelect.chosenRace, selectedClass)
                if not ok then
                    addMessage(reason or "이 종족은 해당 직업을 선택할 수 없습니다.")
                    return
                end
                charSelect.chosenClass = selectedClass
                finishCharCreation()
            elseif key == "escape" then
                charSelect.phase = "race"
            end
        end
        return
    end

    -- 스킬 핫키 — 게임 플레이 중
    if gameState == "playing" and player.skills then
        local skillKey = tonumber(key)
        if skillKey and skillKey >= 1 and skillKey <= #player.skills then
            local selectedSkill = player.skills[skillKey]
            local target = nil

            -- 공격 마법/스킬은 근처 적을 자동 타겟한다.
            if selectedSkill.type == "attack" then
                local range = selectedSkill.range or 6
                local bestDist = range + 1
                for _, e in ipairs(enemies) do
                    local dist = distance(player.x, player.y, e.x, e.y)
                    if e.alive and dist <= range and dist < bestDist then
                        target = e
                        bestDist = dist
                    end
                end
            end

            if selectedSkill.type == "attack" and not target then
                addMessage("사거리 안에 대상이 없습니다.")
                return
            end

            local used = useSkill(skillKey, target)
            if used then
                -- 공격 스킬 사용 후 턴 소비
                local s = selectedSkill
                if s.type == "attack" or s.type == "heal" then
                    turn = turn + 1
                    processStatusEffects()
                    moveEnemies()
                end
                -- 적 처치 체크
                if target and target.hp <= 0 and target.alive then
                    target.alive = false
                    gainExp(target.exp or 0)
                    local goldDrop = math.random(5, 15) * floor
                    if target.isBoss then
                        goldDrop = goldDrop + floor * 25
                        addMessage("★ 보스를 쓰러뜨렸습니다! 계단이 안정되었습니다.")
                    end
                    player.gold = player.gold + goldDrop
                    addMessage(target.name .. " 처치! (+" .. target.exp .. " 경험치, +" .. goldDrop .. " 골드)")
                    if target.isBoss then
                        local drop = rollDrop()
                        if drop then
                            table.insert(groundItems, {x = target.x, y = target.y, item = drop, picked = false})
                            addMessage("  → " .. drop.name .. " 드롭!")
                        end
                    end
                    checkLevelUp()
                end
            end
            return
        end
    end

    -- 인벤토리 토글
    if key == "i" or key == "tab" then
        if gameState == "playing" then
            gameState = "inventory"
            drag.item = nil
            hoverItem = nil
            return
        elseif gameState == "inventory" then
            gameState = "playing"
            drag.item = nil
            hoverItem = nil
            return
        end
    end

    if gameState == "inventory" and (key == "delete" or key == "backspace") then
        discardHoveredInventoryItem()
        return
    end

    if key == "escape" then
        if gameState == "inventory" then
            gameState = "playing"
            drag.item = nil
            hoverItem = nil
            return
        elseif gameState == "shop" then
            if drag.item then
                if drag.fromSlot == "shop" then
                    shop:addItem(drag.item, drag.shopPrice)
                else
                    inv:autoPlace(drag.item)
                end
                drag.item = nil
            end
            gameState = "town"
            hoverItem = nil
            return
        elseif gameState == "stash" then
            gameState = "town"
            drag.item = nil
            hoverItem = nil
            return
        end
    end

    -- 마을 메뉴
    if gameState == "town" then
        if key == "up" or key == "w" then
            townMenuSel = townMenuSel - 1
            if townMenuSel < 1 then townMenuSel = #TOWN_MENU end
        elseif key == "down" or key == "s" then
            townMenuSel = townMenuSel + 1
            if townMenuSel > #TOWN_MENU then townMenuSel = 1 end
        elseif key == "return" or key == "space" then
            local sel = TOWN_MENU[townMenuSel]
            if sel == "상점" then
                if shop.needsRefresh then
                    shop:refresh()
                end
                gameState = "shop"
                drag.item = nil
                hoverItem = nil
            elseif sel == "보관함" then
                gameState = "stash"
                drag.item = nil
                hoverItem = nil
            elseif sel == "도감" then
                gameState = "bestiary"
                bestiaryScroll = 0
            elseif sel == "던전 출발" then
                startDungeon()
            elseif sel == "저장" then
                addMessage("게임이 저장되었습니다!")
            end
        end
        return
    end

    -- 도감 조작
    if gameState == "bestiary" then
        if key == "escape" then
            gameState = "town"
            return
        end
        local totalRaces = 0
        for _ in pairs(RACE_DB) do totalRaces = totalRaces + 1 end
        if key == "up" or key == "w" then
            bestiaryScroll = math.max(0, bestiaryScroll - 1)
        elseif key == "down" or key == "s" then
            bestiaryScroll = math.min(math.max(0, totalRaces - 4), bestiaryScroll + 1)
        end
        return
    end

    if gameState == "gameover" then
        if key == "r" then
            resetAfterDeath()
        end
        return
    end

    -- 레벨업 스탯 배분
    if gameState == "levelup" and statAlloc then
        local STAT_KEYS = {"str", "dex", "int", "con", "lck"}
        if key == "up" or key == "w" then
            statAlloc.sel = statAlloc.sel - 1
            if statAlloc.sel < 1 then statAlloc.sel = #STAT_KEYS end
        elseif key == "down" or key == "s" then
            statAlloc.sel = statAlloc.sel + 1
            if statAlloc.sel > #STAT_KEYS then statAlloc.sel = 1 end
        elseif key == "return" or key == "space" then
            local stat = STAT_KEYS[statAlloc.sel]
            player[stat] = player[stat] + 1
            statAlloc.points = statAlloc.points - 1
            addMessage(stat:upper() .. " +1! (현재 " .. player[stat] .. ")")

            -- maxHp 재계산
            player.maxHp = getPlayerMaxHp()
            player.hp = math.min(player.hp, player.maxHp)
            player.maxMana = getPlayerMaxMana()
            player.mana = math.min(player.mana or player.maxMana, player.maxMana)

            if statAlloc.points <= 0 then
                statAlloc = nil
                gameState = "playing"
                addMessage("스탯 배분 완료!")
            end
        end
        return
    end

    if gameState ~= "playing" then return end

    if key == "up" or key == "w" then
        movePlayer(0, -1)
    elseif key == "down" or key == "s" then
        movePlayer(0, 1)
    elseif key == "left" or key == "a" then
        movePlayer(-1, 0)
    elseif key == "right" or key == "d" then
        movePlayer(1, 0)
    elseif key == "space" then
        turn = turn + 1
        processStatusEffects()
        moveEnemies()
    elseif key == "pageup" then
        messageScroll = math.min(messageScroll + 3, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
    elseif key == "pagedown" then
        messageScroll = math.max(0, messageScroll - 3)
    end
end

function love.mousepressed(x, y, button)
    if gameState == "charselect" then return end
    -- 상점 클릭
    if gameState == "shop" then
        if button == 1 then
            -- 상점 그리드에서 드래그
            local shopItem = shop:getItemAt(x, y)
            if shopItem then
                drag.item = shopItem
                drag.fromInv = false
                drag.fromSlot = "shop"
                drag.shopPrice = shop:getPrice(shopItem)
                shop:removeItem(shopItem)
                hoverItem = nil
                return
            end
            -- 인벤토리에서 드래그
            local invItem = inv:getItemAt(x, y)
            if invItem then
                drag.item = invItem
                drag.fromInv = true
                drag.fromSlot = nil
                drag.shopPrice = nil
                inv:removeItem(invItem)
                hoverItem = nil
                return
            end
        elseif button == 2 then
            -- 우클릭: 빠른 구매/판매
            local shopItem = shop:getItemAt(x, y)
            if shopItem then
                local price = shop:getPrice(shopItem)
                if player.gold >= price then
                    shop:removeItem(shopItem)
                    if inv:autoPlace(shopItem) then
                        player.gold = player.gold - price
                        addMessage(shopItem.name .. " 구매! (-" .. price .. "G)")
                    else
                        shop:addItem(shopItem, price)
                        addMessage("인벤토리가 꽉 찼습니다!")
                    end
                else
                    addMessage("골드가 부족합니다!")
                end
                return
            end
            local invItem = inv:getItemAt(x, y)
            if invItem then
                local price = shop:getSellPrice(invItem)
                inv:removeItem(invItem)
                player.gold = player.gold + price
                shop:addItem(invItem, price)
                addMessage(invItem.name .. " 판매! (+" .. price .. "G)")
                return
            end
        end
        return
    end

    -- 보관함 클릭
    if gameState == "stash" then
        if button == 1 then
            -- 인벤토리에서 드래그
            local item = inv:getItemAt(x, y)
            if item then
                drag.item = item
                drag.fromInv = true
                drag.fromSlot = nil
                inv:removeItem(item)
                hoverItem = nil
                return
            end
            -- 보관함에서 드래그
            local sItem = stash:getItemAt(x, y)
            if sItem then
                drag.item = sItem
                drag.fromInv = false
                drag.fromSlot = "stash"
                stash:removeItem(sItem)
                hoverItem = nil
                return
            end
        elseif button == 2 then
            -- 인벤토리 → 보관함 이동
            local item = inv:getItemAt(x, y)
            if item then
                inv:removeItem(item)
                if not stash:autoPlace(item) then
                    inv:autoPlace(item)
                    addMessage("보관함이 꽉 찼습니다!")
                else
                    addMessage(item.name .. " → 보관함")
                end
                return
            end
            -- 보관함 → 인벤토리 이동
            local sItem = stash:getItemAt(x, y)
            if sItem then
                stash:removeItem(sItem)
                if not inv:autoPlace(sItem) then
                    stash:autoPlace(sItem)
                    addMessage("인벤토리가 꽉 찼습니다!")
                else
                    addMessage(sItem.name .. " → 인벤토리")
                end
                return
            end
        end
        return
    end

    -- 마을 메뉴 클릭
    if gameState == "town" then
        if button == 1 then
            local sw = love.graphics.getWidth()
            local sh = love.graphics.getHeight()
            local menuW = 200
            local menuH = #TOWN_MENU * 40 + 20
            local menuX = sw / 2 - menuW / 2
            local menuY = sh / 2 - menuH / 2
            for i, label in ipairs(TOWN_MENU) do
                local btnY = menuY + 10 + (i - 1) * 40
                if x >= menuX and x <= menuX + menuW and y >= btnY and y <= btnY + 34 then
                    townMenuSel = i
                    -- 실행
                    if label == "상점" then
                        if shop.needsRefresh then
                            shop:refresh()
                        end
                        gameState = "shop"
                        drag.item = nil
                        hoverItem = nil
                    elseif label == "보관함" then
                        gameState = "stash"
                        drag.item = nil
                        hoverItem = nil
                    elseif label == "도감" then
                        gameState = "bestiary"
                        bestiaryScroll = 0
                    elseif label == "던전 출발" then
                        startDungeon()
                    elseif label == "저장" then
                        addMessage("게임이 저장되었습니다!")
                    end
                    return
                end
            end
        end
        return
    end

    if gameState ~= "inventory" then return end

    if button == 1 then
        local item = inv:getItemAt(x, y)
        if item then
            drag.item = item
            drag.fromInv = true
            drag.fromSlot = nil
            inv:removeItem(item)
            hoverItem = nil
            return
        end

        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                drag.item = eqItem
                drag.fromInv = false
                drag.fromSlot = slot
                hoverItem = nil
                return
            end
        end

    elseif button == 2 then
        local item = inv:getItemAt(x, y)
        if item then
            -- 포션 사용
            if item.id == "health_potion" then
                player.hp = math.min(player.maxHp, player.hp + 30)
                addMessage("체력 포션 사용! (+30 HP)")
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                return
            elseif item.id == "large_potion" then
                player.hp = math.min(player.maxHp, player.hp + 80)
                addMessage("대형 포션 사용! (+80 HP)")
                item.count = item.count - 1
                if item.count <= 0 then inv:removeItem(item) end
                return
            end
            -- 장비 장착
            if item.slot then
                if not canEquipItemByRestriction(item) then
                    return
                end
                inv:removeItem(item)
                local removed = equip:equip(item)
                for _, prev in ipairs(removed) do
                    inv:autoPlace(prev)
                end
                addMessage(item.name .. " 장착!")
                return
            end
        end

        local slot = equip:getSlotAt(x, y)
        if slot then
            local eqItem = equip:unequip(slot)
            if eqItem then
                if inv:autoPlace(eqItem) then
                    addMessage(eqItem.name .. " 해제!")
                else
                    equip:equip(eqItem)
                    addMessage("인벤토리가 꽉 찼습니다!")
                end
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if gameState == "charselect" then return end
    if button == 1 and drag.item then
        local item = drag.item

        -- 상점 모드에서 드랍
        if gameState == "shop" then
            -- 상점→인벤: 구매
            if drag.fromSlot == "shop" then
                local col, row = inv:screenToGrid(x, y)
                col = col - math.floor(item.gridW / 2)
                row = row - math.floor(item.gridH / 2)
                local price = drag.shopPrice or 0
                if inv:canPlace(item, col, row) and player.gold >= price then
                    inv:placeItem(item, col, row)
                    player.gold = player.gold - price
                    addMessage(item.name .. " 구매! (-" .. price .. "G)")
                    drag.item = nil
                    return
                end
                -- 상점 그리드에 드롭 시도
                local sc, sr = shop:screenToGrid(x, y)
                sc = sc - math.floor(item.gridW / 2)
                sr = sr - math.floor(item.gridH / 2)
                if shop:canPlace(item, sc, sr) then
                    shop:placeItem(item, sc, sr, drag.shopPrice)
                    drag.item = nil
                    return
                end
                -- 실패 → 원위치
                shop:addItem(item, drag.shopPrice)
                if player.gold < price then
                    addMessage("골드가 부족합니다!")
                end
            else
                -- 인벤→상점: 판매
                local sc, sr = shop:screenToGrid(x, y)
                sc = sc - math.floor(item.gridW / 2)
                sr = sr - math.floor(item.gridH / 2)
                if shop:canPlace(item, sc, sr) then
                    local price = shop:getSellPrice(item)
                    shop:placeItem(item, sc, sr, price)
                    player.gold = player.gold + price
                    addMessage(item.name .. " 판매! (+" .. price .. "G)")
                    drag.item = nil
                    return
                end
                -- 인벤에 드롭 시도
                local col, row = inv:screenToGrid(x, y)
                col = col - math.floor(item.gridW / 2)
                row = row - math.floor(item.gridH / 2)
                if inv:canPlace(item, col, row) then
                    inv:placeItem(item, col, row)
                    drag.item = nil
                    return
                end
                -- 실패 → 원위치
                inv:autoPlace(item)
            end
            drag.item = nil
            return
        end

        -- 보관함 모드에서 드랍
        if gameState == "stash" then
            -- 인벤토리에 드롭 시도
            local col, row = inv:screenToGrid(x, y)
            col = col - math.floor(item.gridW / 2)
            row = row - math.floor(item.gridH / 2)
            if inv:canPlace(item, col, row) then
                inv:placeItem(item, col, row)
                drag.item = nil
                return
            end

            -- 보관함에 드롭 시도
            local sc, sr = stash:screenToGrid(x, y)
            sc = sc - math.floor(item.gridW / 2)
            sr = sr - math.floor(item.gridH / 2)
            if stash:canPlace(item, sc, sr) then
                stash:placeItem(item, sc, sr)
                drag.item = nil
                return
            end

            -- 실패 — 원래 위치로
            if drag.fromInv then
                inv:autoPlace(item)
            elseif drag.fromSlot == "stash" then
                stash:autoPlace(item)
            end
            drag.item = nil
            return
        end

        -- 인벤토리 모드
        local col, row = inv:screenToGrid(x, y)
        col = col - math.floor(item.gridW / 2)
        row = row - math.floor(item.gridH / 2)

        if inv:canPlace(item, col, row) then
            inv:placeItem(item, col, row)
            drag.item = nil
            return
        end

        local slot = equip:getSlotAt(x, y)
        if slot and equip:canDropToSlot(item, slot) and canEquipItemByRestriction(item) then
            local removed = equip:equip(item, slot)
            for _, prev in ipairs(removed) do
                inv:autoPlace(prev)
            end
            drag.item = nil
            return
        end

        if drag.fromInv then
            inv:autoPlace(item)
        elseif drag.fromSlot then
            equip:equip(item, drag.fromSlot)
        end

        drag.item = nil
    end
end

function love.wheelmoved(x, y)
    if gameState == "playing" then
        if y > 0 then
            messageScroll = math.min(messageScroll + 2, math.max(0, #messages - MAX_VISIBLE_MESSAGES))
        elseif y < 0 then
            messageScroll = math.max(0, messageScroll - 2)
        end
    elseif gameState == "bestiary" then
        local totalRaces = 0
        for _ in pairs(RACE_DB) do totalRaces = totalRaces + 1 end
        if y > 0 then
            bestiaryScroll = math.max(0, bestiaryScroll - 1)
        elseif y < 0 then
            bestiaryScroll = math.min(math.max(0, totalRaces - 4), bestiaryScroll + 1)
        end
    end
end

-- ===== 그리기 =====
local function drawGame()
    -- 맵
    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            local tile = map[y][x]
            local sx = (x - 1) * TILE_SIZE
            local sy = (y - 1) * TILE_SIZE

            if tile == TILE_FLOOR then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(0.5, 0.5, 0.4)
                love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
            elseif tile == TILE_WALL then
                love.graphics.setColor(COLOR_WALL)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(0.25, 0.25, 0.35)
                love.graphics.rectangle("line", sx, sy, TILE_SIZE, TILE_SIZE)
            elseif tile == TILE_STAIR_DOWN then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(COLOR_STAIR)
                love.graphics.print(">", sx + 3, sy)
            elseif tile == TILE_STAIR_UP then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(0.6, 0.9, 1.0)
                love.graphics.print("<", sx + 3, sy)
            end
        end
    end

    -- 바닥 아이템
    for _, gi in ipairs(groundItems) do
        if not gi.picked then
            local rc = gi.item:getRarityColor()
            love.graphics.setColor(rc[1], rc[2], rc[3])
            love.graphics.print(gi.item.icon, (gi.x - 1) * TILE_SIZE + 3, (gi.y - 1) * TILE_SIZE)
        end
    end

    -- 적
    for _, enemy in ipairs(enemies) do
        if enemy.alive then
            if enemy.isBoss then
                love.graphics.setColor(1, 0.85, 0, 0.45)
                love.graphics.rectangle("line", (enemy.x - 1) * TILE_SIZE, (enemy.y - 1) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
            end
            love.graphics.setColor(enemy.color)
            love.graphics.print(enemy.char, (enemy.x - 1) * TILE_SIZE + 3, (enemy.y - 1) * TILE_SIZE)
        end
    end

    -- 플레이어
    love.graphics.setColor(COLOR_PLAYER)
    love.graphics.print(player.char, (player.x - 1) * TILE_SIZE + 3, (player.y - 1) * TILE_SIZE)

    -- ===== HUD =====
    local hudX = MAP_WIDTH * TILE_SIZE + 10
    local hudY = 10
    local hudW = 230

    love.graphics.setColor(COLOR_HUD_BG)
    love.graphics.rectangle("fill", hudX - 5, 0, hudW + 10, MAP_HEIGHT * TILE_SIZE + 10)

    -- 플레이어 정보
    love.graphics.setColor(COLOR_GOLD)
    local rn = player.raceName or "인간"
    local cn = player.className or "전사"
    love.graphics.print("=== " .. rn .. " " .. cn .. " ===", hudX, hudY)
    hudY = hudY + 22

    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("레벨 " .. player.level .. "  " .. floor .. "층  턴: " .. turn, hudX, hudY)
    hudY = hudY + 18

    -- HP 바
    love.graphics.setColor(COLOR_HP_BG)
    love.graphics.rectangle("fill", hudX, hudY, 200, 14)
    love.graphics.setColor(COLOR_HP_BAR)
    local hpRatio = player.hp / player.maxHp
    love.graphics.rectangle("fill", hudX, hudY, 200 * hpRatio, 14)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("체력: " .. player.hp .. "/" .. player.maxHp, hudX + 5, hudY)
    hudY = hudY + 18

    -- MP 바
    love.graphics.setColor(COLOR_MP_BG)
    love.graphics.rectangle("fill", hudX, hudY, 200, 14)
    love.graphics.setColor(COLOR_MP_BAR)
    local mpRatio = 0
    if player.maxMana and player.maxMana > 0 then
        mpRatio = (player.mana or 0) / player.maxMana
    end
    love.graphics.rectangle("fill", hudX, hudY, 200 * mpRatio, 14)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("마나: " .. (player.mana or 0) .. "/" .. (player.maxMana or 0), hudX + 5, hudY)
    hudY = hudY + 18

    -- EXP 바
    love.graphics.setColor(0.1, 0.1, 0.4)
    love.graphics.rectangle("fill", hudX, hudY, 200, 12)
    love.graphics.setColor(0.3, 0.3, 1)
    local expRatio = player.exp / player.nextExp
    love.graphics.rectangle("fill", hudX, hudY, 200 * expRatio, 12)
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("경험치: " .. player.exp .. "/" .. player.nextExp, hudX + 5, hudY - 1)
    hudY = hudY + 18

    -- 스탯 (DCSS 스타일)
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("--- 스탯 ---", hudX, hudY)
    hudY = hudY + 16

    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("힘(STR):  " .. player.str, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("민첩(DEX): " .. player.dex, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("지능(INT): " .. player.int, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(1, 0.7, 0.3)
    love.graphics.print("체력(CON): " .. player.con, hudX, hudY)
    hudY = hudY + 14
    love.graphics.setColor(1, 1, 0.4)
    love.graphics.print("운(LCK):  " .. player.lck, hudX, hudY)
    hudY = hudY + 18

    -- 전투 스탯
    local eqStats = equip:getTotalStats()
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("공격: " .. getPlayerAtk(), hudX, hudY)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("방어: " .. getPlayerDef(), hudX + 70, hudY)
    hudY = hudY + 14
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("회피: " .. math.floor(getPlayerEvasionFull()) .. "%", hudX, hudY)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print("치명: " .. math.floor(getPlayerCritFull()) .. "%", hudX + 70, hudY)
    hudY = hudY + 14

    -- 무기 속성 표시
    local pElem = getPlayerElement()
    local elemColor = Item.ELEMENT_COLORS[pElem] or {0.8, 0.8, 0.8}
    love.graphics.setColor(elemColor[1], elemColor[2], elemColor[3])
    love.graphics.print("속성: " .. (Item.ELEMENT_NAMES[pElem] or "물리"), hudX, hudY)
    hudY = hudY + 14

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 특수효과 ---", hudX, hudY)
        hudY = hudY + 14
        for _, p in ipairs(passives) do
            local pName = Item.PASSIVE_NAMES[p.type] or p.type
            love.graphics.setColor(0.7, 0.5, 1)
            love.graphics.print("◆ " .. pName, hudX, hudY)
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("골드: " .. player.gold, hudX, hudY)
    hudY = hudY + 18

    -- 스킬 표시
    if player.skills and #player.skills > 0 then
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 스킬 ---", hudX, hudY)
        hudY = hudY + 15
        for i, s in ipairs(player.skills) do
            local cost = getSkillManaCost(s)
            if s.currentCd > 0 then
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost .. " (쿨:" .. s.currentCd .. ")", hudX, hudY)
            elseif (player.mana or 0) < cost then
                love.graphics.setColor(0.35, 0.35, 0.55)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost, hudX, hudY)
            else
                love.graphics.setColor(0.9, 0.8, 1)
                love.graphics.print("[" .. i .. "] " .. s.name .. " MP" .. cost, hudX, hudY)
            end
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    -- 활성 버프 표시
    if player.buffs and #player.buffs > 0 then
        love.graphics.setColor(0.3, 1, 0.6)
        love.graphics.print("--- 버프 ---", hudX, hudY)
        hudY = hudY + 15
        for _, b in ipairs(player.buffs) do
            love.graphics.setColor(0.5, 1, 0.7)
            love.graphics.print("◆ " .. b.name .. " (" .. b.duration .. "턴)", hudX, hudY)
            hudY = hudY + 13
        end
        hudY = hudY + 4
    end

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.print("--- 조작법 ---", hudX, hudY)
    hudY = hudY + 16
    love.graphics.print("방향키/WASD: 이동", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("부딪히기: 공격 | Space: 대기", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print("I/Tab: 인벤 | 숫자: 스킬", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print(">/<: 계단 | PgUp/Dn: 로그", hudX, hudY)
    hudY = hudY + 18

    -- 인접 적 정보
    for _, enemy in ipairs(enemies) do
        if enemy.alive and distance(player.x, player.y, enemy.x, enemy.y) <= 2 then
            local rd = RACE_DB[enemy.race]
            local raceName = rd and rd.name or "???"
            local raceCol = rd and rd.color or {0.8, 0.8, 0.8}
            love.graphics.setColor(raceCol[1], raceCol[2], raceCol[3])
            love.graphics.print("▶ " .. enemy.name .. " [" .. raceName .. "]", hudX, hudY)
            hudY = hudY + 14
            -- HP바
            local hpRatio = enemy.hp / enemy.maxHp
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", hudX, hudY, 100, 6)
            love.graphics.setColor(1 - hpRatio, hpRatio, 0)
            love.graphics.rectangle("fill", hudX, hudY, 100 * hpRatio, 6)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(enemy.hp .. "/" .. enemy.maxHp, hudX + 105, hudY - 3)
            hudY = hudY + 14
            break
        end
    end

    -- 메시지 로그
    love.graphics.setColor(COLOR_GOLD)
    local scrollInfo = ""
    if #messages > MAX_VISIBLE_MESSAGES then
        scrollInfo = " (" .. (messageScroll + 1) .. "-" .. math.min(messageScroll + MAX_VISIBLE_MESSAGES, #messages) .. "/" .. #messages .. ")"
    end
    love.graphics.print("--- 메시지 ---" .. scrollInfo, hudX, hudY)
    hudY = hudY + 18

    if messageScroll > 0 then
        love.graphics.setColor(COLOR_GOLD)
        love.graphics.print("  ▲ PgUp / 휠↑", hudX, hudY - 4)
    end

    for i = 1 + messageScroll, math.min(#messages, MAX_VISIBLE_MESSAGES + messageScroll) do
        local msg = messages[i]
        local alpha = 1 - (i - 1 - messageScroll) * 0.1
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(msg, hudX, hudY)
        hudY = hudY + 14
    end

    if messageScroll + MAX_VISIBLE_MESSAGES < #messages then
        love.graphics.setColor(COLOR_GRAY)
        love.graphics.print("  ▼ PgDn / 휠↓", hudX, hudY)
    end

    -- 게임오버 화면
    if gameState == "gameover" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.printf("사망했습니다...", 0, love.graphics.getHeight() / 2 - 30, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf(floor .. "층  레벨 " .. player.level .. "  턴: " .. turn, 0, love.graphics.getHeight() / 2, love.graphics.getWidth(), "center")
        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("R키: 캐릭터 삭제 후 새로 시작", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
    end
end

local function drawInventory()
    -- 어두운 배경
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- 인벤토리 위치 설정
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    inv.x = 30
    inv.y = 50

    equip.x = inv.x + inv.cols * inv.cellSize + 140
    equip.y = 170

    -- 인벤토리 그리기
    inv:draw(font)

    -- 장비 패널
    equip:draw(font)

    -- 장비 스탯
    equip:drawStats(equip.x - 80, equip.y + 130)

    -- 플레이어 현재 스탯
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("=== 전투 스탯 ===", equip.x - 80, equip.y + 230)
    love.graphics.setColor(1, 0.4, 0.4)
    love.graphics.print("공격: " .. getPlayerAtk(), equip.x - 76, equip.y + 248)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.print("방어: " .. getPlayerDef(), equip.x - 76, equip.y + 264)
    love.graphics.setColor(0.4, 1, 0.4)
    love.graphics.print("회피: " .. math.floor(getPlayerEvasionFull()) .. "%", equip.x - 76, equip.y + 280)
    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.print("치명: " .. math.floor(getPlayerCritFull()) .. "%", equip.x - 76, equip.y + 296)
    love.graphics.setColor(COLOR_WHITE)
    love.graphics.print("STR:" .. player.str .. " DEX:" .. player.dex .. " INT:" .. player.int, equip.x - 76, equip.y + 316)
    love.graphics.print("CON:" .. player.con .. " LCK:" .. player.lck, equip.x - 76, equip.y + 332)
    love.graphics.setColor(0.45, 0.65, 1)
    love.graphics.print("MP:" .. (player.mana or 0) .. "/" .. (player.maxMana or 0) .. "  회복:" .. getPlayerManaRegen(), equip.x - 76, equip.y + 348)

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        local py = equip.y + 366
        love.graphics.setColor(0.8, 0.6, 1)
        love.graphics.print("--- 특수효과 ---", equip.x - 76, py)
        py = py + 16
        for _, p in ipairs(passives) do
            love.graphics.setColor(0.7, 0.5, 1)
            love.graphics.print("◆ " .. (p.desc or ""), equip.x - 76, py)
            py = py + 14
        end
    end

    -- 타이틀
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.printf("EXTRACTION INVENTORY", 0, 10, sw, "center")
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 장착/사용 | Delete/Backspace: 마우스 아이템 버리기 | I/Tab/Esc: 닫기", 0, 28, sw, "center")

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end
end

local function drawTown()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 배경
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("마 을", 0, 40, sw, "center")

    -- 플레이어 정보
    local rn = player.raceName or "인간"
    local cn = player.className or "전사"
    love.graphics.setColor(player.raceColor or {1,1,1})
    love.graphics.printf(rn .. " " .. cn .. "  Lv." .. player.level .. "  골드: " .. player.gold .. "  탐험: " .. dungeonRun .. "회", 0, 70, sw, "center")

    -- 메뉴
    local menuW = 200
    local menuH = #TOWN_MENU * 40 + 20
    local menuX = sw / 2 - menuW / 2
    local menuY = sh / 2 - menuH / 2

    love.graphics.setColor(0.12, 0.12, 0.16, 0.9)
    love.graphics.rectangle("fill", menuX - 10, menuY - 10, menuW + 20, menuH + 20, 8, 8)

    for i, label in ipairs(TOWN_MENU) do
        local btnY = menuY + 10 + (i - 1) * 40
        if i == townMenuSel then
            love.graphics.setColor(0.3, 0.5, 0.3)
        else
            love.graphics.setColor(0.18, 0.18, 0.22)
        end
        love.graphics.rectangle("fill", menuX, btnY, menuW, 34, 4, 4)

        if i == townMenuSel then
            love.graphics.setColor(0.4, 0.8, 0.4)
            love.graphics.rectangle("line", menuX, btnY, menuW, 34, 4, 4)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(label, menuX, btnY + 8, menuW, "center")
    end

    -- 조작법
    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("↑↓: 선택 | Enter/Space: 확인 | 클릭: 선택", 0, sh - 30, sw, "center")
end

local function drawStash()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 인벤토리 위치
    inv.x = 30
    inv.y = 50

    -- 보관함 위치
    stash.x = inv.x + inv.cols * inv.cellSize + 40
    stash.y = 50

    -- 타이틀
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("인벤토리", inv.x, 20)
    love.graphics.print("보관함", stash.x, 20)

    inv:draw(font)
    stash:draw(font)

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        stash:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 빠른 이동 | Esc: 닫기", 0, sh - 25, sw, "center")
end

local function drawShop()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- 상점 그리드 위치 설정
    shop.grid.x = 30
    shop.grid.y = 50

    -- 인벤토리 위치 설정
    inv.x = shop.grid.x + shop.grid.cols * shop.grid.cellSize + 40
    inv.y = 50

    -- 타이틀
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("상 점", 0, 8, sw, "center")
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("골드: " .. player.gold, 0, 8, sw - 20, "right")

    -- 라벨
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.print("상점 재고", shop.grid.x, shop.grid.y - 20)
    love.graphics.setColor(COLOR_GOLD)
    love.graphics.print("인벤토리", inv.x, inv.y - 20)

    -- 그리드 그리기
    shop.grid:draw(font)
    inv:draw(font)

    -- 가격 표시 (상점 아이템)
    for _, item in ipairs(shop.grid.items) do
        local price = shop:getPrice(item)
        local ix = shop.grid.x + (item._gridCol - 1) * shop.grid.cellSize
        local iy = shop.grid.y + (item._gridRow - 1) * shop.grid.cellSize

        love.graphics.setColor(0, 0, 0, 0.7)
        local priceText = price .. "G"
        local tw = font:getWidth(priceText)
        love.graphics.rectangle("fill", ix, iy, tw + 4, 14)

        if player.gold >= price then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(0.7, 0.3, 0.3)
        end
        love.graphics.print(priceText, ix + 2, iy)
    end

    -- 인벤토리 아이템 판매가 표시
    for _, item in ipairs(inv:getAllItems()) do
        local price = shop:getSellPrice(item)
        local ix = inv.x + (item._gridCol - 1) * inv.cellSize
        local iy = inv.y + (item._gridRow - 1) * inv.cellSize
        local iw = item.gridW * inv.cellSize
        local priceText = price .. "G"
        local tw = font:getWidth(priceText)

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", ix + iw - tw - 4, iy, tw + 4, 14)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.print(priceText, ix + iw - tw - 2, iy)
    end

    -- 드래그 프리뷰
    if drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawPlacePreview(drag.item, mx, my)
        shop.grid:drawPlacePreview(drag.item, mx, my)
        inv:drawDragItem(drag.item, mx, my)
    end

    -- 툴팁
    if hoverItem and not drag.item then
        local mx, my = love.mouse.getPosition()
        inv:drawTooltip(hoverItem, mx, my)
    end

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("좌클릭: 드래그 (상점↔인벤) | 우클릭: 빠른 구매/판매 | Esc: 나가기", 0, sh - 25, sw, "center")
end

local function drawLevelUp()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- 배경
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local panelW = 300
    local panelH = 280
    local px = sw / 2 - panelW / 2
    local py = sh / 2 - panelH / 2

    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", px, py, panelW, panelH, 8, 8)
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.rectangle("line", px, py, panelW, panelH, 8, 8)

    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("레벨 업! Lv." .. player.level, px, py + 12, panelW, "center")

    if statAlloc then
        love.graphics.setColor(COLOR_WHITE)
        love.graphics.printf("남은 포인트: " .. statAlloc.points, px, py + 35, panelW, "center")

        local STAT_KEYS = {"str", "dex", "int", "con", "lck"}
        local STAT_NAMES = {"힘 (STR)  — 근접 데미지", "민첩 (DEX) — 명중/회피/치명타", "지능 (INT) — 마법 (향후 확장)", "체력 (CON) — 최대 HP/방어", "운 (LCK)  — 치명타/드롭률"}
        local STAT_COLORS = {{1,0.4,0.4},{0.4,1,0.4},{0.4,0.6,1},{1,0.7,0.3},{1,1,0.4}}

        for i, stat in ipairs(STAT_KEYS) do
            local sy = py + 60 + (i - 1) * 38

            if i == statAlloc.sel then
                love.graphics.setColor(0.3, 0.4, 0.3)
                love.graphics.rectangle("fill", px + 15, sy - 2, panelW - 30, 34, 4, 4)
                love.graphics.setColor(0.5, 0.8, 0.5)
                love.graphics.rectangle("line", px + 15, sy - 2, panelW - 30, 34, 4, 4)
            end

            love.graphics.setColor(STAT_COLORS[i])
            love.graphics.print(STAT_NAMES[i], px + 25, sy + 2)
            love.graphics.setColor(COLOR_WHITE)
            love.graphics.print("현재: " .. player[stat], px + 25, sy + 17)
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter/Space: 배분", px, py + panelH - 25, panelW, "center")
    end
end

-- 속성 한글/색상 참조 (item.lua)
local ELEMENT_LIST = {"slash", "pierce", "strike", "fire", "ice", "lightning", "poison", "holy"}
local ELEMENT_NAMES = Item.ELEMENT_NAMES
local ELEMENT_COLORS = Item.ELEMENT_COLORS

-- ===== 캐릭터 선택 화면 =====
local function drawCharSelect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0.05, 0.05, 0.12)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    if charSelect.phase == "race" then
        -- 종족 선택
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.printf("= 종족 선택 =", 0, 15, sw, "center")

        local listX = 30
        local infoX = sw * 0.45
        local startY = 50
        local rowH = math.max(18, math.min(28, math.floor((sh - startY - 35) / #PLAYER_RACES)))
        local rowBoxH = math.max(16, rowH - 2)

        for i, race in ipairs(PLAYER_RACES) do
            local y = startY + (i - 1) * rowH
            if i == charSelect.raceSel then
                love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, rowBoxH, 4, 4)
                love.graphics.setColor(race.color[1], race.color[2], race.color[3])
                love.graphics.print("▶ " .. race.name, listX, y)
            else
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.print("  " .. race.name, listX, y)
            end
        end

        -- 선택된 종족 상세 정보
        local sel = PLAYER_RACES[charSelect.raceSel]
        if sel then
            local iy = startY
            love.graphics.setColor(sel.color[1], sel.color[2], sel.color[3])
            love.graphics.print("【" .. sel.name .. "】", infoX, iy)
            iy = iy + 22

            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(sel.desc, infoX, iy, sw - infoX - 20, "left")
            iy = iy + 40

            -- 기본 스탯
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.print("기본 스탯:", infoX, iy)
            iy = iy + 18
            love.graphics.setColor(1, 0.5, 0.3)
            love.graphics.print("STR " .. sel.stats.str, infoX, iy)
            love.graphics.setColor(0.3, 1, 0.5)
            love.graphics.print("DEX " .. sel.stats.dex, infoX + 55, iy)
            love.graphics.setColor(0.4, 0.7, 1)
            love.graphics.print("INT " .. sel.stats.int, infoX + 110, iy)
            iy = iy + 16
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.print("CON " .. sel.stats.con, infoX, iy)
            love.graphics.setColor(1, 1, 0.4)
            love.graphics.print("LCK " .. sel.stats.lck, infoX + 55, iy)
            iy = iy + 22

            -- HP/경험치 보너스
            if sel.hpBonus ~= 0 then
                local sign = sel.hpBonus > 0 and "+" or ""
                love.graphics.setColor(0.8, 0.3, 0.3)
                love.graphics.print("HP 보너스: " .. sign .. sel.hpBonus, infoX, iy)
                iy = iy + 16
            end
            if sel.expBonus ~= 0 then
                local sign = sel.expBonus > 0 and "+" or ""
                love.graphics.setColor(0.3, 0.8, 0.3)
                love.graphics.print("경험치 보너스: " .. sign .. sel.expBonus .. "%", infoX, iy)
                iy = iy + 16
            end

            -- 저항
            iy = iy + 4
            love.graphics.setColor(0.3, 0.7, 1)
            love.graphics.print("저항:", infoX, iy)
            local rx = infoX + 40
            if next(sel.resist) then
                for elem, val in pairs(sel.resist) do
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label
                    if val >= 1.0 then label = (ELEMENT_NAMES[elem] or elem) .. "(면역)"
                    else label = (ELEMENT_NAMES[elem] or elem) .. "(-" .. math.floor(val*100) .. "%)" end
                    love.graphics.print(label, rx, iy)
                    rx = rx + font:getWidth(label) + 10
                end
            else
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("없음", rx, iy)
            end
            iy = iy + 18

            -- 약점
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.print("약점:", infoX, iy)
            local wx = infoX + 40
            if next(sel.weak) then
                for elem, val in pairs(sel.weak) do
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "(+" .. math.floor(val*100) .. "%)"
                    love.graphics.print(label, wx, iy)
                    wx = wx + font:getWidth(label) + 10
                end
            else
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("없음", wx, iy)
            end
            iy = iy + 22

            -- 숙련 보너스
            love.graphics.setColor(0.8, 0.6, 1)
            love.graphics.print("무기 숙련:", infoX, iy)
            local px = infoX + 60
            local hasProf = false
            for elem, val in pairs(sel.profBonus) do
                if val > 0 then
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "+" .. val
                    love.graphics.print(label, px, iy)
                    px = px + font:getWidth(label) + 10
                    hasProf = true
                end
            end
            if not hasProf then
                love.graphics.setColor(COLOR_GRAY)
                love.graphics.print("균등", px, iy)
            end
            iy = iy + 22

            -- 종족 스킬
            if #sel.skills > 0 then
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.print("종족 스킬:", infoX, iy)
                iy = iy + 18
                for _, sk in ipairs(sel.skills) do
                    love.graphics.setColor(0.9, 0.7, 1)
                    love.graphics.print("◆ " .. sk.name, infoX + 8, iy)
                    iy = iy + 15
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.printf("  " .. sk.desc .. " (쿨: " .. sk.cooldown .. "턴)", infoX + 8, iy, sw - infoX - 30, "left")
                    iy = iy + 18
                end
            end
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter: 확정", 0, sh - 25, sw, "center")

    elseif charSelect.phase == "class" then
        -- 직업 선택
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.printf("= 직업 선택 = [" .. charSelect.chosenRace.name .. "]", 0, 15, sw, "center")

        local listX = 30
        local infoX = sw * 0.45
        local startY = 50
        local rowH = math.max(18, math.min(28, math.floor((sh - startY - 35) / #PLAYER_CLASSES)))
        local rowBoxH = math.max(16, rowH - 2)

        for i, cls in ipairs(PLAYER_CLASSES) do
            local y = startY + (i - 1) * rowH
            local allowed = isClassAllowedForRace(charSelect.chosenRace, cls)
            if i == charSelect.classSel then
                love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, rowBoxH, 4, 4)
                if allowed then
                    love.graphics.setColor(cls.color[1], cls.color[2], cls.color[3])
                    love.graphics.print("▶ " .. cls.name, listX, y)
                else
                    love.graphics.setColor(0.45, 0.25, 0.25)
                    love.graphics.print("× " .. cls.name, listX, y)
                end
            else
                if allowed then
                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.print("  " .. cls.name, listX, y)
                else
                    love.graphics.setColor(0.32, 0.25, 0.25)
                    love.graphics.print("  × " .. cls.name, listX, y)
                end
            end
        end

        local sel = PLAYER_CLASSES[charSelect.classSel]
        if sel then
            local iy = startY
            local allowed, blockReason = isClassAllowedForRace(charSelect.chosenRace, sel)
            love.graphics.setColor(sel.color[1], sel.color[2], sel.color[3])
            love.graphics.print("【" .. sel.name .. "】", infoX, iy)
            iy = iy + 22

            if not allowed then
                love.graphics.setColor(1, 0.35, 0.25)
                love.graphics.printf("선택 불가: " .. (blockReason or "종족 금기와 충돌합니다."), infoX, iy, sw - infoX - 20, "left")
                iy = iy + 34
            end

            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(sel.desc, infoX, iy, sw - infoX - 20, "left")
            iy = iy + 40

            -- 스탯 보너스
            local race = charSelect.chosenRace
            love.graphics.setColor(COLOR_GOLD)
            love.graphics.print("최종 스탯 (종족+직업):", infoX, iy)
            iy = iy + 18
            local finalStr = race.stats.str + sel.statBonus.str
            local finalDex = race.stats.dex + sel.statBonus.dex
            local finalInt = race.stats.int + sel.statBonus.int
            local finalCon = race.stats.con + sel.statBonus.con
            local finalLck = race.stats.lck + sel.statBonus.lck
            love.graphics.setColor(1, 0.5, 0.3)
            love.graphics.print("STR " .. finalStr .. " (+" .. sel.statBonus.str .. ")", infoX, iy)
            love.graphics.setColor(0.3, 1, 0.5)
            love.graphics.print("DEX " .. finalDex .. " (+" .. sel.statBonus.dex .. ")", infoX + 100, iy)
            iy = iy + 16
            love.graphics.setColor(0.4, 0.7, 1)
            love.graphics.print("INT " .. finalInt .. " (+" .. sel.statBonus.int .. ")", infoX, iy)
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.print("CON " .. finalCon .. " (+" .. sel.statBonus.con .. ")", infoX + 100, iy)
            iy = iy + 16
            love.graphics.setColor(1, 1, 0.4)
            love.graphics.print("LCK " .. finalLck .. " (+" .. sel.statBonus.lck .. ")", infoX, iy)
            iy = iy + 22

            -- 무기 숙련
            love.graphics.setColor(0.8, 0.6, 1)
            love.graphics.print("무기 숙련:", infoX, iy)
            local px = infoX + 60
            for elem, val in pairs(sel.profBonus) do
                if val > 0 then
                    local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                    love.graphics.setColor(ec[1], ec[2], ec[3])
                    local label = (ELEMENT_NAMES[elem] or elem) .. "+" .. val
                    love.graphics.print(label, px, iy)
                    px = px + font:getWidth(label) + 10
                end
            end
            iy = iy + 22

            -- 시작 장비
            love.graphics.setColor(0.7, 0.9, 0.7)
            love.graphics.print("시작 장비:", infoX, iy)
            iy = iy + 16
            if sel.startWeapon then
                local wData = Item.DATABASE[sel.startWeapon]
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("  무기: " .. (wData and wData.name or sel.startWeapon), infoX, iy)
                iy = iy + 15
            end
            if sel.startArmor then
                local aData = Item.DATABASE[sel.startArmor]
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("  방어구: " .. (aData and aData.name or sel.startArmor), infoX, iy)
                iy = iy + 15
            end
            iy = iy + 8

            -- 직업 스킬
            if #sel.skills > 0 then
                love.graphics.setColor(1, 0.8, 0.2)
                love.graphics.print("직업 스킬:", infoX, iy)
                iy = iy + 18
                for _, sk in ipairs(sel.skills) do
                    love.graphics.setColor(0.9, 0.7, 1)
                    love.graphics.print("◆ " .. sk.name, infoX + 8, iy)
                    iy = iy + 15
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.printf("  " .. sk.desc .. " (쿨: " .. sk.cooldown .. "턴)", infoX + 8, iy, sw - infoX - 30, "left")
                    iy = iy + 18
                end
            end
        end

        love.graphics.setColor(COLOR_GRAY)
        love.graphics.printf("↑↓: 선택 | Enter: 확정 | Esc: 종족 재선택", 0, sh - 25, sw, "center")
    end
end

local function drawBestiary()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(1, 0.85, 0)
    love.graphics.printf("= 도감 (종족/속성) =", 0, 15, sw, "center")

    love.graphics.setColor(COLOR_GRAY)
    love.graphics.printf("↑↓/마우스 휠: 스크롤 | ESC: 돌아가기", 0, sh - 25, sw, "center")

    -- 종족 목록 정렬 (일관된 순서)
    local raceOrder = {"human", "beast", "goblinoid", "orc", "troll", "undead", "demon", "dragon", "construct", "insect", "reptile", "elf"}
    local cardH = 130
    local cardW = sw - 60
    local startY = 50
    local visibleCards = math.floor((sh - 90) / (cardH + 8))

    for idx, raceKey in ipairs(raceOrder) do
        local raceData = RACE_DB[raceKey]
        if raceData then
            local cardIdx = idx - bestiaryScroll
            if cardIdx >= 1 and cardIdx <= visibleCards then
                local cy = startY + (cardIdx - 1) * (cardH + 8)
                local cx = 30

                -- 카드 배경
                love.graphics.setColor(0.12, 0.12, 0.18, 0.9)
                love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6, 6)
                love.graphics.setColor(raceData.color[1], raceData.color[2], raceData.color[3], 0.7)
                love.graphics.rectangle("line", cx, cy, cardW, cardH, 6, 6)

                -- 종족명
                love.graphics.setColor(raceData.color[1], raceData.color[2], raceData.color[3])
                love.graphics.print("【" .. raceData.name .. "】", cx + 10, cy + 6)

                -- 설명
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.printf(raceData.desc, cx + 10, cy + 24, cardW - 20, "left")

                -- 해당 종족의 몬스터들
                local monsters = {}
                for _, m in ipairs(ENEMY_DB) do
                    if m.race == raceKey then
                        table.insert(monsters, m.name)
                    end
                end
                love.graphics.setColor(0.6, 0.7, 0.8)
                love.graphics.print("몬스터: " .. table.concat(monsters, ", "), cx + 10, cy + 46)

                -- 저항 표시
                local ry = cy + 66
                love.graphics.setColor(0.3, 0.7, 1)
                love.graphics.print("저항:", cx + 10, ry)
                local rx = cx + 50
                if next(raceData.resist) then
                    for elem, val in pairs(raceData.resist) do
                        local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                        love.graphics.setColor(ec[1], ec[2], ec[3])
                        local label = (ELEMENT_NAMES[elem] or elem)
                        if val >= 1.0 then
                            label = label .. "(면역)"
                        else
                            label = label .. "(-" .. math.floor(val * 100) .. "%)"
                        end
                        love.graphics.print(label, rx, ry)
                        rx = rx + font:getWidth(label) + 12
                    end
                else
                    love.graphics.setColor(COLOR_GRAY)
                    love.graphics.print("없음", rx, ry)
                end

                -- 약점 표시
                local wy = cy + 86
                love.graphics.setColor(1, 0.4, 0.3)
                love.graphics.print("약점:", cx + 10, wy)
                local wx = cx + 50
                if next(raceData.weak) then
                    for elem, val in pairs(raceData.weak) do
                        local ec = ELEMENT_COLORS[elem] or {0.8, 0.8, 0.8}
                        love.graphics.setColor(ec[1], ec[2], ec[3])
                        local label = (ELEMENT_NAMES[elem] or elem) .. "(+" .. math.floor(val * 100) .. "%)"
                        love.graphics.print(label, wx, wy)
                        wx = wx + font:getWidth(label) + 12
                    end
                else
                    love.graphics.setColor(COLOR_GRAY)
                    love.graphics.print("없음", wx, wy)
                end

                -- 속성 범례 줄 (하단)
                local ly = cy + 108
                love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
                love.graphics.line(cx + 10, ly, cx + cardW - 10, ly)
            end
        end
    end
end

function love.draw()
    if gameState == "charselect" then
        drawCharSelect()
    elseif gameState == "town" then
        drawTown()
    elseif gameState == "bestiary" then
        drawBestiary()
    elseif gameState == "shop" then
        drawShop()
    elseif gameState == "stash" then
        drawStash()
    elseif gameState == "levelup" then
        drawGame()
        drawLevelUp()
    else
        drawGame()
        if gameState == "inventory" then
            drawInventory()
        end
    end
end
