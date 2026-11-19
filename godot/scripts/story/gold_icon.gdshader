shader_type canvas_item;
render_mode unshaded;
uniform vec4 gold : source_color = vec4(0.9451,0.7451,0.2941,1.0);
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    // Keep the original icon strokes; discard the white sticker surround.
    float pale = min(sample_color.r,min(sample_color.g,sample_color.b));
    float stroke = 1.0-smoothstep(0.70,0.96,pale);
    COLOR = vec4(gold.rgb,sample_color.a*stroke);
}
