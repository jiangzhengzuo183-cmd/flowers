shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 light_color : source_color = vec4(1.0, 0.87, 0.69, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.32;

void vertex() {
    // Keep depth testing enabled: a solid wall can occlude this light halo.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
        INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
        INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]
    );
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    float r = length((UV - vec2(0.5)) * 2.0);
    float soft_edge = 1.0 - smoothstep(0.68, 1.0, r);
    float halo = exp(-r * r * 6.5) * soft_edge;
    ALBEDO = light_color.rgb;
    ALPHA = halo * strength;
}
