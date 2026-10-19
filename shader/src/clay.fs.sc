$input v_texcoord0, v_color0
#include "common.sh"

SAMPLER2D(s_texColor, 0);

// u_rcParams = (featherPx, invW, invH, mode)
// mode: 0 = fill, 1 = rounded border ring, 2 = flat edge border
uniform vec4 u_rcParams;
uniform vec4 u_rcCorner;  // (tl, tr, br, bl) in pixels
uniform vec4 u_rcBorder;  // (left, right, top, bottom) in pixels
uniform vec4 u_borderColor;

float sdRoundRect(vec2 p, vec2 b, vec4 r)
{
    // Texture UVs grow downwards, so p.y < 0 is the top half of the element.
    float rx = (p.y < 0.0) ? (p.x > 0.0 ? r.y : r.x)
                           : (p.x > 0.0 ? r.z : r.w);
    rx = max(rx, 0.0);
    vec2 q = abs(p) - b + vec2_splat(rx);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rx;
}

void main()
{
    vec2 uv = v_texcoord0;
    vec4 base = texture2D(s_texColor, uv) * v_color0;

    float feather = u_rcParams.x;
    float invW = u_rcParams.y;
    float invH = u_rcParams.z;
    float mode = u_rcParams.w;

    vec2 sizePx = vec2(invW > 0.0 ? 1.0 / invW : 0.0,
                       invH > 0.0 ? 1.0 / invH : 0.0);
    vec2 pos = (uv - 0.5) * sizePx;
    vec2 ext = sizePx * 0.5;
    float maxRadius = min(ext.x, ext.y);
    vec4 radius = clamp(u_rcCorner, vec4_splat(0.0), vec4_splat(maxRadius));
    vec4 borders = u_rcBorder;

    float distOuter = sdRoundRect(pos, ext, radius);
    float featherPx = max(feather, 0.001);
    float halfFeatherPx = featherPx * 0.5;
    float insideOuter = 1.0 - smoothstep(-halfFeatherPx, halfFeatherPx, distOuter);

    if (mode < 0.5)
    {
        base.a *= insideOuter;
        gl_FragColor = base;
        return;
    }

    if (mode < 1.5)
    {
        float avgBorderPx = (u_rcBorder.x + u_rcBorder.y +
                             u_rcBorder.z + u_rcBorder.w) * 0.25;
        // Keep both antialiased edges on the same signed-distance contour.
        // The border lies inside the outer edge, so its inner edge is d + t.
        float distInner = distOuter + avgBorderPx;
        float innerMask = 1.0 - smoothstep(-halfFeatherPx, halfFeatherPx, distInner);
        float borderMask = clamp(insideOuter - innerMask, 0.0, 1.0);

        vec4 color = u_borderColor;
        color.a *= borderMask;
        gl_FragColor = color;
        return;
    }

    float leftMask = step(pos.x, -ext.x + borders.x);
    float rightMask = step(ext.x - borders.y, pos.x);
    float topMask = step(pos.y, -ext.y + borders.z);
    float bottomMask = step(ext.y - borders.w, pos.y);
    float edgeMask = clamp(leftMask + rightMask + topMask + bottomMask, 0.0, 1.0);
    edgeMask *= insideOuter;

    vec4 color = u_borderColor;
    color.a *= edgeMask;
    gl_FragColor = color;
}
