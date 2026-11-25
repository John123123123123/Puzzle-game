shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(1.0, 0.97, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.52, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.92, 0.14, 0.02, 1.0);
uniform float scroll_speed : hint_range(1.0, 12.0) = 4.6;
uniform float sway_strength : hint_range(0.0, 0.4) = 0.11;
uniform float intensity : hint_range(0.5, 5.0) = 2.2;
uniform float mesh_height : hint_range(0.1, 2.0) = 0.68;

varying float v_height01;
varying float v_angle;
varying vec3 v_local;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * amp;
		p = p * 2.07 + vec2(13.1, 7.7);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	float h = clamp((VERTEX.y + mesh_height * 0.5) / max(mesh_height, 0.05), 0.0, 1.0);
	v_height01 = h;
	v_angle = atan(VERTEX.x, VERTEX.z);
	float t = TIME * scroll_speed;

	// Taper upper cone & add dancing flame tongues
	float taper = mix(1.08, 0.18, pow(h, 1.15));
	float tongue = sin(v_angle * 5.0 - t * 2.1 + h * 6.0) * 0.14 + cos(v_angle * 3.0 + t * 1.7 - h * 4.5) * 0.10;
	VERTEX.xz *= max(0.05, taper + tongue * h);

	// Licking upward & lateral flicker increasing toward the crown
	VERTEX.x += sin(t * 2.3 + h * 5.2) * sway_strength * h * h;
	VERTEX.z += cos(t * 1.9 + h * 4.7) * sway_strength * h * h;
	VERTEX.y += sin(v_angle * 4.0 + t * 2.8) * 0.045 * h;
	v_local = VERTEX;
}

void fragment() {
	float u_ang = (v_angle + PI) / TAU;
	float t = TIME * scroll_speed;

	// Multi-layered upward scrolling fire noise
	float n1 = fbm(vec2(u_ang * 6.0, v_height01 * 3.6 - t));
	float n2 = fbm(vec2(u_ang * 11.0 + 3.4, v_height01 * 6.2 - t * 1.45));
	float flame_noise = n1 * 0.65 + n2 * 0.35;

	// Erode higher portions into flickering tongues
	float erosion = mix(0.12, 0.78, pow(v_height01, 1.25));
	float flame_mask = smoothstep(erosion - 0.18, erosion + 0.22, flame_noise);

	// Soft bottom & crown fade so there are no sharp geometry edges
	float bottom_fade = smoothstep(0.0, 0.14, v_height01);
	float top_fade = 1.0 - smoothstep(0.72, 1.0, v_height01);
	float fresnel = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 0.65);

	float alpha = clamp(flame_mask * bottom_fade * top_fade * (0.45 + 0.65 * fresnel), 0.0, 1.0);

	// Temperature gradient: white-gold base -> blazing orange middle -> crimson tips
	float heat = clamp((1.0 - v_height01) * 0.75 + flame_noise * 0.45, 0.0, 1.0);
	vec3 col = mix(tip_color.rgb, mid_color.rgb, smoothstep(0.18, 0.58, heat));
	col = mix(col, core_color.rgb, smoothstep(0.62, 0.92, heat));

	ALBEDO = col * intensity;
	ALPHA = alpha;
}
