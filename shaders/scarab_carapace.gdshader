shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_lapis : source_color = vec4(0.03, 0.20, 0.46, 1.0);
uniform vec4 turquoise_mid : source_color = vec4(0.06, 0.72, 0.85, 1.0);
uniform vec4 emerald_sheen : source_color = vec4(0.20, 0.96, 0.70, 1.0);
uniform vec4 gold_inlay : source_color = vec4(1.0, 0.82, 0.24, 1.0);
uniform float glow_strength : hint_range(0.0, 4.0) = 1.15;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.3);

	// Subtle engraved longitudinal elytra flutes + Egyptian chevron inlay
	float ribs = sin(v_local_pos.x * 46.0) * 0.5 + 0.5;
	float rib_groove = smoothstep(0.15, 0.55, ribs);
	float chevron_coord = v_local_pos.z * 14.0 + abs(v_local_pos.x) * 10.0;
	float chevron = smoothstep(0.86, 0.95, sin(chevron_coord));
	float shimmer = sin(TIME * 2.5 + v_local_pos.z * 9.0 + v_local_pos.x * 6.0) * 0.5 + 0.5;

	// Beetle-shell iridescence: royal lapis -> vibrant turquoise -> emerald/gold rim
	vec3 shell = mix(deep_lapis.rgb, turquoise_mid.rgb, smoothstep(0.08, 0.62, fresnel + shimmer * 0.22));
	shell = mix(shell, emerald_sheen.rgb, smoothstep(0.42, 0.88, fresnel));
	shell *= mix(0.82, 1.06, rib_groove);

	// Delicate gold filigree inlay on chevron ridges and grazing rim glint
	float gold_mask = clamp(chevron * 0.48 + pow(fresnel, 3.5) * 0.55, 0.0, 1.0);
	vec3 col = mix(shell, gold_inlay.rgb, gold_mask);

	float pulse = 0.86 + 0.14 * sin(TIME * 3.0);
	vec3 glow_col = mix(turquoise_mid.rgb, emerald_sheen.rgb, fresnel);

	ALBEDO = col;
	METALLIC = mix(0.84, 0.98, max(fresnel, gold_mask));
	ROUGHNESS = mix(0.17, 0.07, max(fresnel, gold_mask));
	CLEARCOAT = 0.90;
	CLEARCOAT_ROUGHNESS = 0.10;
	EMISSION = glow_col * (0.40 + 0.65 * fresnel) * glow_strength * pulse + gold_inlay.rgb * (gold_mask * 0.30);
}
