const print = @import("std").debug.print;

// two bytes long opcode (16 bits)
pub const Opcode = u16;
/// opcode design struct
pub const Opcode_struct = struct {
    /// opcode index
    opcode: Opcode = 0,
    /// 4bit constant
    N: u4 = 0,
    /// 8bit constant
    NN: u8 = 0,
    /// addr: 0x200-0xFFF
    NNN: u12 = 0,
    /// registers index
    X: u4 = 0,
    Y: u4 = 0,

    /// format the Opcode_struct to show the different
    /// components
    pub fn show(self: Opcode_struct) void {
        print("{{opcode: {d}, N: {x}, NN: {x}, NNN: {x}, X: {d}, Y: {d}}}\n", .{ self.opcode, self.N, self.NN, self.NNN, self.X, self.Y });
    }
};
