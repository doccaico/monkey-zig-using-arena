const std = @import("std");
const Io = std.Io;

const repl = @import("Repl.zig");

// var stdout_buf: [1024]u8 = undefined;
// var stdout: std.Io.Writer = .fixed(&stdout_buf);
// var stdin_buf: [1024]u8 = undefined;
// var stdin: std.Io.Reader = .fixed(&stdin_buf);

pub fn main(init: std.process.Init) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer std.debug.assert(debug_allocator.deinit() == .ok);

    const gpa = debug_allocator.allocator();

    // var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    // const gpa = general_purpose_allocator.allocator();

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    // const stdin = std.io.getStdIn().reader();
    // const stdout = std.io.getStdOut().writer();

    // try stdout.writeAll("Hello! This is the Monkey programming language!\n");
    // try stdout.writeAll("Feel free to type in commands\n");

    try repl.start(gpa, stdin, stdout);
    // try repl.start(gpa, &stdin, &stdout, init);
    // try repl.start(gpa);
}

test {
    _ = @import("Ast.zig");
    _ = @import("Environment.zig");
    _ = @import("Evaluator.zig");
    _ = @import("Lexer.zig");
    _ = @import("Parser.zig");
    _ = @import("Repl.zig");
    _ = @import("Token.zig");
}
