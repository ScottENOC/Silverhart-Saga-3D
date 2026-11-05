shader_type spatial;
render_mode cull_back;

uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool use_base_texture = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 secondary_colour : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform int fabric_mode : hint_enum("Solid", "Linen", "Wool", "Leather", "Open weave") = 0;
uniform float pattern_scale = 90.0;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.18;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec4 base = use_base_texture ? texture(base_texture, UV) : vec4(1.0);
    vec3 colour = base.rgb * tint.rgb;
    vec2 p = UV * pattern_scale;

    if (fabric_mode == 1) {
        float warp = 0.5 + 0.5 * sin(p.x * 6.28318);
        float weft = 0.5 + 0.5 * sin(p.y * 6.28318);
        colour *= mix(0.88, 1.08, (warp + weft) * 0.5);
    } else if (fabric_mode == 2) {
        float fleck = hash21(floor(p));
        colour = mix(colour, colour * mix(0.72, 1.18, fleck), pattern_strength);
    } else if (fabric_mode == 3) {
        float grain = 0.5 + 0.5 * sin(p.x * 0.45 + sin(p.y * 0.08) * 2.0);
        colour *= mix(0.82, 1.12, grain);
    } else if (fabric_mode == 4) {
        vec2 cell = fract(p / 4.0);
        float hole = step(0.38, cell.x) * step(0.38, cell.y);
        colour = mix(colour, secondary_colour.rgb, hole * pattern_strength);
        ALPHA = base.a * tint.a * (1.0 - hole * 0.72);
    }

    ALBEDO = colour;
    if (fabric_mode != 4) {
        ALPHA = base.a * tint.a;
    }
    ROUGHNESS = fabric_mode == 3 ? 0.78 : 0.62;
}
