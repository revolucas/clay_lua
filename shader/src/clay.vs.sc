$input a_position, a_texcoord0, a_color0
$output v_texcoord0, v_color0

#include "common.sh"

uniform vec4 u_transform2D;

void main()
{
    vec2 position = a_position.xy * u_transform2D.xy + u_transform2D.zw;
    gl_Position = mul(u_modelViewProj, vec4(position, 0.0, 1.0));
    v_texcoord0 = a_texcoord0;
    v_color0 = a_color0;
}
