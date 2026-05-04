const std = @import("std");
const rl = @import("raylib");
const SceneId = @import("id.zig").SceneId;
const SceneContext = @import("context.zig").SceneContext;
const Camera = @import("../core/camera.zig").Camera;
const Block = @import("../core/block.zig").Block;
const Level = @import("../core/level.zig").Level;
const Keybinds = @import("keybinds.zig");
const GlobalState = @import("../global_state.zig");
const Blender_Unit_2_Raylib_Unit = 0.50;

pub const EditorScene = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    level: Level,
    collision: rl.RayCollision,
    current_block_id: Block.BlockID,
    keylist: Keybinds.BindList,
    // Setting default values WILL NOT work because the scene struct is initialised using an allocator instead of the normal way,
    // every value is thus set to its 0 value;

    pub fn onStartup(self: *EditorScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Editor scene", .{});

        self.allocator = context.allocator;

        self.camera = .init(Camera.Default_Distance, 35, rl.Vector3{ .x = 1, .y = 1, .z = 1 });

        self.camera.follow_fn = Camera.simple_follow;
        self.current_block_id = .simple;
        self.keylist = try .import_init("editor_binds", self.allocator);

        self.level = Level.import_level(GlobalState.CurrentLevelID, self.allocator) catch |err| blk: {
            std.log.err("Level Could not be loaded {}\n", .{err});
            break :blk try Level.init(GlobalState.CurrentLevelID, 10, 10, self.allocator);
        };

        self.collision = rl.RayCollision{ .hit = false, .distance = 0, .point = .zero(), .normal = .zero() };

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *EditorScene, context: *SceneContext, delta_time: f32, render_texture: rl.RenderTexture) anyerror!void {
        rl.beginTextureMode(render_texture);
        defer rl.endTextureMode();
        // main Loop

        _ = delta_time;
        if (try self.getInput(context)) return;

        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();
            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);
            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1, true);
            self.level.draw_grid();

            if (self.collision.hit) {
                rl.drawCube(self.collision.point, 0.5, 0.1, 0.5, .red);
            }
        }
    }

    pub fn onCleanup(self: *EditorScene, context: *SceneContext) anyerror!void {
        std.log.info("Editor Scene Cleaning up...", .{});
        self.level.deinit(context.allocator);
        self.keylist.deinit();
    }

    fn getInput(self: *EditorScene, context: *SceneContext) anyerror!bool {
        const k = self.keylist;
        if (k.check(.to_menu, .isDown)) {
            try self.level.export_level(self.allocator);
            try self.keylist.export_json("bind_test");
            try context.switchTo(SceneId.menu);
            return true;
        }

        if (self.level.grid != null) {
            const grid_center: rl.Vector3 = .{ .x = 0.5, .y = 0, .z = 0.5 };
            if (screenToTile(self.camera.camera, grid_center, self.level.length, self.level.width)) |tile| {
                self.collision.hit = true;
                self.collision.point = tile.world;
                if (k.check(.place_block, .isPressed)) {
                    if (self.current_block_id == .spawn_point) {
                        self.level.starting_point = .{ .x = tile.x, .y = tile.z };
                    } else {
                        self.level.grid.?[tile.x][tile.z] = .{ .id = self.current_block_id };
                    }
                }
                if (k.check(.break_block, .isPressed)) {
                    self.level.grid.?[tile.x][tile.z] = .{ .id = .empty };
                }
            }
        }

        if (k.check(.toolbar_one, .isPressed)) {
            try self.level.export_level(self.allocator);
            self.level.deinit(self.allocator);
            self.level = try Level.import_level(.one, self.allocator);
        }
        if (k.check(.toolbar_zero, .isPressed)) {
            try self.level.export_level(self.allocator);
            self.level.deinit(self.allocator);
            self.level = try Level.import_level(.zero, self.allocator);
        }

        if (k.check(.clear_lvl, .isPressed)) {
            self.level.deinit_grid(self.allocator);
            self.level.grid = try Level.init_grid(self.level.length, self.level.width, self.allocator);
        }
        if (k.check(.toolbar_two, .isPressed))
            self.current_block_id = .simple;
        if (k.check(.toolbar_three, .isPressed))
            self.current_block_id = .red;
        if (k.check(.toolbar_four, .isPressed))
            self.current_block_id = .green;
        if (k.check(.toolbar_five, .isPressed))
            self.current_block_id = .wall;
        if (k.check(.toolbar_six, .isPressed))
            self.current_block_id = .spawn_point;

        if (k.check(.mod_fpv, .isDown)) {
            self.camera.camera.update(.first_person);
        } else {
            var forward = self.camera.camera.target
                .subtract(self.camera.camera.position)
                .normalize();

            const right = forward.crossProduct(.{ .x = 0, .y = 1, .z = 0 }).normalize();

            const up: rl.Vector3 = .{ .x = 0, .y = 1, .z = 0 };

            const speed: f32 = 0.5;

            // Forward / Backward
            if (k.check(.roll_north, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(forward, speed));
            }
            if (k.check(.roll_south, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(forward, -speed));
            }

            // Left / Right (strafe)
            if (k.check(.roll_east, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(right, -speed));
            }
            if (k.check(.roll_west, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(right, speed));
            }

            // Up / Down
            if (k.check(.go_up, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(up, speed));
            }
            if (k.check(.go_down, .isDown)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(up, -speed));
            }
        }
        return false;
    }
};

fn screenToTile(camera: rl.Camera3D, grid_center: rl.Vector3, cols: i32, rows: i32) ?struct { x: usize, z: usize, world: rl.Vector3 } {
    const ray = rl.getScreenToWorldRay(rl.getMousePosition(), camera);

    const half_cols: f32 = @as(f32, @floatFromInt(cols)) / 2.0;
    const half_rows: f32 = @as(f32, @floatFromInt(rows)) / 2.0;

    const p1: rl.Vector3 = .{ .x = grid_center.x + half_cols, .y = grid_center.y, .z = grid_center.z + half_rows };
    const p2: rl.Vector3 = .{ .x = grid_center.x - half_cols, .y = grid_center.y, .z = grid_center.z + half_rows };
    const p3: rl.Vector3 = .{ .x = grid_center.x - half_cols, .y = grid_center.y, .z = grid_center.z - half_rows };
    const p4: rl.Vector3 = .{ .x = grid_center.x + half_cols, .y = grid_center.y, .z = grid_center.z - half_rows };

    const collision = rl.getRayCollisionQuad(ray, p1, p4, p3, p2);
    if (!collision.hit) return null;

    const tile_x: usize = @intFromFloat(@floor(collision.point.x - grid_center.x + half_cols));
    const tile_z: usize = @intFromFloat(@floor(collision.point.z - grid_center.z + half_rows));

    if (tile_x < 0 or tile_x >= cols or tile_z < 0 or tile_z >= rows) return null;

    return .{
        .x = tile_x,
        .z = tile_z,
        .world = .{
            .x = @as(f32, @floatFromInt(tile_x)) - half_cols + grid_center.x + 0.5,
            .y = grid_center.y,
            .z = @as(f32, @floatFromInt(tile_z)) - half_rows + grid_center.z + 0.5,
        },
    };
}
