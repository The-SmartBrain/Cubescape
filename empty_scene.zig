const std = @import("std");
const rl = @import("raylib");

pub const GameScene = struct {
    allocator: std.mem.Allocator,

    pub fn onStartup(self: *GameScene, allocator: std.mem.Allocator) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = allocator;

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *GameScene, delta_time: f32) anyerror!void {
        // main Loop
        _ = self;
        _ = delta_time;
        rl.beginDrawing();
        rl.clearBackground(.white);
        defer rl.endDrawing();
    }

    pub fn onCleanup(self: *GameScene, allocator: std.mem.Allocator) anyerror!void {
        _ = allocator;
        _ = self;
        std.log.info("Game Scene Cleaning up...", .{});
    }
};
