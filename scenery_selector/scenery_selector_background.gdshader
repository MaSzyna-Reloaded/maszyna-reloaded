shader_type canvas_item;

// The scenery selector's background, drawn here and not from a picture: an abstract of dark blue
// smears - brush strokes swirled over one another, near flat, drifting slowly - dissolved away by
// noise blotches when a scenario is chosen, uncovering the loading screen below. No texture is
// read: any node draws it over its rect.

uniform vec3 tint : source_color = vec3(0.16, 0.27, 0.5);
uniform float brightness : hint_range(0.0, 2.0) = 1.2;
// how bright the smears lie on the whole (a share of the tint) and how far they stand out of it
uniform float level : hint_range(0.0, 1.0) = 0.32;
uniform float contrast : hint_range(0.0, 1.0) = 0.28;
// how many smears across the height, how long the strokes are drawn out and how fast they drift
uniform float smear_scale : hint_range(0.5, 10.0) = 2.2;
uniform float stroke_stretch : hint_range(1.0, 12.0) = 6.0;
uniform float drift_speed : hint_range(0.0, 0.2) = 0.008;
// how much darker the corners are
uniform float vignette : hint_range(0.0, 1.0) = 0.3;
// 0 - fully visible, 1 - fully dissolved
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_softness : hint_range(0.01, 1.0) = 0.25;
uniform float dissolve_scale = 6.0;

// a hash without sin: steady at the large coordinates the drawn-out strokes reach
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// octaves of noise, each turned against the last so its grid does not show - few: the finest would
// come near a pixel's size and shimmer as dots
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int octave = 0; octave < octaves; octave++) {
		value += amplitude * value_noise(p);
		p = turn * p * 2.03 + 11.7;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	// the strokes keep the screen's aspect
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = UV * vec2(aspect, 1.0) * smear_scale;
	float t = TIME * drift_speed;
	// the paint pushed about: the smears swirl where the warp turns them
	vec2 warp = vec2(fbm(p + vec2(0.0, t), 3), fbm(p + vec2(5.2, 1.3) - t, 3));
	vec2 q = p + 1.8 * warp;
	// patches of paint laid over one another, their edges sharp as a brush leaves them
	float patches = smoothstep(0.42, 0.58, fbm(q, 3));
	// the strokes drawn out along the flow and the bristles' streaks inside them
	float strokes = smoothstep(0.35, 0.65, fbm(vec2(q.x, q.y * stroke_stretch), 3));
	float bristles = value_noise(vec2(q.x * 0.7, q.y * stroke_stretch * 5.0));
	float paint = mix(patches, strokes, 0.5) + 0.25 * (bristles - 0.5);
	float shade = level + contrast * (paint - 0.5) * 2.0;
	shade *= 1.0 - vignette * smoothstep(0.35, 0.95, length(UV - 0.5) * 1.4);
	float n = 0.65 * value_noise(UV * dissolve_scale) + 0.35 * value_noise(UV * dissolve_scale * 4.0);
	float threshold = dissolve * (1.0 + dissolve_softness);
	// input COLOR carries the node modulate
	COLOR *= vec4(tint * shade * brightness, smoothstep(threshold - dissolve_softness, threshold, n));
}
