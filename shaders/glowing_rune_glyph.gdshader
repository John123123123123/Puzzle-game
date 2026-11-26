shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 base_color : source_color = vec3(0.15, 0.14, 0.12);
uniform vec3 rune_glow_color : source_color = vec3(0.2, 0.85, 1.0);
uniform float pulse_speed = 3.0;
uniform float emission_energy = 2.8;
uniform float pressed_ratio : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    float pulse = sin(TIME * pulse_speed) * 0.22 + 0.78;
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float angle = atan(uv.y, uv.x);

    // Outer segmented solar compass ring + inner ring
    float seg = step(0.15, sin(angle * 8.0 + TIME * (0.4 + pressed_ratio * 1.4)));
    float outer_ring = smoothstep(0.04, 0.0, abs(dist - 0.78)) * mix(0.65, 1.0, seg);
    float inner_ring = smoothstep(0.032, 0.0, abs(dist - 0.44));

    // Slowly rotating inner diamond seal
    float rot = TIME * (0.35 + pressed_ratio * 1.1);
    mat2 rm = mat2(vec2(cos(rot), -sin(rot)), vec2(sin(rot), cos(rot)));
    vec2 ruv = rm * uv;
    float dia = abs(ruv.x) + abs(ruv.y);
    float diamond = smoothstep(0.032, 0.0, abs(dia - 0.36));

    // Orthogonal + diagonal glowing energy fracture veins
    float cross_vein = smoothstep(0.03, 0.0, min(abs(uv.x), abs(uv.y))) * step(dist, 0.85);
    float diag_vein = smoothstep(0.024, 0.0, min(abs(uv.x - uv.y), abs(uv.x + uv.y)) * 0.7071) * step(0.22, dist) * step(dist, 0.86);

    float rune_mask = clamp(outer_ring + inner_ring + diamond + cross_vein + diag_vein * (0.35 + 0.65 * pressed_ratio), 0.0, 1.0);

    vec3 col = mix(base_color, rune_glow_color * pulse, rune_mask);
    ALBEDO = col;
    EMISSION = rune_glow_color * (rune_mask * emission_energy * pulse * mix(0.75, 1.35, pressed_ratio));
    ROUGHNESS = 0.52 - rune_mask * 0.42;
    METALLIC = 0.20 + rune_mask * 0.60;
}
