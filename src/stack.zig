const std = @import("std");
const print = std.debug.print;

pub fn Stack(comptime T: type) type {
    return struct {
        index: usize,
        memory: []T,
        const Self = @This();

        pub fn init(self: *Self, buff: []T) void {
            self.index = 0;
            self.memory = buff;
        }

        /// pretty print the stack
        pub fn show(self: Self) void {
            if (self.index == 0) {
                print("\n", .{});
                return;
            }
            for (self.memory[0..self.index]) |data| {
                print("| {} ", .{data});
            }
            print("|\n", .{});
        }

        /// push a value to the stack
        pub fn push(self: *Self, value: T) void {
            if (self.index < self.size) {
                self.memory[self.index] = value;
                self.index += 1;
            }
        }

        /// pop a value from the stack
        pub fn pop(self: *Self) ?T {
            if (self.index == 0) {
                return null;
            }
            var toRemove: T = self.memory[self.index];
            self.index -= 1;
            return toRemove;
        }
    };
}
