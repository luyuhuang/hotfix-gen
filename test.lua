local hotfix = require("init")

local res = hotfix.make("test", [[
local a = 1
local M = {}

function M.foo()
    print(a)
end

return M
]], {"foo"})

assert(load(res) ~= nil)

local a = res:find('local a = 1', 1, true)
local M = res:find('local M = require("test")', a, true)
local foo = res:find('function M.foo', M, true)
assert(a and M and foo)


local res = hotfix.make("test", [[
function foo()
end

function M1.foo()
end

function M2.foo()
end
]], {"M1.foo", "M2.foo"})

assert(load(res) ~= nil)

local foo = res:find('function foo()', 1, true)
local M1 = res:find('function M1.foo()', 1, true)
local M2 = res:find('function M1.foo()', M1, true)

assert(not foo and M1 and M2)


local res = hotfix.make("test", [[
function M:foo()
end
function M.bar()
end
]], {"M:foo"})

assert(load(res) ~= nil)

local foo = res:find('function M:foo()', 1, true)

assert(foo)


local res = hotfix.make("test", [[
local app = require("app")
function app.foo()
    app.bar()
end
]], {"foo"})

assert(load(res) ~= nil)

local app = res:find('local app = require("app")', 1, true)
local foo = res:find('function app.foo()', app, true)

assert(app and foo)


local res = hotfix.make("test", [[
local function foo()
    foo()
end

local bar = 1

function M.baz()
    local bar = 2
    foo(bar)
end
]], {"baz"})

assert(load(res) ~= nil)

local foo = res:find('local function foo()', 1, true)
local bar = res:find('local bar = 1', 1, true)
local baz = res:find('function M.baz()', foo, true)

assert(foo and not bar and baz)


local res = hotfix.make("test", [[
local function foo()
    foo()
end

local bar = 1

function M.baz()
    local function bar()
        print(bar)
    end
    foo(bar)
    bar()
end
]], {"baz"})

assert(load(res) ~= nil)

local foo = res:find('local function foo()', 1, true)
local bar = res:find('local bar = 1', 1, true)
local baz = res:find('function M.baz()', foo, true)

assert(foo and not bar and baz)


local res = hotfix.make("test", [[
local function foo()
    foo()
end

local bar = 1

function M.baz()
    local bar = function()
        print(bar)
    end
    foo(bar)
    bar()
end
]], {"baz"})

assert(load(res) ~= nil)

local foo = res:find('local function foo()', 1, true)
local bar = res:find('local bar = 1', foo, true)
local baz = res:find('function M.baz()', foo, true)

assert(foo and bar and baz)

local res = hotfix.make("test", [[
local i = 1
function M.foo()
    for i = 1, 10 do
        print(i)
    end
end
]], {"foo"})

assert(load(res) ~= nil)

local i = res:find('local i = 1', 1, true)
local foo = res:find('function M.foo()', 1, true)

assert(not i and foo)


local res = hotfix.make("test", [[
local i = 1
function M.foo()
    for i = 10, 1, -1 do
        print(i)
    end
end
]], {"foo"})

assert(load(res) ~= nil)

local i = res:find('local i = 1', 1, true)
local foo = res:find('function M.foo()', 1, true)

assert(not i and foo)


local res = hotfix.make("test", [[
local i = 1
function M.foo()
    for i = 10, 1, -1 do
    end
    print(i)
end
]], {"foo"})

assert(load(res) ~= nil)

local i = res:find('local i = 1', 1, true)
local foo = res:find('function M.foo()', i, true)

assert(i and foo)


local res = hotfix.make("test", [[
local i = 1
function M.foo()
    for i = 10, i, -1 do
    end
end
]], {"foo"})

assert(load(res) ~= nil)

local i = res:find('local i = 1', 1, true)
local foo = res:find('function M.foo()', i, true)

assert(i and not j and foo)


local res = hotfix.make("test", [[
local a = {1,2,3}
local i = 1
function M.foo()
    for i, v in ipairs(a) do
        print(i, v)
    end
end
]], {"foo"})

assert(load(res) ~= nil)

local a = res:find('local a = {1,2,3}', 1, true)
local i = res:find('local i = 1', 1, true)
local foo = res:find('function M.foo()', a, true)

assert(a and not i and foo)


local res = hotfix.make("test", [[
local a, b = 1
function M.foo()
    if b then
        local a
        print(a)
    end
end
]], {"foo"})

local a = res:find('local a = 1', 1, true)
local b = res:find('local b', 1, true)
local foo = res:find('function M.foo()', a, true)

assert(not a and b and foo)


local res = hotfix.make("test", [[
local a, b = -1
function M.foo()
    if b then
        local a
    end
    print(a)
end
]], {"foo"})

local a = res:find('local a = -1', 1, true)
local b = res:find('local b', a, true)
local foo = res:find('function M.foo()', b, true)

assert(a and b and foo)


local res = hotfix.make("test", [[
local a, b
local t = {a = a, b = b}

local foo = function()
    return t
end

local function bar()
    return foo()
end

function M.baz()
    bar()
    print(a, b)
end
]], {"baz"})

local a = res:find('local a', 1, true)
local b = res:find('local b', a, true)
local t = res:find('local t = {a = a, b = b}', b, true)
local foo = res:find('local foo = function()', t, true)
local bar = res:find('local function bar()', foo, true)
local baz = res:find('function M.baz()', bar, true)

assert(a and b and foo and bar and baz)

print("passed")
