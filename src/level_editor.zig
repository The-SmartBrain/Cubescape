const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;
const Camera = @import("core/camera.zig").Camera;
const Block = @import("core/block.zig").Block;
const Level = @import("core/level.zig").Level;
const Blender_Unit_2_Raylib_Unit = 0.50;

pub const EditorScene = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    level: Level,
    collision: rl.RayCollision,
    // Setting default values WILL NOT work because the scene struct is initialised using an allocator instead of the normal way,
    // every value is thus set to its 0 value;

    pub fn onStartup(self: *EditorScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Editor scene", .{});

        self.allocator = context.allocator;

        self.camera = .init(Camera.Default_Distance, 35, rl.Vector3{ .x = 1, .y = 1, .z = 1 });

        self.camera.follow_fn = Camera.simple_follow;

        self.level = try .init(Level.LevelID.one, 10, 10, self.allocator);
        self.collision = rl.RayCollision{ .hit = false, .distance = 0, .point = .zero(), .normal = .zero() };

        // Init Scene here --> Läuft EINMAL beim Start
    }

    pub fn onUpdate(self: *EditorScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop

        _ = delta_time;
        try self.getInput(context);

        rl.clearBackground(.white);
        {
            self.camera.begin();
            defer self.camera.end();
            const length: f32 = @floatFromInt(self.level.length);
            const width: f32 = @floatFromInt(self.level.width);
            Level.draw_2D_grid(.{ .x = 0.5, .y = 0, .z = 0.5 }, width, length, 1);
            self.level.draw_grid();

            if (self.collision.hit) {
                rl.drawCube(self.collision.point, 1, 0.1, 1, .red);
            }
        }
    }

    pub fn onCleanup(self: *EditorScene, context: *SceneContext) anyerror!void {
        std.log.info("Editor Scene Cleaning up...", .{});
        Level.deinit_grid(self.level.grid, context.allocator);
    }

    fn getInput(self: *EditorScene, context: *SceneContext) anyerror!void {
        if (rl.isKeyDown(.m)) {
            try context.switchTo(SceneId.menu);
            return;
        }

        const grid_center: rl.Vector3 = .{ .x = 0.5, .y = 0, .z = 0.5 };
        if (screenToTile(self.camera.camera, grid_center, self.level.length, self.level.width)) |tile| {
            self.collision.hit = true;
            self.collision.point = tile.world;
            if (rl.isMouseButtonPressed(.right)) {
                self.level.grid[tile.x][tile.z] = .{ .id = .simple };
            }
        }

        if (rl.isKeyDown(.left_shift)) {
            self.camera.camera.update(.first_person);
        } else {
            var forward = self.camera.camera.target
                .subtract(self.camera.camera.position)
                .normalize();

            const right = forward.crossProduct(.{ .x = 0, .y = 1, .z = 0 }).normalize();

            const up: rl.Vector3 = .{ .x = 0, .y = 1, .z = 0 };

            const speed: f32 = 0.5;

            // Forward / Backward
            if (rl.isKeyDown(.w)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(forward, speed));
            }
            if (rl.isKeyDown(.s)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(forward, -speed));
            }

            // Left / Right (strafe)
            if (rl.isKeyDown(.a)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(right, -speed));
            }
            if (rl.isKeyDown(.d)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(right, speed));
            }

            // Up / Down
            if (rl.isKeyDown(.up)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(up, speed));
            }
            if (rl.isKeyDown(.down)) {
                self.camera.camera.position = .add(self.camera.camera.position, .scale(up, -speed));
            }
        }
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
