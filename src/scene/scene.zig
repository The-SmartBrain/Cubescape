const std = @import("std");
const SceneContext = @import("context.zig").SceneContext;
const SceneId = @import("id.zig").SceneId;

pub const SceneError = error{
    OutOfMemory,
};

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    id: SceneId,
    is_active: bool,

    const VTable = struct {
        onStartup: *const fn (ptr: *anyopaque, context: *SceneContext) anyerror!void,
        onUpdate: *const fn (ptr: *anyopaque, context: *SceneContext, delta_time: f32) anyerror!void,
        onCleanup: *const fn (ptr: *anyopaque, context: *SceneContext) anyerror!void,
    };

    pub fn init(
        comptime T: type,
        scene_id: SceneId,
        allocator: std.mem.Allocator,
        is_active: bool,
    ) SceneError!Scene {
        comptime validateScene(T);

        const gen = struct {
            fn onStartup(ptr: *anyopaque, context: *SceneContext) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onStartup(self, context);
            }

            fn onUpdate(ptr: *anyopaque, context: *SceneContext, delta_time: f32) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onUpdate(self, context, delta_time);
            }

            fn onCleanup(ptr: *anyopaque, context: *SceneContext) !void {
                const self: *T = @ptrCast(@alignCast(ptr));
                try T.onCleanup(self, context);
            }
        };

        const instance = allocator.create(T) catch |err| {
            std.log.err("Failed to allocate scene instance: {}", .{err});
            return SceneError.OutOfMemory;
        };

        return .{
            .ptr = instance,
            .id = scene_id,
            .vtable = &.{
                .onStartup = gen.onStartup,
                .onUpdate = gen.onUpdate,
                .onCleanup = gen.onCleanup,
            },
            .is_active = is_active,
        };
    }

    pub fn onStartup(self: *Scene, context: *SceneContext) !void {
        try self.vtable.onStartup(self.ptr, context);
    }

    pub fn onUpdate(self: *Scene, context: *SceneContext, delta_time: f32) !void {
        try self.vtable.onUpdate(self.ptr, context, delta_time);
    }

    pub fn onCleanup(self: *Scene, context: *SceneContext) !void {
        try self.vtable.onCleanup(self.ptr, context);
    }
};

fn validateScene(comptime T: type) void {
    const required_fns = .{
        .{ "onStartup", fn (*T, *SceneContext) anyerror!void },
        .{ "onUpdate", fn (*T, *SceneContext, f32) anyerror!void },
        .{ "onCleanup", fn (*T, *SceneContext) anyerror!void },
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
