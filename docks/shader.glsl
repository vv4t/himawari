#define MAX_DISTANCE 128.0

#include "../util/math.glsl"
#include "../util/light.glsl"
#include "../util/march.glsl"

layout (std140) uniform ubo {
  vec3 view_pos;
  float view_yaw;
  float view_pitch;
  float time;
};

out vec4 frag_color;

uniform sampler2D wood_albedo;
uniform sampler2D wood_normal;
uniform sampler2D wood_ao;

float sdf_fence(vec3 p);
float sdf_lamp(vec3 p, vec3 o);
float h_march(vec3 ro, vec3 rd);
int map_id(vec3 p);
float f(vec2 p);
vec3 f_N(vec2 p);

void main() {
  vec2 screen_pos = gl_FragCoord.xy / vec2(400.0, 300.0) * 2.0 - 1.0;
  screen_pos.x *= 400.0 / 300.0;
  
  mat4 view_mat = mat4(1.0) * rotate_y(view_yaw) * rotate_x(view_pitch);
  vec3 ro = view_pos;
  vec3 rd = normalize((view_mat * vec4(screen_pos, 1.0, 1.0)).xyz);
  
  float td = min(h_march(ro, rd), ray_march(ro, rd, 0));
  // float td = ray_march(ro, rd, 0);
  vec3 p = ro + rd * td;
  vec3 V = normalize(ro - p);
  int id = map_id(p);
  
  vec3 color;
  if (id == 1) {
    vec3 N = f_N(p.xz);
    color = calc_point_lighting(p, V, N, vec3(0.7, 0.8, 1.0), 0.3, 0.3);
  } else if (id == 2) {
    mat3 TBN = axis_aligned_TBN(p, 0);
    vec2 uv = fract((transpose(TBN) * p).xy * 0.5 + 0.5);
    
    vec3 albedo = texture(wood_albedo, uv).xyz;
    vec3 normal = TBN * normalize(texture(wood_normal, uv).xyz * 2.0 - 1.0);
    float ao = texture(wood_ao, uv).x;
    
    color = calc_point_lighting(p, V, normal, albedo, 0.1, 0.5) * ao;
  } else if (id == 3) {
    vec3 N = sdf_normal(p, 0);
    color = calc_point_lighting(p, V, N, vec3(0.2), 0.6, 0.7);
  } else if (id == 4) {
    color = vec3(1.0, 1.0, 0.9) * 2.0;
  } else {
    color = vec3(0.0);
  }
  
  color += calc_point_scatter(p, ro, 0.005);
  
  frag_color = vec4(color, 1.0);
}

int map_id(vec3 p) {
  float s1 = p.y - f(p.xz);
  float s2 = sdf_cuboid(p, vec3(-1.0, -1.0, -1.0), vec3(2.0, 2.0, 128.0));
  float s3 = sdf_fence(p);
  if (s1 < 0.1         ) return 1;
  if (s2 < MIN_DISTANCE) return 2;
  if (s3 < MIN_DISTANCE) return 2;
  
  for (int i = 0; i < lights_count(); i++)
    if (sdf_lamp(p, lights_get(i).position) < MIN_DISTANCE)
      return 3;
  
  for (int i = 0; i < lights_count(); i++)
    if (sdf_cylinder(p, lights_get(i).position - vec3(0.0, 0.25, 0.0), 0.2, 0.5) < MIN_DISTANCE)
      return 4;
  
  return 0;
}

float sdf(vec3 p, int mask) {
  float d = MAX_DISTANCE;
  
  float s2 = sdf_cuboid(p, vec3(-1.0, -1.0, -1.0), vec3(2.0, 2.0, 128.0));
  float s3 = sdf_fence(p);
  
  d = min(d, s2);
  d = min(d, s3);
  
  for (int i = 0; i < lights_count(); i++)
    d = min(d, sdf_lamp(p, lights_get(i).position));
  
  for (int i = 0; i < lights_count(); i++)
    d = min(d, sdf_cylinder(p, lights_get(i).position - vec3(0.0, 0.25, 0.0), 0.2, 0.5));
  
  return d;
}

