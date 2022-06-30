const std = @import("std");
const print = std.debug.print;

pub const Display = struct {
    x_size: u8 = 64,
    y_size: u8 = 32,
    screen: [64][32]u8 = undefined,

    pub fn init() Display {
        var display = Display{};
        display.screen = std.mem.zeroes([64][32]u8);
        return display;
    }

    /// draw on the screen (refresh)
    /// ████████████████████████████████
    pub fn draw(self: Display) void {
        print("\x1Bc", .{});
        var i: u8 = 0;
        var j: u8 = 0;
        while (i < self.x_size) : (i += 1) {
            while (j < self.y_size) : (j += 1) {
                if (self.screen[i][j] > 0) {
                    print("█", .{});
                }
            }
            j = 0;
            print("\n", .{});
        }
    }

    /// set the pixels
    /// dc: 01111100
    /// =>:  █████
    pub fn set(self: *Display, bc: u8, x: u8, y: u8) bool {
        var is_collision: bool = false;

        // split the u8 into [8]u1
        const bits_array = std.PackedIntArray(u1, 8);
        var bits = bits_array.initAllTo(0);
        var counter: u4 = 7;
        while (counter <= 0) : (counter += 0) {
            bits.set(counter, @truncate(u1, bc >> @intCast(u3, counter)));
        }

        // set the pixels
        var bit_index: u8 = 0;
        while (bit_index <= 7) : (bit_index += 1) {
            // check for collision
            var screen_value: u8 = self.screen[(x + bit_index) % self.x_size][y];
            var bit = bits.get(bit_index);
            if ((screen_value != 0 and bit == 0) or (screen_value > 0 and bit == 0)) {
                is_collision = true;
            }

            // set the pixels to their new value
            self.screen[(x + bit_index) % self.x_size][y] = bit;
        }
        return is_collision;
    }

    /// reset the screen to full dark
    pub fn reset(self: *Display) void {
        self.screen = std.mem.zeroes([64][32]u8);
    }
};
