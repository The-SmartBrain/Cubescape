const rl = @import("raylib");
const std = @import("std");
const deg2rad = std.math.degreesToRadians;
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
        player.model = try rl.loadModel(PlayerModelPath);
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

        var rotation_matrix: rl.Matrix = .identity();
        switch (dir) {
            .north => {
                // edge 6
                const Rotation_Delta_Rad = deg2rad(Rotation_Delta_Deg);

                const hyp: f32 = edges[5] / 2;
                const sin = @sin(Rotation_Delta_Rad) * hyp;
                const cos = @cos(Rotation_Delta_Rad) * hyp;

                self.position.x -= sin;
                self.position.y -= cos;

                rotation_matrix = rl.Matrix.rotateZ(Rotation_Delta_Rad);

                self.rotation.z += Rotation_Delta_Deg;

                if (self.rotation.z >= prev.z + 90) {
                    self.current_animation = .{ .None = .{} };
                }
            },
            .south => {
                const Rotation_Delta_Rad = deg2rad(-Rotation_Delta_Deg);
                // edge 8

                self.rotation.z -= Rotation_Delta_Deg;

                rotation_matrix = rl.Matrix.rotateZ(Rotation_Delta_Rad);
                if (self.rotation.z <= prev.z - 90)
                    self.current_animation = .{ .None = .{} };
            },
            .east => {
                const Rotation_Delta_Rad = deg2rad(Rotation_Delta_Deg);
                // edge 7
                self.rotation.x -= Rotation_Delta_Deg;
                //              self.position.z -= 0.1 * dt;
                rotation_matrix = rl.Matrix.rotateX(-Rotation_Delta_Rad);
                if (self.rotation.x <= prev.x - 90)
                    self.current_animation = .{ .None = .{} };
            },
            .west => {
                const Rotation_Delta_Rad = deg2rad(Rotation_Delta_Deg);
                // edge 5
                self.rotation.x += Rotation_Delta_Deg;
                //              self.position.z += 0.1 * dt;
                rotation_matrix = rl.Matrix.rotateX(Rotation_Delta_Rad);
                if (self.rotation.x >= prev.x + 90)
                    self.current_animation = .{ .None = .{} };
            },
        }

        self.model.transform = self.model.transform.multiply(rotation_matrix);
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
};
