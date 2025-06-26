out vec4 frag_color;

uniform sampler2D image;
uniform vec2 iResolution;

float gamma = 0.6;
float exposure = 2.0;

void main() {
  vec2 uv = gl_FragCoord.xy / iResolution;
  vec3 color = texture(image, uv).rgb;
  color = vec3(1.0) - exp(-color * exposure);
  color = pow(color, vec3(1.0 / gamma));
  frag_color = vec4(color, 1.0);
}

