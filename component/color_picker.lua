-- component/color_picker_tex.lua
-- HSV(A) color picker using a mutable bgfx texture passed via clay.image.imageData.
-- No per-pixel Clay elements; we rasterize into textures and update them when H/S/V/A change.
--
-- API:
--   local rgba, changed, hsva = color_picker_tex(id, rgba, opts)
--     opts = {
--       width=260, height=180, pad=6, barWidth=18, showAlpha=true,
--       cornerRadius=6,
--       sampleSV=1.0,        -- internal sampling scale (1.0 = 1:1 pixels)
--     }
--
local ffi  = require("ffi")
local bgfx = require("ffi.ffi_bgfx")
local glfw = require("ffi.ffi_glfw")

local _state = _state or {} -- per-id: {h,s,v,a, lastDown, drag, svTex,hTex,aTex, svW,svH, hW,hH, aW,aH, svBuf,hBuf,aBuf}

local function clamp(x,a,b) if x<a then return a elseif x>b then return b end; return x end

local function hsv_to_rgb(h, s, v)
    h = (h % 1.0) * 6.0
    local i = math.floor(h)
    local f = h - i
    local p = v * (1.0 - s)
    local q = v * (1.0 - s * f)
    local t = v * (1.0 - s * (1.0 - f))
    local r,g,b
    if i == 0 then r,g,b = v,t,p
    elseif i == 1 then r,g,b = q,v,p
    elseif i == 2 then r,g,b = p,v,t
    elseif i == 3 then r,g,b = p,q,v
    elseif i == 4 then r,g,b = t,p,v
    else r,g,b = v,p,q end
    return math.floor(r*255+0.5), math.floor(g*255+0.5), math.floor(b*255+0.5)
end

local INVALID = 0xFFFF

local function is_valid(h)
  return h ~= nil and h.idx ~= INVALID
end

local function ensure_tex(w, h, handle, buf)
  if is_valid(handle) then
    return handle, buf
  end
  local fmt = bgfx.BGFX_TEXTURE_FORMAT_RGBA8
  local tex = bgfx.bgfx_create_texture_2d(w, h, false, 1, fmt, 0, nil)
  local pixels = ffi.new("uint8_t[?]", w*h*4)
  return tex, pixels
end

local function resize_tex(tex, buf, w, h)
  if is_valid(tex) then
    bgfx.bgfx_destroy_texture(tex)
  end
  local fmt = bgfx.BGFX_TEXTURE_FORMAT_RGBA8
  local t = bgfx.bgfx_create_texture_2d(w, h, false, 1, fmt, 0, nil)
  local b = ffi.new("uint8_t[?]", w*h*4)
  return t, b
end

local function upload(tex, buf, w, h)
    local mem = bgfx.bgfx_copy(buf, w*h*4)
    bgfx.bgfx_update_texture_2d(tex, 0, 0, 0, 0, w, h, mem, w*4)
end

local function raster_sv(buf, w, h, hue)
    local idx = 0
    for y=0,h-1 do
        local v = 1.0 - (y / (h-1))
        for x=0,w-1 do
            local s = (w>1) and (x / (w-1)) or 0
            local r,g,b = hsv_to_rgb(hue, s, v)
            buf[idx+0] = r; buf[idx+1] = g; buf[idx+2] = b; buf[idx+3] = 255
            idx = idx + 4
        end
    end
end

local function raster_hue(buf, w, h)
    local row = 0
    for y=0,h-1 do
        local hue = (h>1) and (y / (h-1)) or 0
        local r,g,b = hsv_to_rgb(hue, 1.0, 1.0)
        row = y*w*4
        for x=0,w-1 do
            local i = row + x*4
            buf[i+0] = r; buf[i+1] = g; buf[i+2] = b; buf[i+3] = 255
        end
    end
end

local function raster_alpha(buf, w, h, h_, s_, v_)
    local rr,gg,bb = hsv_to_rgb(h_, s_, v_)
    for y=0,h-1 do
        local a = math.floor((1.0 - (y/(h-1))) * 255 + 0.5)
        local row = y*w*4
        for x=0,w-1 do
            local i = row + x*4
            buf[i+0] = rr; buf[i+1] = gg; buf[i+2] = bb; buf[i+3] = a
        end
    end
