#include "../util/math.glsl"
#include "../util/trace.glsl"
#include "../util/march.glsl"

layout (std140) uniform ubo {
  vec3 view_pos;
  float view_yaw;
  float view_pitch;
};

uniform samplerCube sky;

out vec4 frag_color;

float trace_floor(vec3 ro, vec3 rd);
float sdf(vec3 p, vec3 o, int mask);
float sdf_lamp(vec3 p, vec3 o);
float sdf_repeat_lamp(vec3 p);
float sdf_repeat_light(vec3 p);
int map_id(vec3 p);

void main() {
  vec2 screen_pos = gl_FragCoord.xy / 300.0 * 2.0 - 1.0;
  mat4 view_mat = mat4(1.0) * rotate_y(view_yaw) * rotate_x(view_pitch);
  vec3 ro = view_pos;
  vec3 rd = normalize((view_mat * vec4(screen_pos, 1.0, 1.0)).xyz);
  
  float td = min(trace_floor(ro, rd), ray_march(ro, rd, 0));
  vec3 p = ro + rd * td;
  int id = map_id(p);
  
  vec3 color;
  if (id == 1) {
    vec3 a = vec3(0.90, 0.75, 0.90);
    vec3 b = vec3(0.25, 0.05, 0.19);
    
    vec2 t = floor(p.xz);
    vec3 albedo = mod(t.x + t.y, 2.0) > 0.0 ? a : b;
    float dim = exp(-0.02 * td);
    color = albedo * dim;
  } else if (id == 2) {
    float dim = exp(-0.02 * td);
    color = vec3(0.1) * dim;
  } else if (id == 3) {
    color = vec3(1.0, 1.0, 0.9) * 30.0;
  } else {
    color = texture(sky, rd).xyz;
  }
  
  frag_color = vec4(color, 1.0);
}

float sdf(vec3 p, int mask) {
  float d = MAX_DISTANCE;
  
  d = min(d, sdf_repeat_lamp(p));
  d = min(d, sdf_repeat_light(p));
  
  return d;
}

float sdf_repeat_lamp(vec3 p) {
  float s = 8.0;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
    d = min(d, sdf_lamp(q, vec3(-3.0, 3.0, 0.0)));
    d = min(d, sdf_lamp(q, vec3(+3.0, 3.0, 0.0)));
  }
  
  return d;
}

float sdf_repeat_light(vec3 p) {
  float s = 8.0;
  float id = round(p.z/s);
  float o = sign(p.z-s*id);
  
  float d = MAX_DISTANCE;
  
  for (int i = 0; i < 2; i++) {
    float rid = id + float(i)*o;
    float r = p.z - s*rid;
    vec3 q = vec3(p.x, p.y, r);
    d = min(d, sdf_sphere(q, vec3(-3.0, 3.0, 0.0), 0.4));
    d = min(d, sdf_sphere(q, vec3(+3.0, 3.0, 0.0), 0.4));
  }
  
  return d;
}

int map_id(vec3 p) {
  float s1 = sdf_plane(p, vec3(0.0, 1.0, 0.0), 0.0);
  float s2 = sdf_repeat_lamp(p);
  float s3 = sdf_repeat_light(p);
  if (abs(s1) < MIN_DISTANCE) return 1;
  if (s2 < MIN_DISTANCE) return 2;
  if (s3 < MIN_DISTANCE) return 3;
  return 0;
}

float trace_floor(vec3 ro, vec3 rd) {
  float td = trace_plane(ro, rd, vec3(0.0, 1.0, 0.0), 0.0);
  vec3 p = ro + rd * td;
  
  if (p.x > -2.0 && p.x < 2.0) return td;
  if (p.x > 20.0 && p.z > 10.0 && p.z < 14.0) return td;
  if (p.x > 2.0 && p.x < 20.0 && p.z > 2.0 && p.z < 22.0)
    if (p.x > 2.0 && p.x < 16.0 && p.z > 6.0 && p.z < 18.0) return MAX_DISTANCE;
    else return td;
  
  return MAX_DISTANCE;
}

float sdf_lamp(vec3 p, vec3 o) {
  float s1 = sdf_sub(
    sdf_sphere(p, o, 0.5),
    sdf_cuboid(p, o - vec3(1.0, 0.25, 1.0), vec3(2.0, 0.3, 2.0))
  );
  float s2 = sdf_cylinder(p, o - vec3(0.0, 3.5, 0.0), 0.1, 3.0);
  float s3 = sdf_sphere(p, o + vec3(0.0, 0.55, 0.0), 0.1);
  float s4 = sdf_cylinder(p, o - vec3(0.0, 3.9, 0.0), 0.4, 0.4);
  float s5 = sdf_cylinder(p, o - vec3(0.0, 4.0, 0.0), 0.6, 0.1);
  return min(min(min(s1, s2), min(s3, s4)), s5);
}
