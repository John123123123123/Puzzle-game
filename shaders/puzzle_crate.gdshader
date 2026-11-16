shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Crate colors & materials (rich adventure timber & aged bronze hardware)
uniform vec3 wood_plank_color : source_color = vec3(0.58, 0.44, 0.28);
uniform vec3 wood_frame_color : source_color = vec3(0.42, 0.30, 0.18);
uniform vec3 wood_dark : source_color = vec3(0.22, 0.14, 0.08);
uniform vec3 metal_color : source_color = vec3(0.32, 0.30, 0.28);
uniform vec3 rivet_color : source_color = vec3(0.85, 0.72, 0.42); // Polished brass / bronze rivet

uniform float frame_width : hint_range(0.05, 0.20) = 0.12;
uniform float brace_width : hint_range(0.02, 0.10) = 0.045;
uniform float corner_size : hint_range(0.08, 0.25) = 0.15;
uniform float roughness_wood : hint_range(0.0, 1.0) = 0.78;
uniform float roughness_metal : hint_range(0.0, 1.0) = 0.42;

varying vec3 v_local_pos;
varying vec3 v_local_normal;

// Fast procedural hash
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Value Noise with smooth hermite curve
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

// Organic wood grain along plank direction
float wood_grain(vec2 uv) {
    vec2 stretched = vec2(uv.x * 2.5, uv.y * 18.0);
    float n1 = value_noise(stretched);
    float n2 = value_noise(stretched * 2.2 + vec2(1.7, 3.4));
    return n1 * 0.65 + n2 * 0.35;
}

void vertex() {
    v_local_pos = VERTEX;
    v_local_normal = NORMAL;
}

