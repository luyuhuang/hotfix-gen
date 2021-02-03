local parser = require("lua-parser.parser")

local function compare_name(index, name)
    local k = name:find("[%.:][^%.:]+$")
    if k then
        return index.tag == "Index"
           and (name:sub(k, k) == ":") == (index.is_method == true)
           and index[2].tag == "String"
           and index[2][1] == name:sub(k+1)
           and compare_name(index[1], name:sub(1, k-1))
    else
        if index.tag == "Index" then
            return index[2].tag == "String" and index[2][1] == name
        elseif index.tag == "Id" then
            return index[1] == name
        end
        return false
    end
end

local function compare_names(index, names)
    for _, name in ipairs(names) do
        if compare_name(index, name) then return true end
    end
    return false
end

local function get_path(index, ans)
    if index.tag == "Index" and index[2].tag == "String" then
        table.insert(ans, 1, index[2][1])
        if index.is_method then
            ans.is_method = true
        end
        ans = get_path(index[1], ans)
    elseif index.tag == "Id" then
        table.insert(ans, 1, index[1])
    else
        ans = nil
    end

    return ans
end

local function walk(up, localvals, node, ans)
    if type(node) ~= "table" then return ans end

    local tag = node.tag
    if tag == "Local" then
        local names, exps = table.unpack(node)
        walk(up, localvals, exps, ans)

        for _, name in ipairs(names) do
            localvals[name[1]] = true
        end

    elseif tag == "Localrec" then
        local left, right = table.unpack(node)
        local name, func = left[1], right[1]
        localvals[name[1]] = true
        walk(up, localvals, func, ans)

    elseif tag == "Forin" then
        local names, exps, block = table.unpack(node)
        walk(up, localvals, exps, ans)

        local newlocal = setmetatable({}, {__index = localvals})
        for _, name in ipairs(names) do
            newlocal[name[1]] = true
        end
        walk(up, newlocal, block, ans)

    elseif tag == "Fornum" then
        local name, start, stop = table.unpack(node, 1, 3)
        local step, block
        if #node == 4 then
            block = node[4]
        else
            step, block = table.unpack(node, 4, 5)
        end
        walk(up, localvals, start, ans)
        walk(up, localvals, stop, ans)
        walk(up, localvals, step, ans)

        local newlocal = setmetatable({}, {__index = localvals})
        newlocal[name[1]] = true
        walk(up, newlocal, block, ans)

    elseif tag == "Function" then
        local args, block = table.unpack(node)
        local newlocal = setmetatable({}, {__index = localvals})
        for _, arg in ipairs(args) do
            if arg.tag == "Id" then
                newlocal[arg[1]] = true
            end
        end
        walk(up, newlocal, block, ans)

    elseif tag == "Id" then
        local id = node[1]
        if not localvals[id] and up[id] then
            ans[up[id]] = true
        end

    elseif tag == "Block" then
        local newlocal = setmetatable({}, {__index = localvals})
        for _, statement in ipairs(node) do
            walk(up, newlocal, statement, ans)
        end

    else
        for _, statement in ipairs(node) do
            walk(up, localvals, statement, ans)
        end

    end

    return ans
end

local is_expr = {
    Nil = 1, Dots = 1, Boolean = 1, Number = 1, String = 1,
    Function = 1, Table = 1, Pair = 1, Op = 1, Paren = 1,
    Call = 1, Invoke = 1, Id = 1, Index = 1,
}

local function dependences(up, expr, ans)
    if type(expr) ~= "table" then return ans end
    assert(is_expr[expr.tag], expr.tag)

    if expr.tag == "Id" then
        local id = expr[1]
        if up[id] then
            ans[up[id]] = true
        end
    elseif expr.tag == "Function" then
        walk(up, {}, expr, ans)
    else
        for _, e in ipairs(expr) do
            dependences(up, e, ans)
        end
    end

    return ans
end

