shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 clay_light : source_color = vec4(0.76, 0.42, 0.23, 1.0);
uniform vec4 clay_dark : source_color = vec4(0.46, 0.22, 0.11, 1.0);
uniform vec4 paint_obsidian : source_color = vec4(0.12, 0.10, 0.09, 1.0);
uniform vec4 paint_gold : source_color = vec4(0.94, 0.76, 0.26, 1.0);
uniform vec4 paint_turquoise : source_color = vec4(0.14, 0.56, 0.62, 1.0);

varying vec3 v_local_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float angle = atan(v_local_pos.x, v_local_pos.z);
	float u = (angle + PI) / TAU;
	float y = v_local_pos.y;

	// Wheel-thrown pottery ridges + kiln clay mottling
	float wheel_rings = sin(y * 95.0) * 0.5 + 0.5;
	float grain = vnoise(vec2(u * 28.0, y * 22.0));
	vec3 col = mix(clay_dark.rgb, clay_light.rgb, clamp(grain * 0.75 + wheel_rings * 0.25, 0.0, 1.0));

	// Belly frieze band around y in [-0.14 .. 0.16]
	float belly_band = smoothstep(-0.15, -0.13, y) * (1.0 - smoothstep(0.14, 0.16, y));
	float border_top = smoothstep(0.10, 0.115, y) * (1.0 - smoothstep(0.14, 0.155, y));
	float border_bot = smoothstep(-0.145, -0.13, y) * (1.0 - smoothstep(-0.105, -0.09, y));
	float borders = clamp(border_top + border_bot, 0.0, 1.0);

	// Painted Egyptian chevron & lotus petal motif inside belly band
	float rep_u = fract(u * 14.0);
	float zigzag = abs(rep_u * 2.0 - 1.0);
	float norm_y = clamp((y + 0.09) / 0.19, 0.0, 1.0);
	float chevron_line = 1.0 - smoothstep(0.0, 0.16, abs(norm_y - zigzag));
	float diamond_dot = (1.0 - smoothstep(0.12, 0.24, length(vec2(rep_u - 0.5, norm_y - 0.5))));

	vec3 frieze_col = mix(paint_obsidian.rgb, paint_turquoise.rgb, diamond_dot * 0.85);
	frieze_col = mix(frieze_col, paint_gold.rgb, clamp(chevron_line + borders, 0.0, 1.0));

	col = mix(col, frieze_col, belly_band * 0.92);

	// Soot / kiln darkening near lower base
	float base_shade = smoothstep(-0.34, -0.08, y);
	col *= mix(0.62, 1.0, base_shade);

	float gold_mask = belly_band * clamp(chevron_line + borders, 0.0, 1.0);
	ALBEDO = col;
	METALLIC = gold_mask * 0.82;
	ROUGHNESS = mix(0.62 - wheel_rings * 0.06, 0.24, gold_mask);
	EMISSION = paint_gold.rgb * (gold_mask * 0.10);
}
