local setmetatable = setmetatable
local ffi          = require "ffi"
local ffi_new      = ffi.new
local ffi_cdef     = ffi.cdef
local ffi_load     = ffi.load
local ffi_str      = ffi.string
local sub          = string.sub
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
]]
local arr = { __index = { __jsontype = "array"  }}
local obj = { __index = { __jsontype = "object" }}
local lib = ffi_load("libopjson")
local n, b, t, p = ffi_new("json_number[1]"), ffi_new("json_char[256]"), ffi_new("struct json_token"), ffi_new("json_pair")
local ok, newtab = pcall(require, "table.new")
if not ok then newtab = function() return {} end  end
local json = newtab(0, 3)
function json.obj(i)
    local o = setmetatable({}, obj)
    i = lib.json_parse(p, i)
    while i.err == 0 do
        o[sub(ffi_str(b, lib.json_cpy(b, 256, p[0])), 2, -2)] = json.decode(p[1])
        i = lib.json_parse(p, i)
    end
    return o
end
function json.arr(i)
    local a = setmetatable({}, arr)
    local j = 1
    i = lib.json_read(t, i)
    while i.err == 0 do
        a[j] = json.decode(t)
        i = lib.json_read(t, i)
        j = j + 1
    end
    return a
end
function json.decode(v)
    local z = tonumber(lib.json_type(v))
    if z == 1 then return json.obj(lib.json_begin(v.str, v.len))            end
    if z == 2 then return json.arr(lib.json_begin(v.str, v.len))            end
    if z == 3 then return lib.json_num(n, v) and tonumber(n[0]) or math.nan end
    if z == 4 then return sub(ffi_str(b, lib.json_cpy(b, 256, v)), 2, -2)   end
    if z == 5 then return true  end
    if z == 6 then return false end
    if z == 7 then return null  end
    return nil
end
return { decode = function(j, l) return setmetatable(json.obj(lib.json_begin(j, l or #j)), obj) end }