shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 wall_color : source_color = vec3(0.38, 0.32, 0.25);
uniform vec3 brick_dark : source_color = vec3(0.24, 0.20, 0.16);
uniform vec3 mortar_color : source_color = vec3(0.18, 0.15, 0.12);
uniform vec3 frieze_color : source_color = vec3(0.52, 0.44, 0.30);
uniform float brick_width = 1.4;
uniform float brick_height = 0.7;

varying vec3 world_pos;
varying vec3 world_normal;

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    // Determine wall coordinate based on orientation (X or Z wall)
    float horiz_coord = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
    float vert_coord = world_pos.y;

    // Row calculation
    float row_id = floor(vert_coord / brick_height);
    // Stagger every second row
    float row_offset = mod(row_id, 2.0) * (brick_width * 0.5);

    vec2 brick_uv = vec2((horiz_coord + row_offset) / brick_width, vert_coord / brick_height);
    vec2 brick_cell = floor(brick_uv);
    vec2 f = fract(brick_uv);

    // Distance to brick borders
    vec2 dist_to_edge = min(f, 1.0 - f);
    float edge_dist = min(dist_to_edge.x * brick_width, dist_to_edge.y * brick_height);

    // Brick color variation
    float rnd = hash21(brick_cell);
    vec3 col = mix(brick_dark, wall_color, 0.7 + 0.4 * rnd);

    // Mortar groove
    float mortar = smoothstep(0.02, 0.06, edge_dist);
    vec3 final_color = mix(mortar_color, col, mortar);

    // Decorative carved frieze band near top of wall (around y = 2.8 to 3.2)
    float frieze_band = smoothstep(2.7, 2.85, vert_coord) * (1.0 - smoothstep(3.15, 3.3, vert_coord));
    if (frieze_band > 0.01) {
        float carved_pattern = sin(horiz_coord * 12.0) * cos(vert_coord * 24.0);
        vec3 frieze_accent = mix(frieze_color * 0.8, frieze_color * 1.25, carved_pattern * 0.5 + 0.5);
        final_color = mix(final_color, frieze_accent, frieze_band * 0.85);
    }

    // Dirt & contact shadow at floor base (below y = 0.8)
    float ground_ao = clamp(vert_coord / 1.0, 0.0, 1.0);
    final_color *= mix(0.7, 1.0, ground_ao);

    ALBEDO = final_color;
    ROUGHNESS = 0.88;
    SPECULAR = 0.15;
}
