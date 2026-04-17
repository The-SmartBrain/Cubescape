const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("context.zig").SceneContext;
const GlobalState = @import("../global_state.zig");
const SceneId = @import("id.zig").SceneId;
const Player = @import("../core/player.zig").Player;
const Camera = @import("../core/camera.zig").Camera;
const Block = @import("../core/block.zig").Block;
const Level = @import("../core/level.zig").Level;
const Keybinds = @import("keybinds.zig");
const overlay = @import("ingame_overlay.zig");
const Blender_Unit_2_Raylib_Unit = Block.Blender_Unit_2_Raylib_Unit;
const Blender_Unit_2_Raylib_Unit_Vec: rl.Vector3 = .{ .x = Blender_Unit_2_Raylib_Unit, .y = Blender_Unit_2_Raylib_Unit, .z = Blender_Unit_2_Raylib_Unit };

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
    keylist: Keybinds.BindList,
    // Setting default values WILL NOT work because the scene struct is initialised using an allocator instead of the normal way,
    // every value is thus set to its 0 value;

    pub fn onStartup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Game scene", .{});

        self.allocator = context.allocator;

        self.camera = .init(Camera.Default_Distance, 35, rl.Vector3.zero());
        self.camera.follow_fn = Camera.simple_follow;

        self.player = try .init(self.allocator);

        self.level = Level.import_level(GlobalState.CurrentLevelID, self.allocator) catch |err| {
            std.log.err("Level Could not be loaded {}\n", .{err});
            try context.switchTo(SceneId.menu);
            return;
        };
        self.keylist = try .import_init("game_binds", self.allocator);

        self.player.origin = self.level.idx_to_coord(self.level.starting_point.x, self.level.starting_point.y);
        self.player.origin.y = self.player.edges[5] / 2;

        try self.player.calculate_occupied_cells(self.level.length, self.level.width);

        self.camera.update(self.player.origin);

        // Init Scene here --> Läuft EINMAL beim Start
        self.current_moves = 0;
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const player: *Player = &self.player;

        if (try self.getInput(context)) return;

        player.animate(delta_time) catch |err| {
            std.log.err("failed to animate player {}\n", .{err});
        };

        if (check_falling(self.level, player.*)) {
            player.fall(&self.level, player.last_roll);
        }

        self.camera.update(player.origin);

        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();

            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);
            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1, false);
            self.level.draw_grid();

            rl.drawModel(player.model, player.origin, Blender_Unit_2_Raylib_Unit, .white);
        }

        rl.drawText(rl.textFormat("Aktuelle Unterseite: 0. %f 1. %f 4. %f 5. %f", .{ player.edges[0], player.edges[1], player.edges[4], player.edges[5] }), 10, 40, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle Drehung: %f %f %f ", .{
            player.rotation.x,
            player.rotation.y,
            player.rotation.z,
        }), 10, 60, 20, .red);
        rl.drawText(rl.textFormat("Aktuelle position: x:%f y:%f z:%f ", .{
            player.origin.x,
            player.origin.y,
            player.origin.z,
        }), 10, 80, 20, .red);

        // Overlay als letztes
        overlay.draw(self);
    }

    pub fn onCleanup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Game Scene Cleaning up...", .{});
        self.level.deinit(context.allocator);
        try self.player.deinit();
        self.keylist.deinit();
    }

    fn getInput(self: *GameScene, context: *SceneContext) anyerror!bool {
        if (self.keylist.check(.to_menu, .isDown)) {
            try context.switchTo(SceneId.menu);
            return true;
        }
        if (self.keylist.check(.roll_north, .isDown)) {
            if (self.player.roll(.north, self.level.width, self.level.length)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_south, .isDown)) {
            if (self.player.roll(.south, self.level.width, self.level.length)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_west, .isDown)) {
            if (self.player.roll(.west, self.level.width, self.level.length)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_east, .isDown)) {
            if (self.player.roll(.east, self.level.width, self.level.length)) self.current_moves += 1;
        }
        if (self.keylist.check(.hide_player, .isDown)) {
            self.player.hidden = true;
        }
        if (self.keylist.check(.hide_player, .isUp)) {
            self.player.hidden = false;
        }
        if (self.keylist.check(.topdown_view, .isDown)) {
            self.camera.follow_fn = Camera.top_down;
            self.camera.update(self.player.origin);
        }
        if (self.keylist.check(.topdown_view, .isUp)) {
            self.camera.follow_fn = Camera.simple_follow;
            self.camera.update(self.player.origin);
        }
        return false;
    }

    fn check_falling(lvl: Level, player: Player) bool {
        var stable = true;
        if (lvl.grid == null) return false;
        for (player.grid_position.items) |pos| {
            if (lvl.grid.?[pos.x][pos.y].id != .empty) {
                stable = true;
                return false;
            }
        }
        return stable;
    }
};
