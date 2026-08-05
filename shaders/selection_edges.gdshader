shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled,
	depth_draw_never;


// ------------------------------------------------------------------
// Colours and opacity
// ------------------------------------------------------------------

uniform vec4 line_color : source_color =
	vec4(0.02, 0.28, 1.0, 1.0);

uniform vec4 star_color : source_color =
	vec4(0.82, 0.97, 1.0, 1.0);

uniform float effect_opacity : hint_range(0.0, 1.0) = 1.0;


// ------------------------------------------------------------------
// Base line
// ------------------------------------------------------------------

uniform float core_width : hint_range(0.01, 1.0) = 0.20;
uniform float halo_width : hint_range(0.01, 1.0) = 0.58;

uniform float line_brightness : hint_range(0.0, 12.0) = 1.0;
uniform float halo_brightness : hint_range(0.0, 8.0) = 0.12;


// ------------------------------------------------------------------
// Moving stars
// ------------------------------------------------------------------

uniform int star_count : hint_range(1, 12) = 3;

uniform float star_speed : hint_range(0.0, 2.0) = 0.10;

// Length along the edge.
uniform float star_min_size : hint_range(0.002, 0.15) = 0.012;
uniform float star_max_size : hint_range(0.002, 0.15) = 0.026;

// Width across the ribbon.
uniform float star_min_width : hint_range(0.01, 1.0) = 0.28;
uniform float star_max_width : hint_range(0.01, 1.0) = 0.75;

uniform float star_brightness : hint_range(0.0, 30.0) = 6.0;

uniform float star_pulse_speed : hint_range(0.0, 10.0) = 1.5;
uniform float star_pulse_amount : hint_range(0.0, 1.0) = 0.20;


// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------

float hash_1d(float value) {
	return fract(
		sin(value * 127.1)
		* 43758.5453123
	);
}


float wrapped_distance(
	float first,
	float second
) {
	float difference = abs(first - second);

	return min(
		difference,
		1.0 - difference
	);
}


// Creates one compact elliptical blob.
//
// along_distance controls its length along the edge.
// across controls its width across the ribbon.
float create_compact_star(
	float along_distance,
	float across,
	float star_length,
	float star_width
) {
	float safe_length = max(
		star_length,
		0.0001
	);

	float safe_width = max(
		star_width,
		0.0001
	);

	float normalized_along =
		along_distance / safe_length;

	float normalized_across =
		across / safe_width;

	float radial_distance = length(
		vec2(
			normalized_along,
			normalized_across
		)
	);

	// Small bright centre and short soft edge.
	float star =
		1.0 - smoothstep(
			0.30,
			1.0,
			radial_distance
		);

	// Tightens the shape so it does not look smoky.
	return star * star;
}


// ------------------------------------------------------------------
// Fragment
// ------------------------------------------------------------------

void fragment() {
	// Continuous position along the logical edge.
	float along = UV.x;

	// Zero at the centre of the ribbon and one at its sides.
	float across =
		abs(UV.y - 0.5) * 2.0;

	// Both crossed ribbons receive this same edge seed.
	// Therefore they generate the same stars.
	float edge_seed = UV2.y;


	// --------------------------------------------------------------
	// Base line
	// --------------------------------------------------------------

	float safe_core_width = max(
		core_width,
		0.001
	);

	float safe_halo_width = max(
		halo_width,
		safe_core_width + 0.001
	);

	float core =
		1.0 - smoothstep(
			0.0,
			safe_core_width,
			across
		);

	float halo =
		1.0 - smoothstep(
			safe_core_width,
			safe_halo_width,
			across
		);


	// --------------------------------------------------------------
	// One deterministic star list per logical edge
	// --------------------------------------------------------------

	float stars = 0.0;

	float safe_min_size = min(
		star_min_size,
		star_max_size
	);

	float safe_max_size = max(
		star_min_size,
		star_max_size
	);

	float safe_min_width = min(
		star_min_width,
		star_max_width
	);

	float safe_max_width = max(
		star_min_width,
		star_max_width
	);

	for (int index = 0; index < 12; index++) {
		if (index >= star_count) {
			break;
		}

		float star_index = float(index);

		// Depends only on the logical edge and star index.
		// Both crossed ribbons therefore get identical results.
		float star_seed =
			edge_seed * 31.73
			+ star_index * 7.19;

		float speed_variation = mix(
			0.55,
			1.45,
			hash_1d(star_seed * 3.71)
		);

		float movement_direction = mix(
			-1.0,
			1.0,
			step(
				0.5,
				hash_1d(star_seed * 5.23)
			)
		);

		// Start stars apart instead of placing them completely randomly.
		float initial_position =
			star_index / float(star_count);

		initial_position += (
			hash_1d(star_seed * 9.17) - 0.5
		) * 0.10;

		float star_position = fract(
			initial_position
			+ TIME
				* star_speed
				* speed_variation
				* movement_direction
		);

		float random_length = mix(
			safe_min_size,
			safe_max_size,
			hash_1d(star_seed * 11.31)
		);

		float random_width = mix(
			safe_min_width,
			safe_max_width,
			hash_1d(star_seed * 13.73)
		);

		float along_distance = wrapped_distance(
			along,
			star_position
		);

		float star = create_compact_star(
			along_distance,
			across,
			random_length,
			random_width
		);

		float pulse =
			1.0
			+ sin(
				TIME
					* star_pulse_speed
					* speed_variation
				+ star_seed
			) * star_pulse_amount;

		float brightness_variation = mix(
			0.65,
			1.0,
			hash_1d(star_seed * 17.43)
		);

		stars += (
			star
			* pulse
			* brightness_variation
		);
	}


	// --------------------------------------------------------------
	// Output
	// --------------------------------------------------------------

	vec3 line_output =
		line_color.rgb
		* (
			core * line_brightness
			+ halo * halo_brightness
		);

	vec3 star_output =
		star_color.rgb
		* stars
		* star_brightness;

	vec3 visible_color =
		line_output
		+ star_output;

	float alpha =
		(
			core
			+ halo * 0.20
			+ stars
		)
		* COLOR.a
		* effect_opacity;

	ALBEDO =
		visible_color
		* effect_opacity;

	EMISSION =
		visible_color
		* effect_opacity;

	ALPHA = clamp(
		alpha,
		0.0,
		1.0
	);
}