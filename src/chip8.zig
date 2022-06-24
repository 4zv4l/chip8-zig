const std = @import("std");
const fs = std.fs;
const print = std.debug.print;

// two bytes long opcode (16 bits)
const Opcode = u16;
/// opcode design struct
const Opcode_struct = struct {
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
};

pub const Chip8 = struct {
    /// opcode 2x8bits
    opcode: Opcode = undefined,
    /// 4k of ram
    memory: [4096]u8 = undefined,
    /// 16 registers :: 8bits long
    /// V0 - VF
    V: [16]u8 = undefined,
    /// Index register from 0x000 to 0xFFF
    I: u16 = undefined,
    /// Program Counter from 0x000 to 0xFFF
    PC: u16 = undefined,
    /// graphics 64x32
    gfx: [64][32]u8 = undefined,
    // timers
    delay_timer: u8 = undefined,
    sound_timer: u8 = undefined,
    /// stack
    stack: [16]u16 = undefined,
    /// stack pointer
    sp: u16 = undefined,
    /// keypad
    key: [16]u8 = undefined,
    /// draw flag
    drawFlag: bool = false,

    /// fontset to draw on the screen
    const fontset: [80]u8 = .{
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80, // F
    };

    pub fn setupGraphics() void {}
    pub fn setupInput() void {}

    /// initialize the chip8
    pub fn init() Chip8 {
        // init registers and memory
        var c8 = std.mem.zeroes(Chip8);
        c8.PC = 0x200; // program counter starts at 0x200
        c8.opcode = 0; // reset current opcode
        c8.I = 0; // reset index register
        c8.sp = 0; // reset stack pointer
        c8.gfx = std.mem.zeroes([64][32]u8); // clear dislay
        c8.stack = std.mem.zeroes([16]u16); // clear stack
        c8.V = std.mem.zeroes([16]u8); // clear registers V0-VF
        c8.memory = std.mem.zeroes([4096]u8); // clear ram

        // load fontset
        for (fontset) |c8_fs, i| {
            c8.memory[i] = c8_fs;
        }

        c8.sound_timer = 0; // reset timers
        c8.delay_timer = 0;
        return c8;
    }

    /// load program to ram
    pub fn load(self: *Chip8, allocator: std.mem.Allocator, path: []const u8) !void {
        // open the file in binary mode
        const abs_path = try fs.realpathAlloc(allocator, path);
        defer allocator.free(abs_path);
        print("=> {s}\n", .{abs_path});

        // try to open the file
        const file = fs.openFileAbsolute(abs_path, .{ .mode = .read_only }) catch |e| {
            return e;
        };
        const reader = file.reader();
        // for each byte => fill ram starting from 0x200 (512)
        var i: usize = 0;
        while (true) {
            const byte = reader.readByte() catch {
                break;
            };
            self.memory[i + 0x200] = byte;
            i += 1;
            // if rom too long abort :: max size for a rom is 3583-bits or 3,5kb
            if (i + 0x200 >= 0xFFF) return error.RomTooBig;
        }
    }

    /// emulate one cycle from the chip8
    /// read instruction from ram
    /// fetch => decode => execute
    /// update the Porgram Counter (PC) and the timers
    pub fn emulateCycle(self: *Chip8) !void {
        // check Program Counter, loop if max addr is reached
        if (self.PC >= 0xFFF) {
            self.PC = 0x200;
        }

        // fetch
        self.opcode = @as(u16, self.memory[self.PC]) << 8; // AAAA 0000
        self.opcode |= self.memory[self.PC + 1]; // AAAA BBBB
        print("fetched: 0x{X}\n", .{self.opcode});

        // decode opcode
        const call = self.decode(self.opcode);

        // execute if call isn't 0 (not known opcode)
        if (call.opcode == 0) return error.UnknownOpcode;
        self.execute(call);

        // update timers
        if (self.delay_timer > 0) {
            self.delay_timer -= 1;
        }
        if (self.sound_timer > 0) {
            if (self.sound_timer == 1) {
                print("BEEP!\n", .{});
            }
            self.sound_timer -= 1;
        }
    }
    pub fn setKeys(self: *Chip8) void {
        _ = self;
    }

    /// decode opcode
    /// return 0 if not known opcode
    fn decode(self: *Chip8, opcode: Opcode) Opcode_struct {
        _ = opcode;
        switch (self.opcode & 0xF000) {

            // some opcodes //
            // TODO

            0x0000 => {
                // TODO
                switch (self.opcode & 0x000F) {
                    0x0000 => { // 00E0: Clear the screen

                    },
                    0x000E => { // 00EE: Return from subroutine

                    },
                    else => {
                        print("opcode not known: 0x{x} .. aborting\n", .{self.opcode});
                        return Opcode_struct{ .opcode = 0 };
                    },
                }
            },
            0xA000 => { // ANNN: Sets I to the address NNN
                // return Opcode_struct{ .opcode = 21, .NNN = NNN };
            },
            else => {
                print("opcode not known: 0x{x} .. aborting\n", .{self.opcode});
                return Opcode_struct{ .opcode = 0 };
            },
        }
        return Opcode_struct{ .opcode = 0 };
    }

    /// execute opcode
    fn execute(self: *Chip8, opcode: Opcode_struct) void {
        _ = self;
        _ = opcode;
        switch (opcode.opcode) {
            1 => { // 0NNN: call machine routine at addr NNN

            },
            2 => { // 00E0: clears the screen

            },
            3 => { // 00EE: return from subroutine

            },
            4 => { // 1NNN: jumps to addr NNN

            },
            5 => { // 2NNN: calls subroutine at NNN

            },
            6 => { // 3XNN: skips the next instruction if V[X] equals NN

            },
            7 => { // 4XNN: skips the next instruction if V[X] is not equal NN

            },
            8 => { // 5XY0: skips the next instruction if V[X] equals V[Y]

            },
            9 => { // 6XNN: sets V[X] to NN

            },
            10 => { // 7XNN: adds NN to V[X]

            },
            11 => { // 8XY0: setx V[X] to the value of V[Y]

            },
            12 => { // 8XY1: setx V[X] to V[X]|V[Y] (or bitwise)
                // v[x] |= v[y]
            },
            13 => { // 8XY2: sets V[X] to V[X]&V[Y] (and bitwise)

            },
            14 => { // 8XY3: sets V[X] to V[X]^V[Y] (xor bitwise)

            },
            15 => { // 8XY4: adds V[Y] to V[X], VF is set to 1 if a carry or 0 if not
                // v[x] += v[y]
            },
            16 => { // 8XY5: V[Y] is subtracted from V[X], VF is set to 0 when borrow and 1 if not

            },
            17 => { // 8XY6: stores the least significant bit of V[X] in VF and then shift V[X] to the right by 1
                // Vx >>= 1

            },
            18 => { // 8XY7: sets V[X] to V[Y] minux V[X], VF is set to 0 when borrow and 1 if not
                // Vx = Vy - Vx
            },
            19 => { // 8XYE: store the most significant bit of V[X] in VF and then shift V[X] to the left by 1
                // Vx <<= 1

            },
            20 => { // 9XY0: skips the next instruction if V[X] != V[Y]

            },
            21 => { // ANNN: sets I to the addr NNN
                self.I = self.opcode & 0x0FFF;
                self.PC += 2;
            },
            22 => { // BNNN: jumps to the addr NNN + V[0]

            },
            23 => { // CXNN: sets V[X] to the result of a bitwise operation on a random number and NN
                // Vx = rand() & NN

            },
            24 => { // DXYN: draw sprite at coordinate (Vx, Vy) width 8px height of N px, each row of 8px is read as bit-cded starting from memory[I], VF is set to 1 if any screen pixels are flipped from set to unset and to 0 if it doesn't happen

            },
            25 => { // EX9E: skips the next instruction if the key stored in V[X] is pressed
                // if(key() == Vx)

            },
            26 => { // EXA1: skips the next instruction if the key stored in V[X] is not pressed
                // if(key() != Vx)

            },
            27 => { // FX07: sets V[X] to the value of the delay timer

            },
            28 => { // FX0A: A key press is awaited and then stored in V[X] (blocking)

            },
            29 => { // FX15: sets the delay_timer to V[X]

            },
            30 => { // FX18: sets the sound_timer to V[X]

            },
            31 => { // FX1E: adds V[X] to I
                // self.I += self.V[X]
            },
            32 => { // FX29: sets I tot he location of the sprite for the char in V[X], char O-F (in hex) are represented by a 4x5 font

            },
            33 => { // FX33:

            },
            34 => { // FX55:

            },
            35 => { // FX65:

            },
            else => {},
        }
    }
};
