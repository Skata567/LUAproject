-- 숫자사각형1 #1303

--[[
local a,b = io.read("*n","*n")
local i = 1
local y = 1
local num = 1

while y <= a do
   
    while i <= b do
        io.write(num.." ")
        i = i + 1
        num = num + 1
    end
    io.write("\n")
    y = y + 1
    i = 1
end
]]

--[[
-- 숫자 사각형2 #1856

local a,b = io.read("*n","*n")
local y = 1

while y <= a do
    local start = (y - 1) * b + 1
    local finish = y * b

    if y == 1 then
        while start <= finish do
            io.write(start.." ")
            start = start + 1
        end
    else
        while finish >= start do
            io.write(finish.." ")
            finish = finish - 1
        end
    end

    io.write("\n")
    y = y + 1
end
]]

-- #1304 숫자 삼각형 3

--[[
local a = io.read("*n")

local y = 1

if(a <= 100 and a > 0 )then
    while y <= a do
        local i = 1
        local start = y

        while i <= a do
            io.write(start .. " ")
            start = start + a
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end 
else
    print("범위 초과")
end

]]

-- #5931 숫자 사각형 4 - 1
--[[
local i = 1

while i <= 5 do
    print(i.." "..i.." "..i.." "..i.." "..i)
    i= i + 1
end
]]

-- #5932 숫자 사각형 4 - 2

--[[

local i = io.read("*n")

local y = 1

if(i <= 100 and i > 0 )then
    while y <= i do
        if(y % 2 == 1)then
            local a = 1

            while a <= i do
                io.write(a.." ")
                a = a + 1
            end
        else
            local a = i

            while a >= 1 do
                io.write(a.." ")
                a = a - 1
            end
        end
        io.write("\n")
        y = y + 1
    end
else
    print("범위 초과")
end

]]


-- 숫자삼각형 4- 3
--[[

local i = io.read("*n")

local a = 1
local b = 1
local c = 1

if(i <= 100 and i > 0 )then
    while b <= i do
        while c <= i do
            io.write(a.." ")
            a = a + b
            c = c + 1
        end
        c = 1
        b = b + 1
        a = b
        io.write("\n")
    end
else
    print("범위 초과")
end

]]

-- 숫자사각형1 #1307

--[[
local i = io.read("*n")

local j = i * i
local b = 1
local c = 1

if(i <= 100 and i > 0 )then
    while c <= i do
        while b <= i do
            io.write(string.char(64 + j).." ")
            j = j - i
            b = b + 1
        end
        j = (i * i) - c
        b = 1
        c = c + 1
        io.write("\n")
    end 
else
     print("범위 초과")
end

]]

-- 문자사각형2 #1314

--[[
local i = io.read("*n")

local a = 1 -- 가로줄
local b = 1 -- 세로줄

if(i <= 100 and i > 0 )then
           while a <= i do
        b = 1

        while b <= i do
            if b % 2 == 1 then
                local hol = (b - 1) * i + a
                io.write(string.char(64 + hol) .. " ")
            else
                local jjack = b * i - a + 1
                io.write(string.char(64 + jjack) .. " ")
            end

            b = b + 1
        end

        a = a + 1
        io.write("\n")
    end
else
     print("범위 초과")
end
]]

--문자 삼각형 1 #1338
--[[
local i = io.read("*n")

local a = 1 -- 현재 줄 번호
local b = 1 -- 알파벳 진행 번호

while a <= i do
    local c = 0 -- 공백 개수

    while c < i - a do
        io.write(" ")
        c = c + 1
    end

    local d = 0 -- 문자 개수

    while d < a do
        local e = ((b - 1) % 26) + 1
        io.write(string.char(64 + e))

        b = b + 1
        d = d + 1
    end

    io.write("\n")
    a = a + 1
end
]]

--문자 삼각형2 #1339

--[[
local n = io.read("*n")

if n <= 100 and n > 0 and n % 2 == 1 then
    local center = math.ceil(n / 2)

    -- board 만들기
    local board = {}
    for r = 1, n do
        board[r] = {}
    end

    local alpha = 1
    local length = 1
    local col = center

    -- 오른쪽 기둥부터 왼쪽으로 채우기
    while length <= n do
        local startRow = center - math.floor(length / 2)
        local endRow = center + math.floor(length / 2)

        local row = startRow
        while row <= endRow do
            local letterNum = ((alpha - 1) % 26) + 1
            board[row][col] = string.char(64 + letterNum)

            alpha = alpha + 1
            row = row + 1
        end

        length = length + 2
        col = col - 1
    end

    -- 출력
    local r = 1
    while r <= n do
        local c = 1

        while c <= center do
            if board[r][c] ~= nil then
                io.write(board[r][c] .. " ")
            end
            c = c + 1
        end

        io.write("\n")
        r = r + 1
    end
else
    print("범위 초과")
end
]]


-- 별삼각형1 #1523

