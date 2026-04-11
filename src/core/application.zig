const std = @import("std");

const SceneManager = @import("../scene/manager.zig").SceneManager;
const Scene = @import("../scene/scene.zig").Scene;

const Time = @import("time.zig").Time;
const win = @import("window.zig");

const WindowParams = win.WindowParams;
const Window = win.Window;

pub const ApplicationError = error{
    WindowError,
};

pub const Application = struct {
    scene_manager: *SceneManager,
    window: *Window,
    allocator: std.mem.Allocator,
    time: Time,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .scene_manager = try .init(allocator),
            .allocator = allocator,
            .window = window,
            .time = .init(),
        };

        return app;
    }

    pub fn run(app: *Application) void {
        app.scene_manager.initScene() catch |err| {
            std.log.err("Error initializing scene: {}", .{err});
            return;
        };

        while (!app.window.shouldClose()) {
            const current_time = app.window.getTime();
            app.time.update(@floatCast(current_time));

            app.scene_manager.updateScene(app.time.delta_time) catch |err| {
                std.log.err("Error updating Scene: {}", .{err});
                continue;
            };
        }
    }

    pub fn deinit(self: *Application) !void {
        self.scene_manager.deinit();
        self.window.deinit();
        self.allocator.destroy(self);
    }

    pub fn pushScene(self: *Application, comptime scene: type, is_active: bool) void {
        self.scene_manager.addScene(scene, is_active) catch |err| {
            std.log.err("Failed to push Scene: {}", .{err});
            return;
        };
    }
};
