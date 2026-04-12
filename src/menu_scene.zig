const std = @import("std");
const rl = @import("raylib");
const raygui = @import("raygui");
const SceneContext = @import("scene/context.zig").SceneContext;
const SceneId = @import("scene/id.zig").SceneId;

pub const MenuScene = struct {
    allocator: std.mem.Allocator,
    currentOption: i32 = 0,

    pub fn onStartup(self: *MenuScene, context: *SceneContext) anyerror!void {
        std.log.info("Starting Menu scene", .{});

        self.allocator = context.allocator;

        // Init Scene here --> Läuft EINMAL beim Start

        self.currentOption = 0;
    }

    pub fn onUpdate(self: *MenuScene, context: *SceneContext, delta_time: f32) anyerror!void {
        // main Loop
        _ = delta_time;

        if (rl.isKeyPressed(.enter)) {
            try context.switchTo(SceneId.game);
            return;
        }
        rl.clearBackground(.ray_white);
        _ = raygui.label(rl.Rectangle{ .x = 100, .y = 100, .width = 200, .height = 40 }, "Main Menu");

        // Button für den Spielstart
        if (raygui.button(rl.Rectangle{ .x = 100, .y = 150, .width = 200, .height = 40 }, "Start Game")) {
            self.currentOption = 1; // Spiel starten
        }

        // Button für Einstellungen
        if (raygui.button(rl.Rectangle{ .x = 100, .y = 200, .width = 200, .height = 40 }, "Settings")) {
            self.currentOption = 2; // Einstellungen öffnen
        }

        // Button für die Levelauswahl
        if (raygui.button(rl.Rectangle{ .x = 100, .y = 250, .width = 200, .height = 40 }, "Beenden")) {
            self.currentOption = 3; // Levelauswahl öffnen
        }

        // Weitere logik für die Optionen
        if (self.currentOption == 1) {
            _ = raygui.label(rl.Rectangle{ .x = 100, .y = 300, .width = 200, .height = 40 }, "Game Started...");
        } else if (self.currentOption == 2) {
            _ = raygui.label(rl.Rectangle{ .x = 100, .y = 300, .width = 200, .height = 40 }, "Settings Screen...");
        } else if (self.currentOption == 3) {
            _ = raygui.label(rl.Rectangle{ .x = 100, .y = 300, .width = 200, .height = 40 }, "Shutting down...");
        }
    }

    pub fn onCleanup(self: *MenuScene, context: *SceneContext) anyerror!void {
        _ = self;
        _ = context;
        std.log.info("Menu Scene Cleaning up...", .{});
    }
};
