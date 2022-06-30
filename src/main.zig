const std = @import("std");
const chip8 = @import("./chip8.zig");
const print = std.debug.print;

pub fn main() void {
    // create allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // get argv
    const argv = std.process.argsAlloc(allocator) catch {
        print("couldn't get the rom from the argument..aborting\n", .{});
        return;
    };
    defer std.process.argsFree(allocator, argv);

    // check arg
    if (argv.len != 2) {
        const path = std.fs.path.basename(argv[0]);
        print("usage:\n\t./{s} [rom]\n", .{path});
        return;
    }

    ///////////////// START HERE

    // init and load program in the ram
    var myChip8 = chip8.Chip8.init();
    myChip8.load(allocator, argv[1]) catch |e| {
        print("{e}: couldn't open the rom\n", .{e});
        return;
    };

    while (true) {
        // do one cycle
        myChip8.emulateCycle() catch |e| {
            print("{e}\n", .{e});
            return;
        };
    }
}
