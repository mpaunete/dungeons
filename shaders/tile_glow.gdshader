shader_type spatial;

render_mode unshaded, blend_add, cull_disabled,
	depth_draw_never, depth_test_disabled;

uniform vec4 glow_color : source_color =
	vec4(0.03, 0.40, 1.0, 1.0);

uniform float emission_strength : hint_range(0.0, 12.0) = 5.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.45;
uniform float minimum_opacity : hint_range(0.0, 1.0) = 0.25;

uniform float effect_opacity : hint_range(0.0, 1.0) = 1.0;


void fragment() {
	float wave = sin(TIME * pulse_speed) * 0.5 + 0.5;

	float brightness = mix(
		1.0 - pulse_amount,
		1.0 + pulse_amount,
		wave
	);

	float opacity = mix(
		minimum_opacity,
		1.0,
		wave
	);

	ALBEDO = glow_color.rgb * brightness;

	EMISSION =
		glow_color.rgb
		* emission_strength
		* brightness;

	ALPHA =
		COLOR.a
		* glow_color.a
		* opacity
		* effect_opacity;
}