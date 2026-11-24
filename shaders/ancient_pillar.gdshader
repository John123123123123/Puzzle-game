shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

instance uniform float occlusion_fade : hint_range(0.0, 1.0) = 0.0;

uniform vec4 stone_light : source_color = vec4(0.56, 0.47, 0.35, 1.0);
uniform vec4 stone_dark : source_color = vec4(0.32, 0.25, 0.18, 1.0);
uniform vec4 groove_color : source_color = vec4(0.18, 0.14, 0.10, 1.0);
uniform vec4 gold_color : source_color = vec4(0.92, 0.74, 0.28, 1.0);
uniform vec4 lapis_color : source_color = vec4(0.14, 0.36, 0.52, 1.0);
uniform float flute_count : hint_range(8.0, 32.0) = 16.0;
uniform float drum_Repeat : hint_range(1.0, 8.0) = 4.0;
uniform float roughness_base : hint_range(0.2, 1.0) = 0.80;

varying vec3 v_local_pos;
varying vec3 v_local_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_local_pos = VERTEX;
	v_local_normal = NORMAL;
}

void fragment() {
	if (occlusion_fade > 0.01) {
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (ign < occlusion_fade) {
			discard;
		}
	}

	float angle = atan(v_local_pos.x, v_local_pos.z);
	float norm_angle = (angle + PI) / TAU; // 0..1 around shaft
	float y_coord = v_local_pos.y;

	// Stone grain & weathering
	float grain = value_noise(vec2(norm_angle * 24.0, y_coord * 9.0));
	float fine_grain = value_noise(vec2(norm_angle * 64.0, y_coord * 26.0));
	vec3 base_stone = mix(stone_dark.rgb, stone_light.rgb, clamp(grain * 0.72 + fine_grain * 0.28, 0.0, 1.0));

	// Horizontal drum joints
	float drum_phase = fract(y_coord * 1.45 + 0.5);
	float drum_seam = 1.0 - smoothstep(0.0, 0.035, min(drum_phase, 1.0 - drum_phase));

	// Decorative carved Egyptian bands near upper and lower shaft
	float upper_band = smoothstep(0.68, 0.71, y_coord) * (1.0 - smoothstep(1.02, 1.05, y_coord));
	float lower_band = smoothstep(-1.05, -1.02, y_coord) * (1.0 - smoothstep(-0.71, -0.68, y_coord));
	float band_mask = clamp(upper_band + lower_band, 0.0, 1.0);

	// Vertical fluting (suppressed inside decorative bands)
	float flute_wave = cos(angle * flute_count);
	float flute_concavity = clamp((1.0 - flute_wave) * 0.5, 0.0, 1.0);
	float ridge_mask = smoothstep(0.75, 0.98, flute_wave) * (1.0 - band_mask);
	float flute_shadow = mix(0.76, 1.08, ridge_mask) * mix(0.86, 1.0, 1.0 - flute_concavity * (1.0 - band_mask));

	vec3 col = base_stone * flute_shadow;
	col = mix(col, groove_color.rgb, drum_seam * 0.78);

	// Ornate hieroglyphic / chevron band details
	float glyph_cell = floor(norm_angle * 20.0);
	float glyph_u = fract(norm_angle * 20.0);
	float glyph_v = fract((y_coord + 2.0) * 6.0);
	float glyph_id = hash21(vec2(glyph_cell, floor((y_coord + 2.0) * 3.0)));
	float bar_frame = step(0.82, abs(glyph_v * 2.0 - 1.0));
	float glyph_shape = step(0.32, glyph_u) * step(glyph_u, 0.68) * step(0.24, glyph_v) * step(glyph_v, 0.76);
	float is_gold = clamp(bar_frame + glyph_shape * step(0.35, glyph_id), 0.0, 1.0);

	vec3 band_col = mix(lapis_color.rgb, gold_color.rgb, is_gold);
	col = mix(col, band_col, band_mask * 0.92);

	// Subtle dark patina near bottom base
	float base_ao = smoothstep(-1.45, -0.95, y_coord);
	col *= mix(0.72, 1.0, base_ao);

	// Tangent normal perturbation for carved flutes & seams
	float d_flute = -sin(angle * flute_count) * 0.24 * (1.0 - band_mask);
	float d_seam = (drum_phase < 0.04 ? -0.25 : (drum_phase > 0.96 ? 0.25 : 0.0));
	vec3 horiz_tangent = normalize(vec3(cos(angle), 0.0, -sin(angle)));
	vec3 obj_n = normalize(v_local_normal + horiz_tangent * d_flute + vec3(0.0, d_seam, 0.0));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(obj_n, 0.0)).xyz);

	ALBEDO = col;
	METALLIC = band_mask * is_gold * 0.78;
	ROUGHNESS = mix(roughness_base - ridge_mask * 0.08, 0.28, band_mask * is_gold);
	EMISSION = gold_color.rgb * (band_mask * is_gold * 0.08);
}
