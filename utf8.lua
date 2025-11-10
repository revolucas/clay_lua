-- utf8.lua - minimal, fast UTF-8 module for LuaJIT/Lua 5.1+
--   utf8.char(...)
--   utf8.codepoint(s [, i [, j]])
--   utf8.len(s [, i [, j]])           -> n, posInvalidOrNil
--   utf8.codes(s)                     -> iterator(i, cp)
--   utf8.offset(s, n [, i])
-- Extras:
--   utf8.validate(s)                  -> true | false, pos
--   utf8.sub(s, i, j)                 -- by codepoint indices
--   utf8.tochar = utf8.char           -- alias for convenience

local ffi = require("ffi")
local bit = require("bit")
local band, bor, rshift, lshift = bit.band, bit.bor, bit.rshift, bit.lshift

local M = {}

-- ------------------------------------------------------------
-- Encoding: codepoint -> UTF-8
-- ------------------------------------------------------------
local function enc1(cp)
    return string.char(cp)
end
local function enc2(cp)
    return string.char(bor(0xC0, rshift(cp, 6)), bor(0x80, band(cp, 0x3F)))
end
local function enc3(cp)
    return string.char(bor(0xE0, rshift(cp, 12)), bor(0x80, band(rshift(cp, 6), 0x3F)), bor(0x80, band(cp, 0x3F)))
end
local function enc4(cp)
    return string.char(
        bor(0xF0, rshift(cp, 18)),
        bor(0x80, band(rshift(cp, 12), 0x3F)),
        bor(0x80, band(rshift(cp, 6), 0x3F)),
        bor(0x80, band(cp, 0x3F))
    )
end

local function check_cp(cp)
    -- Valid Unicode scalar value (exclude UTF-16 surrogates)
    return cp >= 0 and cp <= 0x10FFFF and not (cp >= 0xD800 and cp <= 0xDFFF)
end

function M.char(...)
    local n = select("#", ...)
    if n == 0 then
        return ""
    end
    local t = {}
    for i = 1, n do
        local cp = assert(tonumber(select(i, ...)), "utf8.char expects integers")
        assert(check_cp(cp), ("invalid codepoint U+%X"):format(cp))
        if cp < 0x80 then
            t[i] = enc1(cp)
        elseif cp < 0x800 then
            t[i] = enc2(cp)
        elseif cp < 0x10000 then
            t[i] = enc3(cp)
        else
            t[i] = enc4(cp)
        end
    end
    return table.concat(t)
end

M.tochar = M.char -- alias if you like calling utf8.tochar()

