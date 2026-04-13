const std = @import("std");
const rl = @import("raylib");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;

pub const MenuScene = struct {
    allocator: std.mem.Allocator,
    selected_index: i32 = 0,
    gear_angle_deg: f32 = 0.0,

    pub fn onStartup(self: *MenuScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Menu scene", .{});

        self.allocator = context.allocator;

        // Init Scene here --> Läuft EINMAL beim Start

        self.selected_index = 0;
        self.gear_angle_deg = 0.0;
    }

    pub fn onUpdate(self: *MenuScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        const screen_w = 1920.0;
        const screen_h = 1080.0;
        const mouse_pos = rl.getMousePosition();

        const button_w = @min(420.0, screen_w * 0.55);
        const button_h = 56.0;
        const button_spacing = 22.0;
        const button_x = (screen_w - button_w) * 0.5;
        const button_y = screen_h * 0.52;

        const start_rect = rl.Rectangle{ .x = button_x, .y = button_y, .width = button_w, .height = button_h };
        const quit_rect = rl.Rectangle{
            .x = button_x,
            .y = button_y + button_h + button_spacing,
            .width = button_w,
            .height = button_h,
        };

        const gear_radius_main = 26.0;
        const gear_radius_small = 18.0;
        const gear_margin = 28.0;
        const gear_center_main = rl.Vector2{
            .x = screen_w - gear_margin - gear_radius_main,
            .y = gear_margin + gear_radius_main,
        };
        const gear_distance = gear_radius_main + gear_radius_small - 6.0;
        const gear_center_small = rl.Vector2{
            .x = gear_center_main.x + gear_distance * 0.65,
            .y = gear_center_main.y - gear_distance * 0.65,
        };

        const gear_rect = rl.Rectangle{
            .x = gear_center_main.x - gear_radius_main - 6.0,
            .y = gear_center_small.y - gear_radius_small - 6.0,
            .width = (gear_center_small.x + gear_radius_small + 6.0) - (gear_center_main.x - gear_radius_main - 6.0),
            .height = (gear_center_main.y + gear_radius_main + 6.0) - (gear_center_small.y - gear_radius_small - 6.0),
        };

        const hover_start = rl.checkCollisionPointRec(mouse_pos, start_rect);
        const hover_quit = rl.checkCollisionPointRec(mouse_pos, quit_rect);
        const hover_gear = rl.checkCollisionPointRec(mouse_pos, gear_rect);

        if (hover_start) self.selected_index = 0;
        if (hover_quit) self.selected_index = 1;
        if (hover_gear) self.selected_index = 2;

        const option_count: i32 = 3;
        if (rl.isKeyPressed(.down) or rl.isKeyPressed(.right)) {
            self.selected_index = @mod(self.selected_index + 1, option_count);
        }
        if (rl.isKeyPressed(.up) or rl.isKeyPressed(.left)) {
            self.selected_index = @mod(self.selected_index + option_count - 1, option_count);
        }

        var activate_selected = false;
        if (rl.isKeyPressed(.enter) or rl.isKeyPressed(.space)) {
            activate_selected = true;
        }

        rl.clearBackground(.ray_white);

        const title_text = "Cubescape";
        const title_size = 64;
        const title_width = rl.measureText(title_text, title_size);
        rl.drawText(
            title_text,
            @as(i32, @intFromFloat((screen_w - @as(f32, @floatFromInt(title_width))) * 0.5)),
            @as(i32, @intFromFloat(screen_h * 0.23)),
            title_size,
            rl.Color{ .r = 20, .g = 20, .b = 20, .a = 255 },
        );

        const start_clicked = drawMenuButton(
            start_rect,
            "Spiel starten",
            hover_start,
            self.selected_index == 0,
        );
        const quit_clicked = drawMenuButton(
            quit_rect,
            "Spiel beenden",
            hover_quit,
            self.selected_index == 1,
        );

        const gear_hot = hover_gear or self.selected_index == 2;
        drawGearCluster(
            gear_center_main,
            gear_radius_main,
            gear_center_small,
            gear_radius_small,
            self.gear_angle_deg,
            gear_hot,
        );

        if (hover_gear) {
            self.gear_angle_deg += delta_time * 140.0;
        }

        if (start_clicked or (activate_selected and self.selected_index == 0)) {
            try context.switchTo(SceneId.game);
            return;
        }

        if (quit_clicked or (activate_selected and self.selected_index == 1)) {
            // Platzhalter für späteres Menüverhalten
        }

        if ((hover_gear and rl.isMouseButtonPressed(.left)) or (activate_selected and self.selected_index == 2)) {
            // Platzhalter für Settings/Extras
        }
    }

    pub fn onCleanup(self: *MenuScene, context: *SceneContext) anyerror!void {
        _ = self;
        _ = context;
        std.log.info("Menu Scene Cleaning up...", .{});
    }

    fn drawMenuButton(rect: rl.Rectangle, text: [:0]const u8, hovered: bool, focused: bool) bool {
        const fill = if (hovered or focused)
            rl.Color{ .r = 245, .g = 245, .b = 245, .a = 255 }
        else
            rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
        const outline = if (focused)
            rl.Color{ .r = 30, .g = 30, .b = 30, .a = 255 }
        else
            rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 };
        const thickness: f32 = if (focused) 3.0 else 2.0;

        rl.drawRectangleRounded(rect, 0.6, 12, fill);
        rl.drawRectangleRoundedLinesEx(rect, 0.6, 12, thickness, outline);

        const font_size = 24;
        const text_width = rl.measureText(text, font_size);
        rl.drawText(
            text,
            @as(i32, @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_width))) * 0.5)),
            @as(i32, @intFromFloat(rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) * 0.5)),
            font_size,
            outline,
        );

        return hovered and rl.isMouseButtonPressed(.left);
    }

    fn drawGearCluster(
        center_main: rl.Vector2,
        radius_main: f32,
        center_small: rl.Vector2,
        radius_small: f32,
        angle_deg: f32,
        highlighted: bool,
    ) void {
        const color_main = if (highlighted)
            rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 }
        else
            rl.Color{ .r = 70, .g = 70, .b = 70, .a = 255 };
        const color_secondary = if (highlighted)
            rl.Color{ .r = 20, .g = 20, .b = 20, .a = 255 }
        else
            rl.Color{ .r = 50, .g = 50, .b = 50, .a = 255 };

        drawGear(center_main, radius_main, 10, angle_deg, color_main);
        const ratio = radius_main / radius_small;
        drawGear(center_small, radius_small, 8, -angle_deg * ratio, color_secondary);
    }

    fn drawGear(center: rl.Vector2, radius: f32, tooth_count: i32, angle_deg: f32, color: rl.Color) void {
        const tooth_width = radius * 0.28;
        const tooth_height = radius * 0.22;
        const inner_radius = radius * 0.45;

        const step = 360.0 / @as(f32, @floatFromInt(tooth_count));
        var i: i32 = 0;
        while (i < tooth_count) : (i += 1) {
            const tooth_angle = angle_deg + step * @as(f32, @floatFromInt(i));
            const rad = std.math.degreesToRadians(tooth_angle);
            const pos = rl.Vector2{
                .x = center.x + @cos(rad) * (radius + tooth_height * 0.35),
                .y = center.y + @sin(rad) * (radius + tooth_height * 0.35),
            };
            const rect = rl.Rectangle{
                .x = pos.x - tooth_width * 0.5,
                .y = pos.y - tooth_height * 0.5,
                .width = tooth_width,
                .height = tooth_height,
            };
            rl.drawRectanglePro(rect, rl.Vector2{ .x = tooth_width * 0.5, .y = tooth_height * 0.5 }, tooth_angle, color);
        }

        rl.drawCircleV(center, radius, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        rl.drawCircleLines(@as(i32, @intFromFloat(center.x)), @as(i32, @intFromFloat(center.y)), radius, color);
        rl.drawCircleV(center, inner_radius, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        rl.drawCircleLines(@as(i32, @intFromFloat(center.x)), @as(i32, @intFromFloat(center.y)), inner_radius, color);
    }
};
