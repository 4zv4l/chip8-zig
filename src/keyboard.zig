const std = @import("std");

pub const Keys = struct {
    // |1|2|3|C|
    // |4|5|6|D|
    // |7|8|9|E|
    // |A|0|B|F|
    // keys: [16]u8 = undefined,
    keys: enum { KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F } = undefined,

    pub fn init() Keys {
        return Keys{};
    }

    // TODO check keys
    pub fn isPressed(self: *Keys, k: u8) bool {
        _ = self;
        _ = k;
        return false;
    }
};
