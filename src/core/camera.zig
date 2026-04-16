const rl = @import("raylib");
const std = @import("std");
const pitch_deg: f32 = 50.0;
const yaw_deg: f32 = 60.0;

pub const Camera = struct {
    pub const Default_Distance: f32 = 12.0;
    pub const Default_Pitch = std.math.degreesToRadians(pitch_deg);
    pub const Default_Yaw = std.math.degreesToRadians(yaw_deg);
    pub const Default_Roll = std.math.degreesToRadians(0);
    camera: rl.Camera,
    distance: f32 = 0,
    pitch_rad: f32 = 0,
    yaw_rad: f32 = 0,
    roll_rad: f32 = 0,

    // Position der Kamera anhand der Position des Spielers berechnen
    follow_fn: ?*const fn (*Camera, rl.Vector3) rl.Vector3,

    pub fn update(self: *Camera, target_pos: rl.Vector3) void {
        self.camera.target = .{ .x = target_pos.x, .y = 1, .z = target_pos.z };
        if (self.follow_fn != null) {
            self.camera.position = self.follow_fn.?(self, target_pos);
        }
    }

    pub fn init(distance: f32, fovy: f32, pos: rl.Vector3) Camera {
        return Camera{ .camera = rl.Camera3D{
            .position = pos,
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = fovy,
            .projection = .perspective,
        }, .distance = distance, .pitch_rad = Default_Pitch, .yaw_rad = Default_Yaw, .roll_rad = Default_Roll, .follow_fn = null };
    }
    pub fn simple_follow(self: *Camera, target_pos: rl.Vector3) rl.Vector3 {
        return .{
            .x = target_pos.x + (self.distance * @cos(self.pitch_rad) * @sin(self.yaw_rad)),
            .y = self.distance * @sin(self.pitch_rad),
            .z = target_pos.z + (self.distance * @cos(self.pitch_rad) * @cos(self.yaw_rad)),
        };
    }
    pub fn top_down(self: *Camera, target_pos: rl.Vector3) rl.Vector3 {
        _ = self;
        return .{
            .x = target_pos.x + 0.1,
            .y = 30,
            .z = target_pos.z + 0.1,
        };
    }

    pub fn begin(self: *Camera) void {
        self.camera.begin();
    }
    pub fn end(self: *Camera) void {
        self.camera.end();
    }
};
