const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;
const Player = @import("core/player.zig").Player;

const pitch_deg: f32 = 50.0;
const yaw_deg: f32 = 60.0;
const distance: f32 = 12.0;

const pitch_rad = std.math.degreesToRadians(pitch_deg);
const yaw_rad = std.math.degreesToRadians(yaw_deg);
// Zum Szenenwechsel:
// try context.switchTo(SceneID.menu); // setzt Context zum Wechseln
// return; //"Stoppt" Den Update-Loop

pub const GameScene = struct {
    allocator: std.mem.Allocator,
    camera: rl.Camera3D,
    player: Player,

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        self.camera = rl.Camera3D{
            .position = .{ .x = 0, .y = 0, .z = 0 },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = 35.0,
            .projection = .perspective,
        };

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        _ = delta_time;
        const player: *Player = &self.player;

        try self.getInput(context);

        // Kamera-Berechnung
        self.camera.target = .{ .x = self.player.transform.x, .y = 0, .z = self.player.transform.z };
        self.camera.position = .{
            .x = player.transform.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
            .y = distance * @sin(pitch_rad),
            .z = player.transform.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        };

        rl.beginDrawing();
        rl.clearBackground(.white);
        defer rl.endDrawing();
        {
            self.camera.begin();
            defer self.camera.end();
            rl.drawGrid(20, 1.0);
        }
        rl.drawText(rl.textFormat("Aktuelle Unterseite (ID)", .{}), 10, 40, 20, .red);
    }

    pub fn onCleanup(self: *GameScene, context: *SceneContext) anyerror!void {
        _ = context;
        _ = self;
        std.log.info("Game Scene Cleaning up...", .{});
    }

    fn getInput(self: *GameScene, context: *SceneContext) anyerror!void {
        if (rl.isKeyPressed(.m)) {
            try context.switchTo(SceneId.menu);
            return;
        }
        if (rl.isKeyPressed(.up)) {
            self.player.transform.x -= 1;
        }
        if (rl.isKeyPressed(.down)) {
            self.player.transform.x += 1;
        }
        if (rl.isKeyPressed(.left)) {
            self.player.transform.z += 1;
        }
        if (rl.isKeyPressed(.right)) {
            self.player.transform.z -= 1;
        }
    }
};
