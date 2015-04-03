local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local tconcat = table.concat
local sformat = string.format
local smatch  = string.match

local function _new_env(userenv)
    local CfgEnv = {}

    for k,v in pairs(_G) do
        CfgEnv[k] = v
    end
    for k,v in pairs(userenv) do
        CfgEnv[k] = v
    end

    local _PATH = {}

    local function dummy_template()
        return true
    end

    local function _LITERAL(template)
        return function (cfg)
            return template == cfg, "wrong value"
        end
    end

    -- declare local before
    local function _check(template, v, path)
        local f
        if type(template) == "table" then
            f = CfgEnv.STRUCT(template)
        elseif type(template) == "function" then
            f = template
        else
            f = _LITERAL(template)
        end

        tinsert(_PATH, path)

        local ok,err = f(v)

        if ok and path then
            tremove(_PATH)
        end

        return ok, err
    end

    function CfgEnv.ANY() 
        return true
    end

    function CfgEnv.NIL(v)
        return type(v) == "nil", "not nil"
    end

    function CfgEnv.BOOL(v)
        return type(v) == "boolean", "not boolean"
    end

    function CfgEnv.NUM(v)
        return type(v) == "number", "not number"
    end

    function CfgEnv.STRING(v)
        return type(v) == "string", "not string"
    end

    function CfgEnv.PATTERN(pat)
        return function (v)
            if type(v) ~= "string" then
                return false, "not string"
            end

            if not smatch(v, pat) then
                return false, sformat("'%s' not match pattern '%s'", v, pat)
            end
            return true
        end
    end

    function CfgEnv.RANGE(min, max) 
        local max = max or math.huge
        local min = min or -math.huge
        return function (v)
            if type(v) ~= "number" then
                return false, "not number"
            end

            if v > max or v < min then
                return false, "not in range"
            end

            return true
        end
    end

    function CfgEnv.LIST(...)
        local temps = {...}
        assert(next(temps))
        return function (v)
            if type(v) ~= "table" then
                return false, "wrong type"
            end

            for i,temp in ipairs(temps) do
                if not _check(temp, v[i], i) then
                    return false,"wrong list element"
                end
            end

            for i=#temps+1, #v do
                if not _check(temps[#temps], v[i], i) then
                    return false,"wrong list element"
                end
            end

            return true
        end
    end

    function CfgEnv.TABLE(ktemp, vtemp)
        ktemp = ktemp or dummy_template
        vtemp = vtemp or dummy_template
        return function (value)
            if type(value) ~= "table" then
                return false, "wrong type"
            end
            for k,v in pairs(value) do
                local ok,err = _check(ktemp, k, tostring(k))
                if not ok then
                    return false, "wrong table key"
                end
                ok,err = _check(vtemp, v, tostring(k))
                if not ok then
                    return false, "wrong table value"
                end
            end

            return true
        end
    end

    -- this syntax can be simplified ,like:
    --   STRUCT{foo = bar} as {foo = bar}
    function CfgEnv.STRUCT(template)
        return function (cfg)
            if type(cfg) ~= "table" then
                return false, "not table"
            end

            for k,v in pairs(template) do
                local ok,err = _check(v, cfg[k], tostring(k))
                if not ok then
                    return false, err
                end
            end
            return true
        end
    end

    function CfgEnv.OR(...)
        local templates = {...}
        return function (value)
            local path = _PATH
            local curpath_sz = #path
            local ok,err
            for _,temp in ipairs(templates) do
                for j=curpath_sz+1,#path do path[j] = nil end
                ok,err = _check(temp, value)
                if ok then
                    return true
                end
            end

            return false,err
        end
    end

    return CfgEnv, function (template, cfg)
        _PATH = {}
        local ok, err = _check(template, cfg)
        return ok, err, _PATH
                   end
end

local mt = {}
mt.__index = mt

function mt:check(cfg, template)
    template = template or self.template
    local ok,err, path = self.begin_check(template, cfg)
    if not ok then
        err = sformat("%s: %s", tconcat(path, "."), err)
    end
    return ok, err
end

function mt:get_template()
    return self.template
end

local M = {}
function M.new(template_func, userenv)
    local self = {}

    assert(type(template_func) == "function")
    self.env, self.begin_check = _new_env(userenv or {})
    self.template = template_func(self.env)

    return setmetatable(self, mt)
end

function M.load_chunk(chunk)
    local reader = coroutine.wrap(function ()
            coroutine.yield("return function (_ENV)\n")
            coroutine.yield(chunk)
            coroutine.yield("\nend\n")
    end)
    return load(reader,path)()
end

return M
