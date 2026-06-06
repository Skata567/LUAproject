--[[숫자의 개수]]

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






















--[[최대공약수, 최소공배수[]]
--[[
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


--[[최대공약수, 최소공배수]]
--[[
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



--[[ 각 자리수와 역과합 ]]
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



--[[ 소수와 합성수]]
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


--[[소수]]
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