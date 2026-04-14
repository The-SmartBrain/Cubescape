const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;
const Player = @import("core/player.zig").Player;
const Camera = @import("core/camera.zig").Camera;
const Block = @import("core/block.zig").Block;
const Level = @import("core/level.zig").Level;
const overlay = @import("ingame_overlay.zig");
const Blender_Unit_2_Raylib_Unit = 0.50;

// Zum Szenenwechsel:
// try context.switchTo(SceneID.menu); // setzt Context zum Wechseln
// return; //"Stoppt" Den Update-Loop
//

pub const GameScene = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    player: Player,
    current_moves: u8,
    level: Level,
    // Setting default values WILL NOT work because the scene struct is initialised using an allocator instead of the normal way,
    // every value is thus set to its 0 value;

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        self.camera = .init(Camera.Default_Distance, 35, rl.Vector3.zero());
        self.player = try .init();

        self.camera.follow_fn = Camera.simple_follow;
        self.level = try .init(Level.LevelID.one, 20, 20, self.allocator);
        self.camera.update(self.player.origin);

        // Init Scene here --> Läuft EINMAL beim Start
        self.current_moves = 0;
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const player: *Player = &self.player;

        try self.getInput(context);
        player.animate(delta_time);

        self.camera.update(player.origin);

        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();

            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);
            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1);
            self.level.draw_grid();

            rl.drawModel(player.model, player.origin, Blender_Unit_2_Raylib_Unit, .white);
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
        std.log.info("Game Scene Cleaning up...", .{});
        Level.deinit_grid(self.level.grid, context.allocator);
    }

    fn getInput(self: *GameScene, context: *SceneContext) anyerror!void {
        if (rl.isKeyDown(.m)) {
            try context.switchTo(SceneId.menu);
            return;
        }
        if (rl.isKeyDown(.up)) {
            if (self.player.roll(.north)) self.current_moves += 1;
        }
        if (rl.isKeyDown(.down)) {
            if (self.player.roll(.south)) self.current_moves += 1;
        }
        if (rl.isKeyDown(.left)) {
            if (self.player.roll(.west)) self.current_moves += 1;
        }
        if (rl.isKeyDown(.right)) {
            if (self.player.roll(.east)) self.current_moves += 1;
        }
    }
};
