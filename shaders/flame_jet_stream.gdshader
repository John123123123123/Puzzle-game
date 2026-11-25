shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 nozzle_color : source_color = vec4(0.82, 0.95, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.94, 0.62, 1.0);
uniform vec4 flame_color : source_color = vec4(1.0, 0.46, 0.06, 1.0);
uniform vec4 tip_color : source_color = vec4(0.88, 0.10, 0.02, 1.0);
uniform float jet_speed : hint_range(2.0, 18.0) = 9.5;
uniform float jet_height : hint_range(0.5, 6.0) = 3.1;
uniform float intensity : hint_range(0.5, 6.0) = 2.4;

varying float v_along;
varying float v_angle;

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
		p = p * 2.05 + vec2(9.2, 5.4);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	// CylinderMesh has local Y from -jet_height*0.5 to +jet_height*0.5.
	// In FlameSpinner, transform maps -local Y -> +Z (away from nozzle), so +half_h is at nozzle and -half_h is at tip!
	float dist01 = clamp((jet_height * 0.5 - VERTEX.y) / max(jet_height, 0.1), 0.0, 1.0);
	v_along = dist01;
	v_angle = atan(VERTEX.x, VERTEX.z);

	float t = TIME * jet_speed;
	// Tight nozzle blast expanding into turbulent roaring billow, tapering at far tip
	float envelope = mix(0.55, 1.38, smoothstep(0.0, 0.65, dist01)) * (1.0 - smoothstep(0.78, 1.0, dist01) * 0.55);
	float ripple = sin(dist01 * 14.0 - t * 1.8 + v_angle * 3.0) * 0.14 * dist01;
	VERTEX.xz *= max(0.04, envelope + ripple);
	VERTEX.x += sin(dist01 * 9.0 - t * 1.4) * 0.06 * dist01;
}

void fragment() {
	float u_ang = (v_angle + PI) / TAU;
	float t = TIME * jet_speed;

	float n1 = fbm(vec2(u_ang * 5.0, v_along * 5.5 - t));
	float n2 = fbm(vec2(u_ang * 10.0 + 2.1, v_along * 9.0 - t * 1.35));
	float turb = n1 * 0.62 + n2 * 0.38;

	// Erode tail into roaring flame tongues, solid pressurized jet near nozzle
	float cutoff = mix(0.08, 0.76, pow(v_along, 1.35));
	float mask = smoothstep(cutoff - 0.16, cutoff + 0.22, turb);

	float nozzle_fade = smoothstep(0.0, 0.06, v_along);
	float tip_fade = 1.0 - smoothstep(0.76, 1.0, v_along);
	float rim = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 0.55);

	float alpha = clamp(mask * nozzle_fade * tip_fade * (0.42 + 0.68 * rim), 0.0, 1.0);

	// Temperature gradient: blue-white nozzle -> white-gold core -> roaring orange -> red tail
	vec3 col = mix(flame_color.rgb, tip_color.rgb, smoothstep(0.45, 0.92, v_along));
	col = mix(col, core_color.rgb, smoothstep(0.52, 0.88, turb * (1.0 - v_along * 0.55)));
	col = mix(col, nozzle_color.rgb, (1.0 - smoothstep(0.0, 0.16, v_along)) * 0.65);

	ALBEDO = col * intensity;
	ALPHA = alpha;
}
