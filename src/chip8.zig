const std = @import("std");
const fs = std.fs;
const print = std.debug.print;

// two bytes long opcode (16 bits)
const Opcode = u16;

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
        const rel_path = try fs.realpathAlloc(allocator, path);
        defer allocator.free(rel_path);
        print("=> {s}\n", .{rel_path});

        // try to open the file
        const file = fs.openFileAbsolute(path, .{ .mode = .read_only }) catch |e| {
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
        }
    }

    /// emulate one cycle from the chip8
    /// read instruction from ram
    /// fetch => decode => execute
    /// update the Porgram Counter (PC) and the timers
    pub fn emulateCycle(self: *Chip8) void {
        // check Program Counter
        if (self.PC >= 0xFFF) {
            self.PC = 0x200;
        }
        // fetch
        self.opcode = @as(u16, self.memory[self.PC]) << 8;
        self.opcode |= self.memory[self.PC + 1];
        print("fetched: 0x{x}\n", .{self.opcode});
        // decode & execute
        const call = self.decode(self.opcode);
        // execute
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
    /// return 36 if not known opcode
    fn decode(self: *Chip8, opcode: Opcode) u8 {
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
                        print("opcode not known: 0x{x}\n", .{self.opcode});
                    },
                }
            },
            0xA000 => { // ANNN: Sets I to the address NNN
                // exec opcode
                return 21;
            },
            0x6000 => { // 6XNN: Sets V[X] to NN
                // TODO
                // const X: u8 = self.opcode;
                // const NN: u8 = self.opcode;
                // self.V[X] = NN;
            },
            else => {
                print("opcode not known: 0x{x}\n", .{self.opcode});
                return 36;
            },
        }
        return 36;
    }

    /// execute opcode
    fn execute(self: *Chip8, opcode: u8) void {
        _ = self;
        switch (opcode) {
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
            20 => { // 9XY0:

            },
            21 => { // ANNN:
                self.I = self.opcode & 0x0FFF;
                self.PC += 2;
            },
            22 => { // BNNN:

            },
            23 => { // CXNN:

            },
            24 => { // DXYN:

            },
            25 => { // EX9E:

            },
            26 => { // EXA1:

            },
            27 => { // FX07:

            },
            28 => { // FX0A:

            },
            29 => { // FX15:

            },
            30 => { // FX18:

            },
            31 => { // FX1E:

            },
            32 => { // FX29:

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
