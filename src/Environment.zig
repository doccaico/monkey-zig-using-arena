const std = @import("std");

const Builtins = @import("Builtins.zig");
const Object = @import("Object.zig");

const Environment = @This();

pub var TRUE: *Object.Object = undefined;
pub var FALSE: *Object.Object = undefined;
pub var NULL: *Object.Object = undefined;

allocator: std.mem.Allocator,
store: std.StringHashMap(*Object.Object),
outer: ?*Environment,

pub fn init(allocator: std.mem.Allocator) *Environment {
    TRUE = createObjectBoolean(allocator, true);
    FALSE = createObjectBoolean(allocator, false);
    NULL = createObjectNull(allocator);

    Builtins.init(allocator);

    const env = allocator.create(Environment) catch @panic("OOM");
    env.* = Environment{
        .allocator = allocator,
        .store = std.StringHashMap(*Object.Object).init(allocator),
        .outer = null,
    };
    return env;
}

pub fn newEnclosedEnvironment(self: *Environment, outer: ?*Environment) *Environment {
    const env = self.allocator.create(Environment) catch @panic("OOM");
    env.allocator = self.allocator;
    env.store = std.StringHashMap(*Object.Object).init(self.allocator);
    env.outer = outer;
    return env;
}

pub fn get(self: Environment, key: []const u8) ?*Object.Object {
    const obj = self.store.get(key);
    if (obj != null) {
        return obj;
    } else {
        if (self.outer != null) {
            return self.outer.?.get(key);
        }
    }
    return null;
}

pub fn set(self: *Environment, key: []const u8, value: *Object.Object) void {
    const gop = self.store.getOrPut(key) catch @panic("OOM");
    if (!gop.found_existing) {
        gop.key_ptr.* = self.allocator.dupe(u8, key) catch @panic("OOM");
    }
    gop.value_ptr.* = value;
}

pub fn getBuiltinFunction(key: []const u8) ?*Object.Object {
    return Builtins.bfs_obj_map.get(key);
}

fn createObjectBoolean(allocator: std.mem.Allocator, value: bool) *Object.Object {
    const new_boolean_obj = allocator.create(Object.Boolean) catch @panic("OOM");
    new_boolean_obj.value = value;

    const new_obj = allocator.create(Object.Object) catch @panic("OOM");
    new_obj.* = Object.Object{ .boolean = new_boolean_obj };
    return new_obj;
}

fn createObjectNull(allocator: std.mem.Allocator) *Object.Object {
    const new_null_obj = allocator.create(Object.Null) catch @panic("OOM");

    const new_obj = allocator.create(Object.Object) catch @panic("OOM");
    new_obj.* = Object.Object{ .null = new_null_obj };
    return new_obj;
}

test "TestEnvironment" {
    const Evaluator = @import("Evaluator.zig");
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "let a = 5; let b = 10; a + b;", 15 },
        .{ "b - a;", 5 },
        .{ "let c = a * b; a + b + c;", 65 },
        .{ "let a = 50; let b = a; a + b;", 100 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const env = init(allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(allocator, lexer);
        const node = parser.parseProgram();

        Parser.checkParserErrors(parser);

        var evaluator = Evaluator.init(allocator);

        const result = evaluator.eval(node, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}
