#define MAX_DISTANCE 64.0

#include "../util/math.glsl"
#include "../util/march.glsl"
#include "../util/ggx.glsl"

#define WATER (1 << 0)
#define GROUND (1 << 1)
#define WALL (1 << 2)
#define FENCE (1 << 3)
#define LEDGE (1 << 4)

layout (std140) uniform ubo {
  vec3 view_pos;
  float view_yaw;
  float view_pitch;
  float time;
};

struct light_t {
  vec3 position;
  vec3 radiance;
};

out vec4 frag_color;
float sdf(vec3 p, int mask);
float sdf_repeat_gap(vec3 p);
float sdf_repeat_window(vec3 p);
float sdf_repeat_fence(vec3 p);
float sdf_repeat_bridge(vec3 p);

vec3 calc_point_lighting(vec3 p, vec3 V, vec3 N, vec3 albedo, float metallic, float roughness);
light_t lights_get(int num);
int lights_count();

int map_id(vec3 p, int mask);
vec3 shade_solid(vec3 ro, vec3 rd, float td, vec3 p, int id);
vec3 shade_water(vec3 ro, vec3 rd, float td, vec3 p);
vec3 water_N(vec2 p);

uniform sampler2D mat_albedo;
uniform sampler2D mat_normal;
uniform sampler2D mat_roughness;
uniform sampler2D graffiti;

void main() {
  vec2 screen_pos = gl_FragCoord.xy / 300.0 * 2.0 - 1.0;
  mat4 view_mat = mat4(1.0) * rotate_y(view_yaw) * rotate_x(view_pitch);
  vec3 ro = view_pos;
  vec3 rd = normalize((view_mat * vec4(screen_pos, 1.0, 1.0)).xyz);
  
  float td = ray_march(ro, rd, 255);
  vec3 p = ro + rd * td;
  int id = map_id(p, 255);

  vec3 color = id == WATER ? shade_water(ro, rd, td, p) : shade_solid(ro, rd, td, p, id);
  
  frag_color = vec4(color, 1.0);
}

vec3 shade_water(vec3 ro, vec3 rd, float td, vec3 p) {
  vec3 N = water_N(p.xz);

  vec3 albedo = vec3(0.5, 1.0, 0.4);
  float absorb = 0.1;
  
  vec3 F0 = mix(vec3(0.04), albedo, absorb);
  vec3 kS = fresnelSchlick(max(dot(N, -rd), 0.0), F0);
  vec3 kD = (vec3(1.0) - kS) * absorb;
  
  vec3 color = vec3(0.0);
  {
    vec3 R = reflect(rd, N);
    float td = ray_march(p, R, GROUND | WALL | FENCE | LEDGE);
    vec3 q = p + R * td;
    int id = map_id(q, GROUND | WALL | FENCE);
    color += shade_solid(p, R, td, q, id) * kS;
  }
  
  {
    vec3 R = refract(rd, N, 1.0/1.33);
    float td = ray_march(p, R, GROUND | WALL | FENCE | LEDGE);
    vec3 q = p + R * td;
    int id = map_id(q, GROUND | WALL | FENCE);
    vec3 c = shade_solid(p, R, td, q, id) * kS;
    color += mix(albedo, c, exp(-0.001 * td)) * kD;
  }
  
  color *= exp(-td * 0.05);

  return color;
}

