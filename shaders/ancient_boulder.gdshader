shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 rock_light : source_color = vec3(0.46, 0.40, 0.33);
uniform vec3 rock_dark : source_color = vec3(0.20, 0.17, 0.14);
uniform vec3 moss_color : source_color = vec3(0.24, 0.32, 0.18);
uniform vec3 rune_color : source_color = vec3(1.0, 0.55, 0.15);

varying vec3 v_local_pos;
varying vec3 v_local_normal;

float hash31(vec3 p) {
    p = fract(p * vec3(127.1, 311.7, 74.7));
    p += dot(p, p.yzx + 19.19);
    return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);

    float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
    float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
    float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
    float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
    float n111 = hash31(i + vec3(1.0, 1.0, 1.0));

    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);

    return mix(mix(nx00, nx10, u.y), mix(nx01, nx11, u.y), u.z);
}

float fbm3(vec3 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        v += amp * noise3d(p);
        p = p * 2.07 + vec3(1.3, 2.7, 0.9);
        amp *= 0.5;
    }
    return v;
}

void vertex() {
    v_local_pos = VERTEX;
    v_local_normal = NORMAL;
    float crag = fbm3(VERTEX * 2.2) - 0.5;
    VERTEX += NORMAL * (crag * 0.14);
}

void fragment() {
    vec3 p = v_local_pos * 2.4;
    float n = fbm3(p);
    float crack_val = abs(fract(n * 3.5) - 0.5);
    float crack_mask = smoothstep(0.06, 0.01, crack_val);

    vec3 col = mix(rock_dark, rock_light, smoothstep(0.22, 0.78, n));
    float moss_n = noise3d(v_local_pos * 1.6 + vec3(4.2, 1.1, 7.3));
    col = mix(col, moss_color, smoothstep(0.62, 0.85, moss_n) * 0.45);
    col = mix(col, rock_dark * 0.45, crack_mask * 0.85);

    float band = smoothstep(0.22, 0.16, abs(v_local_pos.x));
    float glyph_pat = step(0.58, sin(atan(v_local_pos.y, v_local_pos.z) * 12.0) * 0.5 + 0.5);
    float rune_mask = band * glyph_pat * (1.0 - crack_mask);
    col = mix(col, rune_color, rune_mask * 0.75);

    float eps = 0.06;
    float gx = fbm3(p + vec3(eps, 0.0, 0.0)) - fbm3(p - vec3(eps, 0.0, 0.0));
    float gy = fbm3(p + vec3(0.0, eps, 0.0)) - fbm3(p - vec3(0.0, eps, 0.0));
    float gz = fbm3(p + vec3(0.0, 0.0, eps)) - fbm3(p - vec3(0.0, 0.0, eps));
    vec3 world_bump = mat3(MODEL_MATRIX) * (vec3(gx, gy, gz) * 1.4);
    NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * world_bump);

    ALBEDO = col;
    ROUGHNESS = mix(0.92, 0.98, crack_mask);
    SPECULAR = 0.14;
    EMISSION = rune_color * (rune_mask * 1.6);
}
