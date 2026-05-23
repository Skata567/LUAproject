-- 문자열 리터럴 3가지
local s1 = "hello"           -- 큰따옴표
local s2 = 'hello'           -- 작은따옴표 (완전히 동일)
local s3 = [=['
여러 줄
문자열
]]
'
]=]                           -- 긴 괄호 (raw string)

-- 이스케이프 시퀀스 (C와 동일)
local s4 = "line1\nline2"    -- 줄바꿈
local s5 = "tab\there"       -- 탭
local s6 = "quote: \""       -- 따옴표

-- 긴 괄호는 이스케이프 불필요
local shader = [[
    vec4 color = vec4(1.0, 0.0, 0.0, 1.0);
    // 따옴표나 역슬래시를 자유롭게 쓸 수 있다
]]


print(s3)