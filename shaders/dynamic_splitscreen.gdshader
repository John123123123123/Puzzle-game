shader_type canvas_item;

uniform sampler2D viewport_p1 : filter_linear;
uniform sampler2D viewport_p2 : filter_linear;
uniform vec2 split_normal = vec2(1.0, 0.0);
uniform float aspect = 1.77778;
uniform float split_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float line_width : hint_range(0.0, 0.03) = 0.0028;
uniform vec4 line_core_color : source_color = vec4(0.06, 0.05, 0.08, 1.0);
uniform vec4 line_trim_color : source_color = vec4(0.92, 0.75, 0.28, 1.0);

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 n = length(split_normal) > 0.0001 ? normalize(split_normal) : vec2(1.0, 0.0);
	float signed_dist = dot(centered, n);

	vec4 col_p1 = texture(viewport_p1, UV);
	vec4 col_p2 = texture(viewport_p2, UV);

	float aa = 0.0009;
	float side_mix = smoothstep(-aa, aa, signed_dist);
	vec4 scene_col = mix(col_p1, col_p2, side_mix);

	// Temple-styled dark + burnished-gold dividing bar that smoothly grows & fades in with split_alpha
	float active_half_w = line_width * 0.5 * mix(0.25, 1.0, split_alpha);
	float trim_half_w = active_half_w + 0.0009 * split_alpha;
	float abs_d = abs(signed_dist);

	float outer_mask = 1.0 - smoothstep(trim_half_w - aa, trim_half_w + aa, abs_d);
	float core_mask = 1.0 - smoothstep(active_half_w - aa, active_half_w + aa, abs_d);

	vec3 divider_rgb = mix(line_trim_color.rgb, line_core_color.rgb, core_mask);
	vec3 final_rgb = mix(scene_col.rgb, divider_rgb, outer_mask * split_alpha);

	COLOR = vec4(final_rgb, 1.0);
}
