shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec4 sand_light : source_color = vec4(0.74, 0.62, 0.40, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.50, 0.39, 0.23, 1.0);
uniform vec4 abyss_center : source_color = vec4(0.34, 0.25, 0.14, 1.0);
uniform float swirl_speed : hint_range(0.1, 4.0) = 0.38;

varying vec2 v_uv_norm;

void vertex() {
	v_uv_norm = UV * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = v_uv_norm;
	float r = length(uv);
	float angle = atan(uv.y, uv.x);

	// Broad, gentle, calm sand ripples drifting slowly inward
	float spiral = sin(r * 8.5 + TIME * swirl_speed * 1.3 + angle) * 0.5 + 0.5;
	float ripple2 = sin(r * 13.0 + TIME * swirl_speed * 1.7) * 0.5 + 0.5;
	float grain = fract(sin(dot(floor(UV * 96.0), vec2(12.9898, 78.233))) * 43758.5453);

	float center_mask = smoothstep(0.08, 0.90, r);
	vec3 col = mix(abyss_center.rgb, sand_dark.rgb, smoothstep(0.0, 0.50, r));
	col = mix(col, sand_light.rgb, center_mask * (0.55 + 0.22 * spiral));
	col *= 0.92 + 0.08 * ripple2 + 0.05 * grain;

	ALBEDO = col;
	ROUGHNESS = 0.92;
	METALLIC = 0.02;
	EMISSION = vec3(0.0);
}
