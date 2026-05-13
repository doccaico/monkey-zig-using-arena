const builtin = @import("builtin");
const std = @import("std");

const Environment = @import("Environment.zig");
const Evaluator = @import("Evaluator.zig");
const Globals = @import("Globals.zig");
const Lexer = @import("Lexer.zig");
const Parser = @import("Parser.zig");

const checkParserErrors = Parser.checkParserErrors;

const PROMPT = ">> ";
const MONKEY_FACE =
    \\            __,__
    \\   .--.  .-"     "-.  .--.
    \\  / .. \/  .-. .-.  \/ .. \
    \\ | |  '|  /   Y   \  |'  | |
    \\ | \   \  \ 0 | 0 /  /   / |
    \\  \ '- ,\.-"""""""-./, -' /
    \\   ''-' /_   ^ ^   _\ '-''
    \\       |  \._   _./  |
    \\       \   \ '~' /   /
    \\        '._ '-=-' _.'
    \\           '-----'
;

pub fn start(allocator: std.mem.Allocator, stdin: *std.Io.Reader, stdout: *std.Io.Writer) !void {
    try Globals.init(allocator);
    defer Globals.deinit();

    var env = Environment.init(allocator);
    defer env.deinit();

    var line_buf: [1024]u8 = undefined;

    loop: while (true) {
        try stdout.writeAll(PROMPT);
        try stdout.flush();

        var line_writer = std.Io.Writer.fixed(&line_buf);

        const input_len = stdin.streamDelimiter(&line_writer, '\n') catch |err| switch (err) {
            error.EndOfStream => {
                try stdout.writeAll("KeyboardInterrupt");
                try stdout.flush();
                break :loop;
            },
            else => |x| return x,
        };

        stdin.toss(1);

        const line_tmp = if (builtin.os.tag == .windows)
            line_writer.buffered()[0 .. input_len - 1]
        else
            line_writer.buffered();

        const line = allocator.dupe(u8, line_tmp) catch @panic("OOM");

        if (std.mem.eql(u8, line, "exit")) break :loop;
        if (std.mem.eql(u8, line, "quit")) break :loop;

        const lexer = Lexer.init(line);
        defer Globals.lineAppend(line);
        var parser = try Parser.init(allocator, lexer);
        defer parser.deinit();
        const node_program = parser.parseProgram();
        defer Globals.nodeProgramAppend(node_program);

        if (parser.errors.items.len != 0) {
            try printParserErrors(stdout, parser.errors);
            continue;
        }

        var evaluator = Evaluator.init(allocator);

        if (evaluator.eval(node_program, env)) |result| {
            try result.inspect(stdout);
            try stdout.writeByte('\n');
            try stdout.flush();
        }
    }
}

fn printParserErrors(stdout: *std.Io.Writer, errors: std.ArrayList([]const u8)) !void {
    _ = try stdout.print("{s}\n", .{MONKEY_FACE});
    _ = try stdout.write("Woops! We ran into some monkey business here!\n");
    for (errors.items) |msg| {
        try stdout.print("\t{s}\n", .{msg});
    }
    try stdout.flush();
}

test "TestRepl" {
    const Test = struct {
        []const u8,
        i64,
    };
    // use '0' for null value
    const tests = [_]Test{
        .{ "let addTwo = fn(x) { x + 2; }; 0;", 0 },
        .{ "addTwo(2);", 4 },
        // 3.10 - Functions & Function Calls
        .{ "let add = fn(a, b) { a + b }; 0", 0 },
        .{ "let sub = fn(a, b) { a - b }; 0", 0 },
        .{ "let applyFunc = fn(a, b, func) { func(a, b) }; 0;", 0 },
        .{ "applyFunc(2, 2, add);", 4 },
        .{ "applyFunc(10, 2, sub);", 8 },
    };

    try Globals.init(std.testing.allocator);
    defer Globals.deinit();

    var env = Environment.init(std.testing.allocator);
    defer env.deinit();

    for (tests) |t| {
        const line = t[0];

        const lexer = Lexer.init(line);
        var parser = try Parser.init(std.testing.allocator, lexer);
        defer parser.deinit();
        const node_program = parser.parseProgram();
        defer Globals.nodeProgramAppend(node_program);

        checkParserErrors(parser);

        var evaluator = Evaluator.init(std.testing.allocator);

        const result = evaluator.eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}
