shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0;

// LMS Daltonization for Protanopia (1), Deuteranopia (2), and Tritanopia (3).
vec3 daltonize(vec3 rgb, int cb_mode) {
	if (cb_mode <= 0 || cb_mode > 3) {
		return rgb;
	}

	// RGB to LMS
	float l = (17.8824 * rgb.r) + (43.5161 * rgb.g) + (4.11935 * rgb.b);
	float m = (3.45565 * rgb.r) + (27.1554 * rgb.g) + (3.86714 * rgb.b);
	float s = (0.0299566 * rgb.r) + (0.184309 * rgb.g) + (1.46709 * rgb.b);

	// Simulate dichromacy in LMS space
	float l_sim = l;
	float m_sim = m;
	float s_sim = s;

	if (cb_mode == 1) {
		// Protanopia
		l_sim = 0.0 * l + 2.02344 * m - 2.52581 * s;
	} else if (cb_mode == 2) {
		// Deuteranopia
		m_sim = 0.494207 * l + 0.0 * m + 1.24827 * s;
	} else {
		// Tritanopia
		s_sim = -0.395913 * l + 0.801109 * m + 0.0 * s;
	}

	// LMS back to RGB (simulated perception)
	vec3 sim_rgb;
	sim_rgb.r = (0.0809444479 * l_sim) + (-0.130504409 * m_sim) + (0.116721066 * s_sim);
	sim_rgb.g = (-0.0102485335 * l_sim) + (0.0540193266 * m_sim) + (-0.113614708 * s_sim);
	sim_rgb.b = (-0.000365296938 * l_sim) + (-0.00412161469 * m_sim) + (0.693511405 * s_sim);

	// Error vector and shift to perceivable channels
	vec3 err = rgb - sim_rgb;
	vec3 correction;
	if (cb_mode == 3) {
		correction = vec3(
			err.r + 0.7 * err.b,
			err.g + 0.7 * err.b,
			0.0
		);
	} else {
		correction = vec3(
			0.0,
			err.g + 0.7 * err.r,
			err.b + 0.7 * err.r
		);
	}

	return clamp(rgb + correction, 0.0, 1.0);
}

void fragment() {
	vec4 src = texture(screen_texture, SCREEN_UV);
	vec3 out_rgb = daltonize(src.rgb, mode);
	COLOR = vec4(out_rgb, 1.0);
}
