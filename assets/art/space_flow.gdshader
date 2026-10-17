shader_type canvas_item;
render_mode unshaded;
uniform float visual_time = 0.0;
uniform vec2 world_shift = vec2(0.0);
uniform vec2 gravity_center = vec2(-2.0);
uniform float gravity_power = 0.0;
uniform float aspect = 1.777;

void fragment() {
	vec2 uv = UV;
	vec2 toward = uv - gravity_center;
	vec2 metric = toward * vec2(aspect, 1.0);
	float pull = exp(-dot(metric, metric) * 13.0) * gravity_power;
	uv += vec2(-toward.y, toward.x) * pull * 0.16;
	uv += toward * pull * 0.09 * sin(visual_time * 0.7);
	vec2 flow = vec2(sin(uv.y * 5.0 + visual_time * 0.045), cos(uv.x * 4.0 - visual_time * 0.036));
	vec2 far_uv = uv * 0.78 + 0.11 + world_shift * 0.000018 + flow * 0.013;
	vec2 near_uv = uv * 0.70 + 0.15 + world_shift * 0.000045 - flow * 0.024;
	vec3 far_field = texture(TEXTURE, clamp(far_uv, vec2(0.01), vec2(0.99))).rgb;
	vec3 near_field = texture(TEXTURE, clamp(near_uv, vec2(0.01), vec2(0.99))).rgb;
	vec3 color = far_field * 0.82 + near_field * 0.12;
	float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
	color = mix(vec3(gray), color, 1.18);
	COLOR = vec4(pow(max(color, vec3(0.0)), vec3(1.02)), 1.0);
}
