const rl = @import("raylib");
const std = @import("std");
const deg2rad = std.math.degreesToRadians;
const rad2deg = std.math.radiansToDegrees;
const Level = @import("level.zig").Level;
const FallLimit = -10;
const RotationStart = -0.5;
const FallDuration_s = 1.0;
const PlayerModelPath = "assets/models/player_model.obj";
const PlayerTexturePath = "assets/player_texture.png";
const MaskShaderPath = "assets/shaders/mask.fs";
const MaskTexturePath = "assets/mask.png";

pub const Vec2 = struct {
    x: usize,
    y: usize,
    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }
};
pub const PlayerError = error{OutOfBounds};

pub const Player = struct {
    pub const Animation = union(enum) {
        pub const RollingData = struct {
            // zig fmt: off
            st_model: rl.Model,
            starting_origin: rl.Vector3,
            rotation: rl.Vector3,
            old_edges: [12]f32,
            dir: Direction,
            lvl_len: u8,
            lvl_width: u8,
            // zig fmt: on
        };
        pub const FallingData = struct { lvl_ptr: *Level, st_transform: rl.Matrix, fall_time: f32, dir: Direction };
        Rolling: RollingData,
        Falling: FallingData,
        None: struct {},
    };
    pub const GridPosition = std.ArrayList(Vec2);

    allocator: std.mem.Allocator,
    sides: [6]Side, // Ground, North,East,South,West,Top Face
    normal_edges: [12]f32,
    edges: [12]f32,
    model: rl.Model,
    colorTexture: rl.Texture,
    maskTexture: rl.Texture,
    maskShader: rl.Shader,
    useMaskLoc: i32,

    origin: rl.Vector3,
    rotation: rl.Vector3,
    grid_position: GridPosition,
    current_animation: Animation,
    hidden: bool,
    last_roll: Direction,

    pub fn init(allocator: std.mem.Allocator) !Player {
        var player: Player = undefined;
        player.allocator = allocator;
        player.origin = .{ .x = 0.5, .y = 1, .z = 0.5 };
        player.rotation = .{ .x = 0, .z = 0, .y = 0 };
        player.current_animation = .None;
        player.model = try rl.loadModel(PlayerModelPath);
        player.sides = [_]Side{ Side{}, .{ .id = Side.SideID.dash }, .{}, .{}, .{}, .{} };

        player.hidden = false;
        player.last_roll = .north;

        player.normal_edges = [12]f32{ 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1 };
        // Working sizes: 1x1x1,1x2x1, 1x3x1,
        // Broken sizes: 2x2x2,3x3x3,2x1x2, These require an offset(0.5|0|0.5) frrom the grid. Easy to implement

        player.edges = player.normal_edges;
        player.grid_position = try .initCapacity(allocator, 2);
        try player.grid_position.append(allocator, .{ .x = 0, .y = 0 });

        {
            player.colorTexture = try rl.loadTexture(PlayerTexturePath);
            player.model.materials[0].maps[@intFromEnum(rl.MaterialMapIndex.albedo)].texture = player.colorTexture;

            player.maskTexture = try rl.loadTexture(MaskTexturePath);
            player.model.materials[0].maps[@intFromEnum(rl.MaterialMapIndex.emission)].texture = player.maskTexture;

            player.maskShader = try rl.loadShader(null, MaskShaderPath);
            player.maskShader.locs[@intFromEnum(rl.ShaderLocationIndex.map_emission)] = rl.getShaderLocation(player.maskShader, "mask");
            player.useMaskLoc = rl.getShaderLocation(player.maskShader, "useMask");
            const false_int: i32 = 0;
            rl.setShaderValue(player.maskShader, player.useMaskLoc, &false_int, rl.ShaderUniformDataType.int);
            player.model.materials[0].shader = player.maskShader;
        }
        return player;
    }

    pub fn deinit(c: *Player) !void {
        c.grid_position.deinit(c.allocator);
        rl.unloadTexture(c.colorTexture);
        rl.unloadTexture(c.maskTexture);
        rl.unloadShader(c.maskShader);
        rl.unloadModel(c.model);
    }

    pub fn use_effect(self: *Player) !void {
        if (self.sides[0].used) return;
        defer self.sides[0].used = true;
        switch (self.sides[0].id) {
            else => {
                std.debug.print("used effect {s}\n", .{@tagName(self.sides[0].id)});
            },
        }
    }

    pub fn animate(self: *Player, dt: f32) !void {
        const mask_val: i32 = @intFromBool(self.hidden);
        rl.setShaderValue(self.maskShader, self.useMaskLoc, &mask_val, rl.ShaderUniformDataType.int);

        switch (self.current_animation) {
            .Rolling => |data| try self.animate_rotation(data, dt),
            .Falling => |*data| try self.animate_fall(data, dt),
            .None => return,
        }
    }
    fn animate_fall(self: *Player, data: *Animation.FallingData, dt: f32) !void {
        self.origin.y -= 12 * dt;
        if (self.origin.y < RotationStart) {
            data.fall_time += dt;
            var t = data.fall_time / FallDuration_s;
            if (t > 1.0) t = 0.0;
            const eased = ease_out_quint(t);
            const rot_amount = deg2rad(500) * eased;
            var rot_vector: rl.Vector3 = .zero();
            switch (data.dir) {
                .north => rot_vector.z = rot_amount,
                .south => rot_vector.z = -rot_amount,
                .east => rot_vector.x = -rot_amount,
                .west => rot_vector.x = rot_amount,
            }
            self.model.transform =
                data.st_transform.multiply(rl.Matrix.rotateXYZ(rot_vector));
        }
        if (self.origin.y < FallLimit) {
            self.edges = self.normal_edges;
            self.model.transform = .identity();
            self.rotation = .zero();
            self.origin = data.lvl_ptr.idx_to_coord(data.lvl_ptr.starting_point.x, data.lvl_ptr.starting_point.y);
            self.origin.y = self.edges[5] / 2;

            self.current_animation = .{ .None = .{} };
            try self.calculate_occupied_cells(data.lvl_ptr.length, data.lvl_ptr.width);
        }
    }
    fn animate_rotation(self: *Player, data: Animation.RollingData, dt: f32) !void {
        const Rotation_Delta_Deg = 340 * dt; // sweetspot;

        const st_rotation = data.rotation;
        var matrix: rl.Matrix = .identity();
        var anim_done: bool = false;
        switch (data.dir) {
            .north => {
                self.rotation.z = add_wrap(self.rotation.z, Rotation_Delta_Deg);

                const b = data.old_edges[4] / 2;
                const a = -data.old_edges[1] / 2;

                {
                    const c = deg2rad(data.rotation.z - self.rotation.z);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dx = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.x = data.starting_origin.x - dx;
                    self.origin.y = data.starting_origin.y + dy;
                }
                //
                matrix = rl.Matrix.rotateZ(deg2rad(Rotation_Delta_Deg));
                if (check_wrap_margin(self.rotation.z, st_rotation.z + 90, 2)) {
                    matrix = rl.Matrix.rotateZ(deg2rad(90));
                    const c = deg2rad(-90);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dx = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.x = data.starting_origin.x - dx;
                    self.origin.y = data.starting_origin.y + dy;

                    self.model.transform = data.st_model.transform.multiply(matrix);
                    self.rotation.z = add_wrap(st_rotation.z, 90);

                    anim_done = true;
                }
            },
            .south => {
                self.rotation.z = add_wrap(self.rotation.z, -Rotation_Delta_Deg);
                const b = data.old_edges[4] / 2;
                const a = data.old_edges[1] / 2;

                {
                    const c = deg2rad(data.rotation.z - self.rotation.z);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dx = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.x = data.starting_origin.x - dx;
                    self.origin.y = data.starting_origin.y + dy;
                }

                matrix = .rotateZ(deg2rad(-Rotation_Delta_Deg));
                if (check_wrap_margin(self.rotation.z, st_rotation.z - 90, 2)) {
                    const c = deg2rad(90);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dx = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.x = data.starting_origin.x - dx;
                    self.origin.y = data.starting_origin.y + dy;
                    self.model.transform = data.st_model.transform.multiply(.rotateZ(deg2rad(-90)));
                    self.rotation.z = add_wrap(st_rotation.z, -90);
                    anim_done = true;
                }
            },
            .east => {
                // edge 7
                matrix = .rotateX(deg2rad(-Rotation_Delta_Deg));
                self.rotation.x = add_wrap(self.rotation.x, -Rotation_Delta_Deg);
                const b = data.old_edges[5] / 2;
                const a = data.old_edges[0] / 2;

                {
                    const c = deg2rad(data.rotation.x - self.rotation.x);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dz = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.z = data.starting_origin.z + dz;
                    self.origin.y = data.starting_origin.y + dy;
                }

                if (check_wrap_margin(self.rotation.x, st_rotation.x - 90, 2)) {
                    self.model.transform = data.st_model.transform.multiply(.rotateX(deg2rad(-90)));
                    self.rotation.x = add_wrap(st_rotation.x, -90);

                    const c = deg2rad(90);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dz = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.z = data.starting_origin.z + dz;
                    self.origin.y = data.starting_origin.y + dy;

                    anim_done = true;
                }
            },
            .west => {
                // edge 5
                matrix = .rotateX(deg2rad(Rotation_Delta_Deg));
                self.rotation.x = add_wrap(self.rotation.x, Rotation_Delta_Deg);
                const b = data.old_edges[5] / 2;
                const a = -data.old_edges[0] / 2;

                {
                    const c = deg2rad(data.rotation.x - self.rotation.x);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dz = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.z = data.starting_origin.z + dz;
                    self.origin.y = data.starting_origin.y + dy;
                }

                if (check_wrap_margin(self.rotation.x, st_rotation.x + 90, 2)) {
                    self.model.transform = data.st_model.transform.multiply(.rotateX(deg2rad(90)));
                    self.rotation.x = add_wrap(st_rotation.x, 90);

                    const c = deg2rad(-90);
                    const radius = @sqrt(b * b + a * a);
                    const theta = std.math.atan2(b, a);
                    const dz = radius * @cos(theta + c) - a;
                    const dy = radius * @sin(theta + c) - b;

                    self.origin.z = data.starting_origin.z + dz;
                    self.origin.y = data.starting_origin.y + dy;

                    anim_done = true;
                }
            },
        }

        if (anim_done) {
            self.current_animation = .{ .None = .{} };
            self.calculate_occupied_cells(data.lvl_len, data.lvl_width) catch |err| {
                if (err == PlayerError.OutOfBounds) _ = self.roll(data.dir.inv(), data.lvl_width, data.lvl_len);
            };
            self.use_effect() catch |err| @panic(err);
            return;
        }
        self.model.transform = self.model.transform.multiply(matrix);
    }
    pub fn roll(self: *Player, dir: Direction, lvl_w: u8, lvl_l: u8) bool {
        if (self.current_animation != .None) return false;
        var new_edges: [12]f32 = undefined;
        switch (dir) {
            .north => {
                new_edges[8] = self.edges[0];
                new_edges[5] = self.edges[1];
                new_edges[0] = self.edges[2];
                new_edges[4] = self.edges[3];
                new_edges[11] = self.edges[4];
                new_edges[9] = self.edges[5];
                new_edges[1] = self.edges[6];
                new_edges[3] = self.edges[7];
                new_edges[10] = self.edges[8];
                new_edges[6] = self.edges[9];
                new_edges[2] = self.edges[10];
                new_edges[7] = self.edges[11];
            },
            .south => {
                new_edges[2] = self.edges[0];
                new_edges[6] = self.edges[1];
                new_edges[10] = self.edges[2];
                new_edges[7] = self.edges[3];
                new_edges[3] = self.edges[4];
                new_edges[1] = self.edges[5];
                new_edges[9] = self.edges[6];
                new_edges[11] = self.edges[7];
                new_edges[0] = self.edges[8];
                new_edges[5] = self.edges[9];
                new_edges[8] = self.edges[10];
                new_edges[4] = self.edges[11];
            },
            .east => {
                new_edges[5] = self.edges[0];
                new_edges[9] = self.edges[1];
                new_edges[6] = self.edges[2];
                new_edges[1] = self.edges[3];
                new_edges[0] = self.edges[4];
                new_edges[8] = self.edges[5];
                new_edges[10] = self.edges[6];
                new_edges[2] = self.edges[7];
                new_edges[4] = self.edges[8];
                new_edges[11] = self.edges[9];
                new_edges[7] = self.edges[10];
                new_edges[3] = self.edges[11];
            },
            .west => {
                new_edges[4] = self.edges[0];
                new_edges[3] = self.edges[1];
                new_edges[7] = self.edges[2];
                new_edges[11] = self.edges[3];
                new_edges[8] = self.edges[4];
                new_edges[0] = self.edges[5];
                new_edges[2] = self.edges[6];
                new_edges[10] = self.edges[7];
                new_edges[5] = self.edges[8];
                new_edges[1] = self.edges[9];
                new_edges[6] = self.edges[10];
                new_edges[9] = self.edges[11];
            },
        }
        var new_sides: [6]Side = undefined;
        switch (dir) {
            .north => {
                new_sides[0] = self.sides[1];
                new_sides[1] = self.sides[5];
                new_sides[2] = self.sides[2];
                new_sides[3] = self.sides[0];
                new_sides[4] = self.sides[4];
                new_sides[5] = self.sides[3];
            },
            .south => {
                new_sides[0] = self.sides[3];
                new_sides[1] = self.sides[0];
                new_sides[2] = self.sides[2];
                new_sides[3] = self.sides[5];
                new_sides[4] = self.sides[4];
                new_sides[5] = self.sides[1];
            },
            .east => {
                new_sides[0] = self.sides[2];
                new_sides[1] = self.sides[1];
                new_sides[2] = self.sides[5];
                new_sides[3] = self.sides[3];
                new_sides[4] = self.sides[0];
                new_sides[5] = self.sides[4];
            },
            .west => {
                new_sides[0] = self.sides[4];
                new_sides[1] = self.sides[1];
                new_sides[2] = self.sides[0];
                new_sides[3] = self.sides[3];
                new_sides[4] = self.sides[5];
                new_sides[5] = self.sides[2];
            },
        }
        for (&new_sides) |*side|
            side.used = false;

        self.current_animation = .{ .Rolling = .{ .st_model = self.model, .starting_origin = self.origin, .rotation = self.rotation, .old_edges = self.edges, .dir = dir, .lvl_len = lvl_l, .lvl_width = lvl_w } };
        self.edges = new_edges;
        self.sides = new_sides;
        self.last_roll = dir;
        return true;
    }

    pub fn fall(self: *Player, lvl: *Level, dir: Direction) void {
        if (self.current_animation != .None) return;
        self.current_animation = .{ .Falling = .{ .lvl_ptr = lvl, .fall_time = 0, .dir = dir, .st_transform = self.model.transform } };
    }

    pub fn calculate_occupied_cells(self: *Player, lvl_l: u8, lvl_w: u8) !void {
        self.grid_position.clearRetainingCapacity();
        const a: f32 = self.edges[1]; // guaranteed to be whole numbers
        const b: f32 = self.edges[0]; // guaranteed to be whole numbers
        const ul_corner = rl.Vector2{ .x = self.origin.x - a / 2, .y = self.origin.z + b / 2 };
        const lr_corner = rl.Vector2{ .x = self.origin.x + a / 2, .y = self.origin.z - b / 2 };
        var x = ul_corner.x + 0.5;
        var z = ul_corner.y - 0.5;

        while (z >= lr_corner.y) {
            const z_round: i32 = @intFromFloat(@round(z)); // @round is REQUIRED, @floor or @trunc will result in wrong coordinate calc
            while (x <= lr_corner.x) {
                const x_round: i32 = @intFromFloat(@round(x));
                const v2 = index_from_2d(x_round, z_round, lvl_l, lvl_w) orelse return PlayerError.OutOfBounds;
                try self.grid_position.append(self.allocator, v2);
                x += 1.0;
            }
            x = ul_corner.x + 0.5;
            z -= 1;
        }
    }

    fn index_from_2d(x: i32, y: i32, l: u8, w: u8) ?Vec2 {
        const width: f32 = @floatFromInt(w);
        const length: f32 = @floatFromInt(l);
        const xf: f32 = @floatFromInt(x);
        const yf: f32 = @floatFromInt(y);

        const i: f32 = xf + width / 2 - 1;
        const j: f32 = yf + length / 2 - 1;

        if (i < 0 or j < 0 or i >= width or j >= length) return null;

        return .{ .x = @intFromFloat(i), .y = @intFromFloat(j) };
    }

    pub const Side = struct {
        id: SideID = .none,
        used: bool = false,
        pub const SideID = enum {
            none,
            dash,
            portal,
            armor,
        };
    };
};

