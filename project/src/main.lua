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
local TILE_STAIR = 2

-- 색상
local COLOR_WALL     = {0.3, 0.3, 0.4}
local COLOR_FLOOR    = {0.6, 0.6, 0.5}
local COLOR_PLAYER   = {1, 1, 0}
local COLOR_STAIR    = {1, 0.8, 0}
local COLOR_HUD_BG   = {0.1, 0.1, 0.15, 0.9}
local COLOR_HP_BAR   = {0.8, 0.1, 0.1}
local COLOR_HP_BG    = {0.3, 0.1, 0.1}
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

-- ===== 플레이어 종족 (20종) =====
local PLAYER_RACES = {
    {
        id = "human", name = "인간", char = "@", color = {1, 1, 0.8},
        desc = "균형 잡힌 종족. 모든 무기와 마법을 고르게 배울 수 있다.",
        stats = {str=5, dex=5, int=5, con=5, lck=5},
        resist = {}, weak = {},
        profBonus = {},
        hpBonus = 0, expBonus = 5,
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
    -- === 신규 종족 8~20 ===
    {
        id = "dark_elf", name = "다크 엘프", char = "@", color = {0.5, 0.3, 0.7},
        desc = "어둠에 적응한 엘프. 독/번개 마법에 뛰어나고 화염에 약하다.",
        stats = {str=4, dex=8, int=7, con=3, lck=4},
        resist = {poison=0.3, lightning=0.2},
        weak = {fire=0.25, holy=0.2},
        profBonus = {poison=3, lightning=3, pierce=2},
        hpBonus = -3, expBonus = 0,
        skills = {{id="shadow_cloak", name="그림자 은폐", desc="회피율 대폭 상승 (3턴)", cooldown=9, duration=3, type="buff"}},
    },
    {
        id = "gnome", name = "노움", char = "@", color = {0.7, 0.5, 0.3},
        desc = "발명에 능한 소형 종족. INT/LCK가 높고 STR이 낮다.",
        stats = {str=2, dex=6, int=7, con=4, lck=8},
        resist = {lightning=0.3},
        weak = {strike=0.2},
        profBonus = {lightning=3, fire=2},
        hpBonus = -8, expBonus = 15,
        skills = {{id="tinker_bomb", name="폭발 장치", desc="적에게 화염 폭발 데미지", cooldown=5, duration=0, type="attack", value=18, element="fire"}},
    },
    {
        id = "lizardfolk", name = "도마뱀인", char = "@", color = {0.3, 0.7, 0.4},
        desc = "냉혈 전사. 독/빙결에 강하고 빠른 재생력을 가진다.",
        stats = {str=6, dex=6, int=3, con=7, lck=3},
        resist = {poison=0.25, ice=0.15},
        weak = {fire=0.2},
        profBonus = {slash=2, pierce=2, poison=2},
        hpBonus = 5, expBonus = 0,
        skills = {{id="venom_spit", name="독침 뱉기", desc="적에게 독 데미지", cooldown=5, duration=0, type="attack", value=12, element="poison"}},
    },
    {
        id = "fairy", name = "요정", char = "@", color = {1, 0.7, 1},
        desc = "작지만 강력한 마법 종족. INT 극강이지만 체력이 매우 낮다.",
        stats = {str=1, dex=7, int=11, con=1, lck=7},
        resist = {fire=0.2, ice=0.2, lightning=0.2, holy=0.3},
        weak = {slash=0.3, strike=0.3, pierce=0.3},
        profBonus = {fire=3, ice=3, lightning=3, holy=3},
        hpBonus = -15, expBonus = 0,
        skills = {{id="pixie_dust", name="요정 가루", desc="HP를 INT*2 만큼 회복", cooldown=6, duration=0, type="heal"}},
    },
    {
        id = "demon_p", name = "악마", char = "@", color = {0.9, 0.2, 0.2},
        desc = "지옥에서 온 존재. 화염/독에 강하지만 신성에 매우 약하다.",
        stats = {str=7, dex=5, int=7, con=5, lck=2},
        resist = {fire=0.5, poison=0.4},
        weak = {holy=0.6},
        profBonus = {fire=4, poison=3},
        hpBonus = 0, expBonus = -5,
        skills = {{id="hellfire", name="지옥불", desc="적에게 강력한 화염 데미지", cooldown=7, duration=0, type="attack", value=22, element="fire"}},
    },
    {
        id = "angel_p", name = "천사", char = "@", color = {1, 1, 0.7},
        desc = "천상의 존재. 신성/빙결에 강하고 독/화염에 약하다.",
        stats = {str=4, dex=5, int=8, con=4, lck=6},
        resist = {holy=0.5, ice=0.2},
        weak = {poison=0.3, fire=0.2},
        profBonus = {holy=5, ice=2},
        hpBonus = -3, expBonus = 0,
        skills = {{id="divine_light", name="신성한 빛", desc="적에게 신성 데미지 + 자신 HP 회복", cooldown=7, duration=0, type="attack", value=16, element="holy"}},
    },
    {
        id = "golem_p", name = "골렘", char = "@", color = {0.6, 0.6, 0.6},
        desc = "살아있는 돌. 물리 공격에 강하지만 마법에 약하고 느리다.",
        stats = {str=8, dex=1, int=1, con=12, lck=1},
        resist = {slash=0.3, pierce=0.3, strike=0.3, poison=1.0},
        weak = {fire=0.2, ice=0.2, lightning=0.3},
        profBonus = {strike=4},
        hpBonus = 30, expBonus = -15,
        skills = {{id="iron_body", name="강철 육체", desc="방어력 +10, 이동불가 (3턴)", cooldown=12, duration=3, type="buff"}},
    },
    {
        id = "vampire_p", name = "뱀파이어", char = "@", color = {0.6, 0.1, 0.2},
        desc = "밤의 귀족. 생명력 흡수에 뛰어나지만 신성/화염에 약하다.",
        stats = {str=6, dex=7, int=6, con=5, lck=4},
        resist = {poison=0.4, ice=0.2},
        weak = {holy=0.4, fire=0.3},
        profBonus = {pierce=3, slash=2},
        hpBonus = 0, expBonus = 0,
        skills = {{id="blood_drain", name="피의 흡수", desc="적에게 데미지 + HP 대량 흡수", cooldown=6, duration=0, type="attack", value=18}},
    },
    {
        id = "werewolf_p", name = "늑대인간", char = "@", color = {0.5, 0.4, 0.3},
        desc = "야수의 힘. STR/DEX가 높고 변신 시 초강력 공격.",
        stats = {str=8, dex=7, int=2, con=6, lck=3},
        resist = {strike=0.15},
        weak = {holy=0.3},
        profBonus = {slash=3, strike=2},
        hpBonus = 8, expBonus = -5,
        skills = {{id="wolf_frenzy", name="늑대 광기", desc="공격력 2.5배 + 회피 상승 (3턴)", cooldown=12, duration=3, type="buff"}},
    },
    {
        id = "merfolk", name = "인어", char = "@", color = {0.3, 0.7, 0.9},
        desc = "바다의 종족. 빙결/번개에 강하고 찌르기 무기에 뛰어나다.",
        stats = {str=4, dex=7, int=6, con=5, lck=5},
        resist = {ice=0.3, lightning=0.2},
        weak = {fire=0.25},
        profBonus = {pierce=3, ice=3},
        hpBonus = 0, expBonus = 0,
        skills = {{id="tidal_wave", name="파도", desc="적에게 빙결 데미지", cooldown=5, duration=0, type="attack", value=14, element="ice"}},
    },
    {
        id = "dragonborn", name = "용인", char = "@", color = {0.9, 0.5, 0.1},
        desc = "용의 피를 이어받은 종족. 화염에 면역이고 강력한 브레스.",
        stats = {str=8, dex=3, int=5, con=7, lck=3},
        resist = {fire=0.6},
        weak = {ice=0.3},
        profBonus = {fire=4, slash=2},
        hpBonus = 10, expBonus = -5,
        skills = {{id="dragon_breath", name="용의 브레스", desc="적에게 강력한 화염 브레스", cooldown=8, duration=0, type="attack", value=25, element="fire"}},
    },
    {
        id = "spirit", name = "정령", char = "@", color = {0.7, 0.9, 1},
        desc = "원소의 화신. 모든 원소 마법에 뛰어나지만 물리에 약하다.",
        stats = {str=2, dex=5, int=10, con=3, lck=5},
        resist = {fire=0.2, ice=0.2, lightning=0.2, poison=0.2},
        weak = {slash=0.3, strike=0.3, pierce=0.3},
        profBonus = {fire=2, ice=2, lightning=2, poison=2, holy=2},
        hpBonus = -10, expBonus = 0,
        skills = {{id="elemental_burst", name="원소 폭발", desc="무작위 원소로 강력한 데미지", cooldown=6, duration=0, type="attack", value=20, element="fire"}},
    },
    {
        id = "beastman", name = "수인", char = "@", color = {0.7, 0.5, 0.2},
        desc = "야생의 전사. STR/DEX 균형, 독에 강하고 빠른 회복.",
        stats = {str=7, dex=6, int=2, con=6, lck=4},
        resist = {poison=0.2},
        weak = {fire=0.15},
        profBonus = {slash=2, strike=2, pierce=2},
        hpBonus = 5, expBonus = 0,
        skills = {{id="primal_roar", name="원시의 포효", desc="공격력/방어력 +20% (4턴)", cooldown=10, duration=4, type="buff"}},
    },
    {
        id = "shadow", name = "그림자", char = "@", color = {0.3, 0.3, 0.4},
        desc = "어둠의 존재. 물리 회피가 높고 독/암흑에 강하다.",
        stats = {str=4, dex=9, int=5, con=3, lck=6},
        resist = {poison=0.3, ice=0.2},
        weak = {holy=0.4, fire=0.2},
        profBonus = {pierce=3, poison=3},
        hpBonus = -8, expBonus = 5,
        skills = {{id="shadow_step", name="그림자 걸음", desc="회피율 극대화 (2턴)", cooldown=7, duration=2, type="buff"}},
    },
}

-- ===== 플레이어 직업 (20종) =====
local PLAYER_CLASSES = {
    {
        id = "fighter", name = "전사", color = {1, 0.4, 0.3},
        desc = "근접 전투의 달인. 참격/타격 무기에 능하고 방어력이 높다.",
        statBonus = {str=3, dex=1, int=0, con=3, lck=0},
        profBonus = {slash=3, strike=2},
        startWeapon = "steel_sword", startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {
            {id="power_strike", name="강타", desc="다음 공격 데미지 2배", cooldown=6, duration=0, type="nextAtk", value=2.0},
            {id="shield_bash", name="방패 강타", desc="적 기절 + 타격 데미지", cooldown=8, duration=0, type="attack", value=10, element="strike"},
        },
    },
    {
        id = "rogue", name = "도적", color = {0.5, 1, 0.5},
        desc = "은밀한 암살자. 찌르기 무기에 능하고 치명타가 높다.",
        statBonus = {str=0, dex=4, int=0, con=1, lck=3},
        profBonus = {pierce=4},
        startWeapon = "dagger", startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="backstab", name="급소 찌르기", desc="다음 공격 치명타 확정 (3배)", cooldown=8, duration=0, type="nextAtk", value=3.0},
            {id="smoke_bomb", name="연막탄", desc="회피율 극대화 (2턴)", cooldown=10, duration=2, type="buff"},
        },
    },
    {
        id = "mage", name = "마법사", color = {0.4, 0.6, 1},
        desc = "원소 마법의 대가. 화염/빙결/번개 마법 무기에 능하다.",
        statBonus = {str=0, dex=1, int=5, con=1, lck=1},
        profBonus = {fire=3, ice=3, lightning=3},
        startWeapon = "flame_dagger", startArmor = nil,
        startItems = {"health_potion"},
        skills = {
            {id="fireball", name="화염구", desc="적에게 INT 기반 화염 데미지", cooldown=4, duration=0, type="attack", value=0, element="fire"},
            {id="ice_lance", name="얼음 창", desc="적에게 INT 기반 빙결 데미지", cooldown=4, duration=0, type="attack", value=0, element="ice"},
            {id="chain_lightning", name="연쇄 번개", desc="적에게 INT 기반 번개 데미지", cooldown=5, duration=0, type="attack", value=0, element="lightning"},
        },
    },
    {
        id = "paladin", name = "성기사", color = {1, 1, 0.5},
        desc = "신의 전사. 신성 무기에 능하고 언데드/악마에 강하다.",
        statBonus = {str=2, dex=0, int=2, con=3, lck=1},
        profBonus = {holy=5, strike=2},
        startWeapon = "holy_mace", startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {
            {id="holy_smite", name="신성한 강타", desc="적에게 신성 데미지 (언데드/악마 2배)", cooldown=5, duration=0, type="attack", value=0, element="holy"},
            {id="lay_on_hands", name="안수 치유", desc="HP를 INT*4 만큼 회복", cooldown=8, duration=0, type="heal"},
        },
    },
    {
        id = "ranger", name = "궁수", color = {0.3, 0.8, 0.3},
        desc = "민첩한 사냥꾼. 찌르기 무기에 능하고 회피가 높다.",
        statBonus = {str=1, dex=4, int=1, con=1, lck=2},
        profBonus = {pierce=4, slash=1},
        startWeapon = "dagger", startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="precise_shot", name="정밀 사격", desc="다음 공격 명중 100% + 방어 무시", cooldown=6, duration=0, type="nextAtk", value=1.5},
            {id="rain_of_arrows", name="화살 비", desc="적에게 찌르기 데미지 x2", cooldown=7, duration=0, type="attack", value=16, element="pierce"},
        },
    },
    {
        id = "priest", name = "사제", color = {1, 1, 0.8},
        desc = "신성한 치유사. 신성 마법에 능하고 HP 회복 능력이 뛰어나다.",
        statBonus = {str=0, dex=1, int=4, con=3, lck=1},
        profBonus = {holy=4, strike=1},
        startWeapon = "holy_mace", startArmor = nil,
        startItems = {"health_potion", "health_potion", "health_potion"},
        skills = {
            {id="heal", name="치유", desc="HP를 INT*3 만큼 회복", cooldown=5, duration=0, type="heal"},
            {id="smite_evil", name="사악 퇴치", desc="신성 데미지 (언데드/악마 3배)", cooldown=6, duration=0, type="attack", value=0, element="holy"},
        },
    },
    {
        id = "berserker", name = "광전사", color = {1, 0.2, 0.1},
        desc = "분노의 전사. 양손 무기에 능하고 광폭화 시 초강력 공격.",
        statBonus = {str=5, dex=0, int=0, con=3, lck=0},
        profBonus = {slash=3, strike=3},
        startWeapon = "long_sword", startArmor = nil,
        startItems = {"health_potion"},
        skills = {
            {id="berserk", name="광폭화", desc="공격력 2배, 방어 0 (5턴)", cooldown=15, duration=5, type="buff"},
            {id="cleave", name="대회전", desc="강력한 참격 데미지", cooldown=6, duration=0, type="attack", value=20, element="slash"},
        },
    },
    -- === 신규 직업 8~20 ===
    {
        id = "necromancer", name = "강령술사", color = {0.4, 0.2, 0.5},
        desc = "죽음의 마법사. 독/빙결 마법에 특화되고 생명력 흡수 능력.",
        statBonus = {str=0, dex=1, int=6, con=1, lck=1},
        profBonus = {poison=4, ice=3},
        startWeapon = "flame_dagger", startArmor = nil,
        startItems = {"health_potion"},
        skills = {
            {id="death_bolt", name="죽음의 화살", desc="적에게 독 데미지 + HP 흡수", cooldown=4, duration=0, type="attack", value=0, element="poison"},
            {id="corpse_explosion", name="시체 폭발", desc="강력한 독 폭발 데미지", cooldown=8, duration=0, type="attack", value=25, element="poison"},
        },
    },
    {
        id = "monk", name = "수도승", color = {0.9, 0.7, 0.3},
        desc = "맨손 격투의 달인. 타격에 극도로 뛰어나고 회피가 높다.",
        statBonus = {str=2, dex=4, int=1, con=2, lck=2},
        profBonus = {strike=5, pierce=1},
        startWeapon = nil, startArmor = nil,
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="flurry_blows", name="연타", desc="다음 공격 3회 연속 타격", cooldown=7, duration=0, type="nextAtk", value=1.0},
            {id="inner_peace", name="내면의 평화", desc="HP 회복 + 방어 상승 (3턴)", cooldown=10, duration=3, type="buff"},
        },
    },
    {
        id = "warlock", name = "흑마법사", color = {0.6, 0.1, 0.3},
        desc = "어둠의 계약자. 화염/독 마법에 강하지만 체력이 낮다.",
        statBonus = {str=0, dex=2, int=5, con=0, lck=2},
        profBonus = {fire=4, poison=3},
        startWeapon = "flame_dagger", startArmor = nil,
        startItems = {"health_potion"},
        skills = {
            {id="shadow_bolt", name="어둠의 화살", desc="적에게 강력한 마법 데미지", cooldown=3, duration=0, type="attack", value=0, element="fire"},
            {id="dark_pact", name="어둠의 계약", desc="HP 소모 → 공격력 대폭 상승 (3턴)", cooldown=12, duration=3, type="buff"},
        },
    },
    {
        id = "shaman", name = "주술사", color = {0.3, 0.6, 0.5},
        desc = "원소의 중재자. 번개/빙결에 뛰어나고 치유도 가능하다.",
        statBonus = {str=1, dex=2, int=4, con=2, lck=2},
        profBonus = {lightning=4, ice=2},
        startWeapon = "short_sword", startArmor = "leather_armor",
        startItems = {"health_potion"},
        skills = {
            {id="lightning_bolt", name="번개 화살", desc="적에게 INT 기반 번개 데미지", cooldown=4, duration=0, type="attack", value=0, element="lightning"},
            {id="spirit_heal", name="정령 치유", desc="HP를 INT*2 만큼 회복", cooldown=6, duration=0, type="heal"},
        },
    },
    {
        id = "assassin", name = "암살자", color = {0.3, 0.3, 0.3},
        desc = "일격필살의 전문가. DEX/LCK 극대화, 독 무기 전문.",
        statBonus = {str=1, dex=5, int=0, con=0, lck=4},
        profBonus = {pierce=4, poison=3},
        startWeapon = "dagger", startArmor = nil,
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="death_strike", name="암살", desc="다음 공격 치명타 확정 (4배 데미지)", cooldown=10, duration=0, type="nextAtk", value=4.0},
            {id="poison_blade", name="독날", desc="다음 공격에 독 데미지 추가", cooldown=5, duration=0, type="nextAtk", value=1.5},
        },
    },
    {
        id = "knight", name = "기사", color = {0.7, 0.7, 0.9},
        desc = "명예로운 수호자. 방어력 극대화, 참격 무기 전문.",
        statBonus = {str=2, dex=1, int=0, con=5, lck=0},
        profBonus = {slash=3, strike=2},
        startWeapon = "steel_sword", startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {
            {id="bulwark", name="철벽 방어", desc="방어력 +8 (4턴)", cooldown=8, duration=4, type="buff"},
            {id="justice_strike", name="정의의 일격", desc="CON 기반 참격 데미지", cooldown=6, duration=0, type="attack", value=15, element="slash"},
        },
    },
    {
        id = "druid", name = "드루이드", color = {0.2, 0.7, 0.2},
        desc = "자연의 수호자. 독/빙결 마법과 치유에 뛰어나다.",
        statBonus = {str=1, dex=2, int=4, con=2, lck=2},
        profBonus = {poison=3, ice=3},
        startWeapon = "short_sword", startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="entangle", name="덩굴 속박", desc="적에게 독 데미지 + 감속", cooldown=5, duration=0, type="attack", value=12, element="poison"},
            {id="nature_heal", name="자연 치유", desc="HP를 INT*3 만큼 회복 + 재생 (3턴)", cooldown=7, duration=0, type="heal"},
        },
    },
    {
        id = "battle_mage", name = "전투 마법사", color = {0.6, 0.4, 0.8},
        desc = "마법과 검술을 겸비한 전사. 근접+마법 하이브리드.",
        statBonus = {str=2, dex=1, int=3, con=2, lck=0},
        profBonus = {slash=2, fire=2, lightning=2},
        startWeapon = "steel_sword", startArmor = "leather_armor",
        startItems = {"health_potion"},
        skills = {
            {id="arcane_strike", name="비전 강타", desc="다음 공격에 INT 기반 추가 데미지", cooldown=5, duration=0, type="nextAtk", value=2.0},
            {id="flame_shield", name="화염 방패", desc="반사 데미지 + 방어 상승 (4턴)", cooldown=10, duration=4, type="buff"},
        },
    },
    {
        id = "summoner", name = "소환사", color = {0.5, 0.3, 0.8},
        desc = "이계의 힘을 빌리는 마법사. 다양한 원소 소환 공격.",
        statBonus = {str=0, dex=1, int=6, con=1, lck=2},
        profBonus = {fire=2, ice=2, lightning=2, poison=2},
        startWeapon = "flame_dagger", startArmor = nil,
        startItems = {"health_potion"},
        skills = {
            {id="summon_fire", name="화염 정령", desc="강력한 화염 폭발 소환", cooldown=5, duration=0, type="attack", value=0, element="fire"},
            {id="summon_ice", name="빙결 정령", desc="강력한 빙결 폭풍 소환", cooldown=5, duration=0, type="attack", value=0, element="ice"},
            {id="summon_storm", name="폭풍 정령", desc="강력한 번개 폭풍 소환", cooldown=5, duration=0, type="attack", value=0, element="lightning"},
        },
    },
    {
        id = "bard", name = "음유시인", color = {0.9, 0.6, 0.8},
        desc = "노래로 아군을 강화하는 전사. 다양한 버프 스킬 보유.",
        statBonus = {str=1, dex=3, int=2, con=1, lck=4},
        profBonus = {pierce=2, slash=2},
        startWeapon = "short_sword", startArmor = "leather_armor",
        startItems = {"health_potion", "health_potion"},
        skills = {
            {id="war_song", name="전쟁의 노래", desc="공격력 +40% (5턴)", cooldown=12, duration=5, type="buff"},
            {id="healing_melody", name="치유의 선율", desc="HP를 INT*3 만큼 회복", cooldown=6, duration=0, type="heal"},
        },
    },
    {
        id = "alchemist", name = "연금술사", color = {0.7, 0.8, 0.3},
        desc = "약물과 폭발물의 전문가. 독/화염에 뛰어나고 포션 효과 강화.",
        statBonus = {str=0, dex=2, int=4, con=2, lck=3},
        profBonus = {poison=4, fire=3},
        startWeapon = "short_sword", startArmor = nil,
        startItems = {"health_potion", "health_potion", "large_potion"},
        skills = {
            {id="acid_flask", name="산성 플라스크", desc="적에게 독 폭발 데미지", cooldown=4, duration=0, type="attack", value=0, element="poison"},
            {id="fortify", name="강화 물약", desc="모든 스탯 +2 (5턴)", cooldown=12, duration=5, type="buff"},
        },
    },
    {
        id = "spellblade", name = "마검사", color = {0.5, 0.5, 1},
        desc = "마법을 검에 담는 전사. 참격+원소 복합 공격 전문.",
        statBonus = {str=3, dex=2, int=3, con=1, lck=0},
        profBonus = {slash=3, fire=2, ice=2},
        startWeapon = "steel_sword", startArmor = "leather_armor",
        startItems = {"health_potion"},
        skills = {
            {id="frost_blade", name="서리 검", desc="다음 공격에 빙결 데미지 추가 (2배)", cooldown=5, duration=0, type="nextAtk", value=2.0},
            {id="inferno_slash", name="업화 참격", desc="적에게 화염 참격 데미지", cooldown=6, duration=0, type="attack", value=18, element="fire"},
        },
    },
    {
        id = "templar", name = "성전사", color = {0.9, 0.8, 0.3},
        desc = "신성한 심판자. 신성/번개에 특화되고 언데드 사냥 전문.",
        statBonus = {str=3, dex=0, int=2, con=3, lck=1},
        profBonus = {holy=4, lightning=2, strike=2},
        startWeapon = "holy_mace", startArmor = "chain_mail",
        startItems = {"health_potion"},
        skills = {
            {id="judgment", name="심판", desc="신성+번개 복합 데미지", cooldown=6, duration=0, type="attack", value=20, element="holy"},
            {id="divine_shield", name="신성 방패", desc="데미지 30% 감소 (4턴)", cooldown=10, duration=4, type="buff"},
        },
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

-- ===== 유틸리티 =====
local function addMessage(text)
    table.insert(messages, 1, text)
    messageScroll = 0
end

local function distance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
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

    for i = 1, MAX_ROOMS do
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
            for ry = y, y + h - 1 do
                for rx = x, x + w - 1 do
                    map[ry][rx] = TILE_FLOOR
                end
            end

            local room = {x = x, y = y, w = w, h = h,
                          cx = math.floor(x + w / 2),
                          cy = math.floor(y + h / 2)}
            table.insert(rooms, room)

            if #rooms > 1 then
                local prev = rooms[#rooms - 1]
                local sx = math.min(prev.cx, room.cx)
                local ex = math.max(prev.cx, room.cx)
                for cx = sx, ex do
                    if map[prev.cy] then
                        map[prev.cy][cx] = TILE_FLOOR
                    end
                end
                local sy = math.min(prev.cy, room.cy)
                local ey = math.max(prev.cy, room.cy)
                for cy = sy, ey do
                    if map[cy] then
                        map[cy][room.cx] = TILE_FLOOR
                    end
                end
            end
        end
    end

    if #rooms > 1 then
        local lastRoom = rooms[#rooms]
        map[lastRoom.cy][lastRoom.cx] = TILE_STAIR
    end
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
            local ex = math.random(room.x + 1, room.x + room.w - 2)
            local ey = math.random(room.y + 1, room.y + room.h - 2)

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
end

-- ===== 바닥 아이템 생성 =====
local function spawnGroundItems()
    for i = 2, #rooms do
        local room = rooms[i]
        local count = math.random(0, MAX_ITEMS_PER_ROOM)
        for j = 1, count do
            local ix = math.random(room.x + 1, room.x + room.w - 2)
            local iy = math.random(room.y + 1, room.y + room.h - 2)
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
        for _, s in ipairs(race.skills) do
            table.insert(skills, {id=s.id, name=s.name, desc=s.desc, cooldown=s.cooldown, currentCd=0, duration=s.duration, type=s.type, value=s.value, element=s.element, active=0})
        end
        for _, s in ipairs(class.skills) do
            table.insert(skills, {id=s.id, name=s.name, desc=s.desc, cooldown=s.cooldown, currentCd=0, duration=s.duration, type=s.type, value=s.value, element=s.element, active=0})
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

--- 장비 스탯 포함 최종 스탯 계산
local function getPlayerAtk()
    local bonus = equip and equip:getTotalStats().atk or 0
    local strBonus = math.floor(player.str / 3)
    return player.baseAtk + bonus + strBonus
end

local function getPlayerDef()
    local bonus = equip and equip:getTotalStats().def or 0
    local conBonus = math.floor(player.con / 5)
    return player.baseDef + bonus + conBonus
end

--- 회피율 (DEX + LCK 기반)
local function getPlayerEvasion()
    local eqSpd = equip and equip:getTotalStats().spd or 0
    return 5 + player.dex * 1.5 + player.lck * 0.5 + eqSpd
end

--- 명중률 (DEX 기반)
local function getPlayerAccuracy()
    return 70 + player.dex * 2 + player.lck * 0.5
end

--- 치명타 확률 (DEX + LCK 기반)
local function getPlayerCritChance()
    local eqCrit = equip and equip:getTotalStats().crit or 0
    return 5 + player.dex * 0.5 + player.lck * 1.0 + eqCrit
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
    return base + player.con * 3 + eqHp + raceHp
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

--- 버프 적용
local function applyBuff(buffId, name, duration)
    if not player.buffs then player.buffs = {} end
    for _, b in ipairs(player.buffs) do
        if b.id == buffId then
            b.duration = duration
            return
        end
    end
    table.insert(player.buffs, {id=buffId, name=name, duration=duration})
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

--- 스킬 사용
local function useSkill(skillIndex, targetEnemy)
    if not player.skills or not player.skills[skillIndex] then return false end
    local s = player.skills[skillIndex]
    if s.currentCd > 0 then
        addMessage(s.name .. " 쿨다운 중! (남은 " .. s.currentCd .. "턴)")
        return false
    end

    s.currentCd = s.cooldown

    if s.type == "buff" then
        applyBuff(s.id, s.name, s.duration)
        addMessage("★ " .. s.name .. " 발동! (" .. s.duration .. "턴)")
        -- 어둠의 계약: HP 25% 소모
        if s.id == "dark_pact" then
            local cost = math.floor(player.hp * 0.25)
            player.hp = math.max(1, player.hp - cost)
            addMessage("  HP -" .. cost .. " 소모!")
        end
        -- 내면의 평화: 즉시 소량 회복
        if s.id == "inner_peace" then
            local healAmt = player.int * 2
            player.hp = math.min(player.hp + healAmt, getPlayerMaxHp())
            addMessage("  HP +" .. healAmt .. " 회복!")
        end
        return true
    elseif s.type == "heal" then
        local mult = 3
        if s.id == "lay_on_hands" then mult = 4 end
        if s.id == "spirit_heal" or s.id == "pixie_dust" then mult = 2 end
        local healAmt = player.int * mult
        player.hp = math.min(player.hp + healAmt, getPlayerMaxHp())
        addMessage("★ " .. s.name .. "! HP +" .. healAmt .. " 회복!")
        return true
    elseif s.type == "attack" then
        if not targetEnemy then
            addMessage("대상이 없습니다!")
            s.currentCd = 0
            return false
        end
        local baseDmg = player.int * 2 + player.level * 2
        local fixedVal = s.value or 0
        local dmg = math.max(1, baseDmg + fixedVal)
        local elem = s.element or "physical"
        local elemMult = getElementMult(elem, targetEnemy.race)
        -- 신성 스킬: 언데드/악마에 보너스
        if (s.id == "holy_smite" or s.id == "smite_evil" or s.id == "judgment") and (targetEnemy.race == "undead" or targetEnemy.race == "demon") then
            local holyMult = 2
            if s.id == "smite_evil" then holyMult = 3 end
            dmg = dmg * holyMult
        end
        -- 숙련도 보너스
        local profMult = getProficiencyBonus(elem)
        dmg = math.max(1, math.floor(dmg * elemMult * profMult))
        if elemMult == 0 then
            addMessage(targetEnemy.name .. "은(는) 면역!")
            return true
        end
        targetEnemy.hp = targetEnemy.hp - dmg
        local elemName = Item.ELEMENT_NAMES[elem] or elem
        addMessage("★ " .. s.name .. "! " .. targetEnemy.name .. "에게 " .. dmg .. " " .. elemName .. " 데미지!")
        -- 생명력 흡수 계열
        if s.id == "drain_life" or s.id == "blood_drain" or s.id == "death_bolt" or s.id == "divine_light" then
            local healPct = 0.5
            if s.id == "blood_drain" then healPct = 0.6 end
            if s.id == "divine_light" then healPct = 0.3 end
            local heal = math.floor(dmg * healPct)
            player.hp = math.min(player.hp + heal, getPlayerMaxHp())
            addMessage("  HP +" .. heal .. " 흡수!")
        end
        -- 숙련도 성장
        gainProficiency(elem)
        return true
    elseif s.type == "nextAtk" then
        player.nextAtkBonus = {name=s.name, mult=s.value, id=s.id}
        addMessage("★ " .. s.name .. " 준비! 다음 공격에 적용됩니다.")
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
    -- 늑대 광기: 공격력 2.5배
    if hasBuff("wolf_frenzy") then atk = math.floor(atk * 2.5) end
    -- 전쟁의 노래: 공격력 +40%
    if hasBuff("war_song") then atk = math.floor(atk * 1.4) end
    -- 원시의 포효: 공격력 +20%
    if hasBuff("primal_roar") then atk = math.floor(atk * 1.2) end
    -- 어둠의 계약: 공격력 +80%
    if hasBuff("dark_pact") then atk = math.floor(atk * 1.8) end
    -- 강화 물약: 스탯 +2 → 공격력 약간 상승
    if hasBuff("fortify") then atk = atk + 4 end

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

        -- 아이템 드롭 (40% + LCK 보정)
        local dropChance = 0.4 + player.lck * 0.01
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
    -- 그림자 은폐/연막탄/그림자 걸음: 회피 대폭 상승
    if hasBuff("shadow_cloak") or hasBuff("smoke_bomb") or hasBuff("shadow_step") then
        if math.random(1, 100) <= 70 then
            addMessage("  ★ 은폐 효과! " .. enemy.name .. "의 공격을 피했다!")
            return
        end
    end
    -- 늑대 광기: 회피 소폭 상승
    if hasBuff("wolf_frenzy") then
        evasion = evasion + 15
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
    -- 강철 육체: 방어력 +10
    if hasBuff("iron_body") then def = def + 10 end
    -- 철벽 방어: 방어력 +8
    if hasBuff("bulwark") then def = def + 8 end
    -- 원시의 포효: 방어력 +20%
    if hasBuff("primal_roar") then def = math.floor(def * 1.2) end
    -- 강화 물약: 방어력 +2
    if hasBuff("fortify") then def = def + 2 end

    local dmg = math.max(1, (enemy.atk or 0) - math.floor(def * 0.6))
    local variance = math.floor(dmg * 0.15)
    dmg = dmg + math.random(-variance, variance)
    dmg = math.max(1, dmg)

    -- 마나 실드 데미지 감소 20%
    if hasBuff("mana_shield") then
        dmg = math.max(1, math.floor(dmg * 0.8))
    end
    -- 신성 방패 데미지 감소 30%
    if hasBuff("divine_shield") then
        dmg = math.max(1, math.floor(dmg * 0.7))
    end
    -- 화염 방패: 반사 데미지
    if hasBuff("flame_shield") then
        local reflect = math.floor(dmg * 0.25)
        enemy.hp = enemy.hp - reflect
        addMessage("  ★ 화염 방패 반사 " .. reflect .. " 데미지!")
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

-- ===== 마을로 귀환 =====
local function goToTown()
    gameState = "town"
    townMenuSel = 1
    dungeonRun = dungeonRun + 1
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
    shop.needsRefresh = true
    addMessage("** 마을에 도착했습니다! (HP 회복) **")
end

-- ===== 던전 출발 =====
local function startDungeon()
    floor = 1
    turn = 0
    gameState = "playing"
    addMessage(">> 던전 " .. (dungeonRun + 1) .. "번째 탐험 출발! <<")
    createMap()
    spawnEnemies()
    spawnGroundItems()
    initPlayer(true)
    player.maxHp = getPlayerMaxHp()
    player.hp = player.maxHp
end

-- ===== 계단 =====
local function checkStair()
    if map[player.y] and map[player.y][player.x] == TILE_STAIR then
        floor = floor + 1
        if floor > 5 then
            addMessage("** 던전 클리어! 마을로 귀환합니다 **")
            goToTown()
            return
        end
        addMessage(">> " .. floor .. "층으로 이동 <<")
        createMap()
        spawnEnemies()
        spawnGroundItems()
        initPlayer(true)
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

    -- 직업별 시작 장비
    local cls = charSelect.chosenClass or PLAYER_CLASSES[1]
    if cls.startWeapon then
        local w = Item.create(cls.startWeapon)
        if w then inv:autoPlace(w) end
    end
    if cls.startArmor then
        local a = Item.create(cls.startArmor)
        if a then inv:autoPlace(a) end
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
                charSelect.chosenClass = PLAYER_CLASSES[charSelect.classSel]
                finishCharCreation()
            elseif key == "escape" then
                charSelect.phase = "race"
            end
        end
        return
    end

    -- 스킬 핫키 (1~4) — 게임 플레이 중
    if gameState == "playing" and player.skills then
        local skillKey = tonumber(key)
        if skillKey and skillKey >= 1 and skillKey <= #player.skills then
            -- 공격 스킬은 인접 적 자동 타겟
            local target = nil
            for _, e in ipairs(enemies) do
                if e.alive and distance(player.x, player.y, e.x, e.y) <= 1 then
                    target = e
                    break
                end
            end
            local used = useSkill(skillKey, target)
            if used then
                -- 공격 스킬 사용 후 턴 소비
                local s = player.skills[skillKey]
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
                    player.gold = player.gold + goldDrop
                    addMessage(target.name .. " 처치! (+" .. target.exp .. " 경험치, +" .. goldDrop .. " 골드)")
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

    -- 아이템 버리기 (D키)
    if key == "d" and gameState == "inventory" then
        if hoverItem and gameState == "inventory" then
            local item = hoverItem
            inv:removeItem(item)
            table.insert(groundItems, {
                x = player.x, y = player.y,
                item = item,
                picked = false,
            })
            addMessage(item.name .. " 버림!")
            hoverItem = nil
            return
        end
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
            -- 사망 시 마을로 귀환, 인벤토리 유지 (익스트랙션 스타일)
            addMessage("** 사망했지만 마을로 돌아왔습니다... **")
            goToTown()
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
        if slot and equip:canDropToSlot(item, slot) then
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
            elseif tile == TILE_STAIR then
                love.graphics.setColor(COLOR_FLOOR)
                love.graphics.rectangle("fill", sx, sy, TILE_SIZE, TILE_SIZE)
                love.graphics.setColor(COLOR_STAIR)
                love.graphics.print(">", sx + 3, sy)
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
            if s.currentCd > 0 then
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.print("[" .. i .. "] " .. s.name .. " (쿨:" .. s.currentCd .. ")", hudX, hudY)
            else
                love.graphics.setColor(0.9, 0.8, 1)
                love.graphics.print("[" .. i .. "] " .. s.name, hudX, hudY)
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
    local skCount = (player.skills and #player.skills) or 0
    love.graphics.print("I/Tab: 인벤 | 1~" .. math.max(1, skCount) .. ": 스킬", hudX, hudY)
    hudY = hudY + 14
    love.graphics.print(">: 계단 | PgUp/Dn: 로그", hudX, hudY)
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
        love.graphics.printf("R키: 마을로 귀환 (인벤토리 유지)", 0, love.graphics.getHeight() / 2 + 30, love.graphics.getWidth(), "center")
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

    -- 패시브 효과 표시
    local passives = getEquipPassives()
    if #passives > 0 then
        local py = equip.y + 350
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
    love.graphics.printf("좌클릭: 드래그 | 우클릭: 장착/사용 | D: 버리기 | I/Tab/Esc: 닫기", 0, 28, sw, "center")

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
        local itemH = 20
        local maxVisible = math.floor((sh - 100) / itemH)
        local scrollOff = math.max(0, charSelect.raceSel - math.floor(maxVisible / 2))
        scrollOff = math.min(scrollOff, math.max(0, #PLAYER_RACES - maxVisible))

        for i, race in ipairs(PLAYER_RACES) do
            local vi = i - scrollOff
            if vi >= 1 and vi <= maxVisible then
                local y = startY + (vi - 1) * itemH
                if i == charSelect.raceSel then
                    love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                    love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, itemH - 1, 3, 3)
                    love.graphics.setColor(race.color[1], race.color[2], race.color[3])
                    love.graphics.print("▶ " .. race.name, listX, y)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.print("  " .. race.name, listX, y)
                end
            end
        end
        -- 스크롤 인디케이터
        if scrollOff > 0 then
            love.graphics.setColor(COLOR_GRAY)
            love.graphics.print("▲ 더 있음", listX, startY - 15)
        end
        if scrollOff + maxVisible < #PLAYER_RACES then
            love.graphics.setColor(COLOR_GRAY)
            love.graphics.print("▼ 더 있음", listX, startY + maxVisible * itemH)
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
        local itemH = 20
        local maxVisible = math.floor((sh - 100) / itemH)
        local scrollOff = math.max(0, charSelect.classSel - math.floor(maxVisible / 2))
        scrollOff = math.min(scrollOff, math.max(0, #PLAYER_CLASSES - maxVisible))

        for i, cls in ipairs(PLAYER_CLASSES) do
            local vi = i - scrollOff
            if vi >= 1 and vi <= maxVisible then
                local y = startY + (vi - 1) * itemH
                if i == charSelect.classSel then
                    love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
                    love.graphics.rectangle("fill", listX - 5, y - 2, sw * 0.4, itemH - 1, 3, 3)
                    love.graphics.setColor(cls.color[1], cls.color[2], cls.color[3])
                    love.graphics.print("▶ " .. cls.name, listX, y)
                else
                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.print("  " .. cls.name, listX, y)
                end
            end
        end
        if scrollOff > 0 then
            love.graphics.setColor(COLOR_GRAY)
            love.graphics.print("▲ 더 있음", listX, startY - 15)
        end
        if scrollOff + maxVisible < #PLAYER_CLASSES then
            love.graphics.setColor(COLOR_GRAY)
            love.graphics.print("▼ 더 있음", listX, startY + maxVisible * itemH)
        end

        local sel = PLAYER_CLASSES[charSelect.classSel]
        if sel then
            local iy = startY
            love.graphics.setColor(sel.color[1], sel.color[2], sel.color[3])
            love.graphics.print("【" .. sel.name .. "】", infoX, iy)
            iy = iy + 22

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
                local wData = Item.DB[sel.startWeapon]
                love.graphics.setColor(1, 1, 1)
                love.graphics.print("  무기: " .. (wData and wData.name or sel.startWeapon), infoX, iy)
                iy = iy + 15
            end
            if sel.startArmor then
                local aData = Item.DB[sel.startArmor]
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
