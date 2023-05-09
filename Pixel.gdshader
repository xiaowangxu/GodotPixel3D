shader_type spatial;
render_mode unshaded;

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_linear;

uniform float sample_offset : hint_range(0, 10, 0.1) = 1;
uniform float depth_diff_multiplier : hint_range(0, 100, 0.01) = 1.0;
uniform float depth_threshold : hint_range(0, 1, 0.0001) = 1.0;
uniform float normal_edge : hint_range(0, 10, 0.001) = 1.0;

varying mat4 inv_proj_mat4;

void vertex() {
	inv_proj_mat4 = INV_PROJECTION_MATRIX;
	POSITION = vec4(VERTEX, 1.0);
}

float linear_depth(in vec2 uv) {
	float log_depth = texture(depth_texture, uv).x;
	vec4 depth_view = inv_proj_mat4 * vec4(uv * 2.0 - 1.0, log_depth, 1.0);
	depth_view.xyz /= depth_view.w;
	return - depth_view.z;
}

vec3 mapped_normal(in vec2 uv) {
	return texture(normal_texture, uv).xyz;
}

void cross_uv_sample(in vec2 uv, in vec2 pixel_size, in float offset,
	out vec2 uv_origin, out vec2 uv_top_left, out vec2 uv_top_right, out vec2 uv_bottom_left, out vec2 uv_botton_right) {
	uv_origin = uv;
	uv_top_right = uv + pixel_size * offset;
	uv_bottom_left = uv - pixel_size * offset;
	uv_top_left = vec2(uv_bottom_left.x, uv_top_right.y);
	uv_botton_right = vec2(uv_top_right.x, uv_bottom_left.y);
}

void dir_uv_sample(in vec2 uv, in vec2 pixel_size, in float offset,
	out vec2 uv_origin, out vec2 uv_top_left, out vec2 uv_top_right, out vec2 uv_bottom_left, out vec2 uv_botton_right) {
	uv_origin = uv;
	uv_top_left = uv - vec2(0, pixel_size.y) * offset;
	uv_top_right = uv + vec2(pixel_size.x, 0) * offset;
	uv_botton_right = uv + vec2(0, pixel_size.y) * offset;
	uv_bottom_left = uv - vec2(pixel_size.x, 0) * offset;
}

float normal_differ(vec2 uv, float depth, vec3 center_normal) {
	vec3 normal = mapped_normal(uv);
    float depth_diff = linear_depth(uv) - depth;
	// Edge pixels should yield to faces closer to the bias direction.
	vec3 normalEdgeBias = vec3(1., 1., 1.); // This should probably be a parameter.
	float normalDiff = dot(center_normal - normal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	// Only the shallower pixel should detect the normal edge.
	float depthIndicator = clamp(sign(depth_diff * .25 + .0025), 0.0, 1.0);
    return distance(center_normal, normal) * depthIndicator * normalIndicator;
}

void fragment() {
	
	vec2 pixel_size = 1.0 / VIEWPORT_SIZE;
	vec2 uv_origin, uv_top_left, uv_top_right, uv_bottom_left, uv_botton_right;
	dir_uv_sample(SCREEN_UV, pixel_size, sample_offset, uv_origin, uv_top_left, uv_top_right, uv_bottom_left, uv_botton_right);
	
	float depth = linear_depth(uv_origin);
	vec3 normal = mapped_normal(uv_origin);
	
	// depth
	float 	depth_top_left = linear_depth(uv_top_left), 
			depth_top_right = linear_depth(uv_top_right), 
			depth_bottom_left = linear_depth(uv_bottom_left), 
			depth_botton_right = linear_depth(uv_botton_right);
	float depth_diff = (clamp(depth_top_left - depth, 0.0, 1.0) +
						clamp(depth_top_right - depth, 0.0, 1.0) + 
						clamp(depth_bottom_left - depth, 0.0, 1.0) +
						clamp(depth_botton_right - depth, 0.0, 1.0) ) * depth_diff_multiplier;
	float depth_thres = step(depth * depth_threshold, depth_diff);
	
	// normal
	float normal_diff = (  normal_differ(uv_top_left, depth, normal) +
						   normal_differ(uv_top_right, depth, normal) + 
						   normal_differ(uv_bottom_left, depth, normal) +
						   normal_differ(uv_botton_right, depth, normal) );
	float normal_thres = step(normal_edge, normal_diff);
	
	// not
	// NODE_POSITION_VIEW
	vec3 remapped_normal = normal * 2.0 - 1.0;
	vec4 camera_normal = (VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0));
	vec3 w_camera_normal = normalize(camera_normal.xyz);
	float view_diff = dot(remapped_normal, w_camera_normal);
	
	vec3 texel = texture(screen_texture, SCREEN_UV).rgb;
	
	ALBEDO = texel * (1.0 - max(depth_thres, depth_thres > 0.0 ? 0.0 : normal_thres) * 0.5);
}
