const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;

pub const MenuScene = struct {
    allocator: std.mem.Allocator,

    pub fn onStartup(self: *MenuScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Menu scene", .{});

        self.allocator = context.allocator;

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *MenuScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        _ = self;
        _ = delta_time;

        if (rl.isKeyPressed(.enter)) {
            try context.switchTo(SceneId.game);
            return;
        }
        rl.clearBackground(.blue);
        rl.drawText("Menu Scene", 40, 40, 64, .white);
        rl.drawText("Press Enter to start the game.", 40, 120, 36, .white);
    }

    pub fn onCleanup(self: *MenuScene, context: *SceneContext) anyerror!void {
        _ = self;
        _ = context;
        std.log.info("Menu Scene Cleaning up...", .{});
    }
};
