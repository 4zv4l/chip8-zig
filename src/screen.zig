const std = @import("std");

pub const Display = struct {
    x_size: u8 = 64,
    y_size: u8 = 32,
    screen: [64][32]u8 = undefined,

    pub fn init() Display {
        var display = Display{};
        display.screen = std.mem.zeroes([64][32]u8);
        return display;
    }

    pub fn reset(self: *Display) void {
        self.screen = std.mem.zeroes([64][32]u8);
    }
};
