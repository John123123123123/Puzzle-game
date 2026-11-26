shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.04, 0.24, 0.34, 0.86);
uniform vec4 shallow_color : source_color = vec4(0.10, 0.62, 0.72, 0.76);
uniform vec4 caustic_color : source_color = vec4(0.45, 0.96, 1.0, 1.0);
uniform float wave_amp : hint_range(0.0, 0.12) = 0.025;
uniform float wave_speed : hint_range(0.2, 4.0) = 1.65;

varying vec3 v_world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ripple = sin(wp.x * 2.1 + TIME * wave_speed) * cos(wp.z * 2.3 - TIME * wave_speed * 0.85);
	VERTEX.y += ripple * wave_amp;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world_pos.xz;
	float w1 = sin(uv.x * 2.8 + TIME * 1.9 + sin(uv.y * 2.2 - TIME * 1.4));
	float w2 = cos(uv.y * 3.1 - TIME * 1.7 + cos(uv.x * 1.9 + TIME * 1.3));
	float caustic = smoothstep(0.55, 1.0, (w1 * w2) * 0.5 + 0.5);

	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.2);

	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.35 + 0.45 * fresnel);
	col = mix(col, caustic_color.rgb, caustic * 0.55);

	ALBEDO = col;
	ALPHA = clamp(mix(deep_color.a, shallow_color.a, fresnel) + caustic * 0.12, 0.55, 0.95);
	ROUGHNESS = 0.09;
	METALLIC = 0.28;
	SPECULAR = 0.85;
	EMISSION = caustic_color.rgb * (caustic * 0.45 + fresnel * 0.20);
}
