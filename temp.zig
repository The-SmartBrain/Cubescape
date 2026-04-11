// Libary imports
const std = @import("std");
const Application = @import("core/application.zig").Application;

const GameScene = @import("game_scene.zig").GameScene;

pub fn main() void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
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

    app.pushScene(GameScene, true);
    app.run();
}
