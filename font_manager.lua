local ffi = require("ffi")
local ok_bit, bit = pcall(require, "bit")
if not ok_bit then
    local UINT32 = 4294967296
    local function bitop(a, b, use_or)
        a = math.floor(tonumber(a) or 0) % UINT32
        b = math.floor(tonumber(b) or 0) % UINT32
        local result, place = 0, 1
        while a > 0 or b > 0 do
            local abit, bbit = a % 2, b % 2
            if (use_or and (abit ~= 0 or bbit ~= 0)) or (not use_or and abit ~= 0 and bbit ~= 0) then
                result = result + place
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            place = place * 2
        end
        return result
    end
    bit = {
        band = function(a, b) return bitop(a, b, false) end,
        bor = function(...)
            local result = 0
            for i = 1, select("#", ...) do
                result = bitop(result, select(i, ...), true)
            end
            return result
        end,
        lshift = function(value, shift)
            return (math.floor(tonumber(value) or 0) * (2 ^ (shift % 32))) % UINT32
        end,
    }
end
local band, bor, lshift = bit.band, bit.bor, bit.lshift

local utf8 = require("utf8")
local bgfx = require("ffi.ffi_bgfx")

local stbrt = require("ffi.ffi_stb_rect_pack")
local stbtt = require("ffi.ffi_stb_truetype")
local stbi = require("ffi.ffi_stb_image")
require("ffi.ffi_math")

local font_cache = {}
local INVALID_HANDLE = 0xffff
local fonts = {
    [0] = "font/DejaVuSansMono.ttf",
    [1] = "font/georgia.ttf",
    [2] = "font/codicon.ttf"
}
local font_aliases = {}
local font_paths = {}
local next_font_id = 0
local MAX_CACHED_SIZES_PER_FACE = 32
local FONT_ATLAS_SMALL_SIZE = 512
local FONT_ATLAS_STANDARD_SIZE = 1024
local FONT_ATLAS_LARGE_SIZE = 2048
local FONT_ATLAS_SAMPLER_FLAGS = bgfx.BGFX_SAMPLER_U_CLAMP + bgfx.BGFX_SAMPLER_V_CLAMP
local font_cache_clock = 0

local function normalize_font_size(size)
    size = tonumber(size) or 16
    if size < 1 then return 1 end
    return math.floor(size + 0.5)
end

local function font_atlas_size(size)
    if size <= 24 then return FONT_ATLAS_SMALL_SIZE end
    if size <= 64 then return FONT_ATLAS_STANDARD_SIZE end
    return FONT_ATLAS_LARGE_SIZE
end

local function release_font(font)
    if font.pack_context ~= nil then
        stbtt.PackEnd(font.pack_context)
        font.pack_context = nil
    end
    if font.texture ~= nil and font.texture.idx ~= INVALID_HANDLE then
        bgfx.bgfx_destroy_texture(font.texture)
    end
    font.texture = nil
    font.faces = nil
    font.data = nil
    font.info = nil
    font.atlas_pixels = nil
    font.rgba = nil
    font.glyphs = nil
    font.glyphs_first = nil
    font.glyphs_count = nil
    font.glyphs_face = nil
end

local function evict_oldest_font(size_map)
    local oldest_size, oldest_font
    for size, font in pairs(size_map) do
        if (font.references or 0) == 0 and
            (not oldest_font or (font.last_used or 0) < (oldest_font.last_used or 0)) then
            oldest_size, oldest_font = size, font
        end
    end
    if oldest_font then
        size_map[oldest_size] = nil
        release_font(oldest_font)
        return true
    end
    return false
end

local function normalize_font_path(path)
    if type(path) ~= "string" or path == "" then return nil end
    return path:gsub("\\", "/")
end

local function font_alias_name(alias)
    local path = normalize_font_path(alias)
    if not path then return nil end
    local base = path:match("([^/]+)$") or path
    return base:gsub("%.[^%.]+$", "")
end

local function normalize_font_alias(alias)
    local name = font_alias_name(alias)
    return name and name:lower() or nil
end

do
    local max_id = -1
    for font_id, path in pairs(fonts) do
        if type(font_id) == "number" and font_id > max_id then
            max_id = font_id
        end
        local normalized = normalize_font_path(path)
        if normalized then
            fonts[font_id] = normalized
            font_paths[normalized] = font_id
            local alias = normalize_font_alias(normalized)
            if alias then font_aliases[alias] = font_id end
        end
    end
    next_font_id = max_id + 1
end

-- Faux style defaults (tweak to taste)
local STYLE = {
  italic_shear   = -0.22,  -- tan(~12.5°)
  bold_passes    = 2,     -- 1 = off, >=2 thickens
  bold_px        = 1.0,   -- pixel offset per pass
  shadow		 = false,  -- override, always on
  shadow_strength = 1.0,
  shadow_dx      = 1.5,
  shadow_dy      = 1.5,
  shadow_color   = {r=0, g=0, b=0, a=160},
  outline        = false,
  outline_size   = 1,
  outline_strength = 1.0,
  outline_color  = {r=0, g=0, b=0, a=255},
}

-- face helpers ----------------------------------------------------

