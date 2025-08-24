"use strict";

import { scene_t } from "../core/scene.js";
import { input_t } from "../core/input.js";
import { vec3_t } from "../core/math.js";

async function run() {
  const canvas = document.getElementById("display");
  const scene = new scene_t(canvas);
  const input = new input_t(canvas);
  
  input.set_mouse_lock(true);

  const shader = await scene.load_shader("shader.glsl", [ "mat_albedo", "mat_normal", "mat_roughness", "graffiti" ]);
  const tonemap = await scene.load_shader("../util/tonemap.glsl", [ "image" ], { define: { GAMMA: "2.2", EXPOSURE: "2.0" }});
  const dither = await scene.load_shader("../util/dither.glsl", [ "image" ]);
  
  const albedo = await scene.load_image("../assets/asphalt/albedo.jpg");
  const normal = await scene.load_image("../assets/asphalt/normal.jpg");
  const roughness = await scene.load_image("../assets/asphalt/roughness.jpg");
  const graffiti = await scene.load_image("graffiti.png");
  
  const buffer1 = scene.add_buffer(400, 300);
  const buffer2 = scene.add_buffer(400, 300);

  const view_pos = new Float32Array(3);
  const view_yaw = new Float32Array(1);
  const view_pitch = new Float32Array(1);
  const time = new Float32Array(1);
  scene.add_data("ubo", [view_pos, view_yaw, view_pitch, time]);

  scene.add_pass([albedo, normal, roughness, graffiti], shader, [buffer1]);
  scene.add_pass([buffer1], tonemap, [buffer2]);
  scene.add_pass([buffer2], dither, []);
  
  view_pos[0] = 2;
  view_pos[1] = 1;
  view_pos[2] = 20;

  const update = () => {
    time[0] += 0.015;
    free_move(input, view_pos, view_yaw, view_pitch);
    scene.render();
    requestAnimationFrame(update);
  };

  requestAnimationFrame(update);
}

function free_move(input, view_pos, view_yaw, view_pitch) {
  const forward = new vec3_t(0.0, 0.0, 0.035).rotate_y(-view_yaw[0]);
  const side = new vec3_t(0.035, 0.0, 0.0).rotate_y(-view_yaw[0]);
  let move = new vec3_t();
  
  if (input.get_key('W')) move = move.add(forward);
  if (input.get_key('A')) move = move.add(side.mulf(-1));
  if (input.get_key('S')) move = move.add(forward.mulf(-1));
  if (input.get_key('D')) move = move.add(side);
  
  const new_x = view_pos[0] + move.x;
  const new_z = view_pos[2] + move.z;

  if (!test_collide(new_x, new_z)) {
    view_pos[0] = new_x;
    view_pos[2] = new_z;
  } else if (!test_collide(new_x, view_pos[2])) {
    view_pos[0] = new_x;
  } else if (!test_collide(view_pos[0], new_z)) {
    view_pos[2] = new_z;
  }
  
  view_yaw[0] = input.get_mouse_x() / 600.0 + Math.PI;
  view_pitch[0] = -input.get_mouse_y() / 600.0;
}

function test_collide(x, y) {
  const d = 0.5;
  if (x - d < -3.0 || x + d > 3.0) return true;

  const u = y > 0.0 ? y % 16 : (16.0 + (y % 16.0));
  if (x - d > -2.5 && x + d < 1.6 && (u + d < 2.5 || u - d > 3.3))
    return true;
  
  return false;
}

run();
