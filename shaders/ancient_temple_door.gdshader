shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_burley, specular_schlick_ggx;

// Authentic Egyptian sandstone & sacred bronze palette
uniform vec3 stone_color : source_color = vec3(0.42, 0.35, 0.27);
uniform vec3 stone_dark : source_color = vec3(0.22, 0.17, 0.12);
uniform vec3 stone_highlight : source_color = vec3(0.60, 0.52, 0.42);
uniform vec3 bronze_trim : source_color = vec3(0.72, 0.56, 0.28);
uniform vec3 rune_glow_color : source_color = vec3(1.0, 0.82, 0.35); // Warm sacred golden amber

uniform float emission_energy : hint_range(0.0, 10.0) = 3.5;
uniform float pulse_speed : hint_range(0.5, 6.0) = 2.2;
uniform float open_glow : hint_range(0.0, 1.0) = 0.0;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_stone : hint_range(0.0, 1.0) = 0.86;
uniform float roughness_bronze : hint_range(0.0, 1.0) = 0.32;

varying vec3 v_local_pos;
varying vec3 v_local_normal;

// Fast procedural hash
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Value Noise with quintic hermite curve
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

// 3-octave FBM for natural desert sandstone
float fbm(vec2 p) {
    float v = 0.0;
    float amp = 0.52;
    mat2 rot = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
    for (int i = 0; i < 3; i++) {
        v += amp * value_noise(p);
        p = rot * p * 2.05;
        amp *= 0.48;
    }
    return v;
}

void vertex() {
    v_local_pos = VERTEX;
    v_local_normal = NORMAL;
}

