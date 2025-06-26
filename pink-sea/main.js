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
  const dither = await scene.load_shader("../util/dither.glsl", [ "image" ]);
  
  const sky = await scene.load_cubemap("../assets/stormy", "jpg");
  
  const buffer = scene.add_buffer(400, 350);

  const view_pos = new Float32Array(3);
  const view_yaw = new Float32Array(1);
  const view_pitch = new Float32Array(1);
  const time = new Float32Array(1);
  scene.add_data("ubo", [view_pos, view_yaw, view_pitch, time]);

  view_pos[0] = 10.0;

  scene.add_pass([sky], shader, [buffer]);
  scene.add_pass([buffer], dither, []);

  const update = () => {
    time[0] += 0.015;
    free_move(input, view_pos, view_yaw, view_pitch);
    scene.render();
    requestAnimationFrame(update);
  };

  requestAnimationFrame(update);
}

function free_move(input, view_pos, view_yaw, view_pitch) {
  const forward = new vec3_t(0.0, 0.0, 0.2).rotate_y(-view_yaw[0]);
  const side = new vec3_t(0.2, 0.0, 0.0).rotate_y(-view_yaw[0]);
  let move = new vec3_t();
  
  if (input.get_key('W')) move = move.add(forward);
  if (input.get_key('A')) move = move.add(side.mulf(-1));
  if (input.get_key('S')) move = move.add(forward.mulf(-1));
  if (input.get_key('D')) move = move.add(side);
  
  view_pos[0] += move.x;
  view_pos[2] += move.z;
  view_pos[1] = height(view_pos[0], view_pos[2]) + 2.0;
  
  view_yaw[0] = input.get_mouse_x() / 600.0;
  view_pitch[0] = -input.get_mouse_y() / 600.0;
}

function height(x, y) {
  const a = 3.0 * Math.exp(-Math.pow(0.05 * 0.05 * (x*x + y*y), 2.0));
  const b = 0.2 * Math.cos(0.5 * x + 0.05 * Math.sin(y));
  return a + b;
}

run();
