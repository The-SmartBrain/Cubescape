const std = @import("std");
const SceneId = @import("id.zig").SceneId;

pub const SceneContext = struct {
    allocator: std.mem.Allocator,
    ptr: *anyopaque,
    switch_scene_fn: *const fn (ptr: *anyopaque, scene_id: SceneId) anyerror!void,

    pub fn switchTo(self: *const SceneContext, scene_id: SceneId) !void {
        try self.switch_scene_fn(self.ptr, scene_id);
    }
};