float sdf_fence(vec3 p) {
  float s = 0.5;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    rid = max(rid, -1.0);
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
    d = min(d, sdf_cuboid(q, vec3(+0.9, 1.0, 0.0), vec3(0.1, 0.7, 0.1)));
    d = min(d, sdf_cuboid(q, vec3(-1.0, 1.0, 0.0), vec3(0.1, 0.7, 0.1)));
  }
  
  d = min(d, sdf_cuboid(p, vec3( 0.0, 1.0, -1.0), vec3(0.1, 0.7, 0.1)));
  d = min(d, sdf_cuboid(p, vec3(+0.5, 1.0, -1.0), vec3(0.1, 0.7, 0.1)));
  d = min(d, sdf_cuboid(p, vec3(-0.5, 1.0, -1.0), vec3(0.1, 0.7, 0.1)));
  d = min(d, sdf_cuboid(p, vec3(+0.9, 1.0, -1.0), vec3(0.1, 0.7, 0.1)));
  d = min(d, sdf_cuboid(p, vec3(-1.0, 1.0, -1.0), vec3(0.1, 0.7, 0.1)));
  
  d = min(d, sdf_cuboid(p, vec3(+0.9, 1.7, -1.0), vec3(0.1, 0.1, 128.0)));
  d = min(d, sdf_cuboid(p, vec3(-1.0, 1.7, -1.0), vec3(0.1, 0.1, 128.0)));
  d = min(d, sdf_cuboid(p, vec3(-1.0, 1.7, -1.0), vec3(2.0, 0.1, 0.1)));
  
  return d;
}

float sdf_lamp(vec3 p, vec3 o) {
  float s1 = sdf_sub(
    sdf_octahedron(p, o, 0.75),
    sdf_cuboid(p, o - vec3(1.0, 0.15, 1.0), vec3(2.0, 0.3, 2.0))
  );
  float s2 = sdf_cylinder(p, o - vec3(0.0, 3.0, 0.0), 0.1, 2.5);
  float s3 = sdf_sphere(p, o + vec3(0.0, 0.7, 0.0), 0.1);
  return min(min(s1, s2), s3);
}

float f(vec2 p) {
  float d1 = length(p.xy - vec2(10.0, 4.0));
  float d2 = length(p.xy - vec2(-10.0, 20.0));
  float d3 = length(p.xy - vec2(7.0, 60.0));
  return cos(d1 * 1.5 + time * 4.0) * 0.1 + cos(d2 * 2.3 + time * 8.0) * 0.05 + cos(d3 * 3.7 + time * 1.0) * 0.03;
}

vec3 f_N(vec2 p) {
  float d = 0.01;
  float u = f(p);
  float du_dx = (u - f(vec2(p.x - d, p.y))) / d;
  float du_dy = (u - f(vec2(p.x, p.y - d))) / d;
  return normalize(vec3(-du_dx, 1.0, -du_dy));
}

float h_march(vec3 ro, vec3 rd) {
  float dt = 0.01;
  float lh = 0.0;
  float ly = 0.0;
  
  float td;
  for (td = dt; td < MAX_DISTANCE; td += dt) {
    vec3 p = ro + rd * td;
    float h = f(p.xz);
    if (p.y < h) {
      return td - dt + dt * (lh - ly) / (p.y - ly - h + lh);
    }
    
    dt = exp(0.01 * td);
    lh = h;
    ly = p.y;
  }
  
  return MAX_DISTANCE;
}

light_t lights[] = light_t[](
  light_t(vec3(-8.0, 2.0, +0.0), vec3(1.0, 1.0, 0.9) * 2.0),
  light_t(vec3(+8.0, 2.0, +0.0), vec3(1.0, 1.0, 0.9) * 2.0),
  light_t(vec3(-8.0, 2.0, +4.0), vec3(1.0, 1.0, 0.9) * 2.0),
  light_t(vec3(+8.0, 2.0, +4.0), vec3(1.0, 1.0, 0.9) * 2.0),
  light_t(vec3(-8.0, 2.0, +8.0), vec3(1.0, 1.0, 0.9) * 2.0),
  light_t(vec3(+8.0, 2.0, +8.0), vec3(1.0, 1.0, 0.9) * 2.0)
);

light_t lights_get(int num) {
  return lights[num];
}

int lights_count() {
  return 6;
}
