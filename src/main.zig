const std = @import("std");
const chip8 = @import("./chip8.zig");
const print = std.debug.print;

pub fn main() !void {
    // create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // get argv
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    // check arg
    if (argv.len != 2) {
        const path = std.fs.path.basename(argv[0]);
        print("usage:\n\t./{s} [rom]\n", .{path});
        return;
    }

    // init and load program in the ram
    var myChip8 = chip8.Chip8.init();
    try myChip8.load(allocator, argv[1]);

    while (true) {
        // do one cycle
        myChip8.emulateCycle();

        // draw if needed
        if (myChip8.drawFlag) {
            //draw(myChip8.gfx);
        }

        // store key press state (press and release)
        myChip8.setKeys();
    }
}
