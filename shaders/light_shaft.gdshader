shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 beam_color : source_color = vec4(1.0, 0.92, 0.65, 0.22);
uniform float falloff_power = 2.5;

void fragment() {
    // Fade at top and bottom
    float vert_fade = sin(UV.y * 3.14159);
    // Subtle dust motion
    float dust = sin(UV.y * 20.0 + TIME * 1.5) * cos(UV.x * 15.0 - TIME * 0.8) * 0.08 + 0.92;

    float alpha = pow(vert_fade, falloff_power) * beam_color.a * dust;
    ALBEDO = beam_color.rgb;
    ALPHA = clamp(alpha, 0.0, 1.0);
}
