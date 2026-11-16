shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 base_color : source_color = vec3(0.15, 0.14, 0.12);
uniform vec3 rune_glow_color : source_color = vec3(0.2, 0.85, 1.0);
uniform float pulse_speed = 3.0;
uniform float emission_energy = 2.8;

void fragment() {
    float pulse = sin(TIME * pulse_speed) * 0.25 + 0.75;
    
    // Geometric ancient rune pattern
    vec2 uv = UV * 2.0 - 1.0;
    float dist = length(uv);
    float ring = smoothstep(0.04, 0.0, abs(dist - 0.65));
    float cross = smoothstep(0.04, 0.0, min(abs(uv.x), abs(uv.y))) * step(dist, 0.75);
    float rune_mask = clamp(ring + cross, 0.0, 1.0);

    vec3 col = mix(base_color, rune_glow_color * pulse, rune_mask);
    ALBEDO = col;
    EMISSION = rune_glow_color * (rune_mask * emission_energy * pulse);
    ROUGHNESS = 0.5 - rune_mask * 0.4;
    METALLIC = 0.2 + rune_mask * 0.5;
}
