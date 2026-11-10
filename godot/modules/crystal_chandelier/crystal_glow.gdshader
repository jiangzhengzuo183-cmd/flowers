shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 light_color : source_color = vec4(1.0, 0.87, 0.69, 1.0);
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
uniform float emission_strength : hint_range(0.0, 4.0) = 1.15;
varying vec3 model_position;

void vertex() {
    model_position = VERTEX;
}

void fragment() {
    vec3 base = texture(base_texture, UV).rgb;
    // Coordinates belong to the untouched source mesh, before wrapper scaling.
    // Only the eight flame-shaped bulb tips sit outside r=28 above y=39.5.
    float bulbs = smoothstep(28.0, 31.0, length(model_position.xz));
    bulbs *= smoothstep(39.3, 40.6, model_position.y);
    bulbs *= 1.0 - smoothstep(46.0, 48.0, model_position.y);
    ALBEDO = mix(base, light_color.rgb, bulbs * 0.28 * min(brightness, 1.0));
    ROUGHNESS = 0.9;
    METALLIC = 0.0;
    EMISSION = light_color.rgb * bulbs * emission_strength * brightness;
}