vec3 shade_solid(vec3 ro, vec3 rd, float td, vec3 p, int id) {
  if (id == 0)
    return vec3(0.0);

  mat3 TBN = axis_aligned_TBN(p, 0);
  vec2 uv = fract((transpose(TBN) * p).xy * 0.25);
  vec3 N = TBN * normalize(texture(mat_normal, uv).xyz * 2.0 - 1.0);
  vec3 V = rd;
  
  vec3 albedo = texture(mat_albedo, uv).xyz;
  if (id == WALL) {
    albedo *= vec3(0.32, 0.20, 0.49);
    vec3 q = p;
    q.z = mod(q.z, 64.0);
    if (q.z > 14.0 && q.z < 18.0 && q.y < 4.0) {
      vec2 g_uv = (q.zy - vec2(14.0, 0.0)) / 4.0;
      vec4 g_albedo = texture(graffiti, g_uv);
      albedo = mix(albedo, g_albedo.rgb, g_albedo.a);
    }
  } else if (id == GROUND)
    albedo = mix(vec3(0.09, 0.12, 0.02), albedo, 0.5);
  else if (id == LEDGE)
    albedo = mix(vec3(0.04, 0.02, 0.01), albedo, 0.2);

  float metalness = 0.1;
  float roughness = texture(mat_roughness, uv).r;
  if (id == FENCE) {
    metalness = 0.6;
    roughness *= 0.5;
  }
  
  vec3 q = p;
  q.z = mod(p.z, 32.0);
  float beta = exp(-td * 0.05);

  return calc_point_lighting(q, V, N, albedo, metalness, roughness) * beta;
}

int map_id(vec3 p, int mask) {
  float water = sdf_plane(p, vec3(0.0, 1.0, 0.0), -0.5);
  if ((mask & WATER) > 0 && water < MIN_DISTANCE) return WATER;
  
  float ledge1 = sdf_cuboid(p, vec3(-2.0, -3.0, -10000.0), vec3(0.2, 3.05, 20000.0));
  float ledge2 = sdf_cuboid(p, vec3(0.8, -3.0, -10000.0), vec3(0.2, 3.05, 20000.0));
  float ledge = min(ledge1, ledge2);
  if ((mask & LEDGE) > 0 && ledge < MIN_DISTANCE) return LEDGE;

  float ground = sdf_sub(sdf_plane(p, vec3(0.0, 1.0, 0.0), 0.0), sdf_cuboid(p, vec3(-2.0, -1.0, -10000.0), vec3(3.0, 1.5, 20000.0)));
  if ((mask & GROUND) > 0 && ground < MIN_DISTANCE) return GROUND;

  float gap = sdf_repeat_gap(p);
  float window = sdf_repeat_window(p);
  float wall = sdf_sub(sdf_sub(sdf_plane(p, vec3(+1.0, 0.0, 0.0), -3.0), gap), window);
  if ((mask & WALL) > 0 && wall < MIN_DISTANCE) return WALL;

  float bridge = sdf_repeat_bridge(p);
  float fence = sdf_repeat_fence(p);
  if ((mask & FENCE) > 0 && (bridge < MIN_DISTANCE || fence < MIN_DISTANCE)) return FENCE;

  return 0;
}

float sdf(vec3 p, int mask) {
  float d = MAX_DISTANCE;
  float water = sdf_plane(p, vec3(0.0, 1.0, 0.0), -0.5);
  if ((mask & WATER) > 0) d = min(d, water);

  float ledge1 = sdf_cuboid(p, vec3(-2.0, -3.0, -10000.0), vec3(0.2, 3.05, 20000.0));
  float ledge2 = sdf_cuboid(p, vec3(0.8, -3.0, -10000.0), vec3(0.2, 3.05, 20000.0));
  float ledge = min(ledge1, ledge2);

  float ground = sdf_sub(sdf_plane(p, vec3(0.0, 1.0, 0.0), 0.0), sdf_cuboid(p, vec3(-2.0, -3.0, -10000.0), vec3(3.0, 3.5, 20000.0)));

  float gap = sdf_repeat_gap(p);
  float window = sdf_repeat_window(p);
  float wall = sdf_sub(sdf_sub(sdf_plane(p, vec3(+1.0, 0.0, 0.0), -3.0), gap), window);
  
  float bridge = sdf_repeat_bridge(p);
  float fence = sdf_repeat_fence(p);
  
  return min(min(min(ground, ledge), min(fence, bridge)), min(d, wall));
}

float sdf_repeat_bridge(vec3 p) {
  float s = 16.0;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
  
    float bridge1 = sdf_sub(sdf_cuboid(q, vec3(-1.8, -0.2, 2.0), vec3(2.6, 0.2, 1.0)), sdf_cuboid(q, vec3(-0.75, -0.3, 1.9), vec3(0.4, 0.6, 0.3)));
    float bridge2 = sdf_sub(sdf_cuboid(q, vec3(-1.8, -0.2, 3.1), vec3(2.6, 0.2, 1.0)), sdf_cuboid(q, vec3(-0.75, -0.3, 3.0), vec3(0.4, 0.6, 0.3)));

    d = min(d, min(bridge1, bridge2));
  }
  
  return d;
}

