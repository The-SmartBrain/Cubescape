const std = @import("std");
const rl = @import("raylib");

const Side = struct {
    id: u8,
    // Hier später enum effect?
};

const Cube = struct {
    // Indizes für: 0=oben, 1=unten, 2=vorne, 3=hinten, 4=links, 5=rechts
    side_indices: [6]u8 = .{ 0, 1, 2, 3, 4, 5 },
    grid_pos: struct { x: f32, y: f32 } = .{ .x = 0, .y = 0 },

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
            .north => self.grid_pos.y -= 1,
            .south => self.grid_pos.y += 1,
            .east => self.grid_pos.x += 1,
            .west => self.grid_pos.x -= 1,
        }
    }

    pub fn getBottomSideID(self: Cube) u8 {
        return self.side_indices[1]; // Index 1 ist immer die Unterseite
    }
};

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Cubescape");
    defer rl.closeWindow();

    var player = Cube{};

    // Kamera-Setup
    const pitch_deg: f32 = 50.0;
    const yaw_deg: f32 = 60.0;
    const distance: f32 = 12.0;

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
        if (rl.isKeyPressed(.up)) player.roll(.north);
        if (rl.isKeyPressed(.down)) player.roll(.south);
        if (rl.isKeyPressed(.right)) player.roll(.east);
        if (rl.isKeyPressed(.left)) player.roll(.west);

        // Kamera-Berechnung
        const pitch_rad = std.math.degreesToRadians(pitch_deg);
        const yaw_rad = std.math.degreesToRadians(yaw_deg);
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

            const pos = rl.Vector3{ .x = player.grid_pos.x, .y = 0.5, .z = player.grid_pos.y };
            rl.drawCube(pos, 1.0, 1.0, 1.0, .blue);
            rl.drawCubeWires(pos, 1.0, 1.0, 1.0, .dark_blue);
        }

        // GUI Text+
        rl.drawText(rl.textFormat("Aktuelle Unterseite (ID): %d", .{player.getBottomSideID()}), 10, 40, 20, .red);
        rl.drawText(rl.textFormat("Position: %.0f/%.0f", .{ player.grid_pos.x, player.grid_pos.y }), 10, 70, 20, .light_gray);
    }
}

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
