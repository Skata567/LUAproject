local Religion = require("systems.religion")

local M = {}

function M.test_religion_stats()
    -- War God
    assert(Religion.applyAtkMod(10, Religion.GOD_WAR) == 15, "War God should increase ATK by 50%")
    assert(Religion.applyDefMod(10, Religion.GOD_WAR) == 7, "War God should decrease DEF by 30%")

    -- Shadow God
    assert(Religion.applyHpMod(100, Religion.GOD_SHADOW) == 70, "Shadow God should decrease MaxHP by 30%")
    assert(Religion.applyEvasionMod(10, Religion.GOD_SHADOW) == 40, "Shadow God should increase Evasion by 30")
    assert(Religion.applyCritMod(10, Religion.GOD_SHADOW) == 30, "Shadow God should increase Crit by 20")

    -- Magic God
    assert(Religion.applyMagicDmgMod(50, Religion.GOD_MAGIC) == 100, "Magic God should double Magic Dmg")
    assert(Religion.applyFovMod(8, Religion.GOD_MAGIC) == 11, "Magic God should increase FOV by 3")
    assert(Religion.applyAtkMod(10, Religion.GOD_MAGIC) == 5, "Magic God should decrease physical ATK by 50%")
end

return M
