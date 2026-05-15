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

pub fn init(allocator: std.mem.Allocator) anyerror!*Environment {
    TRUE = blk: {
        const new_boolean_obj = try allocator.create(Object.Boolean);
        new_boolean_obj.value = true;

        const new_obj = try allocator.create(Object.Object);
        new_obj.* = .{ .boolean = new_boolean_obj };
        break :blk new_obj;
    };

    FALSE = blk: {
        const new_boolean_obj = try allocator.create(Object.Boolean);
        new_boolean_obj.value = false;

        const new_obj = try allocator.create(Object.Object);
        new_obj.* = .{ .boolean = new_boolean_obj };
        break :blk new_obj;
    };

    NULL = blk: {
        const new_null_obj = try allocator.create(Object.Null);

        const new_obj = try allocator.create(Object.Object);
        new_obj.* = .{ .null = new_null_obj };
        break :blk new_obj;
    };

    try Builtins.init(allocator);

    const env = try allocator.create(Environment);
    env.allocator = allocator;
    env.store = std.StringHashMap(*Object.Object).init(allocator);
    env.outer = null;
    return env;
}

pub fn newEnclosedEnvironment(self: *Environment, outer: ?*Environment) anyerror!*Environment {
    const env = try self.allocator.create(Environment);
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

pub fn set(self: *Environment, key: []const u8, value: *Object.Object) anyerror!void {
    const gop = try self.store.getOrPut(key);
    if (!gop.found_existing) {
        gop.key_ptr.* = try self.allocator.dupe(u8, key);
    }
    gop.value_ptr.* = value;
}

pub fn getBuiltinFunction(key: []const u8) anyerror!?*Object.Object {
    return Builtins.bfs_obj_map.get(key);
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

    const env = try init(allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(allocator, lexer);
        const node = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        Evaluator.init(allocator);

        const result = try Evaluator.eval(node, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}
