
--[[
local A, B = io.read("*n", "*n")

if A > B then
    for a = A, B, -1 do
        for i = 1, 9 do
            print(a .. " * " .. i .. " = " .. (a * i))
        end

        if a > B then
            print()
        end
    end

elseif A < B then
    for a = A, B do
        for i = 1, 9 do
            print(a .. " * " .. i .. " = " .. (a * i))
        end

        if a < B then
            print()
        end
    end

else
    for i = 1, 9 do
        print(A .. " * " .. i .. " = " .. (A * i))
    end
end
]]

--[[
while true do
    

local A, B = io.read("*n", "*n")

    if A >= 10 or B >= 10 then
        print("INPUT ERROR!")
    else
        if A > B then
            for a = A, B, -1 do
                for i = 1, 9 do
                    print(a .. " * " .. i .. " = " .. (a * i))
                end

                if a > B then
                    print()
                end
            end

            elseif A < B then
                for a = A, B do
                    for i = 1, 9 do
                        print(a .. " * " .. i .. " = " .. (a * i))
                    end
                if a < B then
                    print()
                end
            end
        end
    end
end

]]

--[[
local A, B = io.read("*n", "*n")

if A >= 10 or B >= 10 then
else
    if A > B then
        for a = A, B, -1 do
            for i = 1, 9 do
                io.write(a .. " * " .. i .. " = " .. (a * i))

                if i % 3 == 0 then
                    io.write("\n")
                else
                    io.write("\t")
                end
            end
            print()
        end
    else
        for a = A, B do
            for i = 1, 9 do
                io.write(a .. " * " .. i .. " = " .. (a * i))

                if i % 3 == 0 then
                    io.write("\n")
                else
                    io.write("\t")
                end
            end
            print()
        end
    end
end
]]

--[[
while true do

local A, B = io.read("*n", "*n")

if A >= 10 or B >= 10 then
    print("INPUT ERROR!")
else
    if A > B then
        for a = A, B, -1 do
            for i = 1, 9 do
                io.write(a .. " * " .. i .. " = " .. (a * i))

                if i % 3 == 0 then
                    io.write("\n")
                else
                    io.write("\t")
                end
            end
            print()
        end
    else
        for a = A, B do
            for i = 1, 9 do
                io.write(a .. " * " .. i .. " = " .. (a * i))

                if i % 3 == 0 then
                    io.write("\n")
                else
                    io.write("\t")
                end
            end
            print()
        end
    end
end
end

]]

--[[
local a = io.read("*n")
local b = io.read("*n")

local c
local d 
local e

local hap

c = (b % 10) * (a)
d = math.floor(b / 10)%10 * (a)
e = math.floor(b / 100) * (a)

hap = c+(d*10)+(e*100)

print(c)
print(d)
print(e)
print(hap)
]]


--[[
local count = {}

for i = 0, 9 do
    count[i] = 0
end

local a = io.read("*n")
local b = io.read("*n")
local c = io.read("*n")

local hap = a * b * c

local s = tostring(hap)

for i= 1,#s do
    local ch = string.sub(s,i,i)
    local num = tonumber(ch)

    count[num] = count[num] + 1
end
for i = 0, 9 do
    print(count[i])
end

]]

--[[
local a = io.read("*n")
local arr = {}

local divisorSum = 0
local multipleSum = 0


if a <= 40 and a >= 1  then
 
    for i = 1, a do
        arr[i] = io.read("*n")
    end
else
    print("범위 초과")
end

local sum = io.read("*n")

if sum <= 100 and sum >= 1 then
   for i = 1, a do
        local num = arr[i]
        if sum % num == 0 then
            divisorSum = divisorSum + num
        end
        if num % sum == 0 then
            multipleSum = multipleSum + num
        end 
    end
    print(divisorSum)
    print(multipleSum)
else
    print("범위 초과")
end
]]

--[[
local count = 0 -- 약수 갯수
local ansawy = 0 -- K 번째 약수 저장

local N, K = io.read("*n", "*n")

for i = 1, N do
    if(N % i == 0)then
        count = count + 1
        if(count == K)then
            ansawy = i
        end
    
    end 
end
print(ansawy)   

]]

--[[
local N = io.read("*n")

if (N >=2 and  N <= 2100000000)then
    for i = 1, N do
        if(N%i == 0)then
            io.write(i)
            io.write("\t")
        end
    end
else
    print("범위 초과")
end
]]

