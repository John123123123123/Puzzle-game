shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 slab_color : source_color = vec4(0.50, 0.43, 0.33, 1.0);
uniform vec4 slab_dark : source_color = vec4(0.32, 0.27, 0.21, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.14, 0.11, 0.09, 1.0);
uniform vec4 bronze_color : source_color = vec4(0.68, 0.52, 0.24, 1.0);
uniform vec4 rune_glow : source_color = vec4(0.95, 0.72, 0.28, 1.0);
uniform vec3 platform_half_size = vec3(1.6, 0.17, 1.6);

varying vec3 local_pos;
varying vec3 local_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i + vec2(0.0, 0.0));
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = normalize(NORMAL);
}

void fragment() {
	bool is_top = abs(local_normal.y) > 0.7;

	vec3 final_color = slab_color.rgb;
	float roughness_out = 0.80;
	float metallic_out = 0.04;
	vec3 emission_out = vec3(0.0);

	if (is_top) {
		// Carved sandstone flagstone grid strictly in local XZ space (zero swimming while moving!)
		float tile_s = 0.78;
		vec2 uv = local_pos.xz / tile_s;
		float row_idx = floor(uv.y);
		uv.x += mod(abs(row_idx), 2.0) * 0.5;
		vec2 cell_id = floor(uv);
		vec2 f = fract(uv);

		vec2 edge_norm = min(f, 1.0 - f) * tile_s;
		float edge_d = min(edge_norm.x, edge_norm.y);
		float mortar = smoothstep(0.015, 0.036, edge_d);
		float bevel = smoothstep(0.036, 0.072, edge_d);

		float rnd = hash21(cell_id + vec2(11.3, 27.9));
		float grain = value_noise(local_pos.xz * 7.5);
		vec3 stone_base = mix(slab_dark.rgb, slab_color.rgb, 0.55 + 0.45 * rnd) * (0.88 + 0.22 * grain);
		vec3 beveled_stone = mix(stone_base * 1.15, stone_base, bevel);
		final_color = mix(mortar_color.rgb, beveled_stone, mortar);
		roughness_out = mix(0.95, 0.78, mortar * bevel);

		// Burnished bronze perimeter frame
		float edge_dist = min(platform_half_size.x - abs(local_pos.x), platform_half_size.z - abs(local_pos.z));
		float bronze_band = smoothstep(0.045, 0.07, edge_dist) * (1.0 - smoothstep(0.18, 0.21, edge_dist));
		float bronze_rim_groove = smoothstep(0.18, 0.20, edge_dist) * (1.0 - smoothstep(0.22, 0.24, edge_dist));
		final_color = mix(final_color, mortar_color.rgb * 0.85, bronze_rim_groove * 0.8);
		final_color = mix(final_color, bronze_color.rgb * (0.90 + 0.16 * grain), bronze_band);
		metallic_out = mix(metallic_out, 0.80, bronze_band);
		roughness_out = mix(roughness_out, 0.30, bronze_band);

		// Central carved sun-diamond & compass medallion (top surface only)
		if (local_normal.y > 0.7) {
			float r = length(local_pos.xz);
			float ring = smoothstep(0.36, 0.39, r) * (1.0 - smoothstep(0.45, 0.48, r));
			float diamond = abs(local_pos.x) + abs(local_pos.z);
			float d_inlay = smoothstep(0.26, 0.29, diamond) * (1.0 - smoothstep(0.35, 0.38, diamond));
			float inner_seal = 1.0 - smoothstep(0.14, 0.17, diamond);
			float ornament = clamp(max(ring, d_inlay), 0.0, 1.0);

			final_color = mix(final_color, bronze_color.rgb, ornament * 0.92);
			metallic_out = mix(metallic_out, 0.82, ornament);
			roughness_out = mix(roughness_out, 0.28, ornament);
			emission_out = rune_glow.rgb * (ornament * 0.22 + inner_seal * 0.42);
		}
	} else {
		// Side faces: carved stone frieze with recessed dark-bronze gear track channel & stone dentils
		float h_coord = abs(local_normal.x) > 0.5 ? local_pos.z : local_pos.x;
		float grain = value_noise(vec2(h_coord, local_pos.y) * 9.0);
		float channel = 1.0 - smoothstep(0.032, 0.052, abs(local_pos.y));
		float dentil_wave = step(0.5, fract(h_coord * 2.2));
		vec3 side_stone = mix(slab_dark.rgb, slab_color.rgb, 0.5 + 0.18 * dentil_wave) * (0.86 + 0.24 * grain);
		vec3 channel_bronze = bronze_color.rgb * 0.62;

		final_color = mix(side_stone, channel_bronze, channel);
		metallic_out = mix(0.05, 0.78, channel);
		roughness_out = mix(0.84, 0.36, channel);
	}

	ALBEDO = final_color;
	METALLIC = metallic_out;
	ROUGHNESS = roughness_out;
	SPECULAR = mix(0.18, 0.55, metallic_out);
	EMISSION = emission_out;
}
