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
  const fxaa = await scene.load_shader("fxaa.glsl", [ "iChannel0" ]);
  const dither = await scene.load_shader("../util/dither.glsl", [ "image" ]);
  
  const sky = await scene.load_cubemap("../assets/stormy", "jpg");
  
  const buffer1 = scene.add_buffer(400, 300);
  const buffer2 = scene.add_buffer(400, 300);

  const view_pos = new Float32Array(3);
  const view_yaw = new Float32Array(1);
  const view_pitch = new Float32Array(1);
  const time = new Float32Array(1);
  scene.add_data("ubo", [view_pos, view_yaw, view_pitch, time]);

  view_pos[0] = 200.0;

  scene.add_pass([sky], shader, [buffer1]);
  scene.add_pass([buffer1], fxaa, [buffer2]);
  scene.add_pass([buffer2], dither, []);

  const update = () => {
    time[0] += 0.015;
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
  
  view_pos[0] += move.x;
  view_pos[2] += move.z;
  view_pos[1] = height(view_pos[0], view_pos[2]) + 1.5;
  
  view_yaw[0] = input.get_mouse_x() / 600.0 - Math.PI / 2.0;
  view_pitch[0] = -input.get_mouse_y() / 600.0;
}

function height(x, y) {
  const u1 = x - 60;
  const v1 = y - 60;
  
  const u2 = x - 80;
  const v2 = y + 20;
  
  const a = 3.0 * Math.exp(-Math.pow(0.03 * 0.03 * (x*x + y*y), 2.0));
  const b = 2.0 * Math.exp(-Math.pow(0.1 * 0.1 * (u1*u1 + v1*v1), 2.0));
  const c = 0.2 * Math.cos(0.5 * x + 0.05 * Math.sin(y));
  const d = Math.exp(-Math.pow((y - Math.sin(x * 0.3)) / 2.0, 2.0)) * (1.0 / (1.0 + Math.exp(-(x - 40.0))));
  const e = 2.0 * Math.exp(-Math.pow(0.1 * 0.1 * (u2*u2 + v2*v2), 2.0));
  return a + b + c + d + e;
}

run();
