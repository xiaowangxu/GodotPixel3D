shader_type spatial;
render_mode unshaded;

uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform sampler2D normal_texture : source_color, hint_normal_roughness_texture;

varying mat4 inv_proj_mat4;
varying vec2 inv_res;
varying vec2 screen_uv;

void vertex() {
	inv_proj_mat4 = INV_PROJECTION_MATRIX;
	POSITION = vec4(VERTEX, 1.0);
}

float depth(vec2 uv) {
	float depth = texture(depth_texture, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_proj_mat4 * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	return linear_depth;
}

float getDepth(int x, int y) {
    return depth(screen_uv + vec2(float(x),float(y)) * inv_res);
}
vec3 getNormal(int x, int y) {
    return texture(normal_texture, screen_uv + vec2(float(x),float(y)) * inv_res).rgb * 2.0 - 1.0;
}
float neighborNormalEdgeIndicator(int x, int y, float depth, vec3 normal) {
    float depthDiff = getDepth(x, y) - depth;
	// Edge pixels should yield to faces closer to the bias direction.
	vec3 normalEdgeBias = vec3(1., 1., 1.); // This should probably be a parameter.
	float normalDiff = dot(normal - getNormal(x, y), normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
	// Only the shallower pixel should detect the normal edge.
	float depthIndicator = clamp(sign(depthDiff * .25 + .0025), 0.0, 1.0);
    return distance(normal, getNormal(x, y)) * depthIndicator * normalIndicator;
}
float depthEdgeIndicator() {
    float depth = getDepth(0, 0);
    vec3 normal = getNormal(0, 0);
    float diff = 0.0;
    diff += clamp(getDepth(1, 0) - depth, 0.0, 1.0);
    diff += clamp(getDepth(-1, 0) - depth, 0.0, 1.0);
    diff += clamp(getDepth(0, 1) - depth, 0.0, 1.0);
    diff += clamp(getDepth(0, -1) - depth, 0.0, 1.0);
    return floor(smoothstep(0.1, 0.15, diff) * 2.) / 2.;
}
float normalEdgeIndicator() {
    float depth = getDepth(0, 0);
    vec3 normal = getNormal(0, 0);
    float indicator = 0.0;
    indicator += neighborNormalEdgeIndicator(0, -1, depth, normal);
    indicator += neighborNormalEdgeIndicator(0, 1, depth, normal);
    indicator += neighborNormalEdgeIndicator(-1, 0, depth, normal);
    indicator += neighborNormalEdgeIndicator(1, 0, depth, normal);
    return step(0.1, indicator);
}
float lum(vec4 color) {
    vec4 weights = vec4(.2126, .7152, .0722, .0);
    return dot(color, weights);
}
float smoothSign(float x, float radius) {
    return smoothstep(-radius, radius, x) * 2.0 - 1.0;
}

void fragment() {
	inv_res = 1.0 / VIEWPORT_SIZE;
	screen_uv = SCREEN_UV;
	vec4 texel = texture(screen_texture, screen_uv);
    float tLum = lum(texel);
    // float normalEdgeCoefficient = (smoothSign(tLum - .3, .1) + .7) * .25;
    // float depthEdgeCoefficient = (smoothSign(tLum - .3, .1) + .7) * .3;
    float normalEdgeCoefficient = .5;
    float depthEdgeCoefficient = .3;

    float dei = depthEdgeIndicator();
    float nei = normalEdgeIndicator();

    float coefficient = dei > 0.0 ? (1.0 - depthEdgeCoefficient * dei) : (1.0 + normalEdgeCoefficient * nei);

    ALBEDO = texel.rgb * coefficient; //vec3(1.0 - (1.0 - depthEdgeCoefficient * dei), 0.0, 0.0);
}