--[[
local A,B = io.read("*n","*n")

if(A <= 10000 and B <= 10000)then
    function GCD(A,B)
        while B ~= 0 do
        local r = A%B
        A = B
        B = r
        end
        return A
    end
    local g = GCD(A, B)
    local l = A / g * B

    print(g)
    print(l)
else
    print("범위초과")
end
]]

--[[
function GCD(a,b)
    while b ~= 0 do
        local r = a%b
        a = b
        b = r
    end
    return a
end

function LCM(a,b)
    return a * b / GCD(a, b)
end

local N = io.read("*n")
local g = io.read("*n")
local l = g


for i = 2, N do 
    local num = io.read("*n")

    g = GCD(g, num)
    l = LCM(l, num)
end
print (g .. " " .. l)
]]

--[[
local P,V,K = io.read("*n","*n","*n")

local a,b,c,d = 0,0,0,0


for i = 1, K do

    local paintFail = i % (P + 1) == 0
    local glossFail = i % (V + 1) == 0

    if not paintFail and not glossFail then
        a = a + 1
    elseif paintFail and glossFail then
        b = b + 1
    elseif not paintFail and glossFail then
        c = c + 1
    elseif paintFail and not glossFail then
        d = d + 1
    end
end

io.write(a.." "..b.." "..c.." "..d)
]]


--[[
while true do
    local a = io.read("*n")
    
    if( a == 0)then
        break
    end

    local b = tostring(a)
    local reverse = string.reverse(b)
    local sum = 0
    
    for i = 1, #b do
   
        local digit = string.sub(b,i,i)
        sum = sum + tonumber(digit) --tonumber = 문자열을 숫자로 다시 바꿔주는 함수
    end

    print(tonumber(reverse), sum)
end

]]


--[[
isPrime = true

for t = 1, 5 do
    local n = io.read("*n")
    
    if(n == 1 )then
        print("number one")
    else
        for i = 2, math.floor(math.sqrt(n)) do
            if(n%i == 0)then
            isPrime = false
            end
        end

        if(isPrime == false)then
        print("prime number")
        else
        print("composite number")
        end
    end

    isPrime = true
end
]]

--[[
local function isPrime(x)
    if x < 2 then
        return false
    end

    for i = 2, math.floor(math.sqrt(x)) do
        if x % i == 0 then
            return false
        end
    end

    return true
end

local N = io.read("*n")

for t = 1, N do
    local M = io.read("*n")
    local distance = 0

    while true do
        local left = M - distance
        local right = M + distance

        local leftPrime = false
        local rightPrime = false

        if left >= 1 and left <= 1000000 then
            leftPrime = isPrime(left)
        end

        if right >= 1 and right <= 1000000 then
            rightPrime = isPrime(right)
        end

        if distance == 0 and leftPrime then
            print(left)
            break
        elseif leftPrime and rightPrime then
            print(left .. " " .. right)
            break
        elseif leftPrime then
            print(left)
            break
        elseif rightPrime then
            print(right)
            break
        end

        distance = distance + 1
    end
end
]]

--[[
local function isPrime(x)
    if x < 2 then
        return false
    end

    for i = 2, math.floor(math.sqrt(x)) do
        if x % i == 0 then
            return false
        end
    end

    return true
end

local M = io.read("*n")
local N = io.read("*n")

local sum = 0
local minPrime = nil

for num = M, N do
    if isPrime(num) then
        sum = sum + num

        if minPrime == nil then
            minPrime = num
        end
    end
end

if minPrime == nil then
    print(-1)
else
    print(sum)
    print(minPrime)
end

]]


--[[구구단
function _12338(a, b)
if(a > b) then
    for j = a, b, -1 do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
else 
    for j = a, b do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
end
end
do
    _12338(6, 3)
end
--]]

--[[구구단 2
function _12422(a, b)
    if a < 2 or b < 2 or a > 9 or b > 9 then
        print('error')
        return
    end
    if(a > b) then
    for j = a, b, -1 do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
else 
    for j = a, b do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
end
end
do
    _12422(2, 3)
end
--]]

--[[구구단 3

function _12338(a, b)
if(a > b) then
    for j = a, b, -1 do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
else 
    for j = a, b do
        for i = 1, 9 do
            print(j, '*', i, '=', j * i)
        end
        print()
    end
end
end
do
    _12338(6, 3)
end

--]]

