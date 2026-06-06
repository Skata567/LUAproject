local ConfigManager = {}

CONFIG = {
    audio = {
        bgm = 50,
        sfx = 50
    },
    keys = {
        up = "up",
        down = "down",
        left = "left",
        right = "right",
        wait = "space",
        interact = "return",
        inventory = "i",
        skilltree = "k",
        escape = "escape"
    }
}

function ConfigManager.save()
    local data = ""
    for k, v in pairs(CONFIG.audio) do
        data = data .. "audio." .. k .. "=" .. tostring(v) .. "\n"
    end
    for k, v in pairs(CONFIG.keys) do
        data = data .. "keys." .. k .. "=" .. tostring(v) .. "\n"
    end
    
    local success, message = love.filesystem.write("settings.txt", data)
    if not success then
        print("설정 저장 실패: " .. tostring(message))
    end
end

function ConfigManager.load()
    if love.filesystem.getInfo("settings.txt") then
        local contents, size = love.filesystem.read("settings.txt")
        if contents then
            for line in contents:gmatch("[^\r\n]+") do
                local keyPath, value = line:match("([^=]+)=(.+)")
                if keyPath and value then
                    local category, subKey = keyPath:match("([^%.]+)%.([^%.]+)")
                    if category == "audio" and CONFIG.audio[subKey] ~= nil then
                        CONFIG.audio[subKey] = tonumber(value) or CONFIG.audio[subKey]
                    elseif category == "keys" and CONFIG.keys[subKey] ~= nil then
                        CONFIG.keys[subKey] = value
                    end
                end
            end
        end
    end
end

-- 시작 시 한 번 로드 시도
ConfigManager.load()

return ConfigManager