void fragment() {
    // Determine dominant local normal axis for 100% symmetric, seamless per-face mapping
    vec3 abs_n = abs(v_local_normal);
    vec2 face_uv;
    int face_type = 0; // 0=Top/Bottom, 1=Left/Right, 2=Front/Back

    if (abs_n.y > abs_n.x && abs_n.y > abs_n.z) {
        // Top (+Y) or Bottom (-Y) face
        face_uv = v_local_pos.xz / 1.2 + 0.5;
        face_type = 0;
    } else if (abs_n.x > abs_n.y && abs_n.x > abs_n.z) {
        // Left (-X) or Right (+X) face
        face_uv = vec2(v_local_pos.z, v_local_pos.y) / 1.2 + 0.5;
        face_type = 1;
    } else {
        // Front (+Z) or Back (-Z) face
        face_uv = vec2(v_local_pos.x, v_local_pos.y) / 1.2 + 0.5;
        face_type = 2;
    }

    vec2 uv = clamp(face_uv, 0.0, 1.0);

    // Distance to face edges
    vec2 d_edge = min(uv, 1.0 - uv);
    float edge_dist = min(d_edge.x, d_edge.y);

    // Outer wooden frame
    bool is_frame = edge_dist < frame_width;

    // Corner L-bracket reinforcement plates (neatly proportioned along the frame)
    float strap_w = frame_width * 0.75;
    bool is_corner_bracket = (d_edge.x < corner_size && d_edge.y < strap_w) ||
                             (d_edge.y < corner_size && d_edge.x < strap_w);

    // Corner brass rivet position (centered inside corner strap)
    vec2 rivet_pos = vec2(frame_width * 0.5, frame_width * 0.5);
    float dist_to_rivet = length(d_edge - rivet_pos);
    float rivet_radius = 0.026;
    bool is_rivet = dist_to_rivet < rivet_radius;

    // Normalized inner panel coordinates [0.0, 1.0]
    float inner_u = clamp((uv.x - frame_width) / (1.0 - 2.0 * frame_width), 0.0, 1.0);
    float inner_v = clamp((uv.y - frame_width) / (1.0 - 2.0 * frame_width), 0.0, 1.0);

    // Diagonal reinforcing cross-brace (X-brace inside the recessed inner panel)
    float diag1 = abs(inner_u - inner_v) * 0.7071;
    float diag2 = abs(inner_u + inner_v - 1.0) * 0.7071;
    bool is_brace = (!is_frame) && (diag1 < brace_width || diag2 < brace_width);

    // Perfectly spaced 3 horizontal wooden planks
    float plank_num = 3.0;
    float p_v = inner_v * plank_num;
    float plank_idx = floor(p_v);
    float plank_f = fract(p_v);
    float dist_seam = min(plank_f, 1.0 - plank_f);
    bool is_groove = (!is_frame && !is_brace) && (dist_seam < 0.038);

    // Color, material and 3D slope
    vec3 col;
    float roughness = roughness_wood;
    float metallic = 0.0;
    vec2 slope = vec2(0.0);

    // Natural wood grain
    float grain = wood_grain(uv);

    if (is_rivet) {
        // Polished rounded brass/bronze rivet
        vec2 r_dir = (d_edge - rivet_pos) / rivet_radius;
        float dome = clamp(1.0 - length(r_dir), 0.0, 1.0);
        col = rivet_color * (0.85 + 0.45 * dome);
        metallic = 0.90;
        roughness = roughness_metal;
        slope = -r_dir * 0.55;
    } else if (is_corner_bracket) {
        // Aged hammered metal reinforcement plate
        float metal_grain = value_noise(uv * 24.0);
        col = metal_color * (0.88 + 0.25 * metal_grain);
        metallic = 0.75;
        roughness = roughness_metal + 0.08;
    } else if (is_frame) {
        // Sturdy wooden outer frame
        col = wood_frame_color * (0.85 + 0.32 * grain);

        // Frame outer bevel (highlight on corner)
        float outer_bevel = smoothstep(0.02, 0.0, edge_dist);
        col = mix(col, col * 1.35, outer_bevel * 0.6);

        // Frame inner bevel / step down into recessed panel
        float inner_dist = abs(edge_dist - frame_width);
        float inner_bevel = smoothstep(0.018, 0.0, inner_dist);
        col = mix(col, wood_dark * 0.75, inner_bevel * 0.7);

        // Slope for frame bevels
        vec2 dir_from_center = normalize(uv - vec2(0.5));
        slope = dir_from_center * (outer_bevel * 0.35 - inner_bevel * 0.30);
    } else if (is_brace) {
        // Wooden diagonal reinforcing cross-brace
        vec2 brace_grain_uv = vec2((inner_u + inner_v) * 8.0, (inner_u - inner_v) * 2.0);
        float brace_grain = value_noise(brace_grain_uv * 2.0);
        col = mix(wood_frame_color, wood_plank_color, 0.45) * (0.88 + 0.28 * brace_grain);

        // Dark contact shadow along brace borders
        float d_edge1 = abs(diag1 - brace_width);
        float d_edge2 = abs(diag2 - brace_width);
        float brace_edge = min(d_edge1, d_edge2);
        if (brace_edge < 0.012) {
            col *= 0.68;
        }
    } else {
        // Recessed wooden planks
        float plank_rnd = hash21(vec2(plank_idx, 19.3));
        vec3 base_plank = mix(wood_plank_color, wood_plank_color * vec3(0.92, 0.88, 0.82), 0.3 * plank_rnd);
        col = base_plank * (0.84 + 0.32 * grain);

        if (is_groove) {
            // Dark recessed groove between planks
            col = wood_dark * 0.65;
            roughness = 0.95;
            slope.y = (plank_f < 0.5 ? -1.0 : 1.0) * 0.4;
        }

        // Ambient occlusion shadow from outer frame
        float frame_ao = smoothstep(0.0, 0.10, edge_dist - frame_width);
        col *= mix(0.62, 1.0, frame_ao);
    }

    // Convert local 2D slope into 3D world bump vector
    vec3 world_bump = vec3(0.0);
    if (face_type == 0) {
        // Top or bottom face
        float sign_y = sign(v_local_normal.y);
        world_bump = vec3(slope.x, 0.0, slope.y * sign_y);
    } else if (face_type == 1) {
        // Left or right face
        float sign_x = sign(v_local_normal.x);
        world_bump = vec3(0.0, slope.y, slope.x * sign_x);
    } else {
        // Front or back face
        world_bump = vec3(slope.x, slope.y, 0.0);
    }

    // Transform world bump to camera VIEW space and apply to NORMAL
    vec3 view_perturbation = mat3(VIEW_MATRIX) * world_bump;
    NORMAL = normalize(NORMAL + view_perturbation);

    ALBEDO = col;
    ROUGHNESS = roughness;
    METALLIC = metallic;
    SPECULAR = mix(0.18, 0.65, metallic);
}
