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

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.5;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 3; i++) {
        v += amp * value_noise(p);
        p = rot * p * 2.05;
        amp *= 0.5;
    }
    return v;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    bool is_x_wall = abs(world_normal.x) > 0.5;
    float horiz_coord = is_x_wall ? world_pos.z : world_pos.x;
    float vert_coord = world_pos.y;
    vec2 surf_uv = vec2(horiz_coord, vert_coord);

    float row_id = floor(vert_coord / brick_height);
    float row_offset = mod(row_id, 2.0) * (brick_width * 0.5);

    vec2 brick_uv = vec2((horiz_coord + row_offset) / brick_width, vert_coord / brick_height);
    vec2 brick_cell = floor(brick_uv);
    vec2 f = fract(brick_uv);

    vec2 dist_to_edge = min(f, 1.0 - f);
    float edge_dist = min(dist_to_edge.x * brick_width, dist_to_edge.y * brick_height);

    // Stone grain & per-brick variation
    float rnd = hash21(brick_cell);
    float grain = fbm(surf_uv * 3.2 + vec2(rnd * 7.0));
    vec3 col = mix(brick_dark, wall_color, 0.65 + 0.35 * rnd);
    col *= 0.86 + 0.28 * grain;

    // Mortar & bevel masks
    float mortar = smoothstep(0.02, 0.055, edge_dist);
    float bevel = smoothstep(0.055, 0.11, edge_dist);
    vec3 final_color = mix(mortar_color, col, mortar);

    // Decorative carved gilded frieze band near top of wall (y = 2.75 to 3.25)
    float frieze_band = smoothstep(2.7, 2.85, vert_coord) * (1.0 - smoothstep(3.15, 3.3, vert_coord));
    float frieze_relief = 0.0;
    if (frieze_band > 0.01) {
        float carved_pattern = sin(horiz_coord * 12.0) * cos(vert_coord * 24.0);
        frieze_relief = carved_pattern * frieze_band;
        vec3 frieze_accent = mix(frieze_color * 0.75, frieze_color * 1.25, carved_pattern * 0.5 + 0.5);
        final_color = mix(final_color, frieze_accent, frieze_band * 0.85);
    }

    // Ground contact AO
    float ground_ao = clamp(vert_coord / 1.0, 0.0, 1.0);
    float ao = mix(0.68, 1.0, ground_ao) * mix(0.65, 1.0, mortar);

    // View-space PBR normal perturbation (brick bevel + stone grain + frieze carving)
    vec2 center_dir = normalize(vec2(0.5) - f + vec2(1e-4));
    vec2 bevel_grad = center_dir * (1.0 - bevel) * mortar * 0.32;
    float step_eps = 0.06;
    float bump_u = (value_noise(surf_uv * 4.5 + vec2(step_eps, 0.0)) - value_noise(surf_uv * 4.5 - vec2(step_eps, 0.0))) * 0.14;
    float bump_v = (value_noise(surf_uv * 4.5 + vec2(0.0, step_eps)) - value_noise(surf_uv * 4.5 - vec2(0.0, step_eps))) * 0.14;
    bump_u += cos(horiz_coord * 12.0) * cos(vert_coord * 24.0) * frieze_band * 0.18;

    vec3 world_grad = is_x_wall
        ? vec3(0.0, bevel_grad.y + bump_v, bevel_grad.x + bump_u)
        : vec3(bevel_grad.x + bump_u, bevel_grad.y + bump_v, 0.0);
    NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * world_grad);

    ALBEDO = final_color;
    AO = ao;
    METALLIC = frieze_band * 0.45 * clamp(frieze_relief + 0.5, 0.0, 1.0);
    ROUGHNESS = mix(0.95, mix(0.84, 0.42, frieze_band * 0.65), mortar * bevel);
    SPECULAR = mix(0.08, 0.35, frieze_band);
}
