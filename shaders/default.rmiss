#version 460
#extension GL_EXT_ray_tracing : require
#define M_PI 3.1415926535897932384626433832795
#define lonsegs 100
#define latsegs 50

struct RayTracingHit {
	vec4 color;
	vec4 transparentColor[2];
	float transparentDist[4];	//0 = goal, 1 = character
	uvec4 various;		//x = goal, y = recursions, z = renderCharacter
};

layout(set = 3, binding = 0) uniform Background {
	vec4 color;
} background;

readonly layout(set = 3, binding = 1) buffer Gradients {
	float arr[lonsegs*latsegs*2];
} gradients;

rayPayloadInEXT RayTracingHit hitValue;

const float infty = 1. / 0.;


vec2 gradient(int ix, int iy, int level) {
	return vec2(gradients.arr[latsegs/level*ix+2*iy+0], gradients.arr[latsegs/level*ix+2*iy+1]);
}

float dotGridGradient(int ix, int iy, float x, float y, int level) {
	float dx = x - ix;
	float dy = y - iy;
	vec2 grad = gradient(int(mod(ix + level, lonsegs/level)), int(mod(iy + level, latsegs/level)), level);
	return dx*grad.x + dy*grad.y;
}

float perlin(float phi, float theta, int level) {
	int lons = lonsegs / level;
	int lats = latsegs / level;
	float x = mod(phi/(2*M_PI)*lons, lons);
	float y = mod(theta/(M_PI)*lats, lats);
	int x0 = int(x);
	int x1 = x0 + 1;
	int y0 = int(y);
	int y1 = y0 + 1;

	float sx = x - x0;
	float sy = y - y0;

	float n0 = dotGridGradient(x0, y0, x, y, level);
	float n1 = dotGridGradient(x1, y0, x, y, level);
	float ix0 = mix(n0, n1, sx);
	n0 = dotGridGradient(x0, y1, x, y, level);
	n1 = dotGridGradient(x1, y1, x, y, level);
	float ix1 = mix(n0, n1, sx);
	return mix(ix0, ix1, sy);
}

float SRGBReverseGamma(float color) {
	return pow(color, 2.2);
	if (color <= 0.0045) {
		return color / 12.92;
	}
	return pow((color + 0.055) / 1.055, 2.4);
}

void main()
{
	float theta = acos(gl_WorldRayDirectionEXT.y);
	float phi = atan(gl_WorldRayDirectionEXT.z, gl_WorldRayDirectionEXT.x);
	float alpha = 1-clamp(tan((theta-M_PI/2)/1.2),0,1);
    vec3 backgrcolor = alpha*background.color.xyz;
	vec3 color = exp(-pow(1.9*(theta-M_PI/2),2))*0.05*(perlin(phi, theta, 1) + perlin(phi, theta, 2) + perlin(phi, theta, 4)) + backgrcolor;
	color = vec3(SRGBReverseGamma(color.r), SRGBReverseGamma(color.g), SRGBReverseGamma(color.b));
	color = clamp(color, vec3(0), vec3(1));
	hitValue.color.rgb = hitValue.transparentColor[0].rgb + hitValue.transparentColor[1].rgb + color;
	hitValue.various.y = hitValue.various.y | uint(hitValue.transparentDist[1] < 200);
}