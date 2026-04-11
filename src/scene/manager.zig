const std = @import("std");
const SceneContext = @import("context.zig").SceneContext;
const SceneId = @import("id.zig").SceneId;
const Scene = @import("scene.zig").Scene;

pub const SceneManagerError = error{
    OutOfMemory,
    SceneNotFound,
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
        var context = self.makeContext();

        for (self.scenes.items) |*scene| {
            scene.deinit(self.allocator, &context);
        }

        self.scenes.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub inline fn getActiveScene(self: *const SceneManager) *Scene {
        return &self.scenes.items[self.active_scene_index];
    }

    fn makeContext(self: *SceneManager) SceneContext {
        return .{
            .allocator = self.allocator,
            .ptr = self,
            .switch_scene_fn = switchSceneFromContext,
        };
    }

    fn switchSceneFromContext(ptr: *anyopaque, scene_id: SceneId) !void {
        const self: *SceneManager = @ptrCast(@alignCast(ptr));
        try self.switchTo(scene_id);
    }

    pub fn addScene(self: *SceneManager, comptime scene: type, scene_id: SceneId, is_active: bool) SceneManagerError!void {
        const s = Scene.init(scene, scene_id, self.allocator, is_active) catch {
            return SceneManagerError.OutOfMemory;
        };

        self.scenes.append(self.allocator, s) catch {
            var scene_to_destroy = s;
            scene_to_destroy.destroy(self.allocator);
            return SceneManagerError.OutOfMemory;
        };

        if (s.is_active) {
            self.active_scene_index = self.scenes.items.len - 1;
        }
    }

    pub fn updateScene(self: *SceneManager, delta_time: f32) !void {
        var context = self.makeContext();
        const active_scene = self.getActiveScene();
        try active_scene.onUpdate(&context, delta_time);
    }

    pub fn initScene(self: *SceneManager) !void {
        var context = self.makeContext();
        const active_scene = self.getActiveScene();
        try active_scene.onStartup(&context);
    }

    pub fn deinitScene(self: *SceneManager) void {
        var context = self.makeContext();
        const active_scene = self.getActiveScene();
        active_scene.onCleanup(&context) catch |err| std.log.err("Scene Cleanup failed: {}", .{err});
    }

    pub fn switchTo(self: *SceneManager, scene_id: SceneId) !void {
        if (self.scenes.items.len == 0) {
            return SceneManagerError.SceneNotFound;
        }

        const current_index = self.active_scene_index;
        const next_index = self.findSceneIndex(scene_id) orelse return SceneManagerError.SceneNotFound;

        if (current_index == next_index) {
            return;
        }

        var context = self.makeContext();
        self.scenes.items[current_index].onCleanup(&context) catch |err| {
            std.log.err("Scene Cleanup failed before switch: {}", .{err});
            return err;
        };

        self.scenes.items[current_index].is_active = false;
        self.active_scene_index = next_index;
        self.scenes.items[next_index].is_active = true;

        try self.scenes.items[next_index].onStartup(&context);
    }

    fn findSceneIndex(self: *const SceneManager, scene_id: SceneId) ?usize {
        for (self.scenes.items, 0..) |scene, index| {
            if (scene.id == scene_id) {
                return index;
            }
        }

        return null;
    }
};
