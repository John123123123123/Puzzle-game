shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 wall_color : source_color = vec3(0.38, 0.32, 0.25);
uniform vec3 brick_dark : source_color = vec3(0.24, 0.20, 0.16);
uniform vec3 mortar_color : source_color = vec3(0.18, 0.15, 0.12);
uniform vec3 frieze_color : source_color = vec3(0.52, 0.44, 0.30);
uniform float brick_width = 1.4;
uniform float brick_height = 0.7;

instance uniform float occlusion_fade : hint_range(0.0, 1.0) = 0.0;

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
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    if (occlusion_fade > 0.01) {
        float height_factor = smoothstep(0.15, 0.65, world_pos.y);
        float effective_fade = occlusion_fade * mix(0.35, 1.0, height_factor);
        float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
        if (ign < effective_fade) {
            discard;
        }
    }

    bool is_top = abs(world_normal.y) > 0.5;
    float horiz_coord = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
    float vert_coord = is_top ? world_pos.z : world_pos.y;
    if (is_top) {
        horiz_coord = world_pos.x;
    }

    float row_id = floor(vert_coord / brick_height);
    float row_offset = mod(abs(row_id), 2.0) * (brick_width * 0.5);

    vec2 brick_uv = vec2((horiz_coord + row_offset) / brick_width, vert_coord / brick_height);
    vec2 brick_cell = floor(brick_uv);
    vec2 f = fract(brick_uv);

    vec2 dist_to_edge = min(f, 1.0 - f);
    float edge_dist = min(dist_to_edge.x * brick_width, dist_to_edge.y * brick_height);

    float rnd = hash21(brick_cell);
    float grain = value_noise(vec2(horiz_coord, vert_coord) * 4.5);
    vec3 col = mix(brick_dark, wall_color, 0.65 + 0.35 * rnd) * (0.88 + 0.24 * grain);

    float mortar = smoothstep(0.018, 0.045, edge_dist);
    float bevel = smoothstep(0.045, 0.095, edge_dist);
    vec3 beveled_col = mix(col * 1.14, col, bevel);
    vec3 final_color = mix(mortar_color, beveled_col, mortar);

    if (!is_top) {
        float frieze_band = smoothstep(2.7, 2.85, vert_coord) * (1.0 - smoothstep(3.15, 3.3, vert_coord));
        if (frieze_band > 0.01) {
            float carved_pattern = sin(horiz_coord * 12.0) * cos(vert_coord * 24.0);
            vec3 frieze_accent = mix(frieze_color * 0.8, frieze_color * 1.25, carved_pattern * 0.5 + 0.5);
            final_color = mix(final_color, frieze_accent, frieze_band * 0.85);
        }
        float ground_ao = clamp(vert_coord / 0.9, 0.0, 1.0);
        final_color *= mix(0.65, 1.0, ground_ao);
    }

    vec2 center_dir = normalize(vec2(0.5) - f);
    float bevel_slope = (1.0 - bevel) * mortar * 0.32;
    vec2 grad = center_dir * bevel_slope;
    vec3 world_grad = vec3(0.0);
    if (is_top) {
        world_grad = vec3(grad.x, 0.0, grad.y);
    } else if (abs(world_normal.x) > 0.5) {
        world_grad = vec3(0.0, grad.y, grad.x);
    } else {
        world_grad = vec3(grad.x, grad.y, 0.0);
    }
    NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * world_grad);

    ALBEDO = final_color;
    ROUGHNESS = mix(0.96, 0.85, mortar * bevel);
    SPECULAR = mix(0.05, 0.18, mortar * bevel);
}
