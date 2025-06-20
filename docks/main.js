"use strict";

import { scene_t } from "../core/scene.js";
import { input_t } from "../core/input.js";
import { vec3_t } from "../core/math.js";

async function run() {
  const canvas = document.getElementById("display");
  const scene = new scene_t(canvas);
  const input = new input_t(canvas);
  
  input.set_mouse_lock(true);

  const shader = await scene.load_shader("shader.glsl", [ "wood_albedo", "wood_normal", "wood_ao" ]);
  const tonemap = await scene.load_shader("../util/tonemap.glsl", [ "image" ]);
  const dither = await scene.load_shader("../util/dither.glsl", [ "image" ]);
  
  const buffer1 = scene.add_buffer(400, 300);
  const buffer2 = scene.add_buffer(400, 300);
  
  const albedo = await scene.load_image("../assets/wood/albedo.jpg");
  const normal = await scene.load_image("../assets/wood/normal.jpg");
  const ao = await scene.load_image("../assets/wood/ao.jpg");

  const view_pos = new Float32Array(3);
  const view_yaw = new Float32Array(1);
  const view_pitch = new Float32Array(1);
  const time = new Float32Array(1);
  scene.add_data("ubo", [view_pos, view_yaw, view_pitch, time]);

  scene.add_pass([albedo, normal, ao], shader, [buffer1]);
  scene.add_pass([buffer1], tonemap, [buffer2]);
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
  const forward = new vec3_t(0.0, 0.0, 0.05).rotate_x(-view_pitch[0]).rotate_y(-view_yaw[0]);
  const side = new vec3_t(0.05, 0.0, 0.0).rotate_x(-view_pitch[0]).rotate_y(-view_yaw[0]);
  let move = new vec3_t();
  
  if (input.get_key('W')) move = move.add(forward);
  if (input.get_key('A')) move = move.add(side.mulf(-1));
  if (input.get_key('S')) move = move.add(forward.mulf(-1));
  if (input.get_key('D')) move = move.add(side);
  
  view_pos[0] += move.x;
  view_pos[1] += move.y;
  view_pos[2] += move.z;
  
  view_yaw[0] = input.get_mouse_x() / 600.0;
  view_pitch[0] = -input.get_mouse_y() / 600.0;
}

run();
