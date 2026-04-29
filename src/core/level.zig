const std = @import("std");
const rl = @import("raylib");
const Block = @import("block.zig").Block;
const Vec2 = @import("player.zig").Vec2;
const json = std.json;
const LevelPath = "assets/levels/";
const json_suffix = ".json";
const MaxBytesRead: usize = std.math.maxInt(usize);

const Blender_Unit_2_Raylib_Unit = Block.Blender_Unit_2_Raylib_Unit;
const BlockModels = std.AutoHashMap(Block.BlockID, rl.Model);

pub const Level = struct {
    width: u8,
    length: u8,
    id: LevelID,
    starting_point: Vec2,
    finish: Vec2,

    grid: ?[][]Block,
    models: ?BlockModels,
    pub fn idx_to_coord(self: Level, i: usize, j: usize) rl.Vector3 {
        const length: f32 = @floatFromInt(self.length);
        const width: f32 = @floatFromInt(self.width);
        const x: f32 = @as(f32, @floatFromInt(i)) - width / 2 + 1;
        const z: f32 = @as(f32, @floatFromInt(j)) - length / 2 + 1;
        return .{ .x = x, .y = -0.5, .z = z };
    }

    pub fn draw_grid(self: *Level) void {
        for (self.grid orelse return, 0..) |row, i| {
            for (row, 0..) |block, j| {
                if (block.id != .empty) {
                    const pos = self.idx_to_coord(i, j);
                    if (self.models == null) {
                        rl.drawCube(pos, 1, 1, 1, .red);
                    } else {
                        const model = self.models.?.get(block.id) orelse {
                            rl.drawCube(pos, 1, 1, 1, .red);
                            continue;
                        };
                        rl.drawModel(model, pos, Blender_Unit_2_Raylib_Unit, .white);
                    }
                }
            }
        }

        var spawn = self.idx_to_coord(self.starting_point.x, self.starting_point.y);
        spawn.y = 0;
        if (self.models != null) {
            const model = self.models.?.get(.spawn_point) orelse {
                rl.drawCube(spawn, 1, 0.1, 1, .red);
                return;
            };
            rl.drawModel(model, spawn, Blender_Unit_2_Raylib_Unit, .white);
        } else {
            rl.drawCube(spawn, 1, 0.1, 1, .red);
        }
    }

    pub fn init(id: LevelID, length: u8, width: u8, alloator: std.mem.Allocator) !Level {
        const lvl: Level = .{
            // zif fmt: off
            .finish = .zero(),
            .starting_point = .{ .x = 0, .y = 0 },
            .id = id,
            .width = width,
            .length = length,
            .grid = try init_grid(length, width, alloator),
            .models = BlockModels.init(alloator),
            // zif fmt: onn
        };
        return lvl;
    }

    pub fn init_grid(length: u8, width: u8, alloator: std.mem.Allocator) ![][]Block {
        const grid = try alloator.alloc([]Block, length);
        for (grid, 0..) |_, i| {
            const row = try alloator.alloc(Block, width);
            grid[i] = row;
            for (row) |*block| {
                block.id = .empty;
            }
        }
        return grid;
    }

    pub fn deinit(self: *Level, allocator: std.mem.Allocator) void {
        self.deinit_grid(allocator);
        self.deinit_models();
    }

    pub fn deinit_models(self: *Level) void {
        if (self.models == null) return;
        var iter = self.models.?.valueIterator();
        while (iter.next()) |val| {
            rl.unloadModel(val.*);
        }
        self.models.?.deinit();
    }

    pub fn deinit_grid(self: *Level, allocator: std.mem.Allocator) void {
        for (self.grid orelse return, 0..) |_, i| {
            allocator.free(self.grid.?[i]);
        }
        allocator.free(self.grid.?);
        self.grid = null;
    }

    pub fn draw_2D_grid(center: rl.Vector3, width: f32, length: f32, spacing: f32, arrows: bool) void {
        const halfW = width / 2;
        const halfL = length / 2;

        // Draw grid lines
        var x: f32 = -halfW;
        while (x <= halfW) : (x += spacing) {
            const worldX = center.x + x;
            if (worldX != 0) {
                rl.drawLine3D(
                    .{ .x = worldX, .y = center.y, .z = center.z - halfL },
                    .{ .x = worldX, .y = center.y, .z = center.z + halfL },
                    .gray,
                );
            }
        }

        var z: f32 = -halfL;
        while (z <= halfL) : (z += spacing) {
            const worldZ = center.z + z;
            if (worldZ != 0) {
                rl.drawLine3D(
                    .{ .x = center.x - halfW, .y = center.y, .z = worldZ },
                    .{ .x = center.x + halfW, .y = center.y, .z = worldZ },
                    .gray,
                );
            }
        }

        if (arrows) {
            const arrowHeadSize: f32 = spacing * 0.4;

            // X axis arrow (red, along +X)
            rl.drawLine3D(
                .{ .x = center.x - halfW, .y = center.y, .z = center.z },
                .{ .x = center.x + halfW, .y = center.y, .z = center.z },
                .red,
            );
            // Arrowhead for +X
            rl.drawLine3D(
                .{ .x = center.x + halfW, .y = center.y, .z = center.z },
                .{ .x = center.x + halfW - arrowHeadSize, .y = center.y, .z = center.z - arrowHeadSize },
                .red,
            );
            rl.drawLine3D(
                .{ .x = center.x + halfW, .y = center.y, .z = center.z },
                .{ .x = center.x + halfW - arrowHeadSize, .y = center.y, .z = center.z + arrowHeadSize },
                .red,
            );

            // Z axis arrow (blue, along +Z)
            rl.drawLine3D(
                .{ .x = center.x, .y = center.y, .z = center.z - halfL },
                .{ .x = center.x, .y = center.y, .z = center.z + halfL },
                .blue,
            );
            // Arrowhead for +Z
            rl.drawLine3D(
                .{ .x = center.x, .y = center.y, .z = center.z + halfL },
                .{ .x = center.x - arrowHeadSize, .y = center.y, .z = center.z + halfL - arrowHeadSize },
                .blue,
            );
            rl.drawLine3D(
                .{ .x = center.x, .y = center.y, .z = center.z + halfL },
                .{ .x = center.x + arrowHeadSize, .y = center.y, .z = center.z + halfL - arrowHeadSize },
                .blue,
            );
        }
    }

    pub fn import_models(self: *Level, allocator: std.mem.Allocator) !void {
        if (self.models == null) {
            self.models = .init(allocator);
        }

        for (Block.enum_fields) |tag| {
            if (tag == .empty) continue;
            const path: []u8 = try tag.get_path(allocator);
            defer allocator.free(path);
            const model = try rl.loadModel(@ptrCast(path));
            errdefer rl.unloadModel(model);
            try self.models.?.put(tag, model);
        }
    }

    pub fn export_level(self: Level, allocator: std.mem.Allocator) !void {
        std.debug.print("Exporting Level tag:{s}\n", .{@tagName(self.id)});
        var writer = std.Io.Writer.Allocating.init(allocator);
        defer writer.deinit();

        var stringify = std.json.Stringify{ .options = .{}, .writer = &writer.writer };
        stringify.write(self.toData()) catch |err| std.debug.print("error{any}\n", .{err});

        const json_data = try writer.toOwnedSlice();
        defer allocator.free(json_data);

        const lvl_name = @tagName(self.id); // return type : [:0] const u8;
        const full_path = try std.mem.concat(allocator, u8, &[_][]const u8{ LevelPath, lvl_name, json_suffix });
        defer allocator.free(full_path);

        const file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
        defer file.close();
        var w = file.writer(&[_]u8{});
        const file_writer = &w.interface;
        try file_writer.writeAll(json_data);
        try file_writer.flush();
    }

    pub fn import_level(id: LevelID, allocator: std.mem.Allocator) !Level {
        const lvl_name = @tagName(id); // return type : [:0] const u8;
        const full_path = try std.mem.concat(allocator, u8, &[_][]const u8{ LevelPath, lvl_name, json_suffix });
        defer allocator.free(full_path);
        const json_data = try std.fs.cwd().readFileAlloc(allocator, full_path, MaxBytesRead);
        defer allocator.free(json_data);
        const parsed = try std.json.parseFromSlice(LevelData, allocator, json_data, .{});
        defer parsed.deinit();
        const lvlData: LevelData = parsed.value;
        var lvl = Level.fromData(lvlData);

        {
            const grid = try allocator.alloc([]Block, lvl.grid.?.len);
            errdefer lvl.deinit_grid(allocator);

            for (lvl.grid.?, 0..) |old_row, i| {
                const row = try allocator.alloc(Block, old_row.len);
                grid[i] = row;
                for (old_row, 0..) |block, j| {
                    row[j] = block;
                }
            }
            lvl.grid = grid;
        }

        try lvl.import_models(allocator);
        return lvl;
    }
    pub const LevelID = enum { one, zero };
    const LevelData = struct {
        width: u8,
        length: u8,
        id: LevelID,
        starting_point: Vec2,
        finish: Vec2,
        grid: [][]Block,
    };

    fn toData(level: Level) LevelData {
        return .{
            .width = level.width,
            .length = level.length,
            .id = level.id,
            .starting_point = level.starting_point,
            .finish = level.finish,
            .grid = level.grid.?,
        };
    }
    pub fn fromData(data: LevelData) Level {
        const level = Level{
            .width = data.width,
            .length = data.length,
            .id = data.id,
            .starting_point = data.starting_point,
            .finish = data.finish,
            .grid = data.grid,
            .models = null,
        };
        return level;
    }
};
