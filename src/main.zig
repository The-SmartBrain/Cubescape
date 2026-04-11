// Libary imports
const std = @import("std");
const Application = @import("core/application.zig").Application;

const GameScene = @import("game_scene.zig").GameScene;
const MenuScene = @import("menu_scene.zig").MenuScene;
const SceneId = @import("scene/id.zig").SceneId;

pub fn main() void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa_impl.deinit() == .leak) @panic("leaked");
    const gpa = gpa_impl.allocator();

    const app = Application.init(gpa, .{
        .title = "Cubescape",
        .width = 1920,
        .height = 1080,
    }) catch |err| {
        std.log.err("Application init failed: {}", .{err});
        return;
    };
    defer app.deinit() catch |err| std.log.err("Application deinit failed: {}", .{err});

    app.pushScene(MenuScene, SceneId.menu, true);
    app.pushScene(GameScene, SceneId.game, false);
    app.run();
}
