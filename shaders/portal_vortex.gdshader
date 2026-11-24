shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec3 inner_color : source_color = vec3(0.35, 0.95, 1.0);
uniform vec3 outer_color : source_color = vec3(1.0, 0.82, 0.28);
uniform float spin_speed = 2.2;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    p.y *= 1.15;
    float r = length(p);
    float angle = atan(p.y, p.x);

    float spiral = sin(angle * 4.0 - r * 7.5 + TIME * spin_speed * 2.0) * 0.5 + 0.5;
    float counter_ring = sin(r * 16.0 - TIME * 3.2) * 0.5 + 0.5;
    float glyph_ring = smoothstep(0.06, 0.0, abs(r - 0.72)) * (0.6 + 0.4 * sin(angle * 12.0 - TIME * 1.5));

    float edge_fade = 1.0 - smoothstep(0.55, 0.98, r);
    float core_bright = exp(-r * 2.8);

    vec3 col = mix(outer_color, inner_color, clamp(core_bright + spiral * 0.45, 0.0, 1.0));
    col += outer_color * glyph_ring * 1.4;

    float alpha = (0.35 + spiral * 0.35 + counter_ring * 0.15 + core_bright * 0.5 + glyph_ring * 0.6) * edge_fade;
    ALBEDO = col * 1.35;
    ALPHA = clamp(alpha, 0.0, 0.92);
}
