shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 slat_dark : source_color = vec4(0.18, 0.16, 0.19, 1.0);
uniform vec4 slat_light : source_color = vec4(0.32, 0.29, 0.32, 1.0);
uniform vec4 chevron_glow : source_color = vec4(0.84, 0.66, 0.28, 1.0);
uniform vec2 scroll_dir = vec2(0.0, -1.0);
uniform float scroll_speed = 0.75;
uniform vec2 belt_world_size = vec2(3.0, 6.0);

varying vec3 v_local_pos;
varying vec3 v_local_norm;

void vertex() {
	v_local_pos = VERTEX;
	v_local_norm = NORMAL;
}

void fragment() {
	bool is_top = v_local_norm.y > 0.6;
	if (!is_top) {
		ALBEDO = slat_dark.rgb * 0.85;
		ROUGHNESS = 0.72;
		METALLIC = 0.35;
	} else {
		vec2 p = v_local_pos.xz;
		vec2 dir = length(scroll_dir) > 0.001 ? normalize(scroll_dir) : vec2(0.0, -1.0);
		vec2 perp = vec2(-dir.y, dir.x);
		float half_w = max(0.2, abs(perp.x) * belt_world_size.x * 0.5 + abs(perp.y) * belt_world_size.y * 0.5);
		float u_across = dot(p, perp) / half_w;
		float v_along = dot(p, dir) - TIME * scroll_speed;

		float slat_f = fract(v_along * 1.05);
		float seam = 1.0 - smoothstep(0.03, 0.10, min(slat_f, 1.0 - slat_f));

		// Smooth anti-aliased directional chevron arrows at a calm steady spacing
		float chev_coord = fract((dot(p, dir) - TIME * scroll_speed) * 0.52 + abs(u_across) * 0.40);
		float chev_fade_x = 1.0 - smoothstep(0.58, 0.72, abs(u_across));
		float chev_band = chev_fade_x * smoothstep(0.16, 0.21, chev_coord) * (1.0 - smoothstep(0.32, 0.37, chev_coord));

		float edge_rail = smoothstep(0.82, 0.87, abs(u_across));
		vec3 col = mix(slat_light.rgb, slat_dark.rgb, seam * 0.45);
		col = mix(col, vec3(0.50, 0.40, 0.18), edge_rail);
		col = mix(col, chevron_glow.rgb, chev_band * 0.65);

		ALBEDO = col;
		ROUGHNESS = mix(0.74, 0.34, max(edge_rail, chev_band));
		METALLIC = mix(0.22, 0.72, max(edge_rail, chev_band));
		EMISSION = chevron_glow.rgb * (chev_band * (0.30 + 0.05 * sin(TIME * 1.5)));
	}
}
