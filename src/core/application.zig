const std = @import("std");

const SceneId = @import("../scene/id.zig").SceneId;
const SceneManager = @import("../scene/manager.zig").SceneManager;

const Time = @import("time.zig").Time;
const win = @import("window.zig");
const rl = @import("raylib");

const WindowParams = win.WindowParams;
const Window = win.Window;
const virtual_width: i32 = 1920;
const virtual_height: i32 = 1080;

pub const ApplicationError = error{
    WindowError,
};

pub const Application = struct {
    scene_manager: *SceneManager,
    window: *Window,
    allocator: std.mem.Allocator,
    time: Time,
    render_texture: rl.RenderTexture2D,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !*Application {
        const window = Window.init(allocator, params) catch |err| {
            std.log.err("Failed to initialize window: {}", .{err});
            return ApplicationError.WindowError;
        };

        const app = try allocator.create(Application);
        app.* = Application{
            .scene_manager = try .init(allocator, window),
            .allocator = allocator,
            .window = window,
            .time = .init(),
            .render_texture = try rl.loadRenderTexture(virtual_width, virtual_height),
        };

        return app;
    }

    pub fn run(app: *Application) void {
        app.scene_manager.initScene() catch |err| {
            std.log.err("Error initializing scene: {}", .{err});
            return;
        };

        while (!app.window.shouldClose()) {
            app.window.syncSize();
            const current_time = app.window.getTime();
            app.time.update(@floatCast(current_time));

            app.beginVirtualFrame();
            std.debug.print("active_scene:{s}\n", .{@tagName(app.scene_manager.getActiveScene().id)});
            app.scene_manager.updateScene(app.time.delta_time) catch |err| {
                app.endVirtualFrame();
                std.log.err("Error updating Scene: {}", .{err});
                continue;
            };
            app.endVirtualFrame();
            app.presentVirtualFrame();
        }
    }

    pub fn deinit(self: *Application) !void {
        self.scene_manager.deinit();
        rl.unloadRenderTexture(self.render_texture);
        self.window.deinit();
        self.allocator.destroy(self);
    }

    pub fn pushScene(self: *Application, comptime scene: type, scene_id: SceneId, is_active: bool) void {
        self.scene_manager.addScene(scene, scene_id, is_active) catch |err| {
            std.log.err("Failed to push Scene: {}", .{err});
            return;
        };
    }

    fn beginVirtualFrame(self: *Application) void {
        rl.beginTextureMode(self.render_texture);
        rl.clearBackground(.black);
    }

    fn endVirtualFrame(self: *Application) void {
        _ = self;
        rl.endTextureMode();
    }

    fn presentVirtualFrame(self: *Application) void {
        const window_width: f32 = @floatFromInt(self.window.getWidth());
        const window_height: f32 = @floatFromInt(self.window.getHeight());
        const virtual_width_f: f32 = @floatFromInt(virtual_width);
        const virtual_height_f: f32 = @floatFromInt(virtual_height);
        const scale = @min(window_width / virtual_width_f, window_height / virtual_height_f);
        const scaled_width = virtual_width_f * scale;
        const scaled_height = virtual_height_f * scale;
        const offset_x = (window_width - scaled_width) / 2.0;
        const offset_y = (window_height - scaled_height) / 2.0;

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        rl.drawTexturePro(
            self.render_texture.texture,
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.render_texture.texture.width),
                .height = -@as(f32, @floatFromInt(self.render_texture.texture.height)),
            },
            .{
                .x = offset_x,
                .y = offset_y,
                .width = scaled_width,
                .height = scaled_height,
            },
            .{ .x = 0, .y = 0 },
            0,
            .white,
        );
    }
};
