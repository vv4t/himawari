#ifndef HEIGHT_MARCH_GLSL
#define HEIGHT_MARCH_GLSL

#ifndef MIN_DISTANCE
  #define MIN_DISTANCE 0.001
#endif

#ifndef MAX_STEPS
  #define MAX_STEPS 256
#endif

#ifndef MAX_DISTANCE
  #define MAX_DISTANCE 10.0
#endif

float height(vec2 p);

float height_march(vec3 ro, vec3 rd) {
  float dt = 0.01;
  float lh = 0.0;
  float ly = 0.0;
  
  float td;
  for (td = dt; td < MAX_DISTANCE; td += dt) {
    vec3 p = ro + rd * td;
    float h = height(p.xz);
    if (p.y < h) {
      td = td - dt + dt * (lh - ly) / (p.y - ly - h + lh);
      return td;
    }
    
    dt = 0.05 * td;
    lh = h;
    ly = p.y;
  }
  
  return MAX_DISTANCE;
}

#endif
