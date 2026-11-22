shader_type canvas_item;
render_mode unshaded;
// Remove thin colored matte remnants at the transparency edge only.
// Artwork colors and the original warm brown outline are kept unchanged.
void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.5;
    float coverage = min(original.a, min(
        min(texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a,
            texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a),
        min(texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a,
            texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a)));
    bool red_matte = original.r > 0.6 && original.r > original.g * 2.6 && original.r > original.b * 2.6;
    bool green_matte = original.g > 0.55 && original.g > original.r * 1.6 && original.g > original.b * 1.7;
    bool yellow_matte = coverage < 0.99 && original.g > 0.8 && original.g > original.r * 0.96 && original.b < 0.25;
    float alpha = smoothstep(0.06, 0.88, coverage);
    if (red_matte || green_matte || yellow_matte) { alpha = 0.0; }
    COLOR = vec4(original.rgb, original.a * alpha);
}