end

local function update_textures(st, svW, svH, barW, barH, showAlpha)
    local needSV = (st.svW ~= svW or st.svH ~= svH or st._hDirty)
    local needH  = (st.hH ~= barH or st.hW ~= barW or st._hDirtyAll)
    local needA  = showAlpha and (st.aH ~= barH or st.aW ~= barW or st._aDirty or st._hsvDirty)

    if needSV then
        if not st.svTex then st.svTex, st.svBuf = ensure_tex(svW, svH) end
        if st.svW ~= svW or st.svH ~= svH then
            st.svTex, st.svBuf = resize_tex(st.svTex, st.svBuf, svW, svH)
        end
        raster_sv(st.svBuf, svW, svH, st.h)
        upload(st.svTex, st.svBuf, svW, svH)
        st.svW, st.svH = svW, svH
    end

    if needH then
        if not st.hTex then st.hTex, st.hBuf = ensure_tex(barW, barH) end
        if st.hW ~= barW or st.hH ~= barH then
            st.hTex, st.hBuf = resize_tex(st.hTex, st.hBuf, barW, barH)
        end
        raster_hue(st.hBuf, barW, barH)
        upload(st.hTex, st.hBuf, barW, barH)
        st.hW, st.hH = barW, barH
    end

    if showAlpha and needA then
        if not st.aTex then st.aTex, st.aBuf = ensure_tex(barW, barH) end
        if st.aW ~= barW or st.aH ~= barH then
            st.aTex, st.aBuf = resize_tex(st.aTex, st.aBuf, barW, barH)
        end
        raster_alpha(st.aBuf, barW, barH, st.h, st.s, st.v)
        upload(st.aTex, st.aBuf, barW, barH)
        st.aW, st.aH = barW, barH
    end

    st._hDirty, st._hDirtyAll, st._aDirty, st._hsvDirty = false, false, false, false
end

