const std = @import("std");
const rl = @import("raylib");
const Block = @import("block.zig").Block;
const Vec2 = @import("player.zig").Vec2;
const json = std.json;
const Path = "assets/levels/";
const json_suffix = ".json";
const MaxBytesRead: usize = std.math.maxInt(usize);

pub const Level = struct {
    width: u8,
    length: u8,
    id: LevelID,
    grid_initted: bool,
    starting_point: Vec2,
    finish: Vec2,

    grid: [][]Block,
    pub fn idx_to_coord(self: Level, i: usize, j: usize) rl.Vector3 {
        const length: f32 = @floatFromInt(self.length);
        const width: f32 = @floatFromInt(self.width);
        const x: f32 = @as(f32, @floatFromInt(i)) - width / 2 + 1;
        const z: f32 = @as(f32, @floatFromInt(j)) - length / 2 + 1;
        return .{ .x = x, .y = -0.5, .z = z };
    }

    pub fn draw_grid(self: *Level) void {
        if (!self.grid_initted) return;
        for (self.grid, 0..) |row, i| {
            for (row, 0..) |block, j| {
                if (block.id != .empty) {
                    var color: rl.Color = .dark_gray;
                    if (block.id == .green) color = .green;
                    if (block.id == .blue) color = .blue;
                    if (block.id == .red) color = .red;

                    rl.drawCube(self.idx_to_coord(i, j), 1, 1, 1, color);
                }
            }
        }

        var spawn = self.idx_to_coord(self.starting_point.x, self.starting_point.y);
        spawn.y = 0;
        rl.drawCube(spawn, 0.5, 0.1, 0.5, .gold);
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
            .grid_initted = true,
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

    pub fn deinit_grid(self: *Level, allocator: std.mem.Allocator) void {
        if (!self.grid_initted) return;
        for (self.grid, 0..) |_, i| {
            allocator.free(self.grid[i]);
        }
        allocator.free(self.grid);
        self.grid_initted = false;
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

    pub const LevelID = enum { one, zero };

    pub fn export_level(self: Level, allocator: std.mem.Allocator) !void {
        std.debug.print("Exporting Level tag:{s}\n", .{@tagName(self.id)});
        var writer = std.Io.Writer.Allocating.init(allocator);
        defer writer.deinit();

        var stringify = std.json.Stringify{ .options = .{}, .writer = &writer.writer };
        stringify.write(self) catch |err| std.debug.print("error{any}\n", .{err});

        const json_data = try writer.toOwnedSlice();
        defer allocator.free(json_data);

        const lvl_name = @tagName(self.id); // return type : [:0] const u8;
        const full_path = try std.mem.concat(allocator, u8, &[_][]const u8{ Path, lvl_name, json_suffix });
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
        const full_path = try std.mem.concat(allocator, u8, &[_][]const u8{ Path, lvl_name, json_suffix });
        defer allocator.free(full_path);
        const json_data = try std.fs.cwd().readFileAlloc(allocator, full_path, MaxBytesRead);
        defer allocator.free(json_data);
        const parsed = try std.json.parseFromSlice(Level, allocator, json_data, .{});
        defer parsed.deinit();
        var lvl: Level = parsed.value;

        const grid = try allocator.alloc([]Block, lvl.grid.len);
        errdefer lvl.deinit_grid(allocator);

        for (lvl.grid, 0..) |old_row, i| {
            const row = try allocator.alloc(Block, old_row.len);
            grid[i] = row;
            for (old_row, 0..) |block, j| {
                row[j] = block;
            }
        }
        lvl.grid = grid;
        lvl.grid_initted = true;
        return lvl;
    }
};