--[[구구단 4
function _1291(s, e)
    if s < 2 or s > 9 or e < 2 or e > 9 then
        print("INPUT ERROR!")
        return
    end

    local step = (s <= e) and 1 or -1

    for i = 1, 9 do
        local first = true

        for dan = s, e, step do
            if not first then
                io.write("   ") 
            end

            io.write(string.format("%d * %d = %2d", dan, i, dan * i))
            first = false
        end

        print()
    end
end

do
    _1291(3, 4)
end
--]]

--[[숫자 곱셈
function _1692(a, b)
    local h = math.floor(b / 100)      
    local t = math.floor(b / 10) % 10  
    local o = b % 10
    print(a*o)
    print(a*t)
    print(a*h)
    print(a*b)
end

do
    _1692(472, 432)
end
--]]

--[[숫자의 개수
function _1430(a, b, c)
    local s = a * b * c
    local d = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
    print(s)
    while s > 0 do
        local r = s % 10
        d[r] = d[r] + 1
        s = math.floor(s / 10)
    end
    for i = 1, 9 do
        print(d[i])
    end
end
do
    _1430(123, 456, 789)
end
--]]

--[[약수와 배수
function _1071(a)
    local y = {}
    local x = {}
    local t = 1
    local s = 4       
    local yaksuSum = 0
    local baesuSum = 0
    for i = 1, #a do
        if(s % a[i] == 0) then
            print(s, '약수', a[i])
            y[t] = a[i]
            t = t + 1
        end
    end
    t = 1
    for i = 1, #a do
        if(a[i] % s == 0) then
            print(s, '배수', a[i])
            x[t] = a[i]
            t = t + 1
        end
    end
    for i = 1, #y do
         yaksuSum = yaksuSum + y[i]
    end
    print(yaksuSum)
    for i = 1, #x do
        baesuSum = baesuSum + x[i]
    end
    print(baesuSum)
end
do
    a = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    _1071(a)
end
--]]

--[[약수 구하기

function _1402(a, b)
    local yaksu = {}
    local t = 1
    for i = 1, a do
        if(a % i == 0) then
             yaksu[t] = i
             t = t + 1
        end
    end
    if(t < b) then
        print('0')
    
    else
        print(yaksu[b])
    end
end

do
    _1402(12, 3)
end

--]]

--[[약수

function _2809(a)
    local yaksu = {}
    local t = 1
    for i = 1, a do
        if(a % i == 0) then
             yaksu[t] = i
             t = t + 1
        end
    end
    for i = 1, #yaksu do
        print(yaksu[i])
    end
end
do
    _2809(24)
end

--]]

--[[최대공약수, 최소공배수

function _1658(a , b)
    local bestYaksu = 0
    local lessBaesu = 0

    for i = 1, a do
        if(a % i == 0 and b % i == 0) then
             bestYaksu = i
        end
    end
    lessBaesu = a * b / bestYaksu
    print(bestYaksu)
    print(lessBaesu)
end
do 
    _1658(24, 18)
end
--]]

--[[최대공약수, 최소공배수
function gcd_get(gcd, n)
    local bestYaksu = 0
    for i = 1, n do
        if(gcd % i == 0 and n % i == 0) then
            bestYaksu = i
        end
    end
    return bestYaksu
end

function _1002(a)
    local bestYaksu = 0
    local lessBaesu = 2
    for i=1, #a do
        local gcd_value = gcd_get(bestYaksu, a[i])
        bestYaksu = gcd_value
        lessBaesu = lessBaesu * a[i] / bestYaksu
    end
    print(bestYaksu)
    print(lessBaesu)
end

do
    a = {2, 8, 10}
    _1002(a)
end

--]]

--[[연필공장

function _5545(a)
    local k = a[1]
    local v = a[2]
    local m = a[3]
    local dosaek = 0
    local guangTaek = 0
    local dosaekguangTaek = 0
    k = k +1
    v = v +1
    
    for i = 1, m do
        if(i % k == 0) then
            dosaek = dosaek + 1
        end
        if(i % v == 0) then
            guangTaek = guangTaek + 1
        end
    end

    for i = 1, m do
        if(i % k == 0 and i % v == 0) then
            dosaekguangTaek = dosaekguangTaek + 1
        end
    end
    local success = m - dosaek - guangTaek + dosaekguangTaek
    local dosaekfail = dosaek - dosaekguangTaek
    local guangTaekfail = guangTaek - dosaekguangTaek
    print(success)
    print(dosaekguangTaek)
    print(guangTaekfail)
    print(dosaekfail)
    
end

do
    local a = {3, 5, 17}
    _5545(a)
end

--]]
---------------------------------------------------------------------------------------------------------

