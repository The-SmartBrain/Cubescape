pub const Player = struct {
    transform: Transform,
};

pub const Transform = struct {
    x: f32,
    y: f32,
    z: f32,
    rotation_x: f32,
    rotation_y: f32,
    rotation_z: f32,
    pub fn zeros() Transform {
        return .{ .x = 0, .y = 0, .z = 0, .rotation_x = 0, .rotation_y = 0, .rotation_z = 0 };
    }
};
