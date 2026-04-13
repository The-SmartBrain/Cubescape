const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;
const Player = @import("core/player.zig").Player;
const Camera = @import("core/camera.zig").Camera;
const Block = @import("core/block.zig").Block;
const overlay = @import("ingame_overlay.zig");
const Blender_Unit_2_Raylib_Unit = 0.50;

pub const LevelJSON = struct {
    width: u8,
    length: u8,
    blocks: []block,
    const block = struct {
        id: u16,
        x: u8,
        y: u8,
    };
};

// Zum Szenenwechsel:
// try context.switchTo(SceneID.menu); // setzt Context zum Wechseln
// return; //"Stoppt" Den Update-Loop
//

pub const GameScene = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    player: Player,
    grid_width: f32,
    grid_length: f32,
    current_moves: u8,
    // Setting default values WILL NOT work because the scene struct is initialised using an allocator instead of the normal way,
    // every value is thus set to its 0 value;

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        self.camera = .init(Camera.Default_Distance, 35, rl.Vector3.zero());
        self.player = try .init();

        self.camera.follow_fn = Camera.simple_follow;
        self.camera.update(self.player.origin);
        self.grid_length = 100;
        self.grid_width = 100;

        // Init Scene here --> Läuft EINMAL beim Start
        self.current_moves = 0;
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const player: *Player = &self.player;

        try self.getInput(context);
        player.animate(delta_time);

        self.camera.update(player.origin);

        const ray = rl.getScreenToWorldRay(rl.getMousePosition(), self.camera.camera);
        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();
            rl.drawGrid(20, 1.0);

            const p1: rl.Vector3 = .{ .x = self.grid_length / 2, .y = 0, .z = self.grid_width / 2 };
            const p2: rl.Vector3 = .{ .x = -self.grid_length / 2, .y = 0, .z = self.grid_width / 2 };
            const p3: rl.Vector3 = .{ .x = -self.grid_length / 2, .y = 0, .z = -self.grid_width / 2 };
            const p4: rl.Vector3 = .{ .x = self.grid_length / 2, .y = 0, .z = -self.grid_width / 2 };
            const collision = rl.getRayCollisionQuad(ray, p1, p4, p3, p2);

            rl.drawModel(player.model, player.origin, Blender_Unit_2_Raylib_Unit, .white);

            if (collision.hit) {
                rl.drawCube(collision.point, 1, 0.1, 1, .red);
            }
        }

        rl.drawText(rl.textFormat("Aktuelle Unterseite: 0. %f 1. %f 4. %f 5. %f", .{ player.edges[0], player.edges[1], player.edges[4], player.edges[5] }), 10, 40, 20, .red);
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
            if (self.player.roll(.north)) self.current_moves += 1;
        }
        if (rl.isKeyPressed(.down)) {
            if (self.player.roll(.south)) self.current_moves += 1;
        }
        if (rl.isKeyPressed(.left)) {
            if (self.player.roll(.west)) self.current_moves += 1;
        }
        if (rl.isKeyPressed(.right)) {
            if (self.player.roll(.east)) self.current_moves += 1;
        }
    }
};
