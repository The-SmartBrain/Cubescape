const rl = @import("raylib");
const std = @import("std");
const deg2rad = std.math.degreesToRadians;
const rad2deg = std.math.radiansToDegrees;
const PlayerModelPath = "assets/player_model.obj";
const PlayerTexturePath = "assets/player_texture.png";

pub const Player = struct {
    pub const Animation = union(enum) {
        pub const RollingData = struct { st_model: rl.Model, starting_origin: rl.Vector3, rotation: rl.Vector3, old_edges: [12]f32, dir: Direction };
        Rolling: RollingData,
        None: struct {},
    };
    pub const GridPosition = union(enum) {
        OneBlock: rl.Vector2,
        TwoBlock: [2]rl.Vector2,
    };

    sides: [6]Side,
    edges: [12]f32,
    model: rl.Model,
    texture: rl.Texture,
    origin: rl.Vector3,
    rotation: rl.Vector3,
    grid_position: GridPosition,
    current_animation: Animation,

    pub fn init() !Player {
        var player: Player = undefined;
        player.origin = .{ .x = 0, .y = 1, .z = 0 };
        player.rotation = .{ .x = 0, .z = 0, .y = 0 };
        player.current_animation = .None;
        //        player.model = try rl.loadModel(PlayerModelPath);
        player.model = try rl.loadModelFromMesh(rl.genMeshCube(1, 2, 1));
        player.edges = [12]f32{ 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1, 1 };

        const img = try rl.loadImage(PlayerTexturePath);
        defer rl.unloadImage(img);

        player.texture = try rl.loadTextureFromImage(img);
        player.model.materials[0].maps[@intFromEnum(rl.MaterialMapIndex.albedo)].texture = player.texture;
        return player;
    }

    pub fn deinit(c: Player) !void {
        rl.unloadTexture(c.texture);
        rl.unloadModel(c.model);
    }

    pub fn roll(self: *Player, dir: Direction) void {
        if (self.current_animation != .None) return;
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
        self.current_animation = .{ .Rolling = .{ .st_model = self.model, .starting_origin = self.origin, .rotation = self.rotation, .old_edges = self.edges, .dir = dir } };
        self.edges = new_edges;
    }

    pub fn animate(self: *Player, dt: f32) void {
        switch (self.current_animation) {
            .Rolling => |data| self.animate_rotation(data, dt),
            .None => return,
        }
    }
    fn animate_rotation(self: *Player, data: Animation.RollingData, dt: f32) void {
        const Rotation_Delta_Deg = 340 * dt; // sweetspot;

        const st_rotation = data.rotation;
        var matrix: rl.Matrix = .identity();
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
                    self.current_animation = .{ .None = .{} };
                    return;
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
                    self.current_animation = .{ .None = .{} };
                    return;
                }
            },
            .east => {
                // edge 7
                matrix = .rotateX(deg2rad(-Rotation_Delta_Deg));
                self.rotation.x = add_wrap(self.rotation.x, -Rotation_Delta_Deg);
                if (check_wrap_margin(self.rotation.x, st_rotation.x - 90, 2)) {
                    self.model.transform = data.st_model.transform.multiply(.rotateX(deg2rad(-90)));
                    self.rotation.x = add_wrap(st_rotation.x, -90);
                    self.current_animation = .{ .None = .{} };
                    return;
                }
            },
            .west => {
                // edge 5
                matrix = .rotateX(deg2rad(Rotation_Delta_Deg));
                self.rotation.x = add_wrap(self.rotation.x, Rotation_Delta_Deg);
                if (check_wrap_margin(self.rotation.x, st_rotation.x + 90, 2)) {
                    self.model.transform = data.st_model.transform.multiply(.rotateX(deg2rad(90)));
                    self.rotation.x = add_wrap(st_rotation.x, 90);
                    self.current_animation = .{ .None = .{} };
                    return;
                }
            },
        }

        self.model.transform = self.model.transform.multiply(matrix);
    }
    pub const Side = struct {};
};

pub const Direction = enum { north, south, east, west };

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
