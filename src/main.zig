const std = @import("std");

const repl = @import("Repl.zig");

pub fn main(init: std.process.Init) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll("Hello! This is the Monkey programming language!\n");
    try stdout.writeAll("Feel free to type in commands\n");

    try stdout.flush();

    try repl.start(allocator, stdin, stdout);
}

test {
    _ = @import("Ast.zig");
    _ = @import("Environment.zig");
    _ = @import("Evaluator.zig");
    _ = @import("Lexer.zig");
    _ = @import("Parser.zig");
    _ = @import("Repl.zig");
}
