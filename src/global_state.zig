// Alle Scenen können auf Variablen hier drinnen zugreifen
const Level = @import("core/level.zig").Level;

pub var CurrentLevelID: Level.LevelID = .one;
pub const DrawWidth: i32 = 1920;
pub const DrawHeight: i32 = 1080;
