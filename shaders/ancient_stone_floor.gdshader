shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Uniforms with backward-compatible names & types
uniform vec3 base_color : source_color = vec3(0.48, 0.42, 0.35);
uniform vec3 mortar_color : source_color = vec3(0.14, 0.11, 0.09);
uniform vec3 edge_highlight : source_color = vec3(0.58, 0.52, 0.44);
uniform vec3 sand_color : source_color = vec3(0.52, 0.45, 0.33);

uniform float tile_size = 1.4;
uniform float tile_aspect = 1.35;
uniform float mortar_width = 0.035;
uniform float bevel_width = 0.055;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.82;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

// Fast procedural hash functions
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Value Noise with quintic hermite smoothing
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3-octave Fractal Brownian Motion for authentic natural stone grain
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
    // Determine whether this fragment is on a horizontal surface (floor) or vertical surface (sides/blocks)
    bool is_top = abs(world_normal.y) > 0.5;

    // Planar UV coordinates based on orientation
    vec2 surface_coords;
    if (is_top) {
        surface_coords = world_pos.xz;
    } else {
        // Vertical face: side projection along Z or X
        float h_coord = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
        surface_coords = vec2(h_coord, world_pos.y);
    }

    // Flagstone dimensions (ancient rectangular temple paving stones)
    vec2 slab_size = vec2(tile_size * tile_aspect, tile_size);

    // Subtle organic edge warping (ancient hand-chiseled weathered stone)
    vec2 warp = (vec2(value_noise(surface_coords * 1.8), value_noise(surface_coords * 1.8 + vec2(4.3, 1.7))) - 0.5) * 0.06;
    vec2 warped_p = surface_coords + warp;

    // Stagger alternating rows by 50% (running bond pattern)
    vec2 uv = warped_p / slab_size;
    float row_idx = floor(uv.y);
    float row_stagger = mod(abs(row_idx), 2.0) > 0.5 ? 0.5 : 0.0;
    row_stagger += (hash21(vec2(row_idx, 29.1)) - 0.5) * 0.12;
    uv.x += row_stagger;

    vec2 tile_id = floor(uv);
    vec2 f = fract(uv);

    // Distance to slab borders in world meters
    vec2 dist_norm = min(f, 1.0 - f);
    vec2 dist_m = dist_norm * slab_size;
    float edge_dist = min(dist_m.x, dist_m.y);

    // Mortar groove and stone edge bevel
    // Mortar crack: [0, mortar_width]
    // Stone bevel lip: [mortar_width, mortar_width + bevel_width]
    // Stone flat face: > mortar_width + bevel_width
    float mortar_mask = smoothstep(mortar_width * 0.25, mortar_width, edge_dist);
    float bevel_mask = smoothstep(mortar_width, mortar_width + bevel_width, edge_dist);

    // Unique random seeds per stone slab
    float slab_rnd1 = hash21(tile_id);
    float slab_rnd2 = hash21(tile_id + vec2(47.2, 83.9));

    // Per-slab subtle color variation (desert sandstone nuances)
    vec3 slab_color = base_color * (0.85 + 0.30 * slab_rnd1);
    slab_color = mix(slab_color, slab_color * vec3(1.08, 0.98, 0.90), slab_rnd2 * 0.4);

    // Multi-octave natural stone texture & porosity
    float stone_noise = fbm(surface_coords * 3.5);
    slab_color *= (0.84 + 0.32 * stone_noise);

    // Ancient cracks / fissures across occasional weathered stone slabs
    if (crack_intensity > 0.01) {
        float crack_seed = hash21(tile_id + vec2(19.3, 71.2));
        if (crack_seed > 0.60) {
            float crack_pattern = value_noise(surface_coords * 4.5 + slab_rnd1 * 8.0);
            float crack_line = abs(fract(crack_pattern * 2.5) - 0.5);
            float crack_mask = smoothstep(0.04, 0.008, crack_line) * crack_intensity;
            slab_color = mix(slab_color, mortar_color * 0.7, crack_mask * 0.85);
        }
    }

    // Desert dust & accumulated sand in crevices and corners
    float dust_field = fbm(surface_coords * 1.3 + vec2(3.1, 8.4));
    float crevice_dirt = (1.0 - bevel_mask) * 0.55 + (1.0 - mortar_mask) * 0.45;
    vec3 dust_tint = mix(slab_color, sand_color, clamp(dust_field * 0.5 + crevice_dirt * 0.5, 0.0, 0.65));

    // Layer colors in correct depth order:
    // 1. Stone surface with subtle edge highlight along the beveled rim
    vec3 surface_color = mix(edge_highlight, slab_color, bevel_mask);
    // 2. Mix in dust/grime along the beveled shoulder
    surface_color = mix(surface_color, dust_tint, crevice_dirt * 0.35);
    // 3. Dark recessed mortar in the cracks
    vec3 final_color = mix(mortar_color, surface_color, mortar_mask);

    // Physically accurate normal perturbation in camera VIEW space
    vec2 center_dir = normalize(vec2(0.5) - f);
    float bevel_slope = (1.0 - bevel_mask) * mortar_mask;
    vec2 bevel_grad = center_dir * bevel_slope * 0.35;

    // Subtle stone micro-bump
    float bump_step = 0.08;
    float bump_u = (value_noise(surface_coords * 3.5 + vec2(bump_step, 0.0)) - value_noise(surface_coords * 3.5 - vec2(bump_step, 0.0))) * 0.10;
    float bump_v = (value_noise(surface_coords * 3.5 + vec2(0.0, bump_step)) - value_noise(surface_coords * 3.5 - vec2(0.0, bump_step))) * 0.10;

    vec3 world_grad;
    if (is_top) {
        world_grad = vec3(bevel_grad.x + bump_u, 0.0, bevel_grad.y + bump_v);
    } else if (abs(world_normal.x) > 0.5) {
        world_grad = vec3(0.0, bevel_grad.y + bump_v, bevel_grad.x + bump_u);
    } else {
        world_grad = vec3(bevel_grad.x + bump_u, bevel_grad.y + bump_v, 0.0);
    }

    // Transform world perturbation to view space and apply to NORMAL
    vec3 view_perturbation = mat3(VIEW_MATRIX) * world_grad;
    NORMAL = normalize(NORMAL + view_perturbation);

    // Roughness & Specular:
    // Mortar & dusty crevices are rough and matte (0.96), polished stone centers have soft antique sheen
    ROUGHNESS = mix(0.96, roughness_val, mortar_mask * bevel_mask);
    SPECULAR = mix(0.04, 0.22, mortar_mask * bevel_mask);
    ALBEDO = final_color;
}
