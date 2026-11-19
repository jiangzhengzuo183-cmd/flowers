shader_type canvas_item;
render_mode unshaded;
uniform sampler2D needle_layer : filter_linear, repeat_disable;
uniform sampler2D arc_layer : filter_linear, repeat_disable;
uniform sampler2D hub_layer : filter_linear, repeat_disable;
varying vec4 item_tint;
void vertex(){item_tint=COLOR;}
uniform vec4 needle_region;
uniform vec4 arc_region;
uniform vec4 hub_region;
uniform float heading = 0.0;
const vec2 image_size = vec2(1312.0,1199.0);
const vec2 pivot = vec2(640.0,574.0);
vec2 turn(vec2 p, float angle) {
    float c=cos(angle),s=sin(angle);
    return vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
vec4 over(vec4 a,vec4 b){float alpha=b.a+a.a*(1.0-b.a);return vec4((b.rgb*b.a+a.rgb*a.a*(1.0-b.a))/max(alpha,0.00001),alpha);}
void fragment(){
    vec4 base=texture(TEXTURE,UV);
    float angle=heading-atan(215.0,267.0);
    vec2 p=UV*image_size;
    vec2 needle_uv=(pivot+turn(p-pivot,-angle)/0.78-needle_region.xy)/needle_region.zw;
    vec2 arc_uv=(pivot+turn(p-pivot,-angle)-arc_region.xy)/arc_region.zw;
    base=over(base,texture(arc_layer,arc_uv));
    base=over(base,texture(needle_layer,needle_uv));
    vec2 hub_uv=(p-hub_region.xy)/hub_region.zw;
    COLOR=over(base,texture(hub_layer,hub_uv))*item_tint;
}
