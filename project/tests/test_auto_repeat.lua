local function run_test()
    print("Running auto repeat test...")
    -- We can't easily require "main" without love2d, so we run this inside lovec.
    -- But since this is a test script, we just need to ensure lovec runs main.lua.
    
    -- Actually, if we launch lovec with a special argument, we can have main.lua auto-test itself.
    -- Or we can just use `lovec .` and if there's no error in the first 1 second, it's fine.
    -- Better yet, let's create a standalone lua script that uses `pcall`.
end
return { run_test = run_test }
