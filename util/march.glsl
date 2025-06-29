#ifndef RAY_MARCH_GLSL
#define RAY_MARCH_GLSL

#define MIN_DISTANCE 0.001
#define MAX_STEPS 256

#ifndef MAX_DISTANCE
  #define MAX_DISTANCE 10.0
#endif

float sdf(vec3 p, int mask);

vec3 sdf_normal(vec3 p, int mask) {
  float dp = 0.001;
  
  float dx_a = sdf(p - vec3(dp, 0.0, 0.0), mask);
  float dy_a = sdf(p - vec3(0.0, dp, 0.0), mask);
  float dz_a = sdf(p - vec3(0.0, 0.0, dp), mask);
  
  float dx_b = sdf(p + vec3(dp, 0.0, 0.0), mask);
  float dy_b = sdf(p + vec3(0.0, dp, 0.0), mask);
  float dz_b = sdf(p + vec3(0.0, 0.0, dp), mask);
  
  return normalize(vec3(dx_b - dx_a, dy_b - dy_a, dz_b - dz_a));
}

float shadow(vec3 pt, vec3 rd, float ld, int mask, float soft) {
  vec3 p = pt;
  float td = 0.05;
  float kd = 1.0;
  
  for (int i = 0; i < MAX_STEPS && kd > 0.01; i++) {
    p = pt + rd * td;
    
    float d = sdf(p, mask);
    if (td > MAX_DISTANCE || td + d > ld) break;
    if (d < 0.001) kd = 0.0;
    else kd = min(kd, soft * d / td);
    
    td += d;
  }
  
  return kd;
}

float ray_march(vec3 ro, vec3 rd, int mask) {
  float td = 0.0;
  
  for (int i = 0; i < MAX_STEPS; i++) {
    float d = sdf(ro + rd * td, mask);
    if (d < MIN_DISTANCE) return td;
    if (td > MAX_DISTANCE) break;
    td += d;
  }
  
  return MAX_DISTANCE;
}

float sdf_union(float a, float b) {
  return min(a, b);
}

float sdf_sub(float a, float b) {
  return max(a, -b);
}

float sdf_and(float a, float b) {
  return max(a, b);
}

float sdf_smooth_union(float a, float b, float k) {
  float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
  return mix(b, a, h) - k*h*(1.0-h);
}

float sdf_cuboid(vec3 p, vec3 o, vec3 s) {
  s *= 0.5;
  o += s;
  vec3 d = abs(p - o) - s;
  return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdf_sphere(vec3 p, vec3 o, float r) {
  return length(p - o) - r;
}

float sdf_cylinder(vec3 p, vec3 o, float r, float h) {
  h /= 2.0;
  p -= o;
  p.y -= h;
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdf_plane(vec3 p, vec3 n, float d) {
  return dot(p, n) - d;
}

float sdf_octahedron(vec3 p, vec3 o, float s) {
  p = abs(p - o);
  return (p.x+p.y+p.z-s)*0.57735027;
}

float sdf_cone( vec3 p, vec3 o, vec2 c, float h )
{
  o.y += h/2.0;
  p -= o;
  
  // c is the sin/cos of the angle, h is height
  // Alternatively pass q instead of (c,h),
  // which is the point at the base in 2D
  vec2 q = h*vec2(c.x/c.y,-1.0);
    
  vec2 w = vec2( length(p.xz), p.y );
  vec2 a = w - q*clamp( dot(w,q)/dot(q,q), 0.0, 1.0 );
  vec2 b = w - q*vec2( clamp( w.x/q.x, 0.0, 1.0 ), 1.0 );
  float k = sign( q.y );
  float d = min(dot( a, a ),dot(b, b));
  float s = max( k*(w.x*q.y-w.y*q.x),k*(w.y-q.y)  );
  return sqrt(d)*sign(s);
}

float sdf_capped_torus( vec3 p, vec3 o, vec2 sc, float ra, float rb) {
  o.y += ra / 2.0 + rb;
  p -= o;
  p.x = abs(p.x);
  p.y = -p.y;
  float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
  return sqrt( dot(p,p) + ra*ra - 2.0*ra*k ) - rb;
}

mat3 axis_aligned_TBN(vec3 p, int mask) {
  vec3 N = sdf_normal(p, mask);
  vec3 absN = abs(N);
  
  vec3 X = vec3(1.0, 0.0, 0.0);
  vec3 Y = vec3(0.0, 1.0, 0.0);
  vec3 Z = vec3(0.0, 0.0, 1.0);
  
  vec2 uv;
  if (absN.z > absN.y) {
    if (absN.z > absN.x) return mat3(X, Y, Z * sign(N.z));
    else return mat3(Y, Z, X * sign(N.x));
  } else {
    if (absN.y > absN.x) return mat3(X, Z, Y * sign(N.y));
    else return mat3(Y, Z, X * sign(N.x));
  }
}

#endif
