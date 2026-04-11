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
        self.player = try .init();

        self.camera.target = .{ .x = self.player.position.x, .y = 0, .z = self.player.position.z };
        self.camera.position = .{
            .x = self.player.position.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
            .y = distance * @sin(pitch_rad),
            .z = self.player.position.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        };

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const player: *Player = &self.player;

        try self.getInput(context);
        player.animate(delta_time);

        // Kamera-Berechnung
        //self.camera.target = .{ .x = self.player.position.x, .y = 0, .z = self.player.position.z };
        //        self.camera.position = .{
        //            .x = player.position.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
        //            .y = distance * @sin(pitch_rad),
        //            .z = player.position.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        //        };
        //
        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();
            rl.drawGrid(20, 1.0);

            const pos = rl.Vector3{ .x = player.position.x + 0.5, .y = player.position.y + 0.5, .z = player.position.z + 0.5 };
            rl.drawModel(player.model, pos, 0.5, .white);
        }
        rl.drawText(rl.textFormat("Aktuelle Unterseite: %f %f %f %f", .{ player.edges[0], player.edges[1], player.edges[2], player.edges[3] }), 10, 40, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle Drehung: %f %f %f ", .{
            player.rotation.x,
            player.rotation.y,
            player.rotation.z,
        }), 10, 60, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle position: %f %f %f ", .{
            player.position.x,
            player.position.y,
            player.position.z,
        }), 10, 80, 20, .red);
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
            self.player.roll(.north);
        }
        if (rl.isKeyPressed(.down)) {
            self.player.roll(.south);
        }
        if (rl.isKeyPressed(.left)) {
            self.player.roll(.west);
        }
        if (rl.isKeyPressed(.right)) {
            self.player.roll(.east);
        }
    }
};
