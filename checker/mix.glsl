out vec4 frag_color;

uniform sampler2D first;
uniform sampler2D second;
uniform vec2 iResolution;

void main() {
  vec2 uv = gl_FragCoord.xy / iResolution;
  frag_color.rgb = mix(texture(first, uv).rgb, texture(second, uv).rgb, 0.04);
  frag_color.w = 1.0;
}
