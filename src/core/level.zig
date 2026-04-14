const std = @import("std");
const rl = @import("raylib");
const Block = @import("block.zig").Block;

pub const Level = struct {
    width: u8,
    length: u8,
    id: LevelID,
    starting_point: rl.Vector2,
    finish: rl.Vector2,

    grid: [][]Block,
    pub fn draw_grid(self: *Level) void {
        const length: f32 = @floatFromInt(self.length);
        const width: f32 = @floatFromInt(self.width);
        for (self.grid, 0..) |row, i| {
            for (row, 0..) |block, j| {
                if (block.id != .empty) {
                    const x: f32 = @as(f32, @floatFromInt(i)) - width / 2 + 1;
                    const z: f32 = @as(f32, @floatFromInt(j)) - length / 2 + 1;
                    rl.drawCube(.{ .x = x, .z = z, .y = -0.5 }, 1, 1, 1, .dark_gray);
                }
            }
        }
    }

    pub fn init(id: LevelID, length: u8, width: u8, alloator: std.mem.Allocator) !Level {
        const lvl: Level = .{
            // zif fmt: off
            .finish = .zero(),
            .starting_point = .zero(),
            .id = id,
            .width = width,
            .length = length,
            .grid = try init_grid(length, width, alloator),
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

    pub fn deinit_grid(grid: [][]Block, allocator: std.mem.Allocator) void {
        for (grid, 0..) |_, i| {
            allocator.free(grid[i]);
        }
        allocator.free(grid);
    }

    pub fn draw_2D_grid(center: rl.Vector3, width: f32, length: f32, spacing: f32) void {
        const halfW = width / 2;
        const halfL = length / 2;

        var x: f32 = -halfW;
        while (x <= halfW) : (x += spacing) {
            rl.drawLine3D(.{ .x = center.x + x, .y = center.y, .z = center.z - halfL }, .{ .x = center.x + x, .y = center.y, .z = center.z + halfL }, .gray);
        }

        var z: f32 = -halfL;
        while (z <= halfL) : (z += spacing) {
            rl.drawLine3D(.{ .x = center.x - halfW, .y = center.y, .z = center.z + z }, .{ .x = center.x + halfW, .y = center.y, .z = center.z + z }, .gray);
        }
    }
    pub const LevelID = enum { one };

    //    pub fn import_level(id: LevelID) !Level {
    //        _ = id;
    //    }
    //    pub fn export_level(self: Level) !void {
    //        _ = Level;
    //    }
};