local function _load_face(path)
    local f = assert(io.open(path, "rb"), "Font file not found: " .. path)
    local s = f:read("*a")
    f:close()
    local data = ffi.new("uint8_t[?]", #s)
    ffi.copy(data, s, #s)
    return data
end

-- Ensure a donor/source face (by faceIdx in `fonts`) is present in font.faces[faceIdx]
local function ensureFace(font, faceIdx)
    font.faces = font.faces or {}
    if font.faces[faceIdx] then return font.faces[faceIdx] end
    local path = assert(fonts[faceIdx], "invalid font id: " .. tostring(faceIdx))
    local data = _load_face(path)
    local info = ffi.new("stbtt_fontinfo[1]")
    assert(stbtt.InitFont(info, data, 0) ~= 0, "InitFont failed: " .. path)
    local scale = stbtt.ScaleForPixelHeight(info, font.size)
    local face = { data = data, info = info, scale = scale }
    font.faces[faceIdx] = face
    return face
end

-- Does this face actually contain the codepoint?
local function faceHasGlyph(font, faceIdx, cp)
    local face = ensureFace(font, faceIdx)
    local gi = stbtt.FindGlyphIndex(face.info, cp)
    return gi and gi ~= 0
end

-- advance helpers -------------------------------------------------

local function getGlyphAdvanceFace(font, faceIdx, codepoint)
    local face = ensureFace(font, faceIdx)
    local advanceWidth = ffi.new("int[1]")
    local lsb = ffi.new("int[1]")
    stbtt.GetCodepointHMetrics(face.info, codepoint, advanceWidth, lsb)
    local adv = advanceWidth[0] * face.scale
    if adv == 0 then adv = font.space_advance end
    return adv
end

local function getGlyphAdvance(font, codepoint)
    -- keep old signature for callers; use the requested face by default
    return getGlyphAdvanceFace(font, font.id, codepoint)
end

-- kerning (only when two consecutive glyphs came from same face)
local function kernAdjust(font, faceIdx, prev_cp, cur_cp)
    if not (prev_cp and faceIdx) then return 0 end
    local face = ensureFace(font, faceIdx)
    local k = stbtt.GetCodepointKernAdvance(face.info, prev_cp, cur_cp) or 0
    return k * face.scale
end

-- Preload unicode ranges if wanted
local unicode_ranges = {
    -- Basic
    {first = 0xFFFD, count = 1}, -- Replacement Character

	--{ first = 0x2500, count = 0x80 },  -- Box Drawing        0x2500..0x257F
	--{ first = 0x2580, count = 0x20 },  -- Block Elements     0x2580..0x259F
	--{ first = 0x25A0, count = 0x60 },  -- Geometric Shapes   0x25A0..0x25FF

    --{first = 0x0020, count = 96}, -- Basic Latin (ASCII)
    --{first = 0x00A0, count = 96}, -- Latin-1 Supplement
    --{first = 0x0100, count = 256}, -- Latin Extended-A/B
    --{first = 0x0180, count = 208}, -- Latin Extended Additional
    -- Western Europe + punctuation
    --{first = 0x2000, count = 96}, -- General Punctuation
    --{first = 0x2100, count = 128}, -- Letterlike Symbols, Currency, Misc Technical
    -- Greek
    --{first = 0x0370, count = 128}, -- Greek and Coptic
    -- Cyrillic
    --{first = 0x0400, count = 256}, -- Cyrillic + Supplement
    -- Hebrew, Arabic
    --{first = 0x0590, count = 128}, -- Hebrew
    --{first = 0x0600, count = 256}, -- Arabic
    --{first = 0x0750, count = 96}, -- Arabic Supplement
    --{first = 0x08A0, count = 128}, -- Arabic Extended
    -- South Asian
    --{first = 0x0900, count = 128}, -- Devanagari
    --{first = 0x0980, count = 128}, -- Bengali
    --{first = 0x0A00, count = 128}, -- Gurmukhi/Gujarati
    -- CJK
    --{first = 0x3000, count = 256}, -- CJK Symbols & Punct
    --{first = 0x3040, count = 96},  -- Hiragana
    --{first = 0x30A0, count = 96},  -- Katakana
    --{first = 0x3130, count = 96},  -- Hangul Compat Jamo
    --{first = 0x4E00, count = 20992}, -- CJK Unified Ideographs
    --{first = 0xAC00, count = 11184}, -- Hangul Syllables
    -- Thai, Lao
    --{first = 0x0E00, count = 128}, -- Thai
    --{first = 0x0E80, count = 64},  -- Lao
    -- Misc / Emoji
    --{first = 0x1F00, count = 256},  -- Greek Extended / Misc
    --{first = 0x1F300, count = 768}, -- Misc Symbols & Pictographs
    --{first = 0x1F600, count = 512}, -- Emoticons
    --{first = 0x1F900, count = 512}  -- Supplemental Symbols & Pictographs
}

local function findPackedGlyph(font, codepoint)
    for i = 1, #font.glyphs do
        local first = font.glyphs_first[i]
        local count = font.glyphs_count[i]
        if codepoint >= first and codepoint < first + count then
            local faceIdx = (font.glyphs_face and font.glyphs_face[i]) or font.id
            return font.glyphs[i], first, faceIdx
        end
    end
    return nil
end

local function flushAtlas(font)
    if not font.atlas_dirty then
        return
    end
    local count = font.width * font.height

    -- grayscale -> RGBA
    stbtt.GrayscaleToRGBA(font.atlas_pixels, font.rgba, count)

    local mem = bgfx.bgfx_copy(font.rgba, count * 4)
    bgfx.bgfx_update_texture_2d(font.texture, 0, 0, 0, 0, font.width, font.height, mem, font.width * 4)
    font.atlas_dirty = false
end

-- "range" pack (packs from primary face)
local function packGlyph(font, codepoint)
    local pack, base = findPackedGlyph(font, codepoint)
    if pack then
        return true
    end

	-- packs entire range if glyph falls within a font range
    for _, range in ipairs(unicode_ranges) do
        local first, count = range.first, range.count
        if codepoint >= first and codepoint < first + count then
            local buf = ffi.new("stbtt_packedchar[?]", count)
            -- primary requested face
            local ok = stbtt.PackFontRange(font.pack_context, font.data, 0, font.size, first, count, buf)
            if ok ~= 0 then
                table.insert(font.glyphs, buf)
                table.insert(font.glyphs_first, first)
                table.insert(font.glyphs_count, count)
                font.glyphs_face = font.glyphs_face or {}
                font.glyphs_face[#font.glyphs] = font.id
                font.atlas_dirty = true
                return true
            else
                print(string.format("[warn] pack failed for U+%04X..U+%04X", first, first + count - 1))
                return false
            end
        end
    end
    return false
end

-- single-glyph packer from an arbitrary donor face
local function packOneGlyphFromFace(font, faceIdx, cp)
    -- pre-check: skip faces that don't actually have this cp
    if not faceHasGlyph(font, faceIdx, cp) then return false end

    local ch   = ffi.new("stbtt_packedchar[1]")
    local face = ensureFace(font, faceIdx)
    local ok   = stbtt.PackFontRange(font.pack_context, face.data, 0, font.size, cp, 1, ch)
    if ok == 0 then return false end

    table.insert(font.glyphs, ch)
    table.insert(font.glyphs_first, cp)
    table.insert(font.glyphs_count, 1)
    font.glyphs_face = font.glyphs_face or {}
    font.glyphs_face[#font.glyphs] = faceIdx
    font.atlas_dirty = true

    return true
end


local function ensurePacked(font, cp)
    -- already in atlas?
    local pack = select(1, findPackedGlyph(font, cp))
    if pack then return true end

    -- 1) try primary face ONLY if it truly has this cp
    if packOneGlyphFromFace(font, font.id, cp) then
        return true
    end

    -- 2) donors
    for fid, _ in pairs(fonts) do
        if fid ~= font.id then
            if packOneGlyphFromFace(font, fid, cp) then
                return true
            end
        end
    end

    -- 3) final symbolic fallback (�)
    local fcp = 0xFFFD
	if packOneGlyphFromFace(font, font.id, fcp) then
		return true
	end
	for fid, _ in pairs(fonts) do
		if fid ~= font.id and packOneGlyphFromFace(font, fid, fcp) then
			return true
		end
	end

    return false
end


local function utf8_iter_fast(s)
    local p = ffi.cast("const uint8_t*", s) -- pointer to string bytes
    local i, n = 0, #s -- byte index, length

    return function()
        if i >= n then
            return nil
        end

        local b0 = p[i]
        i = i + 1
        if b0 < 0x80 then
            return b0
        end

        if b0 >= 0xC2 and b0 < 0xE0 then
            if i < n then
                local b1 = p[i]
                if band(b1, 0xC0) == 0x80 then
                    i = i + 1
                    return bor(lshift(b0 - 0xC0, 6), band(b1, 0x3F))
                end
            end
        elseif b0 < 0xF0 then
            if i + 1 < n then
                local b1 = p[i]
                local b2 = p[i + 1]
                if b0 == 0xE0 then
                    if b1 >= 0xA0 and b1 <= 0xBF and band(b2, 0xC0) == 0x80 then
                        i = i + 2
                        return bor(lshift(b0 - 0xE0, 12), lshift(band(b1, 0x3F), 6), band(b2, 0x3F))
                    end
                elseif b0 == 0xED then
                    if b1 >= 0x80 and b1 <= 0x9F and band(b2, 0xC0) == 0x80 then
                        i = i + 2
                        return bor(lshift(b0 - 0xE0, 12), lshift(band(b1, 0x3F), 6), band(b2, 0x3F))
                    end
                else
                    if band(b1, 0xC0) == 0x80 and band(b2, 0xC0) == 0x80 then
                        i = i + 2
                        return bor(lshift(b0 - 0xE0, 12), lshift(band(b1, 0x3F), 6), band(b2, 0x3F))
                    end
                end
            end
        elseif b0 < 0xF5 then
            if i + 2 < n then
                local b1 = p[i]
                local b2 = p[i + 1]
                local b3 = p[i + 2]
                if b0 == 0xF0 then
                    if b1 >= 0x90 and b1 <= 0xBF and band(b2, 0xC0) == 0x80 and band(b3, 0xC0) == 0x80 then
                        i = i + 3
                        return bor(
                            lshift(b0 - 0xF0, 18),
                            lshift(band(b1, 0x3F), 12),
                            lshift(band(b2, 0x3F), 6),
                            band(b3, 0x3F)
                        )
                    end
                elseif b0 == 0xF4 then
                    if b1 >= 0x80 and b1 <= 0x8F and band(b2, 0xC0) == 0x80 and band(b3, 0xC0) == 0x80 then
                        i = i + 3
                        return bor(
                            lshift(b0 - 0xF0, 18),
                            lshift(band(b1, 0x3F), 12),
                            lshift(band(b2, 0x3F), 6),
                            band(b3, 0x3F)
                        )
                    end
                else
                    if band(b1, 0xC0) == 0x80 and band(b2, 0xC0) == 0x80 and band(b3, 0xC0) == 0x80 then
                        i = i + 3
                        return bor(
                            lshift(b0 - 0xF0, 18),
                            lshift(band(b1, 0x3F), 12),
                            lshift(band(b2, 0x3F), 6),
                            band(b3, 0x3F)
                        )
                    end
                end
            end
        end

        -- Invalid sequence: advance over any continuation bytes, return U+FFFD
        while i < n and band(p[i], 0xC0) == 0x80 do
            i = i + 1
        end

        return 0xFFFD
    end
end

local function packLanguageRange(font, first, num)
    local ok = stbtt.PackFontRange(font.pack_context, font.data, 0, font.size, first, num, font.glyphs + first)
    if ok == 0 then
        print(string.format("[warn] pack failed for U+%04X..U+%04X", first, first + num - 1))
    end
end

local M = {}

function M.load(font_id, font_size)
    local filename = fonts[font_id]
    assert(filename, "Invalid font id " .. tostring(font_id))

    font_size = normalize_font_size(font_size)
    local size_map = font_cache[font_id]
    if not size_map then
        size_map = {}
        font_cache[font_id] = size_map
    end

    local cached = size_map[font_size]
    if cached then
        font_cache_clock = font_cache_clock + 1
        cached.last_used = font_cache_clock
        return cached
    end

    local cached_sizes = 0
    for _ in pairs(size_map) do cached_sizes = cached_sizes + 1 end
    while cached_sizes >= MAX_CACHED_SIZES_PER_FACE do
        if not evict_oldest_font(size_map) then break end
        cached_sizes = cached_sizes - 1
    end

    -- Load primary font file (requested face)
    local file = assert(io.open(filename, "rb"), "Font file not found: " .. filename)
    local fontDataStr = file:read("*a")
    file:close()

    local fontData = ffi.new("uint8_t[?]", #fontDataStr)
    ffi.copy(fontData, fontDataStr, #fontDataStr)

    local atlasWidth, atlasHeight = font_atlas_size(font_size), font_atlas_size(font_size)
    local atlasPixels = ffi.new("uint8_t[?]", atlasWidth * atlasHeight)
    local packContext = ffi.new("stbtt_pack_context[1]")

    -- Leave a texel around each glyph so linear filtering does not pull in
    -- neighboring glyphs from the atlas.
    assert(stbtt.PackBegin(packContext, atlasPixels, atlasWidth, atlasHeight, 0, 1, nil) ~= 0, "PackBegin failed")
    
    stbtt.PackSetOversampling(packContext, 2, 2)

    -- Bake ASCII range (32–126) from the requested face
    local firstChar, numChars = 32, 95
    local glyphs = ffi.new("stbtt_packedchar[?]", numChars)
    assert(stbtt.PackFontRange(packContext, fontData, 0, font_size, firstChar, numChars, glyphs) ~= 0, "PackFontRange failed")

    -- Convert grayscale -> RGBA
    local rgba = ffi.new("uint8_t[?]", atlasWidth * atlasHeight * 4)
    stbtt.GrayscaleToRGBA(atlasPixels, rgba, atlasWidth * atlasHeight)

	-- make a mutable texture
    local mem = bgfx.bgfx_copy(rgba, atlasWidth * atlasHeight * 4)
    local tex = bgfx.bgfx_create_texture_2d(atlasWidth, atlasHeight, false, 1,
        bgfx.BGFX_TEXTURE_FORMAT_RGBA8, FONT_ATLAS_SAMPLER_FLAGS, nil)
	bgfx.bgfx_update_texture_2d(tex, 0, 0, 0, 0, atlasWidth, atlasHeight, mem, atlasWidth * 4)

    local fontInfo = ffi.new("stbtt_fontinfo[1]")
    assert(stbtt.InitFont(fontInfo, fontData, 0) ~= 0, "InitFont failed")
    local scale = stbtt.ScaleForPixelHeight(fontInfo, font_size)

    -- Create the final font object
    local font = {
        id = font_id,
        size = font_size,
        width = atlasWidth,
        height = atlasHeight,
        texture = tex,
        data = fontData, -- primary face data
        info = fontInfo, -- primary face info
        scale = scale,
        glyphs = {glyphs},
        glyphs_first = {firstChar},
        glyphs_count = {numChars},
        glyphs_face = { [1] = font_id }, -- track source face for each run
        -- UTF-8 Dynamic glyph atlas
        pack_context = packContext,
        atlas_pixels = atlasPixels,
        atlas_dirty = false,
        next_x = 0,
        next_y = 0,
        row_height = 0,
        rgba = rgba,
        references = 0,
        faces = {} -- donor/primary faces cache by faceIdx
    }
    font_cache_clock = font_cache_clock + 1
    font.last_used = font_cache_clock

    -- make sure primary face is cached
    font.faces[font_id] = { data = font.data, info = font.info, scale = font.scale }

    -- space/tab advance from primary
    font.space_advance = getGlyphAdvance(font, 32)
    font.tab_advance   = font.space_advance * 4

    size_map[font_size] = font
    return font
end

-- Retained render packets keep font textures alive until their packets are
-- replaced or destroyed. Immediate-mode geometry is submitted in the current
-- frame and does not need an extra reference.
function M.retain(font)
    if font then font.references = (font.references or 0) + 1 end
    return font
end

function M.release(font)
    if font and (font.references or 0) > 0 then
        font.references = font.references - 1
    end
end

function M.id(alias)
    if alias == nil then return 0 end
    if type(alias) == "number" then return alias end
    if type(alias) ~= "string" then return nil end

    local base_alias = normalize_font_alias(alias)
    if not base_alias then return nil end
    if font_aliases[base_alias] ~= nil then
        return font_aliases[base_alias]
    end

    local lower = alias:lower()
    local has_path = alias:find("[/\\]") ~= nil
    local path
    if has_path or lower:match("%.ttf$") or lower:match("%.otf$") then
        path = normalize_font_path(alias)
    else
        path = "font/" .. font_alias_name(alias) .. ".ttf"
    end

    local path_key = path
    if path_key and font_paths[path_key] ~= nil then
        local font_id = font_paths[path_key]
        font_aliases[base_alias] = font_id
        return font_id
    end

    local file = path and io.open(path, "rb")
    if not file then return nil end
    file:close()

    local font_id = next_font_id
    next_font_id = next_font_id + 1
    fonts[font_id] = path
    font_paths[path_key] = font_id
    font_aliases[base_alias] = font_id
    return font_id
end

-- hex color parser: "#RRGGBB" or "#RRGGBBAA" (AA optional)
local function parse_hex_color(s, curA)
    s = s:gsub("^#","")
    local r = tonumber(s:sub(1,2),16)
    local g = tonumber(s:sub(3,4),16)
    local b = tonumber(s:sub(5,6),16)
    local a = curA or 255
    if #s >= 8 then a = tonumber(s:sub(7,8),16) end
    return r or 255, g or 255, b or 255, a or (curA or 255)
end

local function copy_color(color)
    return {r = color.r, g = color.g, b = color.b, a = color.a}
end

local function clone_rich_style(style)
    local clone = {}
    for key, value in pairs(style) do
        clone[key] = type(value) == "table" and copy_color(value) or value
    end
    return clone
end

local function clamp01(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return math.max(0, math.min(1, number))
end

local function parse_style_attributes(attributes)
    local values = {}
    if not attributes or attributes == "" then return values end
    attributes = attributes:gsub("[,;]", " ")
    for key, value in attributes:gmatch("([%w_]+)%s*=%s*([^%s]+)") do
        values[key:lower()] = value
    end
    return values
end

local function apply_shadow_style(style, value, attributes)
    style.shadow = true
    if value and value ~= "" then
        if value:find("=", 1, true) then
            attributes = attributes and (value .. ";" .. attributes) or value
        elseif value:sub(1, 1) == "#" then
            local rr, gg, bb, aa = parse_hex_color(value, style.shadow_color.a)
            style.shadow_color = {r=rr, g=gg, b=bb, a=aa}
        else
            style.shadow_strength = clamp01(value, style.shadow_strength)
        end
    end

    local values = parse_style_attributes(attributes)
    if values.strength or values.s then
        style.shadow_strength = clamp01(values.strength or values.s, style.shadow_strength)
    end
    if values.color or values.colour then
        local rr, gg, bb, aa = parse_hex_color(values.color or values.colour, style.shadow_color.a)
        style.shadow_color = {r=rr, g=gg, b=bb, a=aa}
    end
    if values.alpha or values.a then
        local alpha = tonumber(values.alpha or values.a)
        if alpha then
            if alpha >= 0 and alpha <= 1 then alpha = alpha * 255 end
            style.shadow_color.a = math.floor(math.max(0, math.min(255, alpha)) + 0.5)
        end
    end
    style.shadow_dx = tonumber(values.x or values.dx) or style.shadow_dx
    style.shadow_dy = tonumber(values.y or values.dy) or style.shadow_dy
end

local function apply_outline_style(style, value, attributes)
    style.outline = true
    if value and value ~= "" then
        if value:find("=", 1, true) then
            attributes = attributes and (value .. ";" .. attributes) or value
        elseif value:sub(1, 1) == "#" then
            local rr, gg, bb, aa = parse_hex_color(value, style.outline_color.a)
            style.outline_color = {r=rr, g=gg, b=bb, a=aa}
        else
            style.outline_size = tonumber(value) or style.outline_size
        end
    end

    local values = parse_style_attributes(attributes)
    local size = tonumber(values.size or values.radius)
    if size then style.outline_size = math.max(0, math.min(2, math.floor(size + 0.5))) end
    local strength = tonumber(values.strength or values.s)
    if strength then style.outline_strength = clamp01(strength, style.outline_strength) end
    if values.color or values.colour then
        local rr, gg, bb, aa = parse_hex_color(values.color or values.colour, style.outline_color.a)
        style.outline_color = {r=rr, g=gg, b=bb, a=aa}
    end
end

-- Rich text uses a complete style stack so nesting and repeated tags restore
-- the exact previous color, font, and effects when their closing tag appears.
local function parseRichText(text, r, g, b, a, baseFontId, baseFontSize)
    text = tostring(text or "")
    local segments = {}
    local stack = {{
        tag = "__root",
        style = {
            color = {r=r or 255, g=g or 255, b=b or 255, a=a or 255},
            fontId = baseFontId,
            fontSize = baseFontSize,
            kern = true,
            bold = false,
            italic = false,
            strike = false,
            shadow = false,
            shadow_strength = 1,
            shadow_color = {r=0, g=0, b=0, a=STYLE.shadow_color.a},
            shadow_dx = STYLE.shadow_dx,
            shadow_dy = STYLE.shadow_dy,
            outline = false,
            outline_size = 1,
            outline_strength = 1,
            outline_color = copy_color(STYLE.outline_color),
        },
    }}
    local buf = {}

    local function current_style()
        return stack[#stack].style
    end

    local function push_text(value)
        if not value or #value == 0 then return end
        local style = current_style()
        segments[#segments + 1] = {
            text = value,
            color = copy_color(style.color),
            fontId = style.fontId,
            fontSize = style.fontSize,
            kern = style.kern,
            bold = style.bold,
            italic = style.italic,
            strike = style.strike,
            shadow = style.shadow,
            shadow_strength = style.shadow_strength,
            shadow_color = copy_color(style.shadow_color),
            shadow_dx = style.shadow_dx,
            shadow_dy = style.shadow_dy,
            outline = style.outline,
            outline_size = style.outline_size,
            outline_strength = style.outline_strength,
            outline_color = copy_color(style.outline_color),
        }
    end

    local function flush()
        if #buf == 0 then return end
        push_text(table.concat(buf))
        for index = #buf, 1, -1 do buf[index] = nil end
    end

    local function push_style(tag, mutate)
        flush()
        local style = clone_rich_style(current_style())
        mutate(style)
        stack[#stack + 1] = {tag=tag, style=style}
    end

    local function pop_style(tag)
        flush()
        for index = #stack, 2, -1 do
            if stack[index].tag == tag then
                while #stack >= index do stack[#stack] = nil end
                return
            end
        end
    end

    local function push_codepoint(value)
        local codepoint = tonumber(value)
        if codepoint and codepoint >= 0 and codepoint <= 0x10FFFF
            and not (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
            push_text(utf8.char(codepoint))
        end
    end

    local i = 1
    while i <= #text do
        if text:sub(i, i) ~= "[" then
            buf[#buf + 1] = text:sub(i, i)
            i = i + 1
        elseif text:sub(i, i + 1) == "[[" then
            buf[#buf + 1] = "["
            i = i + 2
        else
            local start_at, end_at = text:find("%b[]", i)
            if start_at ~= i or not end_at then
                buf[#buf + 1] = "["
                i = i + 1
            else
                local original = text:sub(i, end_at)
                local raw = text:sub(i + 1, end_at - 1)
                local closing = raw:match("^%s*/") ~= nil
                raw = raw:gsub("^%s*/%s*", "")
                raw = raw:match("^%s*(.-)%s*$") or raw

                local shadow_attributes = not closing and raw:match("^shadow%s+(.+)$") or nil
                local outline_attributes = not closing and raw:match("^outline%s+(.+)$") or nil
                local command, value = raw:match("^([%w_]+)%s*=%s*(.-)%s*$")
                if shadow_attributes then
                    command, value = "shadow", nil
                elseif outline_attributes then
                    command, value = "outline", nil
                elseif not command then
                    command = raw
                end
                command = (command or ""):lower()

                if closing then
                    if command == "color" or command == "font" or command == "size"
                        or command == "kerning" or command == "b" or command == "i"
                        or command == "strike" or command == "shadow" or command == "outline" then
                        pop_style(command)
                    end
                elseif command == "color" and value then
                    push_style("color", function(style)
                        local rr, gg, bb, aa = parse_hex_color(value, style.color.a)
                        style.color = {r=rr, g=gg, b=bb, a=aa}
                    end)
                elseif command == "font" and value then
                    push_style("font", function(style)
                        style.fontId = tonumber(value) or M.id(value) or style.fontId
                    end)
                elseif command == "size" and value then
                    push_style("size", function(style)
                        style.fontSize = tonumber(value) or style.fontSize
                    end)
                elseif command == "kerning" and value then
                    push_style("kerning", function(style)
                        local setting = value:lower()
                        style.kern = setting == "on" or setting == "true" or setting == "1"
                    end)
                elseif command == "b" or command == "i" or command == "strike" then
                    push_style(command, function(style) style[command] = true end)
                elseif command == "shadow" then
                    push_style("shadow", function(style)
                        apply_shadow_style(style, value, shadow_attributes)
                    end)
                elseif command == "outline" then
                    push_style("outline", function(style)
                        apply_outline_style(style, value, outline_attributes)
                    end)
                elseif command == "br" then
                    buf[#buf + 1] = "\n"
                elseif command == "cp" and value then
                    flush()
                    push_codepoint(value)
                else
                    local hex = raw:match("^[Uu]%+([%x]+)$")
                    if hex then
                        flush()
                        push_codepoint("0x" .. hex)
                    else
                        buf[#buf + 1] = original
                    end
                end
                i = end_at + 1
            end
        end
    end

    flush()
    return segments
end

--[[
	Persistent cache table for measureText
	For unbounded dynamic text, like a live chat feed, terminal emulator, or anything that constantly generates new strings
	caching could grow indefinitely, so you’d just clear it periodically.
--]]
local measure_cache = {}
local MEASURE_CACHE_LIMIT = 8192
local measure_cache_keys, measure_cache_tokens = {}, {}
local measure_cache_cursor, measure_cache_count, measure_cache_token = 1, 0, 0

function M.clearMeasureCache()
    measure_cache = {}
    measure_cache_keys, measure_cache_tokens = {}, {}
    measure_cache_cursor, measure_cache_count, measure_cache_token = 1, 0, 0
end

local function cache_measurement(key, width, height)
    local old_key = measure_cache_keys[measure_cache_cursor]
    local old_token = measure_cache_tokens[measure_cache_cursor]
    if old_key then
        local old_value = measure_cache[old_key]
        if old_value and old_value.token == old_token then
            measure_cache[old_key] = nil
        end
    else
        measure_cache_count = measure_cache_count + 1
    end

    measure_cache_token = measure_cache_token + 1
    measure_cache_keys[measure_cache_cursor] = key
    measure_cache_tokens[measure_cache_cursor] = measure_cache_token
    measure_cache[key] = { width, height, token = measure_cache_token }
    measure_cache_cursor = measure_cache_cursor % MEASURE_CACHE_LIMIT + 1
end

local function font_line_metrics(font)
    local cached = font._clay_line_metrics
    if cached then return cached end

    local ascent = ffi.new("int[1]")
    local descent = ffi.new("int[1]")
    local gap = ffi.new("int[1]")
    stbtt.GetFontVMetrics(font.info, ascent, descent, gap)

    local metrics = {
        ascent = ascent[0] * font.scale,
        descent = -(descent[0] * font.scale),
        gap = gap[0] * font.scale,
    }
    metrics.descent = math.max(0, metrics.descent)
    metrics.gap = math.max(0, metrics.gap)
    metrics.advance = metrics.ascent + metrics.descent + metrics.gap
    if metrics.advance <= 0 then metrics.advance = math.max(1, font.size or 1) end

    font._clay_line_metrics = metrics
    return metrics
end

local function measure_run_width(font, text, kern_on, start_x)
    start_x = start_x or 0
    local width = start_x
    local previous_cp, previous_face = nil, nil

    for codepoint in utf8_iter_fast(text) do
        if codepoint == 9 then
            width = start_x + math.floor((width - start_x) / font.tab_advance + 1) * font.tab_advance
            previous_cp, previous_face = 9, font.id
        elseif codepoint == 32 then
            width = width + font.space_advance
            previous_cp, previous_face = 32, font.id
        elseif codepoint == 13 then
            previous_cp, previous_face = nil, nil
        elseif codepoint ~= 10 then
            ensurePacked(font, codepoint)
            local _, _, face_id = findPackedGlyph(font, codepoint)
            face_id = face_id or font.id

            if kern_on ~= false and previous_cp and previous_face == face_id then
                width = width + kernAdjust(font, face_id, previous_cp, codepoint)
            end
            width = width + getGlyphAdvanceFace(font, face_id, codepoint)
            previous_cp, previous_face = codepoint, face_id
        end
    end

    return width - start_x
end

local function layout_rich_text_lines(segments, base_font)
    local base_metrics = font_line_metrics(base_font)
    local lines = {}

    local function new_line()
        return {
            runs = {},
            width = 0,
            visual_width = 0,
            ascent = base_metrics.ascent,
            descent = base_metrics.descent,
            gap = base_metrics.gap,
            advance = base_metrics.advance,
            shadow_down = 0,
        }
    end

    local line = new_line()
    local function include_metrics(metrics)
        line.ascent = math.max(line.ascent, metrics.ascent)
        line.descent = math.max(line.descent, metrics.descent)
        line.gap = math.max(line.gap, metrics.gap)
        line.advance = math.max(line.advance, line.ascent + line.descent + line.gap)
    end

    local function append_run(segment, segment_font, text)
        local metrics = font_line_metrics(segment_font)
        include_metrics(metrics)
        if #text == 0 then return end

        local width = measure_run_width(segment_font, text, segment.kern, line.width)
        line.runs[#line.runs + 1] = {
            text = text,
            segment = segment,
            font = segment_font,
            metrics = metrics,
            x = line.width,
            width = width,
        }
        line.width = line.width + width

        local visual_right = line.width
        if segment.shadow then
            local strength = segment.shadow_strength
            if strength == nil then strength = STYLE.shadow_strength or 1 end
            local dx = tonumber(segment.shadow_dx)
            if dx == nil then dx = STYLE.shadow_dx or 0 end
            local dy = tonumber(segment.shadow_dy)
            if dy == nil then dy = STYLE.shadow_dy or 0 end
            if strength > 0 and dx > 0 then visual_right = visual_right + dx end
            if strength > 0 then line.shadow_down = math.max(line.shadow_down, dy) end
        end
        if segment.outline then
            local outline_size = tonumber(segment.outline_size) or STYLE.outline_size or 1
            visual_right = visual_right + math.max(0, math.min(2, outline_size))
        end
        line.visual_width = math.max(line.visual_width, visual_right)
    end

    local function finish_line()
        line.visual_width = math.max(line.visual_width, line.width)
        lines[#lines + 1] = line
        line = new_line()
    end

    for _, segment in ipairs(segments) do
        local segment_font =
            (segment.fontId ~= base_font.id or segment.fontSize ~= base_font.size)
            and M.load(segment.fontId, segment.fontSize)
            or base_font
        segment_font = segment_font or base_font
        local metrics = font_line_metrics(segment_font)
        local start_at = 1

        while true do
            local newline = segment.text:find("\n", start_at, true)
            local slice = newline and segment.text:sub(start_at, newline - 1)
                or segment.text:sub(start_at)
            include_metrics(metrics)
            append_run(segment, segment_font, slice)
            if not newline then break end
            finish_line()
            start_at = newline + 1
        end
    end

    finish_line()
    return lines
end

local function measure_text(text, font_id, font_px, skip_tags)
    text = tostring(text or "")
    font_id = tonumber(font_id) or 0
    font_px = normalize_font_size(font_px)
    local key = string.format("%d:%d:%s:%s", font_id, font_px, skip_tags and "literal" or "rich", text)
    local cached = measure_cache[key]
    if cached then return cached[1], cached[2] end

    local base_font = M.load(font_id, font_px)
    if not base_font then return 0, 0 end

    local segments
    if skip_tags then
        segments = {{
            text = text,
            color = {r=255, g=255, b=255, a=255},
            fontId = font_id,
            fontSize = font_px,
            kern = true,
        }}
    else
        segments = parseRichText(text, 255, 255, 255, 255, font_id, font_px)
    end

    local lines = layout_rich_text_lines(segments, base_font)
    local total_width, total_height = 0, 0
    for _, line in ipairs(lines) do
        total_width = math.max(total_width, line.visual_width)
        total_height = total_height + line.advance
    end
    if #lines > 0 then total_height = total_height + lines[#lines].shadow_down end

    cache_measurement(key, total_width, total_height)
    return total_width, total_height
end

-- Canonical scalar API used by Clay's text measurement callback.
-- The table form remains accepted for older callers; new code should pass
-- font id and size directly to avoid allocating a config table per measure.
function M.measureText(text, font_id, font_px, letter_spacing, line_height,
        wrap_mode, text_alignment, r, g, b, a)
    if type(font_id) == "table" then
        return measure_text(text, font_id.fontId, font_id.fontSize, font_px)
    end
    return measure_text(text, font_id, font_px, false)
end

function M.measureTextConfig(text, config, skip_tags)
    return measure_text(text, config.fontId, config.fontSize, skip_tags)
end

-- Helper for text vertices using stbtt packed atlas
-- 4 verts / 6 indices per glyph
local function generateTextVerticesRaw(font, text, x, y, r, g, b, a, style)
    r = math.floor(math.min(math.max(r or 255, 0), 255))
    g = math.floor(math.min(math.max(g or 255, 0), 255))
    b = math.floor(math.min(math.max(b or 255, 0), 255))
    a = math.floor(math.min(math.max(a or 255, 0), 255))

    -- baseline setup
    local ascent = ffi.new("int[1]")
    local descent = ffi.new("int[1]")
    local lineGap = ffi.new("int[1]")
    stbtt.GetFontVMetrics(font.info, ascent, descent, lineGap)
    local baseline = y + ascent[0] * font.scale

    local xpos = ffi.new("float[1]", x)
    local ypos = ffi.new("float[1]", baseline)
    local quad = ffi.new("stbtt_aligned_quad[1]")

    local vcount, icount = 0, 0
    local prev_cp, prev_face = nil, nil
    
    -- style flags (nil-safe)
    style = style or {}
    local tab_origin = style.tab_origin or x
    local kern_on = style.kern ~= false
    local italic_shear = (style.italic and (style.italic_shear or STYLE.italic_shear)) or 0
	local bold_passes = (style.bold and (style.bold_passes or STYLE.bold_passes)) or 1
	if bold_passes < 1 then bold_passes = 1 end
	local bold_px = style.bold_px or STYLE.bold_px
	local shadow_strength = clamp01(style.shadow_strength, STYLE.shadow_strength or 1)
	local shadow_on = (style.shadow == true or STYLE.shadow == true) and shadow_strength > 0
	local shadow_dx = tonumber(style.shadow_dx) or STYLE.shadow_dx or 0
	local shadow_dy = tonumber(style.shadow_dy) or STYLE.shadow_dy or 0
	local shcol = style.shadow_color or STYLE.shadow_color
	local outline_strength = clamp01(style.outline_strength, STYLE.outline_strength or 1)
	local outline_size = math.floor((tonumber(style.outline_size) or STYLE.outline_size or 1) + 0.5)
	outline_size = math.max(0, math.min(2, outline_size))
	local outline_on = (style.outline == true or STYLE.outline == true)
		and outline_strength > 0 and outline_size > 0
	local outcol = style.outline_color or STYLE.outline_color
	local outline_offsets = {}
	if outline_on then
		for oy = -outline_size, outline_size do
			for ox = -outline_size, outline_size do
				if ox ~= 0 or oy ~= 0 then outline_offsets[#outline_offsets + 1] = {ox, oy} end
			end
		end
	end

    -- Each glyph may emit shadow, outline dilation, and bold/main passes.
    local max_passes_per_cp = bold_passes + (shadow_on and 1 or 0) + #outline_offsets

    -- Upper bound on “codepoints that draw” is ≤ #text (bytes) – safe over-alloc
    local nbytes = #text
    local max_quads   = nbytes * max_passes_per_cp
    local max_verts   = max_quads * 4
    local max_indices = max_quads * 6

    -- Allocate with the new capacity
    local vertices = ffi.new("Vertex[?]",   max_verts)
    local indices  = ffi.new("uint16_t[?]", max_indices)

	-- push one quad (optionally skewed) with an extra offset
	local function emit_quad(q, cr,cg,cb,ca, dx,dy)
		local pa = ca / 255
		cr, cg, cb = cr * pa, cg * pa, cb * pa
		local vbase = vcount
		-- positions with optional shear. Use y relative to baseline.
		local x0, y0 = q.x0 + dx, q.y0 + dy
		local x1, y1 = q.x1 + dx, q.y1 + dy
		if italic_shear ~= 0 then
			local sx0 = italic_shear * (y0 - baseline)
			local sx1 = italic_shear * (y1 - baseline)
			-- top edge uses y0 shear, bottom uses y1 shear
			vertices[vbase + 0] = {x0 + sx0, y0, q.s0, q.t0, cr, cg, cb, ca}
			vertices[vbase + 1] = {x1 + sx0, y0, q.s1, q.t0, cr, cg, cb, ca}
			vertices[vbase + 2] = {x1 + sx1, y1, q.s1, q.t1, cr, cg, cb, ca}
			vertices[vbase + 3] = {x0 + sx1, y1, q.s0, q.t1, cr, cg, cb, ca}
		else
			vertices[vbase + 0] = {x0, y0, q.s0, q.t0, cr, cg, cb, ca}
			vertices[vbase + 1] = {x1, y0, q.s1, q.t0, cr, cg, cb, ca}
			vertices[vbase + 2] = {x1, y1, q.s1, q.t1, cr, cg, cb, ca}
			vertices[vbase + 3] = {x0, y1, q.s0, q.t1, cr, cg, cb, ca}
		end
		indices[icount + 0] = vbase + 0
		indices[icount + 1] = vbase + 1
		indices[icount + 2] = vbase + 2
		indices[icount + 3] = vbase + 0
		indices[icount + 4] = vbase + 2
		indices[icount + 5] = vbase + 3
		vcount = vcount + 4
		icount = icount + 6
	end

	-- bold offset pattern (first pass is the main glyph; >=2 adds thickness)
	local function bold_offsets(n)
		if n <= 1 then return {{0,0}} end
		-- deterministic small diamond: right, down, down-right...
		local out = {{0,0},{bold_px,0}}
		if n >= 3 then out[#out+1] = {0, bold_px} end
		if n >= 4 then out[#out+1] = {bold_px, bold_px} end
		for i = 5, n do out[#out+1] = {i%2==0 and bold_px or 0, i<=6 and -bold_px or bold_px} end
		return out
	end

    for c in utf8_iter_fast(text) do
        if c == 9 then
            local rel = xpos[0] - tab_origin
            xpos[0] = math.floor(rel / font.tab_advance + 1) * font.tab_advance + tab_origin
            prev_cp, prev_face = 9, font.id
        elseif c == 32 then
            xpos[0] = xpos[0] + font.space_advance
            prev_cp, prev_face = 32, font.id
        elseif c == 13 then
            prev_cp, prev_face = nil, nil
        else
            local pack, base, faceIdx = findPackedGlyph(font, c)
			if not pack then
                if ensurePacked(font, c) then
                    pack, base, faceIdx = findPackedGlyph(font, c)
                end
			end

            if not pack then
                -- ultimate fallback sequence
                local fallback_list = {0xFFFD, 0x25A1, 0x003F} -- �, □, ?
                for _, fcp in ipairs(fallback_list) do
                    if ensurePacked(font, fcp) then
                        pack, base, faceIdx = findPackedGlyph(font, fcp)
                        c = fcp
                        break
                    end
                end
            end

            if not pack then
                xpos[0] = xpos[0] + getGlyphAdvance(font, c)
                prev_cp, prev_face = c, font.id
            else
                -- kerning if enabled and the previous glyph used the same face
                if kern_on and prev_cp and prev_face == faceIdx then
                    xpos[0] = xpos[0] + kernAdjust(font, faceIdx, prev_cp, c)
                end

                stbtt.GetPackedQuad(pack, font.width, font.height, c - base, xpos, ypos, quad, 0)

                local q = quad[0]
				
				-- 1) shadow pass (behind text)
				if shadow_on then
					local shadow_alpha = math.floor((shcol.a or 255) * shadow_strength * (a / 255) + 0.5)
					if shadow_alpha > 0 then
						emit_quad(q, shcol.r, shcol.g, shcol.b, math.min(255, shadow_alpha), shadow_dx, shadow_dy)
					end
				end

				-- 2) outline passes around the glyph
				if outline_on then
					local outline_alpha = math.floor((outcol.a or 255) * outline_strength * (a / 255) + 0.5)
					if outline_alpha > 0 then
						for _, offset in ipairs(outline_offsets) do
							emit_quad(q, outcol.r, outcol.g, outcol.b, math.min(255, outline_alpha), offset[1], offset[2])
						end
					end
				end

				-- 3) bold passes (includes the main pass at {0,0})
				for _, off in ipairs(bold_offsets(bold_passes)) do
					emit_quad(q, r, g, b, a, off[1], off[2])
				end

                prev_cp, prev_face = c, faceIdx
            end
        end
    end

    return vertices, indices, vcount, icount, xpos[0]
end

function M.generateTextVertices(font, text, x, y, r, g, b, a)
    local segments = parseRichText(text, r or 255, g or 255, b or 255, a or 255, font.id, font.size)
    local lines = layout_rich_text_lines(segments, font)

    -- Most UI labels are one unstyled line. Return the already-generated run
    -- arrays directly instead of copying every vertex and index through Lua
    -- tables and allocating a second pair of FFI arrays.
    if #lines == 1 and #lines[1].runs == 1 then
        local line = lines[1]
        local run = line.runs[1]
        local segment = run.segment
        local segment_font = run.font
        local run_y = y + line.ascent - run.metrics.ascent
        local vertices, indices, vertex_count, index_count, x_end =
            generateTextVerticesRaw(
                segment_font, run.text, x, run_y,
                segment.color.r, segment.color.g, segment.color.b, segment.color.a,
                {
                    kern = segment.kern,
                    tab_origin = x,
                    italic = segment.italic,
                    bold = segment.bold,
                    shadow = segment.shadow,
                    shadow_strength = segment.shadow_strength,
                    shadow_color = segment.shadow_color,
                    shadow_dx = segment.shadow_dx,
                    shadow_dy = segment.shadow_dy,
                    outline = segment.outline,
                    outline_size = segment.outline_size,
                    outline_strength = segment.outline_strength,
                    outline_color = segment.outline_color,
                    italic_shear = STYLE.italic_shear,
                    bold_passes = STYLE.bold_passes,
                    bold_px = STYLE.bold_px,
                }
            )
        flushAtlas(segment_font)
        local decorations = {}
        if segment.strike and x_end > x then
            decorations[1] = {
                x1 = x,
                x2 = x_end,
                y = y + line.ascent - run.metrics.ascent * 0.34,
                h = math.max(1, math.floor(segment_font.size * 0.06 + 0.5)),
                color = segment.color,
            }
        end
        local batches = {}
        if vertex_count > 0 and index_count > 0 then
            batches[1] = {
                texture = segment_font.texture,
                vertices = vertices,
                indices = indices,
                vertCount = vertex_count,
                idxCount = index_count,
            }
        end
        return vertices, indices, vertex_count, index_count, decorations, batches
    end

    local verts, inds = {}, {}
    local run_meshes, decorations = {}, {}
    local totalVcount, totalIcount = 0, 0
    local line_top = y

    for _, line in ipairs(lines) do
        local cursor_x = x
        local common_baseline = line_top + line.ascent

        for _, run in ipairs(line.runs) do
            local segment = run.segment
            local segment_font = run.font
            local run_y = common_baseline - run.metrics.ascent
            local run_start_x = cursor_x
            local seg_verts, seg_inds, vert_count, index_count, x_end =
                generateTextVerticesRaw(
                    segment_font,
                    run.text,
                    cursor_x,
                    run_y,
                    segment.color.r,
                    segment.color.g,
                    segment.color.b,
                    segment.color.a,
                    {
                        kern = segment.kern,
                        tab_origin = x,
                        italic = segment.italic,
                        bold = segment.bold,
                        shadow = segment.shadow,
                        shadow_strength = segment.shadow_strength,
                        shadow_color = segment.shadow_color,
                        shadow_dx = segment.shadow_dx,
                        shadow_dy = segment.shadow_dy,
                        outline = segment.outline,
                        outline_size = segment.outline_size,
                        outline_strength = segment.outline_strength,
                        outline_color = segment.outline_color,
                        italic_shear = STYLE.italic_shear,
                        bold_passes = STYLE.bold_passes,
                        bold_px = STYLE.bold_px,
                    }
                )

            if vert_count > 0 and index_count > 0 then
                run_meshes[#run_meshes + 1] = {
                    font = segment_font,
                    vertices = seg_verts,
                    indices = seg_inds,
                    vertCount = vert_count,
                    idxCount = index_count,
                }
                for i = 0, vert_count - 1 do
                    verts[#verts + 1] = seg_verts[i]
                end
                for i = 0, index_count - 1 do
                    inds[#inds + 1] = seg_inds[i] + totalVcount
                end

                totalVcount = totalVcount + vert_count
                totalIcount = totalIcount + index_count
            end

            cursor_x = x_end

            if segment.strike and cursor_x > run_start_x then
                local strike_y = common_baseline - run.metrics.ascent * 0.34
                local thickness = math.max(1, math.floor(segment_font.size * 0.06 + 0.5))
                decorations[#decorations + 1] = {
                    x1 = run_start_x,
                    x2 = cursor_x,
                    y = strike_y,
                    h = thickness,
                    color = segment.color,
                }
            end
        end

        line_top = line_top + line.advance
    end

    -- Text measurement can discover several new Unicode glyphs in an atlas.
    -- Upload each font atlas once per text draw, after all glyph packing, rather
    -- than converting and uploading the entire atlas once for every codepoint.
    local flushed_fonts = { [font] = true }
    flushAtlas(font)
    for _, line in ipairs(lines) do
        for _, run in ipairs(line.runs) do
            local run_font = run.font
            if not flushed_fonts[run_font] then
                flushAtlas(run_font)
                flushed_fonts[run_font] = true
            end
        end
    end

    local vertices = ffi.new("Vertex[?]", totalVcount)
    local indices = ffi.new("uint16_t[?]", totalIcount)
    for i = 1, totalVcount do vertices[i - 1] = verts[i] end
    for i = 1, totalIcount do indices[i - 1] = inds[i] end

    local batches = {}
    local first_font
    local multiple_fonts = false
    for _, mesh in ipairs(run_meshes) do
        if not first_font then
            first_font = mesh.font
        elseif mesh.font ~= first_font then
            multiple_fonts = true
            break
        end
    end

    if #run_meshes > 0 and not multiple_fonts then
        batches[1] = {
            texture = first_font.texture,
            vertices = vertices,
            indices = indices,
            vertCount = totalVcount,
            idxCount = totalIcount,
        }
    elseif multiple_fonts then
        for _, mesh in ipairs(run_meshes) do
            local batch = batches[#batches]
            if not batch or batch.font ~= mesh.font then
                batch = {
                    font = mesh.font,
                    texture = mesh.font.texture,
                    vertices = {},
                    indices = {},
                    vertCount = 0,
                    idxCount = 0,
                }
                batches[#batches + 1] = batch
            end

            for i = 0, mesh.vertCount - 1 do
                batch.vertices[#batch.vertices + 1] = mesh.vertices[i]
            end
            for i = 0, mesh.idxCount - 1 do
                batch.indices[#batch.indices + 1] = mesh.indices[i] + batch.vertCount
            end
            batch.vertCount = batch.vertCount + mesh.vertCount
            batch.idxCount = batch.idxCount + mesh.idxCount
        end
    end

    for _, batch in ipairs(batches) do
        if batch.font then
        local batch_vertices = ffi.new("Vertex[?]", batch.vertCount)
        local batch_indices = ffi.new("uint16_t[?]", batch.idxCount)
        for i = 1, batch.vertCount do batch_vertices[i - 1] = batch.vertices[i] end
        for i = 1, batch.idxCount do batch_indices[i - 1] = batch.indices[i] end
        batch.vertices = batch_vertices
        batch.indices = batch_indices
        batch.font = nil
        end
    end

    return vertices, indices, totalVcount, totalIcount, decorations, batches
end

function M.addFont(path, alias)
    if type(path) ~= "string" or path == "" then return nil end
    local font_id = M.id(path)
    if font_id ~= nil and alias then
        local normalized_alias = normalize_font_alias(alias)
        if normalized_alias then font_aliases[normalized_alias] = font_id end
    end
    return font_id
end

function M.shutdown()
    for _, size_map in pairs(font_cache) do
        for _, font in pairs(size_map) do
            release_font(font)
        end
    end

    font_cache = {}
    font_cache_clock = 0
    M.clearMeasureCache()
end

return M
