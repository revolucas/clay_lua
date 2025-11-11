local ffi = require("ffi")
local bit = require("bit")
local band, bor, lshift = bit.band, bit.bor, bit.lshift

local utf8 = require("utf8")
local bgfx = require("ffi.ffi_bgfx")

local window = require("window")
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

-- Faux style defaults (tweak to taste)
local STYLE = {
  italic_shear   = -0.22,  -- tan(~12.5°)
  bold_passes    = 2,     -- 1 = off, >=2 thickens
  bold_px        = 1.0,   -- pixel offset per pass
  shadow		 = false,  -- override, always on
  shadow_dx      = 1.5,
  shadow_dy      = 1.5,
  shadow_color   = {r=0, g=0, b=0, a=160},
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
    for i = 0, count - 1 do
        local v = font.atlas_pixels[i]
        font.rgba[i * 4 + 0] = v
        font.rgba[i * 4 + 1] = v
        font.rgba[i * 4 + 2] = v
        font.rgba[i * 4 + 3] = v
    end

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
                flushAtlas(font)
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
    flushAtlas(font)

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

    if not font_cache[font_id] then
        font_cache[font_id] = {}
    elseif font_cache[font_id][font_size] then
        return font_cache[font_id][font_size]
    end

    -- Load primary font file (requested face)
    local file = assert(io.open(filename, "rb"), "Font file not found: " .. filename)
    local fontDataStr = file:read("*a")
    file:close()

    local fontData = ffi.new("uint8_t[?]", #fontDataStr)
    ffi.copy(fontData, fontDataStr, #fontDataStr)

    local atlasWidth, atlasHeight = 2048, 2048
    local atlasPixels = ffi.new("uint8_t[?]", atlasWidth * atlasHeight)
    local packContext = ffi.new("stbtt_pack_context[1]")

    assert(stbtt.PackBegin(packContext, atlasPixels, atlasWidth, atlasHeight, 0, 1, nil) ~= 0, "PackBegin failed")
    
    stbtt.PackSetOversampling(packContext, 2, 2)

    -- Bake ASCII range (32–126) from the requested face
    local firstChar, numChars = 32, 95
    local glyphs = ffi.new("stbtt_packedchar[?]", numChars)
    assert(stbtt.PackFontRange(packContext, fontData, 0, font_size, firstChar, numChars, glyphs) ~= 0, "PackFontRange failed")

    -- Convert grayscale -> RGBA
    local rgba = ffi.new("uint8_t[?]", atlasWidth * atlasHeight * 4)
    for i = 0, atlasWidth * atlasHeight - 1 do
        local v = atlasPixels[i]
        rgba[i * 4 + 0] = v
        rgba[i * 4 + 1] = v
        rgba[i * 4 + 2] = v
        rgba[i * 4 + 3] = v
    end

	-- make a mutable texture
    local mem = bgfx.bgfx_copy(rgba, atlasWidth * atlasHeight * 4)
    local tex = bgfx.bgfx_create_texture_2d(atlasWidth, atlasHeight, false, 1, bgfx.BGFX_TEXTURE_FORMAT_RGBA8, bgfx.BGFX_SAMPLER_POINT, nil)
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
        faces = {} -- donor/primary faces cache by faceIdx
    }

    -- make sure primary face is cached
    font.faces[font_id] = { data = font.data, info = font.info, scale = font.scale }

    -- space/tab advance from primary
    font.space_advance = getGlyphAdvance(font, 32)
    font.tab_advance   = font.space_advance * 4

    font_cache[font_id][font_size] = font
    return font
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

-- reusable tables to avoid churn
local colorStack   = {}
local fontStack    = {}
local sizeStack    = {}
local buf = {}

-- Rich text -> segments
-- Supports:
--   [color=#RRGGBB[AA]] ... [/color]
--   [font=ID] ... [/font]
--   [size=PX] ... [/size]
--   [kerning=on|off]
--   [cp=0xHEX]  or  [u+XXXX] (inject cp)
--   [br] (newline)
--   [b] [/b], [i] [/i], [strike] [/strike]  (flags kept in segment; not drawn here)
--   Literal [[ -> '[' in text
local function parseRichText(text, r, g, b, a, baseFontId, baseFontSize)
    local segments = {}

    -- stacks
	colorStack[1] = {r=r, g=g, b=b, a=a}
	fontStack[1] = baseFontId
	sizeStack[1] = baseFontSize

    local kernOn       = true
    local bold, italic, strike, shadow = false, false, false, false

    local function curColor() return colorStack[#colorStack] end
    local function curFont()  return fontStack[#fontStack] end
    local function curSize()  return sizeStack[#sizeStack] end

    -- make a segment with current state
    local function push_text(t)
        if #t == 0 then return end
        table.insert(segments, {
            text   = t,
            color  = { r=curColor().r, g=curColor().g, b=curColor().b, a=curColor().a },
            fontId = curFont(),
            fontSize = curSize(),
            kern   = kernOn,
            bold   = bold, italic = italic, strike = strike, shadow = shadow
        })
    end

    -- scan
    local i, n = 1, #text
    local function flush()
        if #buf > 0 then
            push_text(table.concat(buf))
            for j=#buf, 1, -1 do
				table.remove(buf,j)
            end
        end
    end

    while i <= n do
        local c = text:sub(i,i)

        -- escape "["
        if c == "[" then
            if text:sub(i,i+1) == "[[" then
                table.insert(buf, "[")
                i = i + 2
            else
				local s, e = text:find("%b[]", i)
				if s == i and e then
					local raw = text:sub(i+1, e-1)                 -- content without [ ]
					local is_close = raw:match("^%s*/") ~= nil     -- starts with '/'
					raw = raw:gsub("^%s*/%s*", "")                -- remove leading '/'
					raw = raw:match("^%s*(.-)%s*$") or raw         -- trim

					-- cmd[=value] parse (value optional)
					local cmd, value = raw:match("^([%w_]+)%s*=%s*(.-)%s*$")
					if not cmd then cmd, value = raw, nil end
					cmd = (cmd or ""):lower()

					if is_close then
						-- ---------- closing tags ----------
						flush()
						if     cmd == "color"  then if #colorStack > 1 then table.remove(colorStack) end
						elseif cmd == "font"   then if #fontStack  > 1 then table.remove(fontStack)  end
						elseif cmd == "size"   then if #sizeStack  > 1 then table.remove(sizeStack)  end
						elseif cmd == "b"      then bold   = false
						elseif cmd == "i"      then italic = false
						elseif cmd == "strike" then strike = false
						elseif cmd == "shadow" then shadow = false
						-- [/kerning] -> restore default-on (optional)
						elseif cmd == "kerning" then kernOn = true
						else
							-- unknown close tag -> ignore
						end
					else
						-- ---------- opening / self-closing ----------
						if cmd == "color" and value then
							flush()
							local rr, gg, bb, aa = parse_hex_color(value, curColor().a)
							table.insert(colorStack, {r=rr, g=gg, b=bb, a=aa})
						elseif cmd == "font" and value then
							flush()
							local fid = tonumber(value) or curFont()
							table.insert(fontStack, fid)
						elseif cmd == "size" and value then
							flush()
							local px = tonumber(value) or curSize()
							table.insert(sizeStack, px)
						elseif cmd == "kerning" and value then
							flush()
							local v = value:lower()
							kernOn = (v == "on" or v == "true" or v == "1")
						elseif cmd == "b" then
							flush(); bold = true
						elseif cmd == "i" then
							flush(); italic = true
						elseif cmd == "strike" then
							flush(); strike = true
						elseif cmd == "shadow" then
						  flush(); shadow = true
						elseif cmd == "br" then
							table.insert(buf, "\n")
						elseif cmd == "cp" and value then
							flush()
							local cp = tonumber(value) or (value:match("^0x%x+$") and tonumber(value))
							if cp then push_text(utf8.char(cp)) end
						else
							-- [u+XXXX] or [U+XXXX]
							local up = raw:match("^[Uu]%+([%x]+)$")
							if up then
								flush()
								local cp = tonumber("0x"..up)
								if cp then push_text(utf8.char(cp)) end
							else
								-- unknown tag -> treat literally
								table.insert(buf, text:sub(i, e))
							end
						end
					end

					i = e + 1
				else
					-- stray '['
					table.insert(buf, c)
					i = i + 1
				end
            end
        else
            table.insert(buf, c)
            i = i + 1
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

function M.measureText(text, config, skip_tags)
    local font_id  = config.fontId
    local font_px  = config.fontSize
    local key = string.format("%d:%d:%s", font_id, font_px, text)
    local cached = measure_cache[key]
    if cached then return cached[1], cached[2] end

    local baseFont = M.load(font_id, font_px)
    if not baseFont then return 0, 0 end

    local clean_segments
    if skip_tags then
        clean_segments = { { text = text, color={r=255,g=255,b=255,a=255}, fontId=font_id, fontSize=font_px, kern=true } }
    else
        clean_segments = parseRichText(text, 255,255,255,255, font_id, font_px)
    end

    local totalWidth, totalHeight = 0, 0
    local lineWidth = 0
    local lineAscent, lineDescent, lineGap = 0, 0, 0
    local lineAdvance = 0

    local function set_line_metrics(fnt)
        local a = ffi.new("int[1]"); local d = ffi.new("int[1]"); local g = ffi.new("int[1]")
        stbtt.GetFontVMetrics(fnt.info, a, d, g)
        lineAscent  = a[0] * fnt.scale
        lineDescent = d[0] * fnt.scale
        lineGap     = g[0] * fnt.scale
        lineAdvance = (lineAscent - lineDescent + lineGap)
    end
    set_line_metrics(baseFont)

    local prev_cp, prev_face = nil, nil
    local xpos = 0

    for _, seg in ipairs(clean_segments) do
        local segFont = ((seg.fontId ~= font_id or seg.fontSize ~= font_px) and M.load(seg.fontId, seg.fontSize)) or baseFont
        if segFont ~= baseFont then
            set_line_metrics(segFont)
        end

        for cp in utf8_iter_fast(seg.text) do
            if cp == 10 then -- newline
                if lineWidth > totalWidth then totalWidth = lineWidth end
                totalHeight = totalHeight + lineAdvance
                xpos = 0; lineWidth = 0
                prev_cp, prev_face = nil, nil
            elseif cp == 9 then -- tab
                local rel = xpos
                xpos = math.floor(rel / segFont.tab_advance + 1) * segFont.tab_advance
                lineWidth = xpos
                prev_cp, prev_face = 9, segFont.id
            elseif cp == 32 then -- space
                xpos = xpos + segFont.space_advance
                lineWidth = xpos
                prev_cp, prev_face = 32, segFont.id
            else
                -- ensure glyph available in this font or donors
                ensurePacked(segFont, cp)
                local pack, base, faceIdx = findPackedGlyph(segFont, cp)

                -- kerning (same face only, if enabled)
                if seg.kern and prev_cp and prev_face == faceIdx then
                    xpos = xpos + kernAdjust(segFont, faceIdx, prev_cp, cp)
                end

                -- advance by glyph
                xpos = xpos + getGlyphAdvanceFace(segFont, faceIdx or segFont.id, cp)
                lineWidth = xpos
                prev_cp, prev_face = cp, faceIdx or segFont.id
            end
        end
    end

    if lineWidth > totalWidth then totalWidth = lineWidth end
    -- at least one line height
    if totalHeight == 0 then totalHeight = lineAdvance end

    measure_cache[key] = { totalWidth, totalHeight }
    return totalWidth, totalHeight
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
    local italic_shear   = (style.italic and (style.italic_shear or STYLE.italic_shear)) or 0
	local bold_passes    = (style.bold and (style.bold_passes  or STYLE.bold_passes)) or 1
	if bold_passes < 1 then bold_passes = 1 end
	local bold_px        = style.bold_px or STYLE.bold_px
	local shadow_on      = style.shadow == true or STYLE.shadow == true
	local shadow_dx      = (style.shadow_dx or STYLE.shadow_dx)
	local shadow_dy      = (style.shadow_dy or STYLE.shadow_dy)
	local shcol          = style.shadow_color or STYLE.shadow_color

    -- Each printable codepoint can emit up to:
    --   shadow_on ? 1 : 0  (shadow)  +  bold_passes  (main + extra bold offsets)
    local max_passes_per_cp = bold_passes + (shadow_on and 1 or 0)

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
            local rel = xpos[0] - x
            xpos[0] = math.floor(rel / font.tab_advance + 1) * font.tab_advance + x
            prev_cp, prev_face = 9, font.id
        elseif c == 32 then
            xpos[0] = xpos[0] + font.space_advance
            prev_cp, prev_face = 32, font.id
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
                -- kerning if same face
                if prev_cp and prev_face == faceIdx then
                    xpos[0] = xpos[0] + kernAdjust(font, faceIdx, prev_cp, c)
                end

                stbtt.GetPackedQuad(pack, font.width, font.height, c - base, xpos, ypos, quad, 0)

                local q = quad[0]
				
				-- 1) shadow pass (behind text)
				if shadow_on then
					emit_quad(q, shcol.r, shcol.g, shcol.b, shcol.a, shadow_dx, shadow_dy)
				end

				-- 2) bold passes (includes the main pass at {0,0})
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
    -- parse into segments with base font & color
    local segments = parseRichText(text, r or 255, g or 255, b or 255, a or 255, font.id, font.size)
    local verts, inds = {}, {}
    local cursorX, cursorY = x, y
    local totalVcount, totalIcount = 0, 0
    
    local decorations = {}
	local lastSliceX = x

	local function append(segFont, segText, segColor, segFlags)
		local segVerts, segInds, vcount, icount, xEnd =
			generateTextVerticesRaw(
				segFont, segText, cursorX, cursorY,
				segColor.r, segColor.g, segColor.b, segColor.a,
				{
					italic = segFlags.italic,
					bold   = segFlags.bold,
					shadow = segFlags.shadow,     -- requires parser tag or you can force true here
					strike = segFlags.strike,     -- handled as decoration below
					italic_shear = STYLE.italic_shear,
					bold_passes  = STYLE.bold_passes,
					bold_px      = STYLE.bold_px,
					shadow_dx    = STYLE.shadow_dx,
					shadow_dy    = STYLE.shadow_dy,
					shadow_color = STYLE.shadow_color,
				}
			)

		for i = 0, vcount - 1 do verts[#verts+1] = segVerts[i] end
		for i = 0, icount - 1 do inds[#inds+1] = segInds[i] + totalVcount end

		totalVcount = totalVcount + vcount
		totalIcount = totalIcount + icount
		cursorX = xEnd

		-- record strike decoration for this slice
		if segFlags.strike then
			local a = ffi.new("int[1]"); local d = ffi.new("int[1]"); local g = ffi.new("int[1]")
			stbtt.GetFontVMetrics(segFont.info, a, d, g)
			local ascent = a[0]*segFont.scale
			local topY   = cursorY + ascent - ascent         -- same as baseline - ascent
			-- position the strike line ~34% down from the top of the em box
			local strikeY = cursorY + ascent * (1.0 - 0.34)
			local thick   = math.max(1, math.floor(segFont.size * 0.06 + 0.5))
			decorations[#decorations+1] = {x1 = lastSliceX, x2 = cursorX, y = strikeY, h = thick, color = segColor}
		end
	end

    local baseLineAdvance
    do
        local a = ffi.new("int[1]"); local d = ffi.new("int[1]"); local g = ffi.new("int[1]")
        stbtt.GetFontVMetrics(font.info, a, d, g)
        baseLineAdvance = (a[0]*font.scale - d[0]*font.scale + g[0]*font.scale)
    end

    for _, seg in ipairs(segments) do
        local segFont = ((seg.fontId ~= font.id or seg.fontSize ~= font.size) and M.load(seg.fontId, seg.fontSize)) or font

        -- split on '\n' so we can jump lines between chunks
        local start = 1
        while true do
            local nl = seg.text:find("\n", start, true)
            local slice = nl and seg.text:sub(start, nl-1) or seg.text:sub(start)
			
			if #slice > 0 then
				lastSliceX = cursorX
				append(segFont, slice, seg.color, seg)
			end

            if not nl then break end
            -- newline: reset x and advance y by this segment's line height
            local a = ffi.new("int[1]"); local d = ffi.new("int[1]"); local g = ffi.new("int[1]")
            stbtt.GetFontVMetrics(segFont.info, a, d, g)
            local lineAdvance = (a[0]*segFont.scale - d[0]*segFont.scale + g[0]*segFont.scale)
            cursorX = x
            cursorY = cursorY + lineAdvance
            start = nl + 1
        end
    end

    -- to ffi buffers
    local vbuffer = ffi.new("Vertex[?]", totalVcount)
    local ibuffer = ffi.new("uint16_t[?]", totalIcount)
    for i = 1, totalVcount do vbuffer[i-1] = verts[i] end
    for i = 1, totalIcount do ibuffer[i-1] = inds[i] end

    return vbuffer, ibuffer, totalVcount, totalIcount, decorations
end

function M.addFont(path)
    table.insert(fonts, path)
end

function M.shutdown()
    for _, size_map in pairs(font_cache) do
        for _, font in pairs(size_map) do
            if font.pack_context ~= nil then
                stbtt.PackEnd(font.pack_context)
                font.pack_context = nil
            end

            if font.texture ~= nil and font.texture.idx ~= INVALID_HANDLE then
                bgfx.bgfx_destroy_texture(font.texture)
                font.texture = nil
            end

            if font.faces then
                for key in pairs(font.faces) do
                    font.faces[key] = nil
                end
                font.faces = nil
            end

            font.data = nil
            font.info = nil
            font.atlas_pixels = nil
            font.rgba = nil
            font.glyphs = nil
            font.glyphs_first = nil
            font.glyphs_count = nil
            font.glyphs_face = nil
        end
    end

    font_cache = {}
end

return M
