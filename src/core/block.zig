const std = @import("std");
const model_suffix = ".obj";
const ModelPath = "assets/models/";

pub const Block = struct {
    id: BlockID,
    pub const Blender_Unit_2_Raylib_Unit = 0.50;
    pub const BlockID = enum {
        empty,
        simple,
        green,
        blue,
        red,
        spawn_point,
        pub fn get_path(self: BlockID, allocator: std.mem.Allocator) ![]u8 {
            const name = @tagName(self);
            const full_path = try std.mem.concat(allocator, u8, &[_][]const u8{ ModelPath, name, model_suffix });
            return full_path;
        }
    };

    pub const enum_fields = [_]BlockID{
        .empty,
        .simple,
        .green,
        .blue,
        .red,
        .spawn_point,
    };
};
