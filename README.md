# lua-resty-opjson
LuaJIT FFI-based [@bungle/libopjson](https://github.com/bungle/libopjson) (one-pass parser) library for LuaJIT and OpenResty.

## Usage

```
local decode = require "resty.opjson"
local json = [[
{
  "Hello": "World"
}
]]

-- you may optionally pass the length:
-- local t = decode(json, #json)
local t = decode(json)
print(t.Hello) -- Outputs "World"
```