--[[
local n,m = io.read("*n","*n")

local y = 1

if n >= 1 and n <= 100 and m >= 1 and m <= 3 then
    while y <= n do
        local i = 1

        if m == 1 then
            while i <= y do
                io.write("*")
                i = i + 1
            end
        elseif m == 2 then
            while i <= n - y + 1 do
                io.write("*")
                i = i + 1
            end
        else
            while i <= n - y do
                io.write(" ")
                i = i + 1
            end

            i = 1

            while i <= y * 2 - 1 do
                io.write("*")
                i = i + 1
            end
        end

        io.write("\n")
        y = y + 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 별삼각형2 #5934

--[[
local n = io.read("*n")

if n >= 1 and n <= 100 and n % 2 == 1 then
    local a = math.floor(n / 2) + 1
    local y = 1

    while y <= a do
        local i = 1

        while i <= y - 1 do
            io.write(" ")
            i = i + 1
        end

        i = 1

        while i <= a - y + 1 do
            io.write("*")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end

    y = 1

    while y <= a - 1 do
        local i = 1

        while i <= a - 1 do
            io.write(" ")
            i = i + 1
        end

        i = 1

        while i <= y + 1 do
            io.write("*")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 별삼각형3 #1329

--[[
local n = io.read("*n")

if n >= 1 and n <= 100 and n % 2 == 1 then
    local a = math.floor(n / 2)
    local y = 0

    while y < n do
        local b = y

        if y > a then
            b = n - 1 - y
        end

        local i = 1

        while i <= b do
            io.write(" ")
            i = i + 1
        end

        i = 1

        while i <= b * 2 + 1 do
            io.write("*")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 숫자 삼각형1 #5945

--[[
local n = io.read("*n")

if n >= 1 and n <= 50 and n % 2 == 1 then
    local y = 1
    local num = 1

    while y <= n do
        local a = 1
        local b = num

        while a <= y do
            num = num + 1
            a = a + 1
        end

        if y % 2 == 1 then
            a = b

            while a <= num - 1 do
                io.write(a.." ")
                a = a + 1
            end
        else
            a = num - 1

            while a >= b do
                io.write(a.." ")
                a = a - 1
            end
        end

        io.write("\n")
        y = y + 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 숫자 삼각형2 #5946

--[[
local n = io.read("*n")

if n >= 1 and n <= 50 and n % 2 == 1 then
    local y = 0

    while y <= n - 1 do
        local i = 1

        while i <= y do
            io.write(" ")
            i = i + 1
        end

        i = 1

        while i <= n - y do
            io.write(y.." ")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 숫자 삼각형3 #5947

--[[
local n = io.read("*n")

if n >= 1 and n <= 50 and n % 2 == 1 then
    local a = math.floor(n / 2) + 1
    local y = 1

    while y <= a do
        local i = 1

        while i <= y do
            io.write(i.." ")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end

    y = a - 1

    while y >= 1 do
        local i = 1

        while i <= y do
            io.write(i.." ")
            i = i + 1
        end

        io.write("\n")
        y = y - 1
    end
else
    print("INPUT ERROR!")
end
]]

-- 달팽이사각형 #1707

--[[
local n = io.read("*n")

local a = {}
local y = 1

while y <= n do
    a[y] = {}
    local i = 1

    while i <= n do
        a[y][i] = 0
        i = i + 1
    end

    y = y + 1
end

local r = 1
local c = 1
local d = 1
local num = 1

while num <= n * n do
    a[r][c] = num

    local nr = r
    local nc = c

    if d == 1 then
        nc = c + 1
    elseif d == 2 then
        nr = r + 1
    elseif d == 3 then
        nc = c - 1
    else
        nr = r - 1
    end

    if nr < 1 or nr > n or nc < 1 or nc > n or a[nr][nc] ~= 0 then
        d = d + 1

        if d > 4 then
            d = 1
        end

        nr = r
        nc = c

        if d == 1 then
            nc = c + 1
        elseif d == 2 then
            nr = r + 1
        elseif d == 3 then
            nc = c - 1
        else
            nr = r - 1
        end
    end

    r = nr
    c = nc
    num = num + 1
end

y = 1

while y <= n do
    local i = 1

    while i <= n do
        io.write(a[y][i].." ")
        i = i + 1
    end

    io.write("\n")
    y = y + 1
end
]]

-- 달팽이삼각형 #1337

--[[
local n = io.read("*n")

local a = {}
local y = 1

while y <= n do
    a[y] = {}
    local i = 1

    while i <= n do
        a[y][i] = -1
        i = i + 1
    end

    y = y + 1
end

local r = 1
local c = 1
local d = 1
local num = 0
local cnt = 1
local total = n * (n + 1) / 2

while cnt <= total do
    a[r][c] = num % 10

    local nr = r
    local nc = c

    if d == 1 then
        nr = r + 1
        nc = c + 1
    elseif d == 2 then
        nc = c - 1
    else
        nr = r - 1
    end

    if nr < 1 or nr > n or nc < 1 or nc > nr or a[nr][nc] ~= -1 then
        d = d + 1

        if d > 3 then
            d = 1
        end

        nr = r
        nc = c

        if d == 1 then
            nr = r + 1
            nc = c + 1
        elseif d == 2 then
            nc = c - 1
        else
            nr = r - 1
        end
    end

    r = nr
    c = nc
    num = num + 1
    cnt = cnt + 1
end

y = 1

while y <= n do
    local i = 1

    while i <= y do
        io.write(a[y][i].." ")
        i = i + 1
    end

    io.write("\n")
    y = y + 1
end
]]

-- 파스칼 삼각형 #2071

--[[
local n,m = io.read("*n","*n")

local a = {}
local y = 1

while y <= n do
    a[y] = {}
    local i = 1

    while i <= y do
        if i == 1 or i == y then
            a[y][i] = 1
        else
            a[y][i] = a[y - 1][i - 1] + a[y - 1][i]
        end

        i = i + 1
    end

    y = y + 1
end

if m == 1 then
    y = 1

    while y <= n do
        local i = 1

        while i <= y do
            io.write(a[y][i].." ")
            i = i + 1
        end

        io.write("\n")
        y = y + 1
    end
elseif m == 2 then
    y = n

    while y >= 1 do
        local i = 1

        while i <= n - y do
            io.write(" ")
            i = i + 1
        end

        i = 1

        while i <= y do
            io.write(a[y][i].." ")
            i = i + 1
        end

        io.write("\n")
        y = y - 1
    end
else
    local j = n

    while j >= 1 do
        y = n

        while y >= j do
            io.write(a[y][j].." ")
            y = y - 1
        end

        io.write("\n")
        j = j - 1
    end
end
]]

-- 문자마름모 #1331

--[[
local n = io.read("*n")

local size = n * 2 - 1
local a = {}
local y = 1

while y <= size do
    a[y] = {}
    local i = 1

    while i <= size do
        a[y][i] = " "
        i = i + 1
    end

    y = y + 1
end

local layer = 1
local num = 65
local side = n

while layer <= n do
    local r = layer
    local c = n
    local d = 1

    while d <= 4 do
        local k = 1

        while k <= side - 1 do
            a[r][c] = string.char(num)

            num = num + 1

            if num > 90 then
                num = 65
            end

            if d == 1 then
                c = c - 1
                r = r + 1
            elseif d == 2 then
                c = c + 1
                r = r + 1
            elseif d == 3 then
                c = c + 1
                r = r - 1
            else
                c = c - 1
                r = r - 1
            end

            k = k + 1
        end

        d = d + 1
    end

    side = side - 1
    layer = layer + 1
end

a[n][n] = string.char(num)

local left = n
local right = n
y = 1

while y <= size do
    local i = 1

    while i <= left - 1 do
        io.write(" ")
        i = i + 1
    end

    i = left

    while i <= right do
        io.write(a[y][i].." ")
        i = i + 1
    end

    io.write("\n")

    if y < n then
        left = left - 1
        right = right + 1
    else
        left = left + 1
        right = right - 1
    end

    y = y + 1
end
]]

-- 대각선 지그재그 #1495

--[[
local n = io.read("*n")

local a = {}
local y = 1

while y <= n do
    a[y] = {}
    y = y + 1
end

local num = 1
local s = 2

while s <= n * 2 do
    local r1 = s - n

    if r1 < 1 then
        r1 = 1
    end

    local r2 = s - 1

    if r2 > n then
        r2 = n
    end

    if s % 2 == 0 then
        local r = r1

        while r <= r2 do
            local c = s - r
            a[r][c] = num
            num = num + 1
            r = r + 1
        end
    else
        local r = r2

        while r >= r1 do
            local c = s - r
            a[r][c] = num
            num = num + 1
            r = r - 1
        end
    end

    s = s + 1
end

y = 1

while y <= n do
    local i = 1

    while i <= n do
        io.write(a[y][i].." ")
        i = i + 1
    end

    io.write("\n")
    y = y + 1
end
]]

-- 홀수 마방진 #2074

--[[
local n = io.read("*n")

local a = {}
local y = 1

while y <= n do
    a[y] = {}
    local i = 1

    while i <= n do
        a[y][i] = 0
        i = i + 1
    end

    y = y + 1
end

local r = 1
local c = math.floor(n / 2) + 1
local num = 1

while num <= n * n do
    a[r][c] = num

    if num % n == 0 then
        r = r + 1
    else
        r = r - 1
        c = c - 1
    end

    if r < 1 then
        r = n
    end

    if r > n then
        r = 1
    end

    if c < 1 then
        c = n
    end

    if c > n then
        c = 1
    end

    num = num + 1
end

y = 1

while y <= n do
    local i = 1

    while i <= n do
        io.write(a[y][i].." ")
        i = i + 1
    end

    io.write("\n")
    y = y + 1
end
]]

print("한글")