-- ------------------------------------------------------------
-- Decoding helpers: next codepoint from byte index
-- returns cp, nextByteIdx or nil, errorMsg, errorByteIdx
-- ------------------------------------------------------------
local function next_cp_bytes(s, i)
    local b1 = string.byte(s, i)
    if not b1 then
        return nil
    end
    if b1 < 0x80 then
        return b1, i + 1
    end
    local b2 = string.byte(s, i + 1)
    if b1 >= 0xC2 and b1 <= 0xDF then
        if not b2 or band(b2, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        local cp = bor(lshift(b1 - 0xC0, 6), band(b2, 0x3F))
        return cp, i + 2
    end
    local b3 = string.byte(s, i + 2)
    if b1 >= 0xE0 and b1 <= 0xEF then
        if not (b2 and b3) or band(b2, 0xC0) ~= 0x80 or band(b3, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        -- overlong and surrogate checks
        if (b1 == 0xE0 and b2 < 0xA0) or (b1 == 0xED and b2 >= 0xA0) then
            return nil, "invalid codepoint", i
        end
        local cp = bor(lshift(b1 - 0xE0, 12), lshift(band(b2, 0x3F), 6), band(b3, 0x3F))
        if not check_cp(cp) then
            return nil, "invalid codepoint", i
        end
        return cp, i + 3
    end
    local b4 = string.byte(s, i + 3)
    if b1 >= 0xF0 and b1 <= 0xF4 then
        if not (b2 and b3 and b4) or band(b2, 0xC0) ~= 0x80 or band(b3, 0xC0) ~= 0x80 or band(b4, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        -- range checks to prevent overlong/out-of-range
        if (b1 == 0xF0 and b2 < 0x90) or (b1 == 0xF4 and b2 >= 0x90) then
            return nil, "invalid codepoint", i
        end
        local cp = bor(lshift(b1 - 0xF0, 18), lshift(band(b2, 0x3F), 12), lshift(band(b3, 0x3F), 6), band(b4, 0x3F))
        if not check_cp(cp) then
            return nil, "invalid codepoint", i
        end
        return cp, i + 4
    end
    return nil, "invalid leading byte", i
end

-- FFI path (optional), about ~10–20% faster for long strings
local function next_cp_ptr(s, i)
    local len = #s
    local p = ffi.cast("const uint8_t*", s)
    local b1 = (i <= len) and p[i - 1] or nil
    if not b1 then
        return nil
    end
    if b1 < 0x80 then
        return b1, i + 1
    end
    local function B(j)
        return (j <= len) and p[j - 1] or nil
    end
    local b2 = B(i + 1)
    if b1 >= 0xC2 and b1 <= 0xDF then
        if not b2 or band(b2, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        local cp = bor(lshift(b1 - 0xC0, 6), band(b2, 0x3F))
        return cp, i + 2
    end
    local b3 = B(i + 2)
    if b1 >= 0xE0 and b1 <= 0xEF then
        if not (b2 and b3) or band(b2, 0xC0) ~= 0x80 or band(b3, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        if (b1 == 0xE0 and b2 < 0xA0) or (b1 == 0xED and b2 >= 0xA0) then
            return nil, "invalid codepoint", i
        end
        local cp = bor(lshift(b1 - 0xE0, 12), lshift(band(b2, 0x3F), 6), band(b3, 0x3F))
        if not check_cp(cp) then
            return nil, "invalid codepoint", i
        end
        return cp, i + 3
    end
    local b4 = B(i + 3)
    if b1 >= 0xF0 and b1 <= 0xF4 then
        if not (b2 and b3 and b4) or band(b2, 0xC0) ~= 0x80 or band(b3, 0xC0) ~= 0x80 or band(b4, 0xC0) ~= 0x80 then
            return nil, "invalid continuation", i
        end
        if (b1 == 0xF0 and b2 < 0x90) or (b1 == 0xF4 and b2 >= 0x90) then
            return nil, "invalid codepoint", i
        end
        local cp = bor(lshift(b1 - 0xF0, 18), lshift(band(b2, 0x3F), 12), lshift(band(b3, 0x3F), 6), band(b4, 0x3F))
        if not check_cp(cp) then
            return nil, "invalid codepoint", i
        end
        return cp, i + 4
    end
    return nil, "invalid leading byte", i
end

local next_cp = (ok_ffi and next_cp_ptr) or next_cp_bytes

-- ------------------------------------------------------------
-- utf8.codepoint
-- ------------------------------------------------------------
function M.codepoint(s, i, j)
    s = tostring(s or "")
    local len = #s
    i = i or 1
    j = j or i
    if i < 0 then
        i = len + 1 + i
    end
    if j < 0 then
        j = len + 1 + j
    end
    if i < 1 then
        i = 1
    end
    if j > len then
        j = len
    end

    local out = {}
    local k = 1
    local pos = i
    while pos <= j do
        local cp, nx, err, epos = next_cp(s, pos)
        if not cp then
            error(("invalid UTF-8 code at byte %d (%s)"):format(epos or pos, err or "?"))
        end
        out[k], k = cp, k + 1
        pos = nx
    end
    return table.unpack(out, 1, k - 1)
end

-- ------------------------------------------------------------
-- utf8.len
--   returns n, posInvalid (or nil if no invalid)
-- ------------------------------------------------------------
function M.len(s, i, j)
    s = tostring(s or "")
    local len = #s
    i = i or 1
    j = j or len
    if i < 0 then
        i = len + 1 + i
    end
    if j < 0 then
        j = len + 1 + j
    end
    if i < 1 then
        i = 1
    end
    if j > len then
        j = len
    end

    local n, pos = 0, i
    while pos <= j do
        local cp, nx, err, epos = next_cp(s, pos)
        if not cp then
            return nil, epos or pos
        end
        n, pos = n + 1, nx
    end
    return n
end

-- ------------------------------------------------------------
-- utf8.codes (iterator)
--   for i, cp in utf8.codes(s) do ... end
-- ------------------------------------------------------------
function M.codes(s)
    s = tostring(s or "")
    local len = #s
    local i = 1
    return function()
        if i > len then
            return nil
        end
        local cp, nx, err, epos = next_cp(s, i)
        if not cp then
            -- per Lua 5.3: iterator stops at invalid byte
            return nil
        end
        local cur = i
        i = nx
        return cur, cp
    end
end

-- ------------------------------------------------------------
-- utf8.offset(s, n [, i])
--   byte index of nth codepoint starting from byte i (default 1)
--   n can be negative to move backwards
-- ------------------------------------------------------------
function M.offset(s, n, i)
    s = tostring(s or "")
    local len = #s
    n = assert(tonumber(n), "utf8.offset: n must be a number")
    i = i or (n >= 0 and 1 or len + 1)

    if i < 0 then
        i = len + 1 + i
    end
    if i < 1 then
        i = 1
    end
    if i > len + 1 then
        i = len + 1
    end
    if n == 0 then
        -- move to start of current character (or next if at boundary)
        if i <= 1 then
            return 1
        end
        if i > len then
            return len + 1
        end
        -- back up until a valid leading byte
        local p = i
        repeat
            p = p - 1
            local b = string.byte(s, p)
            if not b or b < 0x80 or b >= 0xC2 then
                return p
            end
        until p <= 1
        return 1
    elseif n > 0 then
        local pos = i
        for _ = 1, n do
            if pos > len then
                return nil
            end
            local _, nx, err = next_cp(s, pos)
            if not nx then
                return nil
            end
            pos = nx
        end
        return pos
    else
        -- n < 0 : walk backwards
        local pos = i
        for _ = n, -1 do
            -- step back one cp
            if pos <= 1 then
                return (n == -1) and 1 or nil
            end
            -- find start of previous char
            local p = pos - 1
            while p > 1 do
                local b = string.byte(s, p)
                if b < 0x80 or b >= 0xC2 then
                    local cp, nx = next_cp(s, p)
                    if nx == pos then
                        break
                    end
                end
                p = p - 1
            end
            pos = p
        end
        return pos
    end
end

-- ------------------------------------------------------------
-- Extras
-- ------------------------------------------------------------
function M.validate(s)
    s = tostring(s or "")
    local i, len = 1, #s
    while i <= len do
        local cp, nx, _, epos = next_cp(s, i)
        if not cp then
            return false, epos or i
        end
        i = nx
    end
    return true
end

function M.sub(s, i, j)
    s = tostring(s or "")
    i = i or 1
    j = j or -1
    -- translate cp indices to byte ranges using offset
    local startb = (i >= 1) and M.offset(s, i) or M.offset(s, i, #s + 1)
    if not startb then
        return ""
    end
    local endb
    if j >= 0 then
        endb = M.offset(s, j + 1, startb) -- byte after end
    else
        -- j negative: count from end
        local nb = M.len(s) or 0
        endb = M.offset(s, nb + j + 1, 1)
    end
    if not endb then
        endb = #s + 1
    end
    return string.sub(s, startb, endb - 1)
end

return M

