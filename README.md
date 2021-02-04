# hotfix-gen

Hotfix code generator for Lua.

[![build](https://img.shields.io/github/workflow/status/luyuhuang/hotfix-gen/Build)](https://github.com/luyuhuang/hotfix-gen/actions)
[![codecov](https://img.shields.io/codecov/c/github/luyuhuang/hotfix-gen)](https://codecov.io/gh/luyuhuang/hotfix-gen)

## Installation

```bash
luacov install hotfix-gen
```

## Usage

Hotfix-gen extracts functions and their all dependencies from a Lua module. Ideally, executing these extracted codes when the program is running will hotfix these functions.

```bash
$ cat module.lua
local app = require("app")
local export = {}
local t = {1, 2, 3}

local function bar()
    print("hello")
end

function export.foo()
    app.run(bar)
end

return export

$ hotfix module export.foo
local app = require("app")

local export = require("module")
local function bar()
    print("hello")
end

function export.foo()
    app.run(bar)
end
```
