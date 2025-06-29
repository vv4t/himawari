out vec4 frag_color;
uniform sampler2D image;
uniform vec2 iResolution;

const float bayer_matrix[16] = float[] (
  -0.5,      0.0,    -0.375,   0.125,
   0.25,    -0.25,    0.375,  -0.125,
  -0.3125,   0.1875, -0.4375,  0.0625,
   0.4375,  -0.0625,  0.3125, -0.1875
);

const float color_range = 32.0;
const float bayer_r = 1.0 / color_range;

void main() {
  vec2 uv = gl_FragCoord.xy / iResolution;
  ivec2 image_uv = ivec2(uv * vec2(textureSize(image, 0)));

  vec3 tex_color = texture(image, uv).rgb;
  vec3 dither_color = tex_color + bayer_r * bayer_matrix[(image_uv.y % 4) * 4 + (image_uv.x % 4)];
  vec3 nearest_color = round(dither_color * color_range) / color_range;
  
  frag_color = vec4(nearest_color, 1.0);
}
