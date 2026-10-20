-- Small Lua 5.4 bit-compat module for shared Clay components.
local M = {}
local MASK = 0xffffffff

local function u32(value)
  return (math.tointeger(tonumber(value) or 0) or 0) & MASK
end

function M.band(...)
  local result = MASK
  for i = 1, select("#", ...) do result = result & u32(select(i, ...)) end
  return result
end

function M.bor(...)
  local result = 0
  for i = 1, select("#", ...) do result = result | u32(select(i, ...)) end
  return result & MASK
end

function M.bxor(...)
  local result = 0
  for i = 1, select("#", ...) do result = result ~ u32(select(i, ...)) end
  return result & MASK
end

function M.bnot(value) return (~u32(value)) & MASK end
function M.lshift(value, amount) return (u32(value) << (math.tointeger(amount) or 0)) & MASK end
function M.rshift(value, amount) return u32(value) >> (math.tointeger(amount) or 0) end

return M
