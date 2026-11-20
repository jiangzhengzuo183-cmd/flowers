shader_type canvas_item;
render_mode unshaded;
uniform vec4 gold : source_color = vec4(0.9451,0.7451,0.2941,1.0);
void fragment() {
    vec4 sample_color = texture(TEXTURE, UV);
    // Recolor strokes without removing the supplied white sticker surround.
    float pale = min(sample_color.r,min(sample_color.g,sample_color.b));
    float stroke = 1.0-smoothstep(0.70,0.96,pale);
    // Preserve the supplied white sticker edge while unifying yellow strokes.
    COLOR = vec4(mix(vec3(1.0,0.985,0.95),gold.rgb,stroke),sample_color.a);
}
