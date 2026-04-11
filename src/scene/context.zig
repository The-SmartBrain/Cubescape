const std = @import("std");
const SceneId = @import("id.zig").SceneId;
const Window = @import("../core/window.zig").Window;

pub const SceneContext = struct {
    allocator: std.mem.Allocator,
    window: *Window,
    ptr: *anyopaque,
    switch_scene_fn: *const fn (ptr: *anyopaque, scene_id: SceneId) anyerror!void,

    pub fn switchTo(self: *const SceneContext, scene_id: SceneId) !void {
        try self.switch_scene_fn(self.ptr, scene_id);
    }

    pub fn getWindowWidth(self: *const SceneContext) u32 {
        return self.window.getWidth();
    }

    pub fn getWindowHeight(self: *const SceneContext) u32 {
        return self.window.getHeight();
    }
};
