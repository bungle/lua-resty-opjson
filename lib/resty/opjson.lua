local setmetatable = setmetatable
local require      = require
local ffi          = require "ffi"
local ffi_new      = ffi.new
local ffi_cdef     = ffi.cdef
local ffi_load     = ffi.load
local ffi_typeof   = ffi.typeof
local ffi_str      = ffi.string
local tonumber     = tonumber
local pcall        = pcall
local null         = ngx and ngx.null or {}
ffi_cdef[[
struct json_token {
    const unsigned char *str;
    unsigned long len;
    unsigned long children;
};
struct json_iter {
    int depth;
    int err;
    const void **go;
    const unsigned char *src;
    unsigned long len;
};
void json_read(struct json_token*, struct json_iter*);
void json_num(double *, const struct json_token*);
]]
local ok, newtab = pcall(require, "table.new")
if not ok then newtab = function() return {} end end
local lib = ffi_load("libopjson")
local arr = { __index = { __jsontype = "array"  }}
local obj = { __index = { __jsontype = "object" }}
local itr = ffi_typeof("struct json_iter")
local key = ffi_new("struct json_token")
local val = ffi_new("struct json_token")
local num = ffi_new("double[1]")
local function value(v)
    if v.str[0] == 123 then
        local i = ffi_new(itr)
        local l = tonumber(v.children)
        local o = newtab(0, l)
        i.src = v.str
        i.len = v.len
        for j = 1, l do
            lib.json_read(key, i)
            lib.json_read(val, i)
            o[ffi_str(key.str + 1, key.len - 2)] = value(val)
        end
        return setmetatable(o, obj)
    end
    if v.str[0] == 91 then
        local i = ffi_new(itr)
        local l = tonumber(v.children)
        local a = newtab(l, 0)
        i.src = v.str
        i.len = v.len
        for j = 1, l do
            lib.json_read(val, i)
            a[j] = value(val)
        end
        return setmetatable(a, arr)
    end
    if v.str[0] == 34  then return ffi_str(v.str + 1, v.len - 2) end
    if v.str[0] == 116 then return true  end
    if v.str[0] == 102 then return false end
    if v.str[0] == 110 then return null  end
    lib.json_num(num, v)
    return num[0]
end
return function(j, l)
    local i = ffi_new(itr)
    i.src = j
    i.len = l or #j
    lib.json_read(key, i)
    lib.json_read(val, i)
    local o = {}
    while i.err == 0 do
        o[ffi_str(key.str + 1, key.len - 2)] = value(val)
        lib.json_read(key, i)
        lib.json_read(val, i)
    end
    return setmetatable(o, obj)
end