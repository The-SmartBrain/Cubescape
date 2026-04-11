const std = @import("std");

const rl = @import("raylib");

pub const WindowParams = struct {
    width: ?u32 = null,
    height: ?u32 = null,
    title: [:0]const u8,
};

fn getDefaultWidth() u32 {
    return @intCast(@divTrunc(rl.getMonitorWidth(0), 2));
}

fn getDefaultHeight() u32 {
    return @intCast(@divTrunc(rl.getMonitorHeight(0), 2));
}

pub const Window = struct {
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, params: WindowParams) !*Window {
        const width = params.width orelse getDefaultWidth();
        const height = params.height orelse getDefaultHeight();

        rl.setConfigFlags(.{
            .vsync_hint = true,
            // More Optins here
        });

        rl.initWindow(@intCast(width), @intCast(height), params.title);

        if (!rl.isWindowReady()) {
            return error.InitFailed;
        }

        rl.setTargetFPS(60);

        const self = try allocator.create(Window);
        self.* = Window{
            .width = width,
            .height = height,
            .allocator = allocator,
        };
        return self;
    }

    pub fn beginFrame(self: *Window) void {
        _ = self;
        rl.beginDrawing();
    }

    pub fn endFrame(self: *Window) void {
        _ = self;
        rl.endDrawing();
    }

    pub fn shouldClose(self: *Window) bool {
        _ = self;
        return rl.windowShouldClose();
    }

    pub fn getTime(self: *Window) f64 {
        _ = self;
        return rl.getTime();
    }

    pub fn getSize(self: *Window) void {
        self.width = @intCast(rl.getScreenWidth());
        self.height = @intCast(rl.getScreenHeight());
    }

    pub fn deinit(self: *Window) void {
        rl.closeWindow();
        const alloc = self.allocator;
        alloc.destroy(self);
    }
};
