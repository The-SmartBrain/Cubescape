// Libary imports
const std = @import("std");
const rl = @import("raylib");

const PlayerModelPath = "assets/player_model.obj";
const PlayerTexturePath = "assets/player_texture.png";
const deg2rad = std.math.degreesToRadians;
const Rotation_Delta_Deg = 6;
const Rotation_Delta_Rad = deg2rad(Rotation_Delta_Deg);

const State = struct {
    player: *Cube = undefined,
};

const Side = struct {
    id: u8,
    // Hier später enum effect?
};

const Cube = struct {
    // Indizes für: 0=oben, 1=unten, 2=vorne, 3=hinten, 4=links, 5=rechts
    side_indices: [6]u8 = .{ 0, 1, 2, 3, 4, 5 },
    rotation: rl.Vector3 = .{ .y = 0, .x = 0, .z = 0 },
    prev_rotation: rl.Vector3 = .{ .y = 0, .x = 0, .z = 0 },
    rotate_to: rl.Vector3 = .{ .y = 0, .x = 0, .z = 0 },
    grid_pos: struct { x: f32, y: f32 } = .{ .x = 0, .y = 0 },
    model: rl.Model = undefined,
    texture_atlas: rl.Texture = undefined,

    pub fn roll(self: *Cube, dir: enum { north, south, east, west }) void {
        const s = self.side_indices;
        // Index-Rotation
        self.side_indices = switch (dir) {
            // Norden: vorne -> oben, oben -> hinten, hinten -> unten, unten -> vorne
            .north => .{ s[2], s[3], s[1], s[0], s[4], s[5] },
            // Süden: hinten -> oben, oben -> vorne, vorne -> unten, unten -> hinten
            .south => .{ s[3], s[2], s[0], s[1], s[4], s[5] },
            // Osten: links -> oben, oben -> rechts, rechts -> unten, unten -> links
            .east => .{ s[4], s[5], s[0], s[1], s[3], s[2] },
            // Westen: rechts -> oben, oben -> links, links -> unten, unten -> rechts
            .west => .{ s[5], s[4], s[0], s[1], s[2], s[3] },
        };

        switch (dir) {
            .north => {
                self.rotate_to.z += 1;
                self.rotate_to.x = 0;
                //                self.grid_pos.x -= 1;
            },
            .south => {
                self.rotate_to.z -= 1;
                self.rotate_to.x = 0;
                //               self.grid_pos.x += 1;
            },
            .east => {
                self.rotate_to.x -= 1;
                self.rotate_to.z = 0;
                //              self.grid_pos.y -= 1;
            },
            .west => {
                self.rotate_to.x += 1;
                self.rotate_to.z = 0;
                //             self.grid_pos.y += 1;
            },
        }
    }
    pub fn iterate(self: *Cube) void {
        var rotation_matrix: rl.Matrix = .identity();
        if (self.rotate_to.z > 0) {
            self.rotation.z += Rotation_Delta_Deg;
            self.grid_pos.x -= 0.1;
            rotation_matrix = rl.Matrix.rotateZ(Rotation_Delta_Rad);
            if (self.rotation.z >= self.prev_rotation.z + 90) {
                self.rotate_to.z = 0;
                self.prev_rotation.z = self.rotation.z;
            }
        } else if (self.rotate_to.z < 0) {
            self.rotation.z -= Rotation_Delta_Deg;
            self.grid_pos.x += 0.1;
            rotation_matrix = rl.Matrix.rotateZ(-Rotation_Delta_Rad);
            if (self.rotation.z <= self.prev_rotation.z - 90) {
                self.rotate_to.z = 0;
                self.prev_rotation.z = self.rotation.z;
            }
        } else if (self.rotate_to.x > 0) {
            self.rotation.x += Rotation_Delta_Deg;
            self.grid_pos.y += 0.1;
            rotation_matrix = rl.Matrix.rotateX(Rotation_Delta_Rad);
            if (self.rotation.x >= self.prev_rotation.x + 90) {
                self.rotate_to.x = 0;
                self.prev_rotation.x = self.rotation.x;
            }
        } else if (self.rotate_to.x < 0) {
            self.rotation.x -= Rotation_Delta_Deg;
            self.grid_pos.y -= 0.1;
            rotation_matrix = rl.Matrix.rotateX(-Rotation_Delta_Rad);
            if (self.rotation.x <= self.prev_rotation.x - 90) {
                self.rotate_to.x = 0;
                self.prev_rotation.x = self.rotation.x;
            }
        }
        self.model.transform = self.model.transform.multiply(rotation_matrix);
    }

    pub fn getBottomSideID(self: Cube) u8 {
        return self.side_indices[1]; // Index 1 ist immer die Unterseite
    }

    pub fn init() !Cube {
        var cube = Cube{};
        cube.model = try rl.loadModel(PlayerModelPath);

        const img = try rl.loadImage(PlayerTexturePath);
        defer rl.unloadImage(img);

        cube.texture_atlas = try rl.loadTextureFromImage(img);
        cube.model.materials[0].maps[@intFromEnum(rl.MaterialMapIndex.albedo)].texture = cube.texture_atlas;
        return cube;
    }

    pub fn deinit(c: Cube) !void {
        rl.unloadTexture(c.texture_atlas);
        rl.unloadModel(c.model);
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Cubescape");
    defer rl.closeWindow();

    var state = State{};
    var player: Cube = try .init();
    defer player.deinit() catch |err| @panic(err);

    state.player = &player;

    // Kamera-Setup
    const pitch_deg: f32 = 50.0;
    const yaw_deg: f32 = 60.0;
    const distance: f32 = 12.0;

    const pitch_rad = std.math.degreesToRadians(pitch_deg);
    const yaw_rad = std.math.degreesToRadians(yaw_deg);

    var camera = rl.Camera3D{
        .position = .{ .x = 0, .y = 0, .z = 0 },
        .target = .{ .x = 0, .y = 0, .z = 0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 35.0,
        .projection = .perspective,
    };

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Hotkeys
        get_input(&state);
        player.iterate();

        // Kamera-Berechnung
        camera.target = .{ .x = player.grid_pos.x, .y = 0, .z = player.grid_pos.y };
        camera.position = .{
            .x = player.grid_pos.x + (distance * @cos(pitch_rad) * @sin(yaw_rad)),
            .y = distance * @sin(pitch_rad),
            .z = player.grid_pos.y + (distance * @cos(pitch_rad) * @cos(yaw_rad)),
        };

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);

        {
            camera.begin();
            defer camera.end();
            rl.drawGrid(20, 1.0);

            const pos = rl.Vector3{ .x = player.grid_pos.x, .y = 1, .z = player.grid_pos.y };
            rl.drawModel(player.model, pos, 0.5, .white);
        }

        // GUI Text+
        rl.drawText(rl.textFormat("Aktuelle Unterseite (ID): %d", .{player.getBottomSideID()}), 10, 40, 20, .red);
        rl.drawText(rl.textFormat("Position: %.2f/%.2f", .{ player.grid_pos.x, player.grid_pos.y }), 10, 70, 20, .light_gray);
    }
}

fn get_input(s: *State) void {
    if (rl.isKeyPressed(.up)) s.player.roll(.north);
    if (rl.isKeyPressed(.down)) s.player.roll(.south);
    if (rl.isKeyPressed(.right)) s.player.roll(.east);
    if (rl.isKeyPressed(.left)) s.player.roll(.west);
}

fn gen_cube_mesh() void {}

test "cube_roll_test" {
    var cube = Cube{};
    const start_bottom = cube.getBottomSideID();
    // 4x in dieselbe Richtung rollen --> wieder bei der ursprünglichen Seite landen
    cube.roll(.north);
    cube.roll(.north);
    cube.roll(.north);
    cube.roll(.north);
    try std.testing.expectEqual(start_bottom, cube.getBottomSideID());
}
