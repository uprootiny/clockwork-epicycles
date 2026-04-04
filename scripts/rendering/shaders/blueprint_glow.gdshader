shader_type canvas_item;

uniform float glow_intensity : hint_range(0.0, 2.0) = 0.4;
uniform vec4 glow_color : source_color = vec4(0.5, 0.9, 1.0, 1.0);
uniform float blur_radius : hint_range(0.0, 8.0) = 2.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float luminance = dot(original.rgb, vec3(0.299, 0.587, 0.114));

	vec4 blur = vec4(0.0);
	float total_weight = 0.0;
	vec2 pixel_size = TEXTURE_PIXEL_SIZE;

	for (float x = -blur_radius; x <= blur_radius; x += 1.0) {
		for (float y = -blur_radius; y <= blur_radius; y += 1.0) {
			float weight = 1.0 / (1.0 + x * x + y * y);
			blur += texture(TEXTURE, UV + vec2(x, y) * pixel_size) * weight;
			total_weight += weight;
		}
	}
	blur /= total_weight;

	float glow_mask = smoothstep(0.3, 0.8, luminance);
	vec4 glow = mix(blur, vec4(glow_color.rgb, blur.a), 0.5) * glow_mask * glow_intensity;

	COLOR = original + glow;
	COLOR.a = original.a;
}
