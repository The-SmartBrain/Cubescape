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

const edge_table = std.EnumArray(Direction, [12]u4).init(.{
    .north = .{ 2, 6, 10, 7, 3, 1, 9, 11, 0, 5, 8, 4 },
    .south = .{ 8, 5, 0, 4, 11, 9, 1, 3, 10, 6, 2, 7 },
    .east = .{ 4, 3, 7, 11, 8, 0, 2, 10, 5, 1, 6, 9 },
    .west = .{ 5, 9, 6, 1, 0, 8, 10, 2, 4, 11, 7, 3 },
});

const side_table = std.EnumArray(Direction, [6]u3).init(.{
    .north = .{ 1, 5, 2, 0, 4, 3 },
    .south = .{ 3, 0, 2, 5, 4, 1 },
    .east = .{ 2, 1, 5, 3, 0, 4 },
    .west = .{ 4, 1, 0, 3, 5, 2 },
});

pub const Vec2 = struct {
    x: usize,
    y: usize,
    pub fn zero() Vec2 {
        return .{ .x = 0, .y = 0 };
    }
};
pub const PlayerError = error{ OutOfBounds, AnimationNotNone };

pub const Player = struct {
    pub const Animation = union(enum) {
        pub const RollingData = struct {
            // zig fmt: off
            st_model: rl.Model,
            starting_origin: rl.Vector3,
            rotation: rl.Vector3,
            old_edges: [12]f32,
            dir: Direction,
            // zig fmt: on
        };
        pub const FallingData = struct { st_transform: rl.Matrix, fall_time: f32, dir: Direction };
        pub const DashingData = struct {
            dir: Direction,
            amount: f32,
            anim_time: f32 = 0.0,
            st_pos: rl.Vector3,
        };
        Rolling: RollingData,
        Falling: FallingData,
        Dashing: DashingData,
        None: struct {},
    };
    pub const GridPosition = std.ArrayList(Vec2);

    allocator: std.mem.Allocator,
    sides: [6]Side, // Ground, North,East,South,West,Top Face
    normal_side: [6]Side,
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
    lvl_ptr: *Level,

    pub fn init(allocator: std.mem.Allocator) !Player {
        var player: Player = undefined;
        player.allocator = allocator;
        player.origin = .{ .x = 0.5, .y = 1, .z = 0.5 };
        player.rotation = .{ .x = 0, .z = 0, .y = 0 };
        player.current_animation = .None;
        player.model = try rl.loadModel(PlayerModelPath);
        player.normal_side = [6]Side{ Side{}, .{ .id = Side.SideID.dash }, .{}, .{}, .{}, .{} };
        player.sides = player.normal_side;
        player.hidden = false;
        player.last_roll = .north;
        player.lvl_ptr = undefined;

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
    pub fn check_falling(self: *Player) bool {
        var stable = true;
        if (self.lvl_ptr.grid == null) return false;
        for (self.grid_position.items) |pos| {
            if (self.lvl_ptr.grid.?[pos.x][pos.y].id != .empty) {
                stable = true;
                return false;
            }
        }
        return stable;
    }

    pub fn use_effect(self: *Player) !void {
        if (self.sides[0].used) return;
        switch (self.sides[0].id) {
            .dash => {
                self.dash(self.last_roll) catch |err| if (err == PlayerError.AnimationNotNone) return;
            },
            else => {
                std.log.debug("used unimplemented effect {s}\n", .{@tagName(self.sides[0].id)});
            },
        }
        self.sides[0].used = true;
    }

    pub fn dash(self: *Player, dir: Direction) !void {
        if (self.current_animation != .None) return PlayerError.AnimationNotNone;
        const old_origin = self.origin;
        const amount = 3.0;
        {
            var vector: rl.Vector3 = .zero();
            switch (dir) {
                .north => vector.x = -1.0,
                .south => vector.x = 1.0,
                .east => vector.z = -1.0,
                .west => vector.z = 1.0,
            }

            self.origin = .add(self.origin, vector.scale(amount));
            try self.calculate_occupied_cells();

            for (self.grid_position.items) |tile| {
                if (self.lvl_ptr.grid.?[tile.x][tile.y].id == .wall) {
                    self.origin = old_origin;
                    calculate_occupied_cells(self) catch |err| if (err != PlayerError.OutOfBounds) @panic(@errorName(err));
                    return;
                }
            }
            self.origin = old_origin;
            calculate_occupied_cells(self) catch |err| if (err != PlayerError.OutOfBounds) @panic(@errorName(err));
        }
        self.current_animation = .{ .Dashing = .{ .dir = dir, .st_pos = old_origin, .amount = amount } };
    }
    pub fn animate_dash(self: *Player, data: *Animation.DashingData, dt: f32) !void {
        const speed: f32 = 10.0;
        var vector: rl.Vector3 = .zero();

        data.anim_time += dt;
        var t = data.anim_time / FallDuration_s;
        if (t > 1.0) t = 0.0;
        const eased = ease_out_quint(t);
        //        const eased = easi_in_out_expo(t);
        //        const eased = ease_in_cubic(t);
        //        const eased = ease_in_out_quad(t);

        switch (data.dir) {
            .north => vector.x = -1.0,
            .south => vector.x = 1.0,
            .east => vector.z = -1.0,
            .west => vector.z = 1.0,
        }

        const move = vector.scale(speed * eased);
        self.origin = self.origin.add(move);

        const travelled = self.origin.subtract(data.st_pos).length();
        if (travelled >= data.amount) {
            self.origin = data.st_pos.add(vector.scale(data.amount));
            try self.calculate_occupied_cells();
            self.current_animation = .{ .None = .{} };
        }
    }

    pub fn animate(self: *Player, dt: f32) !void {
        const mask_val: i32 = @intFromBool(self.hidden);
        rl.setShaderValue(self.maskShader, self.useMaskLoc, &mask_val, rl.ShaderUniformDataType.int);

        switch (self.current_animation) {
            .Rolling => |data| try self.animate_roll(data, dt),
            .Falling => |*data| try self.animate_fall(data, dt),
            .Dashing => |*data| try self.animate_dash(data, dt),
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
            try self.reset_player();
            self.current_animation = .{ .None = .{} };
        }
    }
    pub fn reset_player(self: *Player) !void {
        self.edges = self.normal_edges;
        self.sides = self.normal_side;
        self.model.transform = .identity();
        self.rotation = .zero();
        for (&self.sides) |*side| side.used = false;
        self.origin = self.lvl_ptr.idx_to_coord(self.lvl_ptr.starting_point.x, self.lvl_ptr.starting_point.y);
        self.origin.y = self.edges[5] / 2;
        self.current_animation = .{ .None = .{} };
        try self.calculate_occupied_cells();
    }

    fn animate_roll(self: *Player, data: Animation.RollingData, dt: f32) !void {
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
            try self.calculate_occupied_cells();

            return;
        }
        self.model.transform = self.model.transform.multiply(matrix);
    }
    pub fn roll(self: *Player, dir: Direction) bool {
        if (self.current_animation != .None) return false;
        const old_edges = self.edges;
        const old_origin = self.origin;

        const et = edge_table.get(dir);
        var new_edges: [12]f32 = undefined;
        for (0..12) |i| new_edges[i] = self.edges[et[i]];

        const st = side_table.get(dir);
        var new_sides: [6]Side = undefined;
        for (0..6) |i| new_sides[i] = self.sides[st[i]];

        for (&new_sides) |*side|
            side.used = false;

        self.edges = new_edges;

        {
            self.calculate_final_roll_origin(dir);
            calculate_occupied_cells(self) catch |err| if (err != PlayerError.OutOfBounds) @panic(@errorName(err));

            for (self.grid_position.items) |tile| {
                if (self.lvl_ptr.grid.?[tile.x][tile.y].id == .wall) {
                    self.edges = old_edges;
                    self.origin = old_origin;
                    calculate_occupied_cells(self) catch |err| if (err != PlayerError.OutOfBounds) @panic(@errorName(err));
                    return false;
                }
            }
            self.origin = old_origin;
            calculate_occupied_cells(self) catch |err| if (err != PlayerError.OutOfBounds) @panic(@errorName(err));
        }

        self.current_animation = .{ .Rolling = .{ .st_model = self.model, .starting_origin = old_origin, .rotation = self.rotation, .old_edges = old_edges, .dir = dir } };
        self.sides = new_sides;
        self.last_roll = dir;
        return true;
    }

    // use carefully; can NOT be used for animate_roll
    fn calculate_final_roll_origin(self: *Player, dir: Direction) void {
        switch (dir) {
            .north => {
                const b = self.edges[4] / 2;
                const a = -self.edges[1] / 2;
                const c = deg2rad(-90);
                const radius = @sqrt(b * b + a * a);
                const theta = std.math.atan2(b, a);
                const dx = radius * @cos(theta + c) - a;
                const dy = radius * @sin(theta + c) - b;

                self.origin.x -= dx;
                self.origin.y += dy;
            },
            .south => {
                const b = self.edges[4] / 2;
                const a = self.edges[1] / 2;
                const c = deg2rad(90);
                const radius = @sqrt(b * b + a * a);
                const theta = std.math.atan2(b, a);
                const dx = radius * @cos(theta + c) - a;
                const dy = radius * @sin(theta + c) - b;

                self.origin.x -= dx;
                self.origin.y += dy;
            },
            .east => {
                const b = self.edges[5] / 2;
                const a = self.edges[0] / 2;
                const c = deg2rad(90);
                const radius = @sqrt(b * b + a * a);
                const theta = std.math.atan2(b, a);
                const dx = radius * @cos(theta + c) - a;
                const dy = radius * @sin(theta + c) - b;

                self.origin.z += dx;
                self.origin.y += dy;
            },
            .west => {
                const b = self.edges[5] / 2;
                const a = -self.edges[0] / 2;
                const c = deg2rad(-90);
                const radius = @sqrt(b * b + a * a);
                const theta = std.math.atan2(b, a);
                const dx = radius * @cos(theta + c) - a;
                const dy = radius * @sin(theta + c) - b;

                self.origin.z += dx;
                self.origin.y += dy;
            },
        }
    }

    pub fn fall(self: *Player, dir: Direction) void {
        if (self.current_animation != .None) return;
        self.current_animation = .{ .Falling = .{ .fall_time = 0, .dir = dir, .st_transform = self.model.transform } };
    }

    pub fn calculate_occupied_cells(self: *Player) !void {
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
                const v2 = index_from_2d(x_round, z_round, self.lvl_ptr.length, self.lvl_ptr.width) orelse return PlayerError.OutOfBounds;
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

inline fn ease_in_out_quad(x: f32) f32 {
    return if (x < 0.5)
        2.0 * x * x
    else
        1.0 - std.math.pow(f32, -2.0 * x + 2.0, 2.0) / 2.0;
}
inline fn easi_in_out_expo(x: f32) f32 {
    return if (x == 0.0) 0.0 else if (x == 1.0) 1.0 else if (x < 0.5) std.math.pow(f32, 2.0, 20.0 * x - 10.0) / 2.0 else (2.0 - std.math.pow(f32, 2.0, -20.0 * x + 10.0)) / 2.0;
}
