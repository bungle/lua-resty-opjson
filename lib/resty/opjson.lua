local setmetatable = setmetatable
local ffi          = require "ffi"
local ffi_new      = ffi.new
local ffi_cdef     = ffi.cdef
local ffi_load     = ffi.load
local ffi_str      = ffi.string
local null         = {}
if ngx and ngx.null then
    null = ngx.null
end
ffi_cdef[[
typedef unsigned char json_char;
typedef unsigned long json_size;
typedef double json_number;
enum json_typ {
    JSON_NONE,
    JSON_OBJECT,
    JSON_ARRAY,
    JSON_NUMBER,
    JSON_STRING,
    JSON_TRUE,
    JSON_FALSE,
    JSON_NULL
};
typedef struct json_token {
    const json_char *str;
    json_size len;
    json_size sub;
    json_size children;
} json_pair[2];
struct json_iter {
    int depth;
    int err;
    const void **go;
    const json_char *src;
    json_size len;
};
struct json_iter json_begin(const json_char*, json_size);
struct json_iter json_read(struct json_token*, const struct json_iter*);
struct json_iter json_parse(json_pair, const struct json_iter*);
json_size json_cpy(json_char*, json_size, const struct json_token*);
enum json_typ json_type(const struct json_token*);
enum json_typ json_num(json_number *num, const struct json_token *tok);
void json_deq(struct json_token*);
]]
local lib = ffi_load("libopjson")
local ok, newtab = pcall(require, "table.new")
if not ok then newtab = function() return {} end end
local arr = { __index = { __jsontype = "array"  }}
local obj = { __index = { __jsontype = "object" }}
local num = ffi_new("json_number[1]")
local buf = ffi_new("json_char[256]")
local t,p = ffi_new("struct json_token"), ffi_new("json_pair")
local val = newtab(8, 0)
val[0] = function() return nil end
val[1] = function(v)
    local i, l = lib.json_begin(v.str, v.len), tonumber(v.children)
    local o = setmetatable(newtab(0, l), obj)
    for n = 1, l do
        i = lib.json_parse(p, i)
        o[val[4](p[0])] = val[tonumber(lib.json_type(p[1]))](p[1])
    end
    return o
end
val[2] = function(v)
    local i, l = lib.json_begin(v.str, v.len), tonumber(v.children)
    local a = setmetatable(newtab(l, 0), arr)
    for n = 1, l do
        i = lib.json_read(t, i)
        a[n] = val[tonumber(lib.json_type(t))](t)
    end
    return a
end
val[3] = function(v) lib.json_num(num, v); return tonumber(num[0]) end
val[4] = function(v) lib.json_deq(v); return ffi_str(buf, lib.json_cpy(buf, 256, v)) end
val[5] = function() return true  end
val[6] = function() return false end
val[7] = function() return null  end
return function(j, l)
    local i = lib.json_parse(p, lib.json_begin(j, l or #j))
    local o = {}
    while i.err == 0 do
        o[val[4](p[0])] = val[tonumber(lib.json_type(p[1]))](p[1])
        i = lib.json_parse(p, i)
    end
    return o
end