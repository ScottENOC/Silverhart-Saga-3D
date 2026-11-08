shader_type spatial;
render_mode cull_back;

uniform vec4 field_colour : source_color = vec4(0.62, 0.08, 0.08, 1.0);
uniform vec4 secondary_colour : source_color = vec4(0.90, 0.82, 0.60, 1.0);
uniform vec4 emblem_colour : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform int field_pattern : hint_range(0, 5) = 0;
// 0 none, 1 roundel, 2 cross, 3 lozenge, 4 star, 5 tree.
uniform int emblem : hint_range(0, 5) = 0;
uniform float border_width : hint_range(0.0, 0.18) = 0.035;
uniform float roughness_value : hint_range(0.2, 1.0) = 0.78;

float sd_box(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
float sd_diamond(vec2 p, float r) {
    return (abs(p.x) + abs(p.y) - r) * 0.7071;
}
float sd_star(vec2 p) {
    float a = atan(p.y, p.x);
    float r = length(p);
    float edge = 0.105 + 0.045 * cos(5.0 * a);
    return r - edge;
}
void fragment() {
    vec2 uv = UV;
    vec2 p = uv - vec2(0.5);
    vec4 colour = field_colour;
    if (field_pattern == 1 && uv.x > 0.5) colour = secondary_colour;
    if (field_pattern == 2 && uv.y > 0.5) colour = secondary_colour;
    if (field_pattern == 3 && abs(p.x + p.y) < 0.12) colour = secondary_colour;
    if (field_pattern == 4 && abs(p.x) < 0.12) colour = secondary_colour;
    if (field_pattern == 5 && abs(p.y) < 0.12) colour = secondary_colour;
    float edge = min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y));
    if (border_width > 0.0 && edge < border_width) colour = secondary_colour;

    float emblem_distance = 10.0;
    if (emblem == 1) emblem_distance = length(p) - 0.16;
    if (emblem == 2) emblem_distance = min(sd_box(p, vec2(0.045, 0.22)), sd_box(p, vec2(0.22, 0.045)));
    if (emblem == 3) emblem_distance = sd_diamond(p, 0.24);
    if (emblem == 4) emblem_distance = sd_star(p);
    if (emblem == 5) {
        float trunk = sd_box(p - vec2(0.0, -0.10), vec2(0.035, 0.15));
        float crown = length((p - vec2(0.0, 0.10)) * vec2(1.0, 0.82)) - 0.17;
        emblem_distance = min(trunk, crown);
    }
    if (emblem > 0 && emblem_distance < 0.0) colour = emblem_colour;
    ALBEDO = colour.rgb;
    ROUGHNESS = roughness_value;
    METALLIC = 0.0;
}
