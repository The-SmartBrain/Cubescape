const std = @import("std");
const GameScene = @import("game_scene.zig").GameScene;

pub fn draw(game_scene: *GameScene) void {
    _ = game_scene;
    //std.log.info("Overlay: {}", .{game_scene.current_moves});
}