-- returns rgba, changed, hsva
function color_picker(elid, rgba_in, opts)
    opts = opts or {}
    local width      = opts.width or 260
    local height     = opts.height or 180
    local pad        = opts.pad or 6
    local barW       = opts.barWidth or 18
    local showAlpha  = (opts.showAlpha ~= false)
    local radius     = opts.cornerRadius or 6

    local key = elid.id
    local st = _state[key]
    if not st then
        local r = (rgba_in and rgba_in.r or 255)
        local g = (rgba_in and rgba_in.g or 0)
        local b = (rgba_in and rgba_in.b or 0)
        local a = (rgba_in and rgba_in.a or 255)
        -- simple RGB->HSV
        local function rgb_to_hsv(R,G,B)
            R, G, B = R/255, G/255, B/255
            local maxc = math.max(R,G,B); local minc = math.min(R,G,B)
            local v = maxc
            local d = maxc - minc
            local s = (maxc == 0) and 0 or d/maxc
            local h = 0
            if d ~= 0 then
                if maxc == R then h = ((G-B)/d)%6
                elseif maxc == G then h = ((B-R)/d)+2
                else h = ((R-G)/d)+4 end
                h = h/6
                if h < 0 then h = h + 1 end
            end
            return h, s, v
        end
        local h,s,v = rgb_to_hsv(r,g,b)
        st = {h=h,s=s,v=v,a=a/255, lastDown=false, drag=nil}
        _state[key] = st
        st._hDirty, st._hDirtyAll, st._aDirty, st._hsvDirty = true, true, true, true
    end

    -- sizes
    local innerW = width - pad*2
    local innerH = height - pad*2
    local svW = innerW - pad - barW - (showAlpha and (pad + barW) or 0)
    local svH = innerH
    if svW < 20 then svW = 20 end
    local barH = svH

    -- textures kept in st; update if needed
    update_textures(st, svW, svH, barW, barH, showAlpha)

    -- draw UI
    local svId   = clay.id("cptex-sv", key)
    local hueId  = clay.id("cptex-hue", key)
    local aId    = clay.id("cptex-alpha", key)

    clay.createElement(elid, {
        layout = {
            layoutDirection = clay.LEFT_TO_RIGHT,
            sizing = { width = clay.sizingFixed(width), height = clay.sizingFixed(height) },
            padding = clay.paddingAll(pad),
            childGap = pad
        },
        backgroundColor = {r=25,g=25,b=28,a=160},
        border = { color = {r=255,g=255,b=255,a=32}, width = {left=1,right=1,top=1,bottom=1} },
        cornerRadius = { tl=radius,tr=radius,bl=radius,br=radius }
    }, function()
        clay.createElement(svId, {
            layout = { sizing = { width = clay.sizingFixed(svW), height = clay.sizingFixed(svH) } },
            image = { imageData = st.svTex.idx }
        })

        clay.createElement(hueId, {
            layout = { sizing = { width = clay.sizingFixed(barW), height = clay.sizingFixed(barH) } },
            image = { imageData = st.hTex.idx }
        })

        if showAlpha then
            clay.createElement(aId, {
                layout = { sizing = { width = clay.sizingFixed(barW), height = clay.sizingFixed(barH) } },
                image = { imageData = st.aTex.idx }
            })
        end
    end)

    -- mouse
    glfw.GetCursorPos(device.win, mouse_x, mouse_y)
    local mx, my = mouse_x[0], mouse_y[0]
    local down = (glfw.GetMouseButton(device.win, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS)

    local bSV  = clay.getElementData(svId)
    local bH   = clay.getElementData(hueId)
    local bA   = showAlpha and clay.getElementData(aId) or {found=false}

    local overSV = bSV.found and mx>=bSV.x and mx<=bSV.x+bSV.width and my>=bSV.y and my<=bSV.y+bSV.height
    local overH  = bH.found  and mx>=bH.x and mx<=bH.x+bH.width and my>=bH.y and my<=bH.y+bH.height
    local overA  = bA.found  and mx>=bA.x and mx<=bA.x+bA.width and my>=bA.y and my<=bA.y+bA.height

    local changed = false

    if down and not st.lastDown then
        if overSV then st.drag = 'sv'
        elseif overH then st.drag = 'h'
        elseif overA then st.drag = 'a'
        else st.drag = nil end
    elseif (not down) and st.lastDown then
        st.drag = nil
    end

    if st.drag == 'sv' and bSV.found then
        local lx = clamp(mx - bSV.x, 0, bSV.width)
        local ly = clamp(my - bSV.y, 0, bSV.height)
        local s = (bSV.width>1) and (lx/(bSV.width)) or 0
        local v = 1.0 - ((bSV.height>1) and (ly/(bSV.height)) or 0)
        s = clamp(s,0,1); v = clamp(v,0,1)
        if math.abs(s-st.s)>1e-4 or math.abs(v-st.v)>1e-4 then
            st.s, st.v = s, v
            st._hsvDirty = true
            st._aDirty = true
            changed = true
        end
    elseif st.drag == 'h' and bH.found then
        local ly = clamp(my - bH.y, 0, bH.height)
        local h = (bH.height>1) and (ly/(bH.height)) or 0
        h = clamp(h, 0, 1)
        if math.abs(h-st.h)>1e-4 then
            st.h = h
            st._hDirty = true
            st._hDirtyAll = true
            st._aDirty = true
            changed = true
        end
    elseif st.drag == 'a' and showAlpha and bA.found then
        local ly = clamp(my - bA.y, 0, bA.height)
        local a = 1.0 - ((bA.height>1) and (ly/(bA.height)) or 0)
        a = clamp(a, 0, 1)
        if math.abs(a-st.a)>1e-4 then
            st.a = a
            changed = true
        end
    end

    st.lastDown = down

    -- if any dirty flags, refresh textures
    if st._hDirty or st._hDirtyAll or st._hsvDirty or st._aDirty then
        update_textures(st, svW, svH, barW, barH, showAlpha)
    end

    local r,g,b = hsv_to_rgb(st.h, st.s, st.v)
    local out = {r=r,g=g,b=b,a=math.floor(st.a*255+0.5)}
    local hsva = {h=st.h,s=st.s,v=st.v,a=st.a}

    return out, changed, hsva
end
