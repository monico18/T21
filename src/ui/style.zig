const vaxis = @import("vaxis");

// Centralized UI palette for chip colors and focus variants.
pub const chip_white = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 240, 240, 240 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0, 0, 0 } } };
pub const chip_red = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0xC0, 0x39, 0x2B } }, .fg = vaxis.Color{ .rgb = [3]u8{ 255, 255, 255 } } };
pub const chip_blue = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0x28, 0x74, 0xA6 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 255, 255, 255 } } };
pub const chip_green = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0x27, 0xAE, 0x60 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 255, 255, 255 } } };
pub const chip_gold = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0xD4, 0xAF, 0x37 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0, 0, 0 } } };

// Focused/highlight variants (slightly brighter for emphasis)
pub const chip_white_focus = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 255, 255, 255 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0, 0, 0 } }, .bold = true };
pub const chip_red_focus = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0xE8, 0x4C, 0x3D } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0xFF, 0xFF, 0xFF } }, .bold = true };
pub const chip_blue_focus = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0x34, 0x98, 0xDB } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0xFF, 0xFF, 0xFF } }, .bold = true };
pub const chip_green_focus = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0x2E, 0xCC, 0x71 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0xFF, 0xFF, 0xFF } }, .bold = true };
pub const chip_gold_focus = vaxis.Style{ .bg = vaxis.Color{ .rgb = [3]u8{ 0xFF, 0xD7, 0x69 } }, .fg = vaxis.Color{ .rgb = [3]u8{ 0x00, 0x00, 0x00 } }, .bold = true };