float sdf_repeat_fence(vec3 p) {
  float s1 = 0.25;
  float s2 = 3.0;
  
  vec3 p1 = vec3(p.x, p.y, p.z + p.y);
  float id1 = round(p1.z/s1);
  float o1 = sign(p1.z-s1*id1);
  
  vec3 p2 = vec3(p.x, p.y, p.z);
  float id2 = round(p2.z/s2);
  float o2 = sign(p2.z-s2*id2);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid1 = id1 + float(i)*o1;
    float r1 = p1.z - s1*rid1;
    vec3 q1 = vec3(p1.x, p1.y, r1);
    
    float rid2 = id2 + float(i)*o2;
    float r2 = p2.z - s2*rid2;
    vec3 q2 = vec3(p2.x, p2.y, r2);
    
    d = min(d, sdf_cuboid(q1, vec3(3.015, 0.0, 0.0), vec3(0.07, 2.0, 0.07)));
    d = min(d, sdf_cuboid(q2, vec3(3.0, 0.0, 0.0), vec3(0.1, 2.0, 0.1)));
  }
  
  d = min(d, sdf_cuboid(p, vec3(3.0, 2.0, -10000.0), vec3(0.1, 0.1, 20000.0)));
  
  return d;
}

float sdf_repeat_window(vec3 p) {
  float s = 4.0;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
    d = min(d, sdf_cuboid(q, vec3(-100.0, 3.0, -0.5), vec3(101.5, 0.5, 1.0)));
  }
  
  return d;
}

float sdf_repeat_gap(vec3 p) {
  float s = 16.0;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
    d = min(d, sdf_cuboid(q, vec3(-4.0, 0.0, 6.0), vec3(1.5, 100.0, 4.0)));
  }
  
  return d;
}

float water_height(vec2 p) {
  float d1 = length(p.xy - vec2(4.0, -1000.0));
  float d2 = length(p.xy - vec2(1000.0, -1000.0));
  return cos(d1 * 2.0 + time * 4.0) * 0.05 + cos(d2 * 4.0 + time * 2.0) * 0.01;
}

vec3 water_N(vec2 p) {
  float d = 0.01;
  float u = water_height(p);
  float du_dx = (u - water_height(vec2(p.x - d, p.y))) / d;
  float du_dy = (u - water_height(vec2(p.x, p.y - d))) / d;
  return normalize(vec3(-du_dx, 1.0, -du_dy));
}

vec3 calc_point_lighting(vec3 p, vec3 V, vec3 N, vec3 albedo, float metallic, float roughness) {
  vec3 total_radiance = vec3(0.0);
  
  for (int i = 0; i < lights_count(); i++) {
    light_t light = lights_get(i);
    
    vec3 L = normalize(light.position - p);
    float NdotL = max(dot(N, L), 0.0);
    float d = length(light.position - p);
    
    float attenuation = 1.0 / (d * d);
    vec3 radiance = light.radiance * attenuation;
    
    float alpha = pow(max(dot(-L, vec3(0.0, -1.0, 0.0)), 0.0), 6.0);
    
    total_radiance += GGX(albedo, metallic, roughness, L, V, N) * radiance * NdotL * alpha;
  }
  
  return total_radiance;
}

light_t lights[] = light_t[](
  light_t(vec3(-2.5, 16.0, -16.0), vec3(1.0, 1.0, 0.4) * 34.0),
  light_t(vec3(-2.5, 16.0, 16.0), vec3(1.0, 1.0, 0.4) * 34.0),
  light_t(vec3(-2.5, 16.0, 48.0), vec3(1.0, 1.0, 0.4) * 34.0)
);

light_t lights_get(int num) {
  return lights[num];
}

int lights_count() {
  return 3;
}