--[[ 각 자리수와 역과합
while true do
    local a = io.read("*n")
    
    if( a == 0)then
        break
    end

    local b = tostring(a)
    local reverse = string.reverse(b)
    local sum = 0
    
    for i = 1, #b do
   
        local digit = string.sub(b,i,i)
        sum = sum + tonumber(digit) --tonumber = 문자열을 숫자로 다시 바꿔주는 함수
    end

    print(tonumber(reverse), sum)
end

]]


--[[ 소수와 합성수
isPrime = true

for t = 1, 5 do
    local n = io.read("*n")
    
    if(n == 1 )then
        print("number one")
    else
        for i = 2, math.floor(math.sqrt(n)) do
            if(n%i == 0)then
            isPrime = false
            end
        end

        if(isPrime == false)then
        print("prime number")
        else
        print("composite number")
        end
    end

    isPrime = true
end
]]

--[[ 소수 구하기
local function isPrime(x)
    if x < 2 then
        return false
    end

    for i = 2, math.floor(math.sqrt(x)) do
        if x % i == 0 then
            return false
        end
    end

    return true
end

local N = io.read("*n")

for t = 1, N do
    local M = io.read("*n")
    local distance = 0

    while true do
        local left = M - distance
        local right = M + distance

        local leftPrime = false
        local rightPrime = false

        if left >= 1 and left <= 1000000 then
            leftPrime = isPrime(left)
        end

        if right >= 1 and right <= 1000000 then
            rightPrime = isPrime(right)
        end

        if distance == 0 and leftPrime then
            print(left)
            break
        elseif leftPrime and rightPrime then
            print(left .. " " .. right)
            break
        elseif leftPrime then
            print(left)
            break
        elseif rightPrime then
            print(right)
            break
        end

        distance = distance + 1
    end
end
]]

--[[소수
local function isPrime(x)
    if x < 2 then
        return false
    end

    for i = 2, math.floor(math.sqrt(x)) do
        if x % i == 0 then
            return false
        end
    end

    return true
end

local M = io.read("*n")
local N = io.read("*n")

local sum = 0
local minPrime = nil

for num = M, N do
    if isPrime(num) then
        sum = sum + num

        if minPrime == nil then
            minPrime = num
        end
    end
end

if minPrime == nil then
    print(-1)
else
    print(sum)
    print(minPrime)
end

]]

--[[
local a, b = io.read("*n", "*n")
local cnt = 0
for i = a, b do
    local isPrime = true
    if i < 2 then
        isPrime = false
    else
        for j = 2, math.sqrt(i) do
            if i % j == 0 then
                isPrime = false
                break
            end
        end
    end
    if isPrime then
        cnt = cnt + 1
    end
end
print(cnt)
--]]

--[[
local binary = io.read("*n")
local result = 0
local power = 0
while binary > 0 do
    local digit = binary % 10
    result = result + digit * (2 ^ power)
    binary = math.floor(binary / 10)
    power = power + 1
end
print(result)
--]]

--[[
local num, base = io.read("*n", "*n")
local hexChars = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
local result = ""
while num > 0 do
    local remainder = num % base
    result = hexChars[remainder + 1] .. result
    num = math.floor(num / base)
end
print(result)
]]

--[[ 
local S, A, B = io.read("*s", "*n", "*n")
local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local decimal = 0
for i = 1, #S do
    local ch = S:sub(i, i)
    local value = digits:find(ch, 1, true) - 1
    decimal = decimal * A + value
end
if decimal == 0 then
    print("0")
else
    local result = ""
    while decimal > 0 do
        local r = decimal % B
        result = digits:sub(r + 1, r + 1) .. result
        decimal = math.floor(decimal / B)
    end
    print(result)
end
]]

--[[ 
local n = io.read("*n")
local intPart = math.floor(n)
local fracPart = n - intPart
local intBin = ""
if intPart == 0 then
    intBin = "0"
else
    while intPart > 0 do
        intBin = (intPart % 2) .. intBin
        intPart = math.floor(intPart / 2)
    end
end
local fracBin = ""
for i = 1, 4 do
    fracPart = fracPart * 2
    if fracPart >= 1 then
        fracBin = fracBin .. "1"
        fracPart = fracPart - 1
    else
        fracBin = fracBin .. "0"
    end
end
print(intBin .. "." .. fracBin)
]]
