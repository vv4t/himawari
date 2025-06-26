"use strict";

import { scene_t } from "../core/scene.js";
import { input_t } from "../core/input.js";
import { vec3_t } from "../core/math.js";

async function run() {
  const canvas = document.getElementById("display");
  const scene = new scene_t(canvas);
  const input = new input_t(canvas);
  
  input.set_mouse_lock(true);

  const shader = await scene.load_shader("shader.glsl", [ "sky" ]);
  const mix = await scene.load_shader("mix.glsl", [ "first", "second" ]);
  const blur = await scene.load_shader("../util/blur.glsl", [ "iChannel0" ]);
  const downsample = await scene.load_shader("../util/downsample.glsl", [ "srcTexture" ]);
  const upsample = await scene.load_shader("../util/upsample.glsl", [ "srcTexture" ]);
  const tonemap = await scene.load_shader("../util/tonemap.glsl", [ "image" ]);
  const dither = await scene.load_shader("../util/dither.glsl", [ "image" ]);
  
  const sky = await scene.load_cubemap("../assets/gloomy", "jpg");
  
  const buffer1 = scene.add_buffer(400, 300);
  const buffer2 = scene.add_buffer(400, 300);
  
  const mip0 = scene.add_buffer(400, 300, "LINEAR_CLAMP");
  const mip1 = scene.add_buffer(300, 225, "LINEAR_CLAMP");
  const mip2 = scene.add_buffer(200, 150, "LINEAR_CLAMP");
  const mip3 = scene.add_buffer(100, 75, "LINEAR_CLAMP");

  const view_pos = new Float32Array(3);
  const view_yaw = new Float32Array(1);
  const view_pitch = new Float32Array(1);
  scene.add_data("ubo", [view_pos, view_yaw, view_pitch]);

  scene.add_pass([sky], shader, [buffer1]);
  
  scene.add_pass([buffer1], downsample, [mip1]);
  scene.add_pass([mip1], downsample, [mip2]);
  scene.add_pass([mip2], downsample, [mip3]);
  scene.add_pass([mip3], upsample, [mip2]);
  scene.add_pass([mip2], upsample, [mip1]);
  scene.add_pass([mip1], upsample, [mip0]);
  
  scene.add_pass([buffer1, mip0], mix, [buffer2]);
  scene.add_pass([buffer2], tonemap, [buffer1]);
  scene.add_pass([buffer1], dither, []);
  
  view_pos[0] = 50;
  view_pos[1] = 2;
  view_pos[2] = 12;

  const update = () => {
    free_move(input, view_pos, view_yaw, view_pitch);
    scene.render();
    requestAnimationFrame(update);
  };

  requestAnimationFrame(update);
}

function free_move(input, view_pos, view_yaw, view_pitch) {
  const forward = new vec3_t(0.0, 0.0, 0.1).rotate_y(-view_yaw[0]);
  const side = new vec3_t(0.1, 0.0, 0.0).rotate_y(-view_yaw[0]);
  let move = new vec3_t();
  
  if (input.get_key('W')) move = move.add(forward);
  if (input.get_key('A')) move = move.add(side.mulf(-1));
  if (input.get_key('S')) move = move.add(forward.mulf(-1));
  if (input.get_key('D')) move = move.add(side);
  
  const new_x = view_pos[0] + move.x;
  const new_z = view_pos[2] + move.z;
  
  if (in_bound(new_x, new_z)) {
    view_pos[0] = new_x;
    view_pos[2] = new_z;
  } else if (in_bound(view_pos[0], new_z)) {
    view_pos[2] = new_z;
  } else if (in_bound(new_x, view_pos[2])) {
    view_pos[0] = new_x;
  }
  
  view_yaw[0] = input.get_mouse_x() / 600.0 - Math.PI / 2.0;
  view_pitch[0] = -input.get_mouse_y() / 600.0;
}

function in_bound(x, y) {
  if (x > -2.0 && x < 2.0) return true;
  if (x > 20.0 && y > 10.0 && y < 14.0) return true;
  if (x > 2.0 && x < 20.0 && y > 2.0 && y < 22.0)
    if (x > 2.0 && x < 16.0 && y > 6.0 && y < 18.0) return false;
    else return true;
  
  return false;
}

run();
