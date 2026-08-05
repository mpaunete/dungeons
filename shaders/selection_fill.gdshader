shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled,
	depth_draw_never;


uniform vec4 fill_color : source_color =
	vec4(0.05, 0.35, 1.0, 1.0);

uniform float fill_opacity : hint_range(0.0, 1.0) = 0.22;


void fragment() {
	ALBEDO = fill_color.rgb;
	EMISSION = fill_color.rgb * 0.35;

	ALPHA =
		fill_color.a
		* fill_opacity;
}