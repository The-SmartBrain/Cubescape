const rl = @import("raylib");
const std = @import("std");
const json = std.json;
const Path = "assets/";
const json_suffix = ".json";
pub const BindDict = std.AutoHashMap(KeyName, Bind);

const MaxBytesRead: usize = std.math.maxInt(usize);
pub const BindList = struct {
    binds: BindDict,
    allocator: std.mem.Allocator,

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        try jws.beginObject();
        var it = self.binds.iterator();
        while (it.next()) |kv| {
            try jws.objectField(@tagName(kv.key_ptr.*));
            try jws.write(kv.value_ptr.*);
        }
        try jws.endObject();
    }
    pub fn deinit(self: *BindList) void {
        self.binds.deinit();
    }

    pub fn set_bind(self: *BindList, key: KeyName, bind: Bind) !void {
        try self.binds.put(key, bind);
    }

    pub fn init(allocator: std.mem.Allocator) BindList {
        const binds = BindDict.init(allocator);
        return BindList{
            .binds = binds,
            .allocator = allocator,
        };
    }

    pub fn export_json(self: BindList, name: []const u8) !void {
        std.debug.print("Exporting Keybinds name:{s}\n", .{name});
        var writer = std.Io.Writer.Allocating.init(self.allocator);
        defer writer.deinit();

        var stringify = std.json.Stringify{ .options = .{}, .writer = &writer.writer };
        try stringify.write(self);

        const json_data = try writer.toOwnedSlice();
        defer self.allocator.free(json_data);

        const full_path = try std.mem.concat(self.allocator, u8, &[_][]const u8{ Path, name, json_suffix });
        defer self.allocator.free(full_path);

        const file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
        defer file.close();
        var w = file.writer(&[_]u8{});
        const file_writer = &w.interface;
        try file_writer.writeAll(json_data);
        try file_writer.flush();
    }

    pub fn import_init(name: []const u8, allocator: std.mem.Allocator) !BindList {
        std.debug.print("Importing :{s}\n", .{name});
        const full_path = try std.mem.concat(
            allocator,
            u8,
            &[_][]const u8{ Path, name, json_suffix },
        );
        defer allocator.free(full_path);

        const json_data = try std.fs.cwd().readFileAlloc(allocator, full_path, MaxBytesRead);
        defer allocator.free(json_data);

        var list = BindList.init(allocator);
        errdefer list.deinit();

        const parsed = try std.json.parseFromSlice(
            std.json.Value,
            allocator,
            json_data,
            .{},
        );
        defer parsed.deinit();

        const root: std.StringArrayHashMap(json.Value) = parsed.value.object;
        var it = root.iterator();
        while (it.next()) |kv| {
            const keyname = std.meta.stringToEnum(KeyName, kv.key_ptr.*) orelse {
                std.debug.print("unknown key name:{s}\n", .{kv.key_ptr.*});
                continue;
            };
            const bind_parsed = try json.parseFromValue(Bind, allocator, kv.value_ptr.*, .{});
            defer bind_parsed.deinit();
            const bind = bind_parsed.value;

            try list.set_bind(keyname, bind);
        }

        return list;
    }

    pub fn check(self: BindList, key: KeyName, detection: DetectionType) bool {
        const bind = self.binds.get(key) orelse return false;
        return bind.check(detection);
    }
};

pub const KeyName = enum {
    roll_north,
    roll_south,
    roll_east,
    roll_west,
    go_up,
    go_down,
    to_menu,
    break_block,
    place_block,
    toolbar_zero,
    toolbar_one,
    toolbar_two,
    toolbar_three,
    toolbar_four,
    toolbar_five,
    mod_fpv,
};

pub const Bind = union(enum) {
    keybind: Keybind,
    mousebind: MouseBind,

    //   pub fn jsonStringify(self: @This(), jws: anytype) !void {
    //       try jws.beginObject();
    //       switch (self) {
    //           .keybind => |b| {
    //               try jws.objectField("keybind");
    //               try jws.write(b);
    //           },
    //           .mousebind => |b| {
    //               try jws.objectField("mousebind");
    //               try jws.write(b);
    //           },
    //       }
    //       try jws.endObject();
    //   }

    pub fn check(self: Bind, detection: DetectionType) bool {
        switch (self) {
            .keybind => |bind| {
                switch (detection) {
                    .isPressed => return rl.isKeyPressed(bind.key),
                    .isDown => return rl.isKeyDown(bind.key),
                    .isUp => return rl.isKeyUp(bind.key),
                    .isReleased => return rl.isKeyReleased(bind.key),
                }
            },
            .mousebind => |bind| {
                switch (detection) {
                    .isPressed => return rl.isMouseButtonPressed(bind.key),
                    .isDown => return rl.isMouseButtonDown(bind.key),
                    .isUp => return rl.isMouseButtonUp(bind.key),
                    .isReleased => return rl.isMouseButtonReleased(bind.key),
                }
            },
        }
    }
};

pub const Keybind = struct {
    key: rl.KeyboardKey,
    //    pub fn jsonStringify(self: @This(), jws: anytype) !void {
    //        try jws.beginObject();
    //        try jws.objectField("key");
    //        try jws.write(@intFromEnum(self.key)); // store as int
    //        try jws.endObject();
    //    }
};
pub const MouseBind = struct {
    key: rl.MouseButton,
    //    pub fn jsonStringify(self: @This(), jws: anytype) !void {
    //        try jws.beginObject();
    //        try jws.objectField("key");
    //        try jws.write(@intFromEnum(self.key)); // store as int
    //        try jws.endObject();
    //    }
};
pub const DetectionType = enum { isPressed, isDown, isReleased, isUp };