void fragment() {
    bool is_face = abs(v_local_normal.z) > 0.5;

    // Normalizing face UV: Door size is 3.8m wide, 4.2m high, 0.6m thick
    vec2 uv;
    if (is_face) {
        uv = vec2(v_local_pos.x / 3.8 + 0.5, v_local_pos.y / 4.2 + 0.5);
    } else {
        // Sides and top/bottom edges
        float h_coord = abs(v_local_normal.x) > 0.5 ? v_local_pos.z : v_local_pos.x;
        uv = vec2(h_coord / 0.6 + 0.5, v_local_pos.y / 4.2 + 0.5);
    }

    // Natural stone texture
    float stone_grain = fbm(uv * 7.0);
    vec3 base_stone = mix(stone_dark, stone_color, 0.75 + 0.35 * stone_grain);

    if (!is_face) {
        // Side thickness: horizontal stone block seams along the door thickness
        float tier_y = fract(uv.y * 5.0);
        float edge_groove = smoothstep(0.04, 0.01, min(tier_y, 1.0 - tier_y));
        ALBEDO = mix(base_stone, stone_dark * 0.7, edge_groove);
        ROUGHNESS = roughness_stone;
        METALLIC = 0.05;
        SPECULAR = 0.15;
    } else {
        // --- FRONT & BACK PORTAL DOOR ARCHITECTURE ---
        // Physical distance to door borders (in meters)
        vec2 dist_m = min(uv, 1.0 - uv) * vec2(3.8, 4.2);
        float edge_dist = min(dist_m.x, dist_m.y);

        // 1. Massive Chiseled Stone Outer Frame (35 cm wide)
        float frame_w = 0.35;
        bool is_frame = edge_dist < frame_w;
        float outer_bevel = smoothstep(0.06, 0.0, edge_dist);
        float inner_step = smoothstep(0.04, 0.0, abs(edge_dist - frame_w));

        // 2. Horizontal Stone Block Tiers (5 massive stacked blocks)
        float tier_v = uv.y * 5.0;
        float tier_id = floor(tier_v);
        float tier_f = fract(tier_v);
        float seam_dist = min(tier_f, 1.0 - tier_f) * (4.2 / 5.0);
        bool is_block_seam = (!is_frame) && (seam_dist < 0.045);

        // Subtle per-tier sandstone hue
        float tier_rnd = hash21(vec2(tier_id, 13.1));
        base_stone *= (0.88 + 0.24 * tier_rnd);

        // 3. Central Grand Sun Seal of Ra (Winged Sun Medallion)
        vec2 p = vec2((uv.x - 0.5) * 3.8, (uv.y - 0.5) * 4.2);
        float r = length(p);
        float angle = atan(p.y, p.x);

        // Winged crest horizontal extensions
        bool is_wing = abs(p.y) < 0.24 && abs(p.x) < 1.45 && r > 0.50;
        float wing_feather = sin(p.x * 24.0) * 0.5 + 0.5;

        // Concentric bronze hieroglyph rings
        bool is_outer_ring = abs(r - 0.98) < 0.07;
        bool is_inner_ring = abs(r - 0.62) < 0.05;

        // Radiating sun rays between the rings
        float ray_pattern = sin(angle * 16.0);
        bool is_ray_band = (r > 0.62 && r < 0.98) && (ray_pattern > 0.4);

        // Sacred central sun disc core
        bool is_sun_core = r < 0.52;
        // Eye of Ra / Sun pupil glyph inside core
        float pupil_r = length(vec2(p.x * 1.2, p.y));
        bool is_pupil = abs(pupil_r - 0.28) < 0.04 || length(p) < 0.10;

        // Determine colors, roughness, metallic, and 3D slope
        vec3 col = base_stone;
        float metallic = 0.05;
        float roughness = roughness_stone;
        float rune_mask = 0.0;
        vec2 slope = vec2(0.0);

        // Outer frame shading + carved hieroglyph cartouche strips
        if (is_frame) {
            col = mix(col, stone_highlight, outer_bevel * 0.5);
            col = mix(col, stone_dark * 0.6, inner_step * 0.7);
            float cartouche_band = step(0.11, dist_m.x) * step(dist_m.x, 0.25) * step(0.45, dist_m.y);
            float glyph_tick = step(0.42, sin(uv.y * 54.0 + hash21(vec2(floor(uv.y * 16.0), step(0.5, uv.x))) * 4.0));
            float glyph_edge = cartouche_band * glyph_tick;
            col = mix(col, bronze_trim * 0.92, glyph_edge * 0.65);
            rune_mask = max(rune_mask, glyph_edge * (0.28 + 0.55 * open_glow));
            vec2 dir_from_center = normalize(uv - vec2(0.5));
            slope = dir_from_center * (outer_bevel * 0.4 - inner_step * 0.35);
        } else {
            // Horizontal mortar grooves between stone blocks + glowing activation energy veins
            if (is_block_seam) {
                col = stone_dark * 0.65;
                roughness = 0.96;
                slope.y = (tier_f < 0.5 ? -1.0 : 1.0) * 0.35;
                rune_mask = max(rune_mask, (0.08 + 0.82 * open_glow) * smoothstep(1.9, 0.4, r));
            }
            float vein_wave = abs(abs(p.x) * 0.55 - abs(p.y));
            if (r > 0.95 && r < 1.85 && vein_wave < 0.045) {
                rune_mask = max(rune_mask, 0.14 + 0.86 * open_glow);
            }

            // Ambient shadow from outer frame
            float frame_ao = smoothstep(0.0, 0.20, edge_dist - frame_w);
            col *= mix(0.70, 1.0, frame_ao);
        }

        // Apply Winged Sun Seal relief
        if (is_outer_ring || is_inner_ring) {
            // Ornamental antique bronze relief rings
            col = bronze_trim * (0.85 + 0.3 * value_noise(uv * 20.0));
            metallic = 0.82;
            roughness = roughness_bronze;
            rune_mask = 0.35;
        } else if (is_ray_band) {
            // Radiating sun ray engravings
            col = mix(col, bronze_trim * 1.1, 0.55);
            rune_mask = 0.65;
            metallic = 0.45;
            roughness = 0.5;
        } else if (is_wing) {
            // Winged crest with carved feathers
            vec3 wing_col = mix(stone_color, bronze_trim, 0.65);
            col = wing_col * (0.80 + 0.35 * wing_feather);
            metallic = 0.55;
            roughness = 0.45;
            rune_mask = 0.25;
        } else if (is_sun_core) {
            // Center sacred disc
            col = mix(stone_dark * 0.8, bronze_trim * 0.9, 0.5);
            metallic = 0.7;
            roughness = 0.38;

            if (is_pupil) {
                // Sacred Eye / Ankh glyph glowing deeply
                rune_mask = 1.0;
                col = rune_glow_color * 1.2;
            } else {
                rune_mask = 0.55;
            }
        }

        // Pulsing sacred golden light
        float pulse = sin(TIME * pulse_speed) * 0.18 + 0.82;
        float active_energy = mix(emission_energy * 0.4, emission_energy * 1.5, open_glow);
        vec3 emission = rune_glow_color * (rune_mask * active_energy * pulse);

        // 3D View-Space Normal Mapping
        vec3 world_bump = vec3(slope.x, slope.y, 0.0);
        vec3 view_perturbation = mat3(VIEW_MATRIX) * world_bump;
        NORMAL = normalize(NORMAL + view_perturbation);

        ALBEDO = col;
        ROUGHNESS = roughness;
        METALLIC = metallic;
        SPECULAR = mix(0.15, 0.65, metallic);
        EMISSION = emission * fade_alpha;
    }
    ALPHA = fade_alpha;
}
