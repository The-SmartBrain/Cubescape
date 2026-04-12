const rl = @import("raylib");
const std = @import("std");
const deg2rad = std.math.degreesToRadians;
const rad2deg = std.math.radiansToDegrees;
const PlayerModelPath = "assets/player_model.obj";
const PlayerTexturePath = "assets/player_texture.png";

pub const Player = struct {
    pub const Animation = union(enum) {
        Rolling: struct { prev: Transform, old_edges: [12]f32, dir: Direction },
        None: struct {},
    };

    sides: [6]Side,
    edges: [12]f32,
    model: rl.Model,
    texture: rl.Texture,
    position: Transform,
    rotation: Transform,
    current_animation: Animation,

    pub fn init() !Player {
        var player: Player = undefined;
        player.position = .zeros();
        player.rotation = .zeros();
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
        self.current_animation = .{ .Rolling = .{ .prev = self.rotation, .old_edges = self.edges, .dir = dir } };
        self.edges = new_edges;
    }

    pub fn animate(self: *Player, dt: f32) void {
        switch (self.current_animation) {
            .Rolling => |data| self.animate_rotation(data.dir, data.prev, data.old_edges, dt),
            .None => return,
        }
    }
    fn animate_rotation(self: *Player, dir: Direction, prev: Transform, edges: [12]f32, dt: f32) void {
        const Rotation_Delta_Deg = 340 * dt; // sweetspot;

        _ = edges;
        switch (dir) {
            .north => {
                self.rotation.z = add_wrap(self.rotation.z, Rotation_Delta_Deg);

                if (check_wrap_margin(self.rotation.z, prev.z + 90, 2)) {
                    self.rotation.z = add_wrap(prev.z, 90);
                    self.current_animation = .{ .None = .{} };
                }
            },
            .south => {
                self.rotation.z = add_wrap(self.rotation.z, -Rotation_Delta_Deg);

                if (check_wrap_margin(self.rotation.z, prev.z - 90, 2)) {
                    self.rotation.z = add_wrap(prev.z, -90);
                    self.current_animation = .{ .None = .{} };
                }
            },
            .east => {
                // edge 7
                self.rotation.x = add_wrap(self.rotation.x, -Rotation_Delta_Deg);
                if (check_wrap_margin(self.rotation.x, prev.x - 90, 2)) {
                    self.rotation.x = add_wrap(prev.x, -90);
                    self.current_animation = .{ .None = .{} };
                }
            },
            .west => {
                // edge 5
                self.rotation.x = add_wrap(self.rotation.x, Rotation_Delta_Deg);
                if (check_wrap_margin(self.rotation.x, prev.x + 90, 2)) {
                    self.rotation.x = add_wrap(prev.x, 90);
                    self.current_animation = .{ .None = .{} };
                }
            },
        }

        self.model.transform = rl.Matrix.rotateXYZ(self.rotation.apply(deg2rad).as_RaylibVec3());
    }
    pub const Side = struct {};
};

pub const Direction = enum { north, south, east, west };

pub const Transform = struct {
    x: f32,
    y: f32,
    z: f32,
    pub fn zeros() Transform {
        return .{ .x = 0, .y = 0, .z = 0 };
    }
    pub fn as_RaylibVec3(t: Transform) rl.Vector3 {
        return .{ .x = t.x, .z = t.z, .y = t.y };
    }

    pub fn apply(t: Transform, func: *const fn (anytype) f32) Transform {
        const x = func(t.x);
        const y = func(t.y);
        const z = func(t.z);
        return .{ .x = x, .z = z, .y = y };
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
