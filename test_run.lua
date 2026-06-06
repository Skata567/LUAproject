package.path = "project/src/?.lua;" .. package.path
love = {
    graphics = {
        newImage = function() return {} end,
        newCanvas = function() return {} end,
        setCanvas = function() end,
        clear = function() end,
        setColor = function() end,
        rectangle = function() end,
        polygon = function() end,
        circle = function() end,
        line = function() end,
        newQuad = function() return {} end,
        draw = function() end,
        print = function() end,
        printf = function() end,
        newFont = function() return {getWidth = function() return 10 end} end,
        setFont = function() end,
        setLineWidth = function() end,
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
    },
    window = {
        setTitle = function() end,
        setMode = function() end,
    },
    keyboard = {}, mouse = {}, math = {}, timer = {}, event = {}, system = {}
}

local ok, err = pcall(dofile, "project/src/main.lua")
if not ok then
    print("ERROR:", err)
else
    print("SUCCESS")
    local ok, err = pcall(love.load)
    if not ok then print("ERROR in load:", err) else print("LOAD SUCCESS") end
end
