shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 obsidian_light : source_color = vec4(0.24, 0.23, 0.30, 1.0);
uniform vec4 obsidian_dark : source_color = vec4(0.09, 0.09, 0.13, 1.0);
uniform vec4 trim_gold : source_color = vec4(0.92, 0.75, 0.28, 1.0);
uniform vec4 phase_glow : source_color = vec4(1.0, 0.82, 0.22, 1.0);
uniform float glow_strength : hint_range(0.0, 6.0) = 2.4;

varying vec3 v_local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(234.56, 567.89));
	p += dot(p, p + 41.17);
	return fract(p.x * p.y);
}

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float angle = atan(v_local_pos.x, v_local_pos.z);
	float sector = fract((angle + PI) / (PI * 0.5)); // 4 obelisk faces
	float edge_dist = min(sector, 1.0 - sector);
	float y = v_local_pos.y;

	// Polished dark basalt-obsidian face with gold corner bevels
	float corner_bevel = 1.0 - smoothstep(0.0, 0.07, edge_dist);
	float face_center = 1.0 - abs(sector - 0.5) * 2.0;
	vec3 stone = mix(obsidian_dark.rgb, obsidian_light.rgb, face_center * 0.65);

	// Carved vertical rune channel down the center of each obelisk face
	float in_face_band = smoothstep(-0.55, -0.50, y) * (1.0 - smoothstep(0.50, 0.55, y));
	float center_slot = (1.0 - smoothstep(0.06, 0.11, abs(sector - 0.5))) * in_face_band;
	float cell_y = floor((y + 1.0) * 9.0);
	float frac_y = fract((y + 1.0) * 9.0);
	float rnd = hash21(vec2(cell_y, floor((angle + PI) / (PI * 0.5))));
	float glyph_bar = step(0.22, frac_y) * step(frac_y, 0.78) * step(0.25, rnd);
	float pulse = 0.78 + 0.22 * sin(TIME * 2.8 - y * 4.0);
	float rune_mask = center_slot * glyph_bar;

	// Horizontal gold collar bands near top and bottom of shaft
	float top_band = smoothstep(0.52, 0.55, y) * (1.0 - smoothstep(0.62, 0.65, y));
	float bot_band = smoothstep(-0.65, -0.62, y) * (1.0 - smoothstep(-0.55, -0.52, y));
	float gold_mask = clamp(corner_bevel * 0.85 + top_band + bot_band, 0.0, 1.0);

	vec3 col = mix(stone, trim_gold.rgb, gold_mask);
	col = mix(col, phase_glow.rgb, rune_mask * 0.9);

	ALBEDO = col;
	METALLIC = clamp(gold_mask * 0.88 + 0.22, 0.0, 1.0);
	ROUGHNESS = mix(0.32, 0.18, clamp(gold_mask + rune_mask, 0.0, 1.0));
	EMISSION = phase_glow.rgb * (rune_mask * glow_strength * pulse) + trim_gold.rgb * (gold_mask * 0.08);
}
