"use strict";

import { gl } from "./gl.js";

const config_dict = {
  "LINEAR_REPEAT": {
    TEXTURE_MAG_FILTER: "LINEAR",
    TEXTURE_MIN_FILTER: "LINEAR",
    TEXTURE_WRAP_S: "REPEAT",
    TEXTURE_WRAP_T: "REPEAT"
  },
  "LINEAR_CLAMP": {
    TEXTURE_MAG_FILTER: "LINEAR",
    TEXTURE_MIN_FILTER: "LINEAR",
    TEXTURE_WRAP_S: "CLAMP_TO_EDGE",
    TEXTURE_WRAP_T: "CLAMP_TO_EDGE"
  },
  "NEAREST_CLAMP": {
    TEXTURE_MAG_FILTER: "NEAREST",
    TEXTURE_MIN_FILTER: "NEAREST",
    TEXTURE_WRAP_S: "CLAMP_TO_EDGE",
    TEXTURE_WRAP_T: "CLAMP_TO_EDGE"
  }
};

function apply_config(config) {
  for (const setting in config) {
    gl.texParameteri(gl.TEXTURE_2D, gl[setting], gl[config[setting]]);
  }
}

export function create_image(image, config="LINEAR_REPEAT") {
  const level = 0;
  const internalFormat = gl.RGBA;
  const border = 0;
  const srcFormat = gl.RGBA;
  const srcType = gl.UNSIGNED_BYTE;
  
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.texImage2D(
    gl.TEXTURE_2D,
    level,
    internalFormat,
    srcFormat,
    srcType,
    image
  );
  
  apply_config(config_dict[config]);

  return new texture_t(texture, image.width, image.height);
}

export function create_buffer(width, height, format, internalformat, type, config="NEAREST_CLAMP") {
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  apply_config(config_dict[config]);
  gl.texImage2D(gl.TEXTURE_2D, 0, internalformat, width, height, 0, format, type, null);
  return new texture_t(texture, width, height);
}

class texture_t {
  constructor(texture, width, height) {
    this.width = width;
    this.height = height;
    this.texture = texture;
  }
  
  bind(i) {
    gl.activeTexture(gl.TEXTURE0 + i);
    gl.bindTexture(gl.TEXTURE_2D, this.texture);
  }

  destroy() {
    gl.deleteTexture(this.texture);
  }
}
