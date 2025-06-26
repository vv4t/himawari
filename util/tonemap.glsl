out vec4 frag_color;

uniform sampler2D image;
uniform vec2 iResolution;

#ifndef GAMMA
  #define GAMME 1.2
#endif

#ifndef EXPOSURE
  #define EXPOSURE 2.0
#endif

void main() {
  vec2 uv = gl_FragCoord.xy / iResolution;
  vec3 color = texture(image, uv).rgb;
  color = vec3(1.0) - exp(-color * EXPOSURE);
  color = pow(color, vec3(1.0 / GAMMA));
  frag_color = vec4(color, 1.0);
}

