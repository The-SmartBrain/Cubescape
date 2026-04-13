const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;
const Player = @import("core/player.zig").Player;
const overlay = @import("ingame_overlay.zig");

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
    current_moves: u8,

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        self.camera = rl.Camera3D{
            .position = .{ .x = 0, .y = 1, .z = 10 },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = 35.0,
            .projection = .perspective,
        };
        self.player = try .init();

        self.camera.target = .{ .x = self.player.origin.x, .y = 1, .z = self.player.origin.z };
        //        self.camera.position = .{
        //            .x = self.player.origin.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
        //            .y = distance * @sin(pitch_rad),
        //            .z = self.player.origin.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        //        };

        // Init Scene here --> Läuft EINMAL beim Start
        self.current_moves = 0;
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const player: *Player = &self.player;

        try self.getInput(context);
        player.animate(delta_time);

        // Kamera-Berechnung
        //self.camera.target = .{ .x = self.player.origin.x, .y = 0, .z = self.player.origin.z };
        //        self.camera.position = .{
        //            .x = player.origin.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
        //            .y = distance * @sin(pitch_rad),
        //            .z = player.origin.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        //        };
        //
        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();
            rl.drawGrid(20, 1.0);

            rl.drawModel(player.model, player.origin, 0.5, .white);
        }
        rl.drawText(rl.textFormat("Aktuelle Unterseite: %f %f %f %f", .{ player.edges[0], player.edges[1], player.edges[4], player.edges[5] }), 10, 40, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle Drehung: %f %f %f ", .{
            player.rotation.x,
            player.rotation.y,
            player.rotation.z,
        }), 10, 60, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle position: %f %f %f ", .{
            player.origin.x,
            player.origin.y,
            player.origin.z,
        }), 10, 80, 20, .red);

        // Overlay als letztes
        overlay.draw(self);
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

        if (rl.isKeyPressed(.space)) {
            if (self.camera.position.z == 10) {
                self.camera.position = .{
                    .x = self.player.origin.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
                    .y = distance * @sin(pitch_rad),
                    .z = self.player.origin.z + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
                };
                self.camera.target = .{ .x = self.player.origin.x, .y = 0, .z = self.player.origin.z };
            } else {
                self.camera.target = .{ .x = self.player.origin.x, .y = 1, .z = self.player.origin.z };
                self.camera.position = .{ .x = 0, .y = 0.5, .z = 10 };
            }
        }
    }
};
