out vec4 frag_color;

uniform sampler2D srcTexture;
uniform vec2 iResolution;

// https://learnopengl.com/Guest-Articles/2022/Phys.-Based-Bloom
void main()
{
  vec2 uv = gl_FragCoord.xy / iResolution;
  vec2 srcTexelSize = 1.0 / iResolution;
  float x = srcTexelSize.x;
  float y = srcTexelSize.y;

  // Take 13 samples around current texel:
  // a - b - c
  // - j - k -
  // d - e - f
  // - l - m -
  // g - h - i
  // === ('e' is the current texel) ===
  vec3 a = texture(srcTexture, vec2(uv.x - 2.0*x, uv.y + 2.0*y)).rgb;
  vec3 b = texture(srcTexture, vec2(uv.x,       uv.y + 2.0*y)).rgb;
  vec3 c = texture(srcTexture, vec2(uv.x + 2.0*x, uv.y + 2.0*y)).rgb;

  vec3 d = texture(srcTexture, vec2(uv.x - 2.0*x, uv.y)).rgb;
  vec3 e = texture(srcTexture, vec2(uv.x,       uv.y)).rgb;
  vec3 f = texture(srcTexture, vec2(uv.x + 2.0*x, uv.y)).rgb;

  vec3 g = texture(srcTexture, vec2(uv.x - 2.0*x, uv.y - 2.0*y)).rgb;
  vec3 h = texture(srcTexture, vec2(uv.x,       uv.y - 2.0*y)).rgb;
  vec3 i = texture(srcTexture, vec2(uv.x + 2.0*x, uv.y - 2.0*y)).rgb;

  vec3 j = texture(srcTexture, vec2(uv.x - x, uv.y + y)).rgb;
  vec3 k = texture(srcTexture, vec2(uv.x + x, uv.y + y)).rgb;
  vec3 l = texture(srcTexture, vec2(uv.x - x, uv.y - y)).rgb;
  vec3 m = texture(srcTexture, vec2(uv.x + x, uv.y - y)).rgb;

  // Apply weighted distribution:
  // 0.5 + 0.125 + 0.125 + 0.125 + 0.125 = 1
  // a,b,d,e * 0.125
  // b,c,e,f * 0.125
  // d,e,g,h * 0.125
  // e,f,h,i * 0.125
  // j,k,l,m * 0.5
  // This shows 5 square areas that are being sampled. But some of them overlap,
  // so to have an energy preserving downsample we need to make some adjustments.
  // The weights are the distributed, so that the sum of j,k,l,m (e.g.)
  // contribute 0.5 to the final color output. The code below is written
  // to effectively yield this sum. We get:
  // 0.125*5 + 0.03125*4 + 0.0625*4 = 1
  vec3 downsample = e*0.125;
  downsample += (a+c+g+i)*0.03125;
  downsample += (b+d+f+h)*0.0625;
  downsample += (j+k+l+m)*0.125;
  downsample = max(downsample, 0.0001f);
  
  frag_color = vec4(downsample, 1.0);
}
