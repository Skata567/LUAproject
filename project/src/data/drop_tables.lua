local M = {}

-- 바닥 아이템 드롭 테이블 (층별 가중치)
M.DROP_TABLE = {
    -- 소비/재료
    {id = "health_potion", weight = 30, minFloor = 1},
    {id = "large_potion",  weight = 10, minFloor = 2},
    {id = "return_scroll", weight = 15, minFloor = 1},
    {id = "gold_coin",     weight = 25, minFloor = 1},
    {id = "basic_torch",   weight = 15, minFloor = 1},
    {id = "magic_lantern", weight = 5,  minFloor = 3},
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
    {id = "crystal_blade",      weight = 2, minFloor = 4},
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
    {id = "cursed_chalice", weight = 2, minFloor = 3},
    {id = "abyssal_scythe", weight = 1, minFloor = 5},
    {id = "mjolnir",        weight = 1, minFloor = 5},
    {id = "executioner_axe",weight = 1, minFloor = 5},
    -- 방패
    {id = "wooden_shield", weight = 12, minFloor = 1},
    {id = "iron_shield",   weight = 6,  minFloor = 2},
    {id = "thorn_shield",  weight = 3,  minFloor = 3},
    {id = "mirror_shield", weight = 2,  minFloor = 4},
    {id = "dragon_shield", weight = 1,  minFloor = 5},
    {id = "aegis_shield",  weight = 1,  minFloor = 5},
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
    {id = "vengeance_armor", weight = 2, minFloor = 4},
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
    {id = "mana_stone_ring", weight = 2, minFloor = 4},
    -- 목걸이
    {id = "silver_amulet",      weight = 6, minFloor = 2},
    {id = "healing_pendant",    weight = 3, minFloor = 3},
    {id = "amulet_of_fury",     weight = 2, minFloor = 4},
    {id = "amulet_of_eternity", weight = 1, minFloor = 5},
    {id = "phoenix_feather",    weight = 1, minFloor = 5},
    -- 재료
    {id = "dragon_scale",  weight = 1,  minFloor = 5},
}


return M
