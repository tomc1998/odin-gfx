package gfx_test

import gfx ".."
import "core:fmt"

Entity :: struct {
  id:   u64,
  name: string,

  x, y, xvel, yvel: f32,

  derived: any,
}

Player :: struct {
  using entity: Entity,
}

Enemy :: struct {
  using entity: Entity,
}

new_entity :: proc($T: typeid) -> ^T {
  e := new(T);
  e.derived = e^;
  return e;
}

main :: proc () {
  w := gfx.create_window("TestGLGame");

  // Init painter
  painter := gfx.init_painter("assets/cruft.ttf", 24.0);
  atlas := gfx.add_tex(&painter, "assets/test-atlas.png");
  gfx.gpu_sync(&painter);

  // Init entities
  entities := [dynamic]^Entity{};
  player := new_entity(Player);
  enemy := new_entity(Enemy);
  append(&entities, player);
  append(&entities, enemy);

  // Get textures from atlas
  player_tex := gfx.sub_tex(atlas.tex, 0, 0, 32, 32);

  for !gfx.window_should_close(&w) {
    ////// Input
    gfx.poll_events();
    // Player input
    if (gfx.key_down(&w, gfx.KEY_W)) {
      player.yvel = -2.5;
    } else if (gfx.key_down(&w, gfx.KEY_S)) {
      player.yvel = 2.5;
    } else {
      player.yvel = 0.0;
    }
    if (gfx.key_down(&w, gfx.KEY_A)) {
      player.xvel = -2.5;
    } else if (gfx.key_down(&w, gfx.KEY_D)) {
      player.xvel = 2.5;
    } else {
      player.xvel = 0.0;
    }

    gfx.draw_text(&painter, "The quick brown fox jumps over the lazy dog!", 100.0, 100.0);

    ////// Update
    for e in entities {
      e.x += e.xvel;
      e.y += e.yvel;
      switch ederive in e.derived {
      case Player:
       gfx.draw_img(&painter, player_tex, e.x, e.y, 64, 64);
      case:
       gfx.fill_rect(&painter, e.x, e.y, 64, 64);
      }
    }

    ////// Render
    gfx.flush_render(&painter);
    gfx.swap_buffers(&w);
    gfx.clear_window(&w);
  }
}
