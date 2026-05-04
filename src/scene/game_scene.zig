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
const Normal_Vert_Shader_Path = "assets/shaders/normal.vert";
const Normal_Frag_Shader_Path = "assets/shaders/normal.frag";
const Outline_Frag_Shader_Path = "assets/shaders/outline.frag";

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

    normalFBO: rl.RenderTexture,
    sceneFBO: rl.RenderTexture,
    normal_shader: rl.Shader,
    outline_shader: rl.Shader,
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
        self.player.lvl_ptr = &self.level;

        try self.player.calculate_occupied_cells();

        self.camera.update(self.player.origin);

        self.normalFBO = try rl.loadRenderTexture(GlobalState.DrawWidth, GlobalState.DrawHeight);
        self.sceneFBO = try rl.loadRenderTexture(GlobalState.DrawWidth, GlobalState.DrawHeight);
        self.normal_shader = try rl.loadShader(Normal_Vert_Shader_Path, Normal_Frag_Shader_Path);
        self.outline_shader = try rl.loadShader(null, Outline_Frag_Shader_Path);

        // Init Scene here --> Läuft EINMAL beim Start
        self.current_moves = 0;
    }

    pub fn onUpdate(self: *GameScene, context: *SceneContext, delta_time: f32, render_texture: rl.RenderTexture) anyerror!void {

        // main Loop
        const player: *Player = &self.player;

        if (try self.getInput(context)) return;

        player.animate(delta_time) catch |err| {
            std.log.err("failed to animate player {}\n", .{err});
        };

        if (player.check_falling()) {
            player.fall(player.last_roll);
        }

        try player.use_effect();

        self.camera.update(player.origin);
        // zig fmt: off
        rl.beginTextureMode(self.normalFBO);
            rl.clearBackground(.black);
            self.camera.begin();
                rl.beginShaderMode(self.normal_shader);
                    self.draw_world_override_shader(self.normal_shader);
                rl.endShaderMode();
            self.camera.end();
        rl.endTextureMode();
        // zig fmt: on

        // zig fmt: off
        rl.beginTextureMode(self.sceneFBO);
            rl.clearBackground(.white);
            self.camera.begin();
                self.draw_world();
            self.camera.end();
        rl.endTextureMode();
        // zig fmt: on

        rl.beginTextureMode(render_texture);
        rl.drawTextureRec(self.sceneFBO.texture, rl.Rectangle{ .x = 0, .y = 0, .width = GlobalState.DrawWidth, .height = -GlobalState.DrawHeight }, .zero(), .white);
        rl.endTextureMode();

        //        const slice: [:0]const u8 = @tagName(self.player.sides[0].id);
        //        rl.drawText(rl.textFormat("Aktuelle Unterseite: 0. %f 1. %f ID: %s", .{ player.edges[0], player.edges[1], slice.ptr }), 10, 40, 20, .red);
        //        const slice_anim: [:0]const u8 = @tagName(self.player.current_animation);
        //        rl.drawText(rl.textFormat("Aktuelle Animation:  %s", .{slice_anim.ptr}), 10, 60, 20, .red);
        //
        // Overlay als letztes
        overlay.draw(self);
    }
    fn draw_world_override_shader(self: *GameScene, shader: rl.Shader) void {
        const player: *Player = &self.player;

        {
            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);

            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1, false);
            self.level.draw_grid_shader(shader);

            const original_shader = player.model.materials[0].shader;
            player.model.materials[0].shader = shader;
            rl.drawModel(player.model, player.origin, Blender_Unit_2_Raylib_Unit, .white);
            player.model.materials[0].shader = original_shader;
        }
    }

    fn draw_world(self: *GameScene) void {
        const player: *Player = &self.player;

        {
            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);

            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1, false);
            self.level.draw_grid();

            rl.drawModel(player.model, player.origin, Blender_Unit_2_Raylib_Unit, .white);
        }
    }

    pub fn onCleanup(self: *GameScene, context: *SceneContext) anyerror!void {
        std.log.info("Game Scene Cleaning up...", .{});
        self.level.deinit(context.allocator);
        try self.player.deinit();
        self.keylist.deinit();

        rl.unloadRenderTexture(self.normalFBO);
        rl.unloadRenderTexture(self.sceneFBO);
        rl.unloadShader(self.normal_shader);
        rl.unloadShader(self.outline_shader);
    }

    fn getInput(self: *GameScene, context: *SceneContext) anyerror!bool {
        if (self.keylist.check(.to_menu, .isDown)) {
            try context.switchTo(SceneId.menu);
            return true;
        }
        if (self.keylist.check(.roll_north, .isDown)) {
            if (self.player.roll(.north)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_south, .isDown)) {
            if (self.player.roll(.south)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_west, .isDown)) {
            if (self.player.roll(.west)) self.current_moves += 1;
        }
        if (self.keylist.check(.roll_east, .isDown)) {
            if (self.player.roll(.east)) self.current_moves += 1;
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
};
