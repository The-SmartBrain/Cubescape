const std = @import("std");

pub const SceneError = error{
    OutOfMemory,
};

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    is_active: bool,

    const VTable = struct {
        onStartup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!void,
        onUpdate: *const fn (ptr: *anyopaque, delta_time: f32) anyerror!void,
        onCleanup: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!void,
    };

    pub fn init(
        comptime T: type,
        allocator: std.mem.Allocator,
        is_active: bool,
    ) SceneError!Scene {
        comptime validateScene(T);

        const gen = struct {
            fn onStartup(ptr: *anyopaque, alloc: std.mem.Allocator) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onStartup(self, alloc);
            }

            fn onUpdate(ptr: *anyopaque, delta_time: f32) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onUpdate(self, delta_time);
            }

            fn onCleanup(ptr: *anyopaque, alloc: std.mem.Allocator) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onCleanup(self, alloc);
            }
        };

        const instance = allocator.create(T) catch |err| {
            std.log.err("Failed to allocate scene instance: {}", .{err});
            return SceneError.OutOfMemory;
        };

        return .{
            .ptr = instance,
            .vtable = &.{
                .onStartup = gen.onStartup,
                .onUpdate = gen.onUpdate,
                .onCleanup = gen.onCleanup,
            },
            .is_active = is_active,
        };
    }

    pub fn onStartup(self: *Scene, allocator: std.mem.Allocator) !void {
        try self.vtable.onStartup(self.ptr, allocator);
    }

    pub fn onUpdate(self: *Scene, delta_time: f32) !void {
        try self.vtable.onUpdate(self.ptr, delta_time);
    }

    pub fn onCleanup(self: *Scene, allocator: std.mem.Allocator) !void {
        try self.vtable.onCleanup(self.ptr, allocator);
    }
};

fn validateScene(comptime T: type) void {
    const required_fns = .{
        .{ "onStartup", fn (*T, std.mem.Allocator) anyerror!void },
        .{ "onUpdate", fn (*T, f32) anyerror!void },
        .{ "onCleanup", fn (*T, std.mem.Allocator) anyerror!void },
    };

    inline for (required_fns) |req| {
        const name = req[0];
        const Sig = req[1];

        if (!@hasDecl(T, name)) {
            @compileError("Scene implementation missing " ++ name);
        }

        const actual = @TypeOf(@field(T, name));
        if (actual != Sig) {
            @compileError("Scene." ++ name ++ " has wrong signature. Expected: " ++ @typeName(Sig) ++ ", got: " ++ @typeName(actual));
        }
    }
}
