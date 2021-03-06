const std = @import("std");
const fs = std.fs;
const math = std.math;
const print = std.debug.print;

const Stack = @import("./stack.zig").Stack;
const Opcode = @import("./opcode.zig").Opcode;
const Opcode_struct = @import("./opcode.zig").Opcode_struct;
const Screen = @import("./screen.zig");
const Keyboard = @import("./keyboard.zig");

pub const Chip8 = struct {
    /// opcode 2x8bits
    opcode: Opcode,
    /// 4k of ram
    memory: [4096]u8,
    /// 16 registers :: 8bits long
    /// V0 - VF
    V: [16]u8,
    /// Index register from 0x000 to 0xFFF
    I: u16,
    /// Program Counter from 0x000 to 0xFFF
    PC: u16,
    /// graphics 64x32
    gfx: Screen.Display,
    // timers
    delay_timer: u8,
    sound_timer: u8,
    /// stack
    //stack: [16]u16 = undefined,
    stack_buffer: [16]u16 = undefined,
    stack: Stack(u16),
    /// keypad
    key: Keyboard.Keys,
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

    /// initialize the chip8
    pub fn init() Chip8 {
        var c8 = std.mem.zeroes(Chip8);
        c8.PC = 0x200; // program counter starts at 0x200
        c8.opcode = 0; // reset current opcode
        c8.I = 0; // reset index register
        c8.gfx = Screen.Display.init(); // clear, init the dislay
        c8.stack.init(&c8.stack_buffer); // init the stack
        c8.stack_buffer = std.mem.zeroes([16]u16); // clear stack
        c8.V = std.mem.zeroes([16]u8); // clear registers V0-VF
        c8.memory = std.mem.zeroes([4096]u8); // clear ram
        c8.key = Keyboard.Keys.init(); // init keyboard

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
            // if rom too long abort :: max size for a rom is 3583b or 3,5kb
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
        const opcode = self.decode();
        print("0x{X:0>4} =>", .{self.opcode});
        opcode.show();

        // execute if call isn't 0 (not known opcode)
        if (opcode.opcode == 0) return error.UnknownOpcode;
        self.execute(opcode);

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

    /// decode opcode
    /// return 0 if not known opcode
    fn decode(self: *Chip8) Opcode_struct {
        // opcode to decode
        const opcode = self.opcode;
        switch (opcode & 0xF000) {
            0x0000 => switch (opcode & 0x000F) {
                0x0000 => { // 00E0
                    return Opcode_struct{ .opcode = 2 };
                },
                0x000E => { // 00EE
                    return Opcode_struct{ .opcode = 3 };
                },
                else => { // 0NNN
                    return Opcode_struct{ .opcode = 1, .NNN = @truncate(u12, opcode) };
                },
            },
            0x1000 => { // 1NNN
                return Opcode_struct{ .opcode = 4, .NNN = @truncate(u12, opcode) };
            },
            0x2000 => { // 2NNN
                return Opcode_struct{ .opcode = 5, .NNN = @truncate(u12, opcode) };
            },
            0x3000 => { // 3XNN
                return Opcode_struct{ .opcode = 6, .X = @truncate(u4, opcode >> 8), .NN = @truncate(u8, opcode) };
            },
            0x4000 => { // 4XNN
                return Opcode_struct{ .opcode = 7, .X = @truncate(u4, opcode >> 8), .NN = @truncate(u8, opcode) };
            },
            0x5000 => { // 5XY0
                return Opcode_struct{ .opcode = 8, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
            },
            0x6000 => { // 6XNN
                return Opcode_struct{ .opcode = 9, .X = @truncate(u4, opcode >> 8), .NN = @truncate(u8, opcode) };
            },
            0x7000 => { // 7XNN
                return Opcode_struct{ .opcode = 10, .X = @truncate(u4, opcode >> 8), .NN = @truncate(u8, opcode) };
            },
            0x8000 => switch (opcode & 0x000F) {
                0x0000 => { // 8XY0
                    return Opcode_struct{ .opcode = 11, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0001 => { // 8XY1
                    return Opcode_struct{ .opcode = 12, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0002 => { // 8XY2
                    return Opcode_struct{ .opcode = 13, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0003 => { // 8XY3
                    return Opcode_struct{ .opcode = 14, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0004 => { // 8XY4
                    return Opcode_struct{ .opcode = 15, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0005 => { // 8XY5
                    return Opcode_struct{ .opcode = 16, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0006 => { // 8XY6
                    return Opcode_struct{ .opcode = 17, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x0007 => { // 8XY7
                    return Opcode_struct{ .opcode = 18, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                0x000E => { // 8XYE
                    return Opcode_struct{ .opcode = 19, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
                },
                else => {
                    print("opcode not known: 0x{x} .. aborting\n", .{opcode});
                    return Opcode_struct{ .opcode = 0 };
                },
            },
            0x9000 => { // 9XY0
                return Opcode_struct{ .opcode = 20, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4) };
            },
            0xA000 => { // ANNN
                return Opcode_struct{ .opcode = 21, .NNN = @truncate(u12, opcode) };
            },
            0xB000 => { // BNNN
                return Opcode_struct{ .opcode = 22, .NNN = @truncate(u12, opcode) };
            },
            0xC000 => { // CXNN
                return Opcode_struct{ .opcode = 23, .X = @truncate(u4, opcode >> 8), .NN = @truncate(u8, opcode) };
            },
            0xD000 => { // DXYN
                return Opcode_struct{ .opcode = 24, .X = @truncate(u4, opcode >> 8), .Y = @truncate(u4, opcode >> 4), .N = @truncate(u4, opcode) };
            },
            0xE000 => switch (opcode & 0x000F) {
                0x000E => { // EX9E
                    return Opcode_struct{ .opcode = 25, .X = @truncate(u4, opcode >> 8) };
                },
                0x0001 => { // EXA1
                    return Opcode_struct{ .opcode = 26, .X = @truncate(u4, opcode >> 8) };
                },
                else => {
                    print("opcode not known: 0x{x} .. aborting\n", .{opcode});
                    return Opcode_struct{ .opcode = 0 };
                },
            },
            0xF000 => switch (opcode & 0x000F) {
                0x0003 => { // FX33
                    return Opcode_struct{ .opcode = 33, .X = @truncate(u4, opcode >> 8) };
                },
                0x0007 => { // FX07
                    return Opcode_struct{ .opcode = 27, .X = @truncate(u4, opcode >> 8) };
                },
                0x000A => { // FX01
                    return Opcode_struct{ .opcode = 28, .X = @truncate(u4, opcode >> 8) };
                },
                0x0005 => switch (opcode & 0x00F0) {
                    0x0010 => { // FX15
                        return Opcode_struct{ .opcode = 29, .X = @truncate(u4, opcode >> 8) };
                    },
                    0x0050 => { // FX55
                        return Opcode_struct{ .opcode = 34, .X = @truncate(u4, opcode >> 8) };
                    },
                    0x0060 => { // FX65
                        return Opcode_struct{ .opcode = 35, .X = @truncate(u4, opcode >> 8) };
                    },
                    else => {
                        print("opcode not known: 0x{x} .. aborting\n", .{opcode});
                        return Opcode_struct{ .opcode = 0 };
                    },
                },
                0x0008 => { // FX18
                    return Opcode_struct{ .opcode = 30, .X = @truncate(u4, opcode >> 8) };
                },
                0x000E => { // FX1E
                    return Opcode_struct{ .opcode = 31, .X = @truncate(u4, opcode >> 8) };
                },
                0x0009 => { // FX29
                    return Opcode_struct{ .opcode = 32, .X = @truncate(u4, opcode >> 8) };
                },
                else => {
                    print("opcode not known: 0x{x} .. aborting\n", .{opcode});
                    return Opcode_struct{ .opcode = 0 };
                },
            },
            else => {
                print("opcode not known: 0x{x} .. aborting\n", .{opcode});
                return Opcode_struct{ .opcode = 0 };
            },
        }
        return Opcode_struct{ .opcode = 0 };
    }

    /// execute opcode
    fn execute(self: *Chip8, opcode: Opcode_struct) void {
        switch (opcode.opcode) {
            1 => { // 0NNN: call machine routine at addr NNN
                self.PC = opcode.NNN;
            },
            2 => { // 00E0: clears the screen
                self.drawFlag = true;
                self.gfx.reset();
                self.PC += 2;
            },
            3 => { // 00EE: return from subroutine
                self.PC = self.stack.pop() orelse {
                    print("Bad Address: returning to none\n", .{});
                    return;
                };
                self.PC += 2; // otherwise infinite loop BABY !
            },
            4 => { // 1NNN: jumps to addr NNN
                self.PC = opcode.NNN;
            },
            5 => { // 2NNN: calls subroutine at NNN
                self.stack.push(self.PC);
                self.PC = opcode.NNN;
            },
            6 => { // 3XNN: skips the next instruction if V[X] equals NN
                if (opcode.NN == self.V[opcode.X]) {
                    self.PC += 4;
                } else {
                    self.PC += 2;
                }
            },
            7 => { // 4XNN: skips the next instruction if V[X] is not equal NN
                if (opcode.NN != self.V[opcode.X]) {
                    self.PC += 4;
                } else {
                    self.PC += 2;
                }
            },
            8 => { // 5XY0: skips the next instruction if V[X] equals V[Y]
                if (self.V[opcode.X] == self.V[opcode.Y]) {
                    self.PC += 4;
                } else {
                    self.PC += 2;
                }
            },
            9 => { // 6XNN: sets V[X] to NN
                self.V[opcode.X] = opcode.NN;
                self.PC += 2;
            },
            10 => { // 7XNN: adds NN to V[X]
                self.V[opcode.X] += opcode.NN;
                self.PC += 2;
            },
            11 => { // 8XY0: setx V[X] to the value of V[Y]
                self.V[opcode.X] += self.V[opcode.Y];
                self.PC += 2;
            },
            12 => { // 8XY1: setx V[X] to V[X]|V[Y] (or bitwise)
                // v[x] |= v[y]
                self.V[opcode.X] |= self.V[opcode.Y];
                self.PC += 2;
            },
            13 => { // 8XY2: sets V[X] to V[X]&V[Y] (and bitwise)
                self.V[opcode.X] &= self.V[opcode.Y];
                self.PC += 2;
            },
            14 => { // 8XY3: sets V[X] to V[X]^V[Y] (xor bitwise)
                self.V[opcode.X] ^= self.V[opcode.Y];
                self.PC += 2;
            },
            15 => { // 8XY4: adds V[Y] to V[X], VF is set to 1 if a carry or 0 if not
                self.V[15] = 0;
                if (@addWithOverflow(u8, self.V[opcode.X], self.V[opcode.Y], &self.V[opcode.X])) {
                    self.V[15] = 1;
                }
                self.PC += 2;
            },
            16 => { // 8XY5: V[Y] is subtracted from V[X], VF is set to 0 when borrow and 1 if not
                self.V[15] = 0;
                if (@subWithOverflow(u8, self.V[opcode.X], self.V[opcode.Y], &self.V[opcode.X])) {
                    self.V[15] = 1;
                }
                self.PC += 2;
            },
            17 => { // 8XY6: stores the least significant bit of V[X] in VF and then shift V[X] to the right by 1
                self.V[15] = self.V[opcode.X] & 0x0F;
                self.V[opcode.X] >>= 1;
                self.PC += 2;
            },
            18 => { // 8XY7: sets V[X] to V[Y] minux V[X], VF is set to 0 when borrow and 1 if not
                self.V[15] = 0;
                if (@subWithOverflow(u8, self.V[opcode.Y], self.V[opcode.X], &self.V[opcode.X])) {
                    self.V[15] = 1;
                }
                self.PC += 2;
            },
            19 => { // 8XYE: store the most significant bit of V[X] in VF and then shift V[X] to the left by 1
                self.V[15] = self.V[opcode.X] & 0xF0;
                self.V[opcode.X] <<= 1;
                self.PC += 2;
            },
            20 => { // 9XY0: skips the next instruction if V[X] != V[Y]
                if (self.V[opcode.X] != self.V[opcode.Y]) {
                    self.PC += 4;
                } else {
                    self.PC += 2;
                }
            },
            21 => { // ANNN: sets I to the addr NNN
                self.I = opcode.NNN;
                self.PC += 2;
            },
            22 => { // BNNN: jumps to the addr NNN + V[0]
                self.PC = opcode.NNN + self.V[0];
            },
            23 => { // CXNN: sets V[X] to the result of a bitwise operation on a random number and NN
                // Vx = rand() & NN
                self.V[opcode.X] = undefined & opcode.NN;
                self.PC += 2;
            },
            24 => { // DXYN: draw sprite at coordinate (Vx, Vy) width 8px height of N px,
                // each row of 8px is read as bit-coded starting from memory[I],
                // VF is set to 1 if any screen pixels are flipped from set to unset and to 0 if it doesn't happen
                self.V[15] = 0;
                var counter: u4 = 0;

                // set the pixels
                while (counter != opcode.N) : (counter += 1) {
                    if (self.gfx.set(self.memory[self.I + counter], self.V[opcode.X], (self.V[opcode.Y] + counter) % self.gfx.y_size)) {
                        self.V[15] = 1;
                    }
                }

                // refresh the display
                self.gfx.draw();

                self.PC += 2;
            },
            25 => { // EX9E: skips the next instruction if the key stored in V[X] is pressed
                // if(key() == Vx)
                // TODO
                if (self.key.isPressed(self.V[opcode.X])) {
                    self.PC += 4;
                }
                self.PC += 2;
            },
            26 => { // EXA1: skips the next instruction if the key stored in V[X] is not pressed
                // if(key() != Vx)
                // TODO
                if (!self.key.isPressed(self.V[opcode.X])) {
                    self.PC += 4;
                }
                self.PC += 2;
            },
            27 => { // FX07: sets V[X] to the value of the delay timer
                self.V[opcode.X] = self.delay_timer;
                self.PC += 2;
            },
            28 => { // FX0A: A key press is awaited and then stored in V[X] (blocking)
                // TODO

            },
            29 => { // FX15: sets the delay_timer to V[X]
                self.delay_timer = self.V[opcode.X];
                self.PC += 2;
            },
            30 => { // FX18: sets the sound_timer to V[X]
                self.sound_timer = self.V[opcode.X];
                self.PC += 2;
            },
            31 => { // FX1E: adds V[X] to I
                self.I += self.V[opcode.X];
                self.PC += 2;
            },
            32 => { // FX29: sets I tot he location of the sprite for the char in V[X], char O-F (in hex) are represented by a 4x5 font
                // The value of I is set to the location for the hexadecimal sprite corresponding to the value of Vx.
                // See section 2.4, Display, for more information on the Chip-8 hexadecimal font.
                // TODO
                self.I = self.V[opcode.X];
                self.PC += 2;
            },
            33 => { // FX33: Store BCD representation of Vx in memory locations I, I+1, and I+2.
                //The interpreter takes the decimal value of Vx,
                //and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
                //TODO                              // if: 548
                self.memory[self.I] = self.V[opcode.X]; // 5
                self.memory[self.I + 1] = self.V[opcode.X]; // 4
                self.memory[self.I + 2] = self.V[opcode.X]; // 8
                self.PC += 2;
            },
            34 => { // FX55: Store registers V0 through Vx in memory starting at location I.
                // The interpreter copies the values of registers V0 through Vx into memory, starting at the address in I.
                // TODO
            },
            35 => { // FX65: Read registers V0 through Vx from memory starting at location I.
                // The interpreter reads values from memory starting at location I into registers V0 through Vx.
                // TODO
            },
            else => {
                return;
            },
        }
    }
};
