const std = @import("std");

pub const Keys = struct {
    // |1|2|3|C|
    // |4|5|6|D|
    // |7|8|9|E|
    // |A|0|B|F|
    keys: [16]u8 = undefined,

    pub fn init() Keys {
        return Keys{};
    }
};
