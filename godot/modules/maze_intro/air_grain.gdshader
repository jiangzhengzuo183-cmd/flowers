shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float gain = 0.0;
void vertex(){
    vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
    MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(INV_VIEW_MATRIX[0].xyz*scale.x,0),vec4(INV_VIEW_MATRIX[1].xyz*scale.y,0),vec4(INV_VIEW_MATRIX[2].xyz*scale.z,0),MODEL_MATRIX[3]);
}
void fragment(){
    float grain=1.0-smoothstep(0.24,0.5,length((UV-0.5)*vec2(1.0,1.3)));
    float near_fade=smoothstep(0.12,0.45,-VERTEX.z);
    ALBEDO=COLOR.rgb;
    ALPHA=grain*COLOR.a*gain*near_fade;
    if(ALPHA<0.004)discard;
}