local function get_requires(list, i, ans)
    ans[#ans+1] = i
    for j in pairs(list[i].deps) do
        get_requires(list, j, ans)
    end
end

local function pick(statements, names)
    local n2i = {}
    local list = {}
    local funcs = {}
    local returns = {}

    for _, statement in ipairs(statements) do
        if statement.tag == "Local" then
            local left, right = table.unpack(statement)
            for i, id in ipairs(left) do
                local exp = right[i]
                list[#list+1] = {
                    type = "local",
                    name = id[1],
                    deps = dependences(n2i, right[i], {}),
                    exp = exp,
                }
                n2i[id[1]] = #list
            end

        elseif statement.tag == "Localrec" then
            local left, right = table.unpack(statement)
            local id, exp = left[1], right[1]
            list[#list+1] = {
                type = "lfunc",
                name = id[1],
                deps = dependences(n2i, exp, {}),
                pos = statement.pos,
                to = statement.to
            }
            n2i[id[1]] = #list

        elseif statement.tag == "Return" then
            for _, exp in ipairs(statement) do
                if exp.tag == "Id" and n2i[exp[1]] then
                    returns[n2i[exp[1]]] = true
                end
            end

        elseif statement.tag == "Set" then
            local left, right = table.unpack(statement)
            local n = math.min(#left, #right)
            for j = 1, n do
                local tar, exp = left[j], right[j]
                if compare_names(tar, names) and exp.tag == "Function" then
                    local p = get_path(tar, {})
                    if p then
                        local f = {
                            deps = dependences(n2i, exp, {}),
                            type = "func",
                            path = p,
                            pos = exp.pos,
                            to = exp.to,
                        }

                        if n2i[p[1]] then
                            f.deps[n2i[p[1]]] = true
                        end

                        list[#list+1] = f
                        funcs[#funcs+1] = #list
                    end
                end
            end
        end
    end

    local requries = {}
    for _, i in ipairs(funcs) do
        get_requires(list, i, requries)
    end
    table.sort(requries)

    local last
    local ans = {}
    for _, i in ipairs(requries) do
        if i ~= last then
            local s = list[i]
            if returns[i] then
                s.type = "require"
            end
            ans[#ans+1] = s

            last = i
        end
    end

    return ans
end

local unaryop = {
    ["not"] = "not ",
    ["unm"] = "-",
    ["len"] = "#",
    ["bnot"] = "~",
}

local function assemble(module, code, statements)
    local ans = ""
    for _, st in ipairs(statements) do
        local type = st.type
        local s
        if type == "require" then
            s = ("local %s = require(%q)\n"):format(st.name, module)

        elseif type == "local" then
            if not st.exp then
                s = ("local %s\n"):format(st.name)
            else
                local e = code:sub(st.exp.pos, st.exp.to)
                if st.exp.tag == "Function" then
                    e = "function" .. e
                elseif st.exp.tag == "Op" and #st.exp == 2 then
                    e = unaryop[st.exp[1]] .. e
                end

                s = ("local %s = %s\n"):format(st.name, e)
            end

        elseif type == "lfunc" then
            s = "local " .. code:sub(st.pos, st.to)

        elseif type == "func" then
            local name = table.concat(st.path, '.', 1, #st.path-1)
            local sep = ""
            if name ~= "" then
                sep = st.path.is_method and ':' or '.'
            end
            name = name .. sep .. st.path[#st.path]
            s = "function " .. name .. code:sub(st.pos, st.to)

        end

        ans = ans .. s
    end

    return ans
end

local export = {}

function export.make(module, code, funcs)
    local ast, msg = parser.parse(code, module)
    if not ast then
        error(msg)
    end
    assert(ast.tag == "Block")

    return assemble(module, code, pick(ast, funcs))
end

function export.gen(module, funcs)
    local filename = module:gsub("%.", package.config:sub(1, 1)) .. ".lua"
    local f = io.open(filename)
    assert(f, ("load module '%s' failed\n"):format(module))
    local code = f:read('a')
    f:close()

    return export.make(module, code, funcs)
end

return export
