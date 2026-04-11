const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;

// Zum Szenenwechsel:
// try context.switchTo(SceneID.menu); // setzt Context zum Wechseln
// return; //"Stoppt" Den Update-Loop

pub const GameScene = struct {
    allocator: std.mem.Allocator,

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        _ = self;
        _ = delta_time;

        if (rl.isKeyPressed(.m)) {
            try context.switchTo(SceneId.menu);
            return;
        }

        rl.beginDrawing();
        rl.clearBackground(.white);
        defer rl.endDrawing();
    }

    pub fn onCleanup(self: *GameScene, context: *SceneContext) anyerror!void {
        _ = context;
        _ = self;
        std.log.info("Game Scene Cleaning up...", .{});
    }
};
