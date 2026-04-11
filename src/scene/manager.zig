const std = @import("std");
const Scene = @import("scene.zig").Scene;

pub const SceneManagerError = error{
    OutOfMemory,
};

pub const SceneManager = struct {
    scenes: std.ArrayList(Scene),
    allocator: std.mem.Allocator,
    active_scene_index: usize,

    pub fn init(allocator: std.mem.Allocator) SceneManagerError!*SceneManager {
        const manager = allocator.create(SceneManager) catch |err| {
            std.log.err("Failed to allocate SceneManager: {}", .{err});
            return SceneManagerError.OutOfMemory;
        };

        manager.* = SceneManager{
            .allocator = allocator,
            .scenes = .empty,
            .active_scene_index = 0,
        };

        return manager;
    }

    pub fn deinit(self: *SceneManager) void {
        const active_scene = self.getActiveScene();
        active_scene.onCleanup(self.allocator) catch |err| std.log.err("Scene Cleanup failed: {}", .{err});
        self.scenes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub inline fn getActiveScene(self: *const SceneManager) *Scene {
        return &self.scenes.items[self.active_scene_index];
    }

    pub fn addScene(self: *SceneManager, comptime scene: type, is_active: bool) SceneManagerError!void {
        const s = Scene.init(scene, self.allocator, is_active) catch {
            return SceneManagerError.OutOfMemory;
        };

        self.scenes.append(self.allocator, s) catch {
            return SceneManagerError.OutOfMemory;
        };

        if (s.is_active) {
            self.active_scene_index = self.scenes.items.len - 1;
        }
    }

    pub fn updateScene(self: *SceneManager, delta_time: f32) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onUpdate(delta_time);
    }

    pub fn initScene(self: *SceneManager) !void {
        const active_scene = self.getActiveScene();
        try active_scene.onStartup(self.allocator);
    }

    pub fn deinitScene(self: *SceneManager) void {
        const actice_scene = self.getActiveScene();
        try actice_scene.onCleanup(self.allocator);
    }
};