pub const Direction = enum {
    north,
    south,
    east,
    west,

    pub fn inv(dir: Direction) Direction {
        switch (dir) {
            .north => return Direction.south,
            .south => return Direction.north,
            .east => return Direction.west,
            .west => return Direction.east,
        }
    }
};

pub fn add_wrap(a: f32, b: f32) f32 {
    return @mod((a + b), 360);
}

pub fn angular_diff(a: f32, b: f32) f32 {
    const diff = @mod(a - b, 360);
    return if (diff > 180) 360 - diff else diff;
}

pub fn check_wrap_margin(a: f32, b: f32, margin: f32) bool {
    return angular_diff(a, b) < margin;
}

inline fn ease_out_quint(x: f32) f32 {
    return 1 - std.math.pow(f32, 1 - x, 1);
}

inline fn ease_in(x: f32) f32 {
    return x * x;
}
inline fn ease_in_cubic(x: f32) f32 {
    return x * x * x;
}

inline fn easi_in_out_expo(x: f32) f32 {
    return if (x == 0.0) 0.0 else if (x == 1.0) 1.0 else if (x < 0.5) std.math.pow(f32, 2.0, 20.0 * x - 10.0) / 2.0 else (2.0 - std.math.pow(f32, 2.0, -20.0 * x + 10.0)) / 2.0;
}
