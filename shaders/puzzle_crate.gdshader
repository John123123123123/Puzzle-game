shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Crate colors & materials
uniform vec3 wood_plank_color : source_color = vec3(0.55, 0.40, 0.25);
uniform vec3 wood_frame_color : source_color = vec3(0.42, 0.29, 0.17);
uniform vec3 wood_dark : source_color = vec3(0.24, 0.16, 0.10);
uniform vec3 metal_color : source_color = vec3(0.28, 0.25, 0.22);
uniform vec3 rivet_color : source_color = vec3(0.72, 0.58, 0.36); // Aged brass / bronze rivet

uniform float frame_width = 0.12;
uniform float brace_width = 0.055;
uniform float corner_bracket_size = 0.22;
uniform float roughness_wood : hint_range(0.0, 1.0) = 0.80;
uniform float roughness_metal : hint_range(0.0, 1.0) = 0.45;

// Hash functions
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// 2D Value Noise
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

// 2-octave organic noise for wood grain
float fbm(vec2 p) {
    return value_noise(p) * 0.65 + value_noise(p * 2.1) * 0.35;
}

void fragment() {
    // Pure local UV coordinates [0.0, 1.0] - firmly locked to the crate mesh!
    vec2 uv = UV;

    // Distance to face edges
    vec2 d_edge = min(uv, 1.0 - uv);
    float edge_dist = min(d_edge.x, d_edge.y);

    // Is this fragment on the outer protective wooden frame?
    bool is_frame = edge_dist < frame_width;

    // Corner brackets & rivets
    vec2 corner_offset = d_edge;
    bool is_corner_bracket = (corner_offset.x < corner_bracket_size && corner_offset.y < corner_bracket_size) &&
                             (corner_offset.x + corner_offset.y < corner_bracket_size * 1.5);

    // Corner rivet position (placed neatly inside the corner bracket)
    vec2 rivet_pos = vec2(frame_width * 0.55, frame_width * 0.55);
    float dist_to_rivet = length(corner_offset - rivet_pos);
    bool is_rivet = dist_to_rivet < 0.028;

    // Center diagonal cross-braces (X-brace across the inner panel)
    float diag1 = abs(uv.x - uv.y) * 0.7071;
    float diag2 = abs(uv.x + uv.y - 1.0) * 0.7071;
    bool is_brace = (!is_frame) && (diag1 < brace_width || diag2 < brace_width);

    // Background horizontal planks (when not on frame or brace)
    float plank_coord = uv.y * 3.5;
    float plank_idx = floor(plank_coord);
    float plank_fract = fract(plank_coord);
    float plank_seam = min(plank_fract, 1.0 - plank_fract);
    bool is_plank_groove = (!is_frame && !is_brace) && (plank_seam < 0.035);

    // Base colors & materials
    vec3 col;
    float roughness = roughness_wood;
    float metallic = 0.0;
    vec2 slope = vec2(0.0);

    // Wood grain texture
    vec2 grain_uv = vec2(uv.x * 2.5, uv.y * 14.0);
    float grain = fbm(grain_uv + vec2(value_noise(grain_uv * 0.4) * 1.2, 0.0));

    if (is_rivet) {
        // Metallic rivet (domed round head)
        vec2 r_dir = (corner_offset - rivet_pos) / 0.028;
        float dome = 1.0 - length(r_dir);
        col = rivet_color * (0.8 + 0.4 * dome);
        metallic = 0.85;
        roughness = roughness_metal;
        slope = -r_dir * 0.55;
    } else if (is_corner_bracket) {
        // Dark aged metal corner reinforcement plate
        float metal_grain = fbm(uv * 18.0);
        col = metal_color * (0.85 + 0.3 * metal_grain);
        metallic = 0.65;
        roughness = roughness_metal + 0.1;
        // Bevel at edge of corner bracket
        float bracket_edge = min(corner_bracket_size - corner_offset.x, corner_bracket_size - corner_offset.y);
        if (bracket_edge < 0.02) {
            col *= 0.7;
        }
    } else if (is_frame) {
        // Sturdy wooden outer frame
        col = wood_frame_color * (0.82 + 0.36 * grain);
        // Subtle bevel on the outer and inner edges of the frame
        float frame_inner_edge = abs(edge_dist - frame_width);
        if (frame_inner_edge < 0.015) {
            // Shadow step into recessed panel
            col *= 0.65;
            slope = (uv - vec2(0.5)) * 0.3;
        } else if (edge_dist < 0.015) {
            // Highlight on crate outer corner
            col = mix(col, col * 1.3, 0.5);
        }
    } else if (is_brace) {
        // Wooden diagonal reinforcing cross-brace
        vec2 brace_grain_uv = vec2((uv.x + uv.y) * 10.0, (uv.x - uv.y) * 2.5);
        float brace_grain = fbm(brace_grain_uv);
        col = mix(wood_frame_color, wood_plank_color, 0.4) * (0.85 + 0.3 * brace_grain);
        // Shadow along edges of the brace
        float edge_d1 = abs(diag1 - brace_width);
        float edge_d2 = abs(diag2 - brace_width);
        if (min(edge_d1, edge_d2) < 0.012) {
            col *= 0.68;
        }
    } else {
        // Recessed wooden planks
        float plank_rnd = hash21(vec2(plank_idx, 13.7));
        vec3 base_plank = mix(wood_plank_color, wood_dark, 0.25 * plank_rnd);
        col = base_plank * (0.80 + 0.40 * grain);

        if (is_plank_groove) {
            // Dark recessed groove between planks
            col = wood_dark * 0.6;
            roughness = 0.95;
            slope.y = (plank_fract < 0.5 ? -1.0 : 1.0) * 0.4;
        }

        // Ambient occlusion shadow from surrounding frame
        float frame_proximity = edge_dist - frame_width;
        float frame_ao = smoothstep(0.0, 0.08, frame_proximity);
        col *= mix(0.60, 1.0, frame_ao);
    }

    // Tangent-space normal perturbation (solidly locked to the crate mesh!)
    NORMAL = normalize(NORMAL + TANGENT * slope.x + BINORMAL * slope.y);

    ALBEDO = col;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    SPECULAR = mix(0.18, 0.6, metallic);
}
