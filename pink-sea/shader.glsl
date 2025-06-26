#define MAX_DISTANCE 128.0

#include "../util/math.glsl"
#include "../util/trace.glsl"
#include "../util/height_march.glsl"
#include "../util/march.glsl"

layout (std140) uniform ubo {
  vec3 view_pos;
  float view_yaw;
  float view_pitch;
  float time;
};

uniform vec2 iResolution;
uniform samplerCube sky;

out vec4 frag_color;

float height(vec2 p);
vec3 height_N(vec2 p);
int map_id(vec3 p, int mask);
float water_height(vec2 p);
vec3 water_N(vec2 p);
float cast_ray(vec3 ro, vec3 rd, int mask);
vec3 fresnelSchlick(float cosTheta, vec3 F0);

vec3 shade_opaque(vec3 ro, vec3 rd, float td);
vec3 shade_water(vec3 ro, vec3 rd, vec3 p);

#define L normalize(vec3(0.5, 1.0, 0.5))
#define WATER (1 << 0)
#define TERRAIN (1 << 1)
#define CONE (1 << 2)
#define GEOMETRY (TERRAIN | CONE)

void main() {
  vec2 screen_pos = gl_FragCoord.xy / iResolution * 2.0 - 1.0;
  screen_pos.x *= iResolution.x / iResolution.y;
  
  mat4 view_mat = mat4(1.0) * rotate_y(view_yaw) * rotate_x(view_pitch);
  vec3 ro = view_pos;
  vec3 rd = normalize((view_mat * vec4(screen_pos, 1.0, 1.0)).xyz);
  
  float td = cast_ray(ro, rd, WATER | GEOMETRY);
  vec3 p = ro + rd * td;
  int id = map_id(p, WATER | GEOMETRY);
  
  vec3 color;
  if (id == WATER) {
    color = shade_water(ro, rd, p);
  } else {
    color = shade_opaque(ro, rd, td);
  }
  
  frag_color = vec4(color, 1.0);
}

vec3 shade_opaque(vec3 ro, vec3 rd, float td) {
  vec3 p = ro + rd * td;
  int id = map_id(p, WATER | GEOMETRY);
  
  vec3 albedo, N;
  if (id == TERRAIN) {
    N = height_N(p.xz);
    albedo = vec3(1.0, 0.8, 0.9) * (1.0 - 0.05 * rand(floor(p.xz * 50.0) / 50.0));
  } else if (id >= CONE) {
    N = sdf_normal(p, CONE);
    if (id == CONE + 0) albedo = vec3(0.91, 0.50, 0.65);
    if (id == CONE + 1) albedo = vec3(0.68, 0.21, 0.53);
    if (id == CONE + 2) albedo = vec3(0.45, 0.21, 0.66);
    if (id == CONE + 3) albedo = vec3(0.71, 0.60, 0.66);
    if (id == CONE + 4) albedo = vec3(0.55, 0.50, 0.53);
    if (id == CONE + 5) albedo = vec3(0.69, 0.42, 0.74);
  } else {
    return mix(texture(sky, rd).xyz, vec3(1.0, 0.8, 0.9), 0.5);
  }
  
  return albedo * (1.0 - max(dot(N, L), 0.0) * 0.3);
}

vec3 shade_water(vec3 ro, vec3 rd, vec3 p) {
  vec3 N = water_N(p.xz);
  
  vec3 albedo = vec3(1.0, 0.4, 1.0);
  float absorb = 0.05;
  
  vec3 F0 = mix(vec3(0.04), albedo, absorb);
  vec3 kS = fresnelSchlick(max(dot(N, -rd), 0.0), F0);
  vec3 kD = (vec3(1.0) - kS) * (1.0 - absorb);
  
  vec3 color = vec3(0.0);
  {
    vec3 R = reflect(rd, N);
    float td = cast_ray(p, R, TERRAIN);
    color += shade_opaque(p, R, td) * kS;
  }
  
  {
    vec3 R = refract(rd, N, 1.0/1.33);
    float td = cast_ray(p, R, TERRAIN);
    vec3 c = shade_opaque(p, R, td);
    color += mix(albedo, c, exp(-0.01 * td)) * kD;
  }

  return color;
}

int map_id(vec3 p, int mask) {
  if ((mask & TERRAIN) > 0) {
    if (p.y - height(p.xz) < 0.1) return TERRAIN;
  }
  
  if ((mask & WATER) > 0) {
    if (sdf_plane(p, vec3(0.0, 1.0, 0.0), 0.5) < MIN_DISTANCE) return WATER;
  }
  
  if ((mask & CONE) > 0) {
    for (int i = 0; i < 6; i++) {
      float s_i = sdf_cylinder(p, vec3(0.0, 4.0 + 3.0 * float(i), 0.0), 6.0 - float(i), 0.1) - 2.0;
      if (s_i < MIN_DISTANCE) return CONE + i;
    }
    float s2 = sdf_cone(p, vec3(0.0, 4.0 + 18.0, 0.0), vec2(1.0, 1.3), 3.0);
    if (s2 < MIN_DISTANCE) return CONE;
  }
  
  return 0;
}

float sdf(vec3 p, int mask) {
  float d = MAX_DISTANCE;
  
  if ((mask & GEOMETRY) > 0) {
    for (float i = 0.0; i < 6.0; i++) {
      float s_i = sdf_cylinder(p, vec3(0.0, 4.0 + 3.0 * i, 0.0), 6.0 - i, 0.1) - 2.0;
      d = min(d, s_i);
    }
    
    float s2 = sdf_cone(p, vec3(0.0, 4.0 + 18.0, 0.0), vec2(1.0, 1.3), 3.0);
    d = min(d, s2);
  }
  
  return d;
}

float height(vec2 p) {
  float a = 3.0 * exp(-pow(dot(0.03 * p, 0.03 * p), 2.0));
  float b = 0.2 * cos(0.5 * p.x + 0.05 * sin(p.y));
  return a + b;
}

vec3 height_N(vec2 p) {
  float d = 0.01;
  float u = height(p);
  float du_dx = (u - height(vec2(p.x - d, p.y))) / d;
  float du_dy = (u - height(vec2(p.x, p.y - d))) / d;
  return normalize(vec3(-du_dx, 1.0, -du_dy));
}

float water_height(vec2 p) {
  p *= 0.4;
  float d1 = length(p.xy - vec2(100.0, 40.0));
  float d2 = length(p.xy - vec2(-100.0, 20.0));
  float d3 = length(p.xy - vec2(70.0, 60.0));
  return cos(d1 * 2.0 + time * 4.0) * 0.07 + cos(d2 * 5.0 + time * 8.0) * 0.03 + cos(d3 * 8.0 + time * 1.0) * 0.01;
}

vec3 water_N(vec2 p) {
  float d = 0.01;
  float u = water_height(p);
  float du_dx = (u - water_height(vec2(p.x - d, p.y))) / d;
  float du_dy = (u - water_height(vec2(p.x, p.y - d))) / d;
  return normalize(vec3(-du_dx, 1.0, -du_dy));
}

float cast_ray(vec3 ro, vec3 rd, int mask) {
  float d = MAX_DISTANCE;
  
  if ((mask & TERRAIN) > 0) {
    d = min(d, height_march(ro, rd));
  }
  
  if ((mask & WATER) > 0) {
    d = min(d, trace_plane(ro, rd, vec3(0.0, 1.0, 0.0), 0.5));
  }
  
  if ((mask & GEOMETRY) > 0) {
    d = min(d, ray_march(ro, rd, GEOMETRY));
  }
  
  return d;
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
  return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}  
