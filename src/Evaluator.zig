const std = @import("std");

const Allocation = @import("Allocation.zig");
const Ast = @import("Ast.zig");
const Environment = @import("Environment.zig");
const Object = @import("Object.zig");

pub var allocator: std.mem.Allocator = undefined;

pub fn init(evaluator_allocator: std.mem.Allocator) void {
    allocator = evaluator_allocator;
}

pub fn eval(node: *Ast.Node, env: *Environment) anyerror!?*Object.Object {
    switch (node.*) {
        .program => {
            return evalProgram(node, env);
        },
        .statement => |x| {
            switch (x.*) {
                .return_statement => |y| {
                    const new_node = try Allocation.createNode(allocator);
                    new_node.* = .{ .expression = y.return_value };

                    const result = try eval(new_node, env);
                    if (isError(result)) {
                        return result;
                    }

                    const new_return_value_obj = try Allocation.createReturnValue(allocator);
                    new_return_value_obj.value = result.?;

                    const new_obj = try Allocation.createObject(allocator);
                    new_obj.* = .{ .return_value = new_return_value_obj };

                    return new_obj;
                },
                .expression_statement => |y| {
                    const new_node = try Allocation.createNode(allocator);
                    new_node.* = .{ .expression = y.expression };

                    return eval(new_node, env);
                },
                .let_statement => |y| {
                    const new_node = try Allocation.createNode(allocator);
                    new_node.* = .{ .expression = y.value };

                    const result = try eval(new_node, env);
                    if (isError(result)) {
                        return result;
                    }
                    try env.set(y.name.value, result.?);
                },
                else => unreachable,
            }
        },
        .expression => |x| {
            switch (x.*) {
                .integer_literal => |y| {
                    const new_integer_obj = try Allocation.createInteger(allocator);
                    new_integer_obj.value = y.value;

                    const new_obj = try Allocation.createObject(allocator);
                    new_obj.* = .{ .integer = new_integer_obj };

                    return new_obj;
                },
                .prefix_expression => |y| {
                    const new_right_node = try Allocation.createNode(allocator);
                    new_right_node.* = .{ .expression = y.right };

                    const right = try eval(new_right_node, env);
                    if (isError(right)) {
                        return right;
                    }
                    return try evalPrefixExpression(y.operator, right.?);
                },
                .infix_expression => |y| {
                    // left
                    const new_left_node = try Allocation.createNode(allocator);
                    new_left_node.* = .{ .expression = y.left };

                    const left = try eval(new_left_node, env);
                    if (isError(left)) {
                        return left;
                    }
                    // rigth
                    const new_right_node = try Allocation.createNode(allocator);
                    new_right_node.* = .{ .expression = y.right };

                    const right = try eval(new_right_node, env);
                    if (isError(right)) {
                        return right;
                    }

                    return try evalInfixExpression(y.operator, left.?, right.?);
                },
                .boolean => |y| {
                    return nativeBoolToBooleanObject(y.value);
                },
                .if_expression => |y| {
                    return evalIfExpression(y, env);
                },
                .identifier => |y| {
                    return evalIdentifier(y, env);
                },
                .function_literal => |y| {
                    const new_function_obj = try Allocation.createFunction(allocator);
                    new_function_obj.parameters = y.parameters;
                    new_function_obj.body = y.body;
                    new_function_obj.env = env;

                    const new_obj = try Allocation.createObject(allocator);
                    new_obj.* = .{ .function = new_function_obj };
                    return new_obj;
                },
                .call_expression => |y| {
                    const new_node = try Allocation.createNode(allocator);
                    new_node.* = .{ .expression = y.function };

                    const result = try eval(new_node, env);

                    if (isError(result)) {
                        return result.?;
                    }

                    const args = try evalExpressions(y.arguments, env);

                    if (args.items.len == 1 and isError(args.items[0])) {
                        return args.items[0];
                    }
                    return applyFunction(env, result.?, args);
                },
                .string_literal => |y| {
                    const new_string_obj = try Allocation.createString(allocator);
                    new_string_obj.value = y.value;

                    const new_obj = try Allocation.createObject(allocator);
                    new_obj.* = .{ .string = new_string_obj };

                    return new_obj;
                },
                .array_literal => |y| {
                    const elements = try evalExpressions(y.elements, env);
                    if (elements.items.len == 1 and isError(elements.items[0])) {
                        return elements.items[0];
                    }

                    const new_array_obj = try Allocation.createArray(allocator);
                    new_array_obj.elements = elements;

                    const new_obj = try Allocation.createObject(allocator);
                    new_obj.* = .{ .array = new_array_obj };

                    return new_obj;
                },
                .index_expression => |y| {
                    // left
                    const new_left_node = try Allocation.createNode(allocator);
                    new_left_node.* = .{ .expression = y.left };

                    const left = try eval(new_left_node, env);
                    if (isError(left)) {
                        return left;
                    }
                    // index
                    const new_index_node = try Allocation.createNode(allocator);
                    new_index_node.* = .{ .expression = y.index };

                    const index = try eval(new_index_node, env);
                    if (isError(index)) {
                        return index;
                    }

                    return evalIndexExpression(left.?, index.?);
                },
                .hash_literal => |y| {
                    return evalHashLiteral(y, env);
                },
                else => {},
            }
        },
    }
    return null;
}

fn evalProgram(node: *Ast.Node, env: *Environment) anyerror!?*Object.Object {
    var result: ?*Object.Object = null;

    for (node.program.statements.items) |stmt| {
        const new_node = try Allocation.createNode(allocator);
        new_node.* = .{ .statement = stmt };

        result = try eval(new_node, env);

        if (result == null) continue;

        switch (result.?.*) {
            .return_value => |x| return x.value,
            .@"error" => return result.?,
            else => {},
        }
    }
    return result;
}

fn evalBlockStatement(bs: *Ast.BlockStatement, env: *Environment) anyerror!*Object.Object {
    var result: ?*Object.Object = undefined;
    for (bs.statements.items) |stmt| {
        const new_node = try Allocation.createNode(allocator);
        new_node.* = .{ .statement = stmt };

        result = try eval(new_node, env);

        if (result) |r| {
            const rt = r.getType();
            if (std.mem.eql(u8, rt, Object.RETURN_VALUE_OBJ) or std.mem.eql(u8, rt, Object.ERROR_OBJ)) {
                return r;
            }
        }
    }

    return result.?;
}

fn evalIntegerLiteral(il: *Ast.IntegerLiteral) *Object.Object {
    const new_integer_obj = try Allocation.createInteger(allocator);
    new_integer_obj.value = il.value;

    const new_obj = try Allocation.createObject(allocator);
    new_obj.* = .{ .integer = new_integer_obj };
    return new_obj;
}

fn evalPrefixExpression(operator: []const u8, right: *Object.Object) anyerror!*Object.Object {
    if (std.mem.eql(u8, operator, "!")) {
        return evalPrefixBangExpression(right);
    } else if (std.mem.eql(u8, operator, "-")) {
        return evalPrefixMinusExpression(right);
    } else {
        return try Allocation.createError(allocator, "unknown operator: {s}{s}", .{ operator, right.getType() });
    }
}

fn evalPrefixBangExpression(right: *Object.Object) *Object.Object {
    if (right == Environment.TRUE) return Environment.FALSE;
    if (right == Environment.FALSE) return Environment.TRUE;
    if (right == Environment.NULL) return Environment.TRUE;
    return Environment.FALSE;
}

fn evalPrefixMinusExpression(right: *Object.Object) anyerror!*Object.Object {
    if (!std.mem.eql(u8, right.getType(), Object.INTEGER_OBJ)) {
        return try Allocation.createError(allocator, "unknown operator: -{s}", .{right.getType()});
    }

    const value = right.integer.value;

    const new_integer_obj = try Allocation.createInteger(allocator);
    new_integer_obj.value = -value;

    const new_obj = try Allocation.createObject(allocator);
    new_obj.* = .{ .integer = new_integer_obj };
    return new_obj;
}

fn evalInfixExpression(op: []const u8, left: *Object.Object, right: *Object.Object) anyerror!*Object.Object {
    if (std.mem.eql(u8, left.getType(), Object.INTEGER_OBJ) and
        std.mem.eql(u8, right.getType(), Object.INTEGER_OBJ))
    {
        return try evalIntegerInfixExpression(op, left, right);
    } else if (std.mem.eql(u8, left.getType(), Object.STRING_OBJ) and
        std.mem.eql(u8, right.getType(), Object.STRING_OBJ))
    {
        return evalStringInfixExpression(op, left, right);
    } else if (std.mem.eql(u8, op, "==")) {
        return nativeBoolToBooleanObject(left.boolean.value == right.boolean.value);
    } else if (std.mem.eql(u8, op, "!=")) {
        return nativeBoolToBooleanObject(left.boolean.value != right.boolean.value);
    } else if (!std.mem.eql(u8, left.getType(), right.getType())) {
        return try Allocation.createError(allocator, "type mismatch: {s} {s} {s}", .{ left.getType(), op, right.getType() });
    } else {
        return try Allocation.createError(allocator, "unknown operator: {s} {s} {s}", .{ left.getType(), op, right.getType() });
    }
}

fn evalIntegerInfixExpression(op: []const u8, left: *Object.Object, right: *Object.Object) anyerror!*Object.Object {
    switch (op[0]) {
        '+' => {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = left.integer.value + right.integer.value;

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = .{ .integer = new_integer_obj };

            return new_obj;
        },
        '-' => {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = left.integer.value - right.integer.value;

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = .{ .integer = new_integer_obj };

            return new_obj;
        },
        '*' => {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = left.integer.value * right.integer.value;

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = .{ .integer = new_integer_obj };

            return new_obj;
        },
        '/' => {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = @divTrunc(left.integer.value, right.integer.value);

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = .{ .integer = new_integer_obj };

            return new_obj;
        },
        '<' => {
            return nativeBoolToBooleanObject(left.integer.value < right.integer.value);
        },
        '>' => {
            return nativeBoolToBooleanObject(left.integer.value > right.integer.value);
        },
        else => {
            if (std.mem.eql(u8, op, "==")) {
                return nativeBoolToBooleanObject(left.integer.value == right.integer.value);
            }
            if (std.mem.eql(u8, op, "!=")) {
                return nativeBoolToBooleanObject(left.integer.value != right.integer.value);
            }
            return try Allocation.createError(allocator, "unknown operator: {s} {s} {s}", .{ left.getType(), op, right.getType() });
        },
    }
}

fn evalStringInfixExpression(op: []const u8, left: *Object.Object, right: *Object.Object) anyerror!*Object.Object {
    if (!std.mem.eql(u8, op, "+")) {
        return try Allocation.createError(allocator, "unknown operator: {s} {s} {s}", .{ left.getType(), op, right.getType() });
    }

    const slice = &[_][]const u8{ left.string.value, right.string.value };
    const s = try std.mem.concat(allocator, u8, slice);

    const new_string_obj = try Allocation.createString(allocator);
    new_string_obj.value = s;

    const new_obj = try Allocation.createObject(allocator);
    new_obj.* = .{ .string = new_string_obj };

    return new_obj;
}

fn evalIfExpression(ie: *Ast.IfExpression, env: *Environment) anyerror!*Object.Object {
    const new_node = try Allocation.createNode(allocator);
    new_node.* = .{ .expression = ie.condition };

    const condition = try eval(new_node, env);
    if (isError(condition)) {
        return condition.?;
    }
    if (isTruthy(condition.?)) {
        return evalBlockStatement(ie.consequence, env);
    } else if (ie.alternative) |alt| {
        return evalBlockStatement(alt, env);
    } else {
        return Environment.NULL;
    }
}

fn evalIdentifier(ident: *Ast.Identifier, env: *Environment) anyerror!*Object.Object {
    const value = env.get(ident.value);
    if (value != null) {
        return value.?;
    }
    const builtin = try Environment.getBuiltinFunction(ident.value);
    if (builtin != null) {
        return builtin.?;
    }
    return try Allocation.createError(allocator, "identifier not found: {s}", .{ident.value});
}

fn evalExpressions(exps: std.ArrayList(*Ast.Expression), env: *Environment) anyerror!std.ArrayList(*Object.Object) {
    var result: std.ArrayList(*Object.Object) = .empty;
    for (exps.items) |e| {
        const new_node = try Allocation.createNode(allocator);
        new_node.* = .{ .expression = e };

        if (try eval(new_node, env)) |evaluated| {
            if (isError(evaluated)) {
                try result.append(allocator, evaluated);
                return result;
            }
            try result.append(allocator, evaluated);
        }
    }
    return result;
}

fn applyFunction(env: *Environment, func: *Object.Object, args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    switch (func.*) {
        .function => |x| {
            const extended_env = try extendFunctionEnv(env, x, args);
            const evaluated = try evalBlockStatement(x.body, extended_env);
            return unwrapReturnValue(evaluated);
        },
        .builtin => |x| {
            return x.function(args);
        },
        else => return try Allocation.createError(allocator, "not a function: {s}", .{func.getType()}),
    }
}

fn extendFunctionEnv(env: *Environment, func: *Object.Function, args: std.ArrayList(*Object.Object)) anyerror!*Environment {
    const new_env = try env.newEnclosedEnvironment(func.env);
    for (func.parameters.items, 0..) |param, param_idx| {
        try new_env.set(param.value, args.items[param_idx]);
    }
    return new_env;
}

fn unwrapReturnValue(obj: *Object.Object) *Object.Object {
    return switch (obj.*) {
        .return_value => |x| x.value,
        else => obj,
    };
}

fn evalIndexExpression(left: *Object.Object, index: *Object.Object) anyerror!*Object.Object {
    if (std.mem.eql(u8, left.getType(), Object.ARRAY_OBJ) and
        std.mem.eql(u8, index.getType(), Object.INTEGER_OBJ))
    {
        return evalArrayIndexExpression(left, index);
    } else if (std.mem.eql(u8, left.getType(), Object.HASH_OBJ)) {
        return evalHashIndexExpression(left, index);
    } else {
        return try Allocation.createError(allocator, "index operator not supported: {s}", .{left.getType()});
    }
}

fn evalArrayIndexExpression(array: *Object.Object, index: *Object.Object) *Object.Object {
    const array_obj = array.array;
    const idx = index.integer.value;
    const max: i64 = @intCast(array_obj.elements.items.len - 1);

    if (idx < 0 or idx > max) {
        return Environment.NULL;
    }

    return array_obj.elements.items[@intCast(idx)];
}

fn evalHashLiteral(node: *Ast.HashLiteral, env: *Environment) anyerror!*Object.Object {
    var pairs = std.HashMap(Object.HashKey, Object.HashPair, Object.Context, std.hash_map.default_max_load_percentage).init(allocator);

    var iterator = node.pairs.iterator();
    while (iterator.next()) |entry| {
        const key_node = entry.key_ptr.*;
        const value_node = entry.value_ptr.*;

        const new_key_node = try Allocation.createNode(allocator);
        new_key_node.* = .{ .expression = key_node };
        var key = try eval(new_key_node, env);

        if (isError(key)) {
            return key.?;
        }

        var hk: Object.Object = undefined;
        switch (key.?.*) {
            .boolean => |x| hk = Object.Object{ .boolean = x },
            .integer => |x| hk = Object.Object{ .integer = x },
            .string => |x| hk = Object.Object{ .string = x },
            else => return try Allocation.createError(allocator, "unusable as hash key: {s}", .{key.?.getType()}),
        }

        const new_value_node = try Allocation.createNode(allocator);
        new_value_node.* = .{ .expression = value_node };
        const value = try eval(new_value_node, env);

        if (isError(value)) {
            return value.?;
        }

        const hashed = Object.hashKey(hk);
        try pairs.put(hashed, .{
            .key = key.?,
            .value = value.?,
        });
    }

    const new_hash_obj = try Allocation.createHash(allocator);
    new_hash_obj.pairs = pairs;

    const new_obj = try Allocation.createObject(allocator);
    new_obj.* = .{ .hash = new_hash_obj };
    return new_obj;
}

fn evalHashIndexExpression(hash: *Object.Object, index: *Object.Object) anyerror!*Object.Object {
    const hash_obj = hash.hash;

    var key: Object.Object = undefined;
    switch (index.*) {
        .boolean => |x| key = Object.Object{ .boolean = x },
        .integer => |x| key = Object.Object{ .integer = x },
        .string => |x| key = Object.Object{ .string = x },
        else => return try Allocation.createError(allocator, "unusable as hash key: {s}", .{index.getType()}),
    }
    const pair = hash_obj.pairs.get(Object.hashKey(key)) orelse return Environment.NULL;
    return pair.value;
}

fn isTruthy(obj: *Object.Object) bool {
    if (obj == Environment.NULL) {
        return false;
    }
    if (obj == Environment.TRUE) {
        return true;
    }
    if (obj == Environment.FALSE) {
        return false;
    }
    return true;
}

fn nativeBoolToBooleanObject(input: bool) *Object.Object {
    if (input) {
        return Environment.TRUE;
    } else {
        return Environment.FALSE;
    }
}

fn isError(obj: ?*Object.Object) bool {
    if (obj) |value| {
        return std.mem.eql(u8, value.getType(), Object.ERROR_OBJ);
    } else {
        return false;
    }
}

// tests

test "TestEvalIntegerExpression" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "5", 5 },
        .{ "10;", 10 },

        .{ "-5", -5 },
        .{ "-10", -10 },

        .{ "5 + 5 + 5 + 5 - 10", 10 },
        .{ "2 * 2 * 2 * 2 * 2", 32 },
        .{ "-50 + 100 + -50", 0 },
        .{ "5 * 2 + 10", 20 },
        .{ "5 + 2 * 10", 25 },
        .{ "20 + 2 * -10", 0 },
        .{ "50 / 2 * 2 + 10", 60 },
        .{ "2 * (5 + 10)", 30 },
        .{ "3 * 3 * 3 + 10", 37 },
        .{ "3 * (3 * 3) + 10", 37 },
        .{ "(5 + 10 * 2 + 15 / 3) * 2 + -10", 50 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestEvalBooleanExpression" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{ "true", true },
        .{ "false;", false },

        .{ "1 < 2", true },
        .{ "1 > 2", false },
        .{ "1 < 1", false },
        .{ "1 > 1", false },
        .{ "1 == 1", true },
        .{ "1 != 1", false },
        .{ "1 == 2", false },
        .{ "1 != 2", true },

        .{ "true == true", true },
        .{ "false == false", true },
        .{ "true == false", false },
        .{ "true != false", true },
        .{ "false != true", true },
        .{ "(1 < 2) == true", true },
        .{ "(1 < 2) == false", false },
        .{ "(1 > 2) == true", false },
        .{ "(1 > 2) == false", true },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.boolean.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestBangOperator" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        bool,
    };
    const tests = [_]Test{
        .{ "!true", false },
        .{ "!false", true },
        .{ "!5", false },
        .{ "!!true", true },
        .{ "!!false", false },
        .{ "!!5", true },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.boolean.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestIfElseExpressions" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const null_value = -256;
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "if (true) { 10 }", 10 },
        .{ "if (false) { 10 }", null_value },
        .{ "if (1) { 10 }", 10 },
        .{ "if (1 < 2) { 10 }", 10 },
        .{ "if (1 > 2) { 10 }", null_value },
        .{ "if (1 > 2) { 10 } else { 20 }", 20 },
        .{ "if (1 < 2) { 10 } else { 20 }", 10 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            switch (result.?.*) {
                .integer => |x| {
                    const actual = x.value;
                    try std.testing.expectEqual(expected, actual);
                },
                .null => {
                    try std.testing.expectEqual(expected, null_value);
                },
                else => unreachable,
            }
        }
    }
}

test "TestReturnStatements" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "return 10;", 10 },
        .{ "return 10; 9;", 10 },
        .{ "return 2 * 5; 9;", 10 },
        .{ "9; return 2 * 5; 9;", 10 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestErrorHandling" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        []const u8,
    };
    const tests = [_]Test{
        .{
            "5 + true;",
            "type mismatch: INTEGER + BOOLEAN",
        },
        .{
            "5 + true; 5;",
            "type mismatch: INTEGER + BOOLEAN",
        },
        .{
            "-true",
            "unknown operator: -BOOLEAN",
        },
        .{
            "true + false;",
            "unknown operator: BOOLEAN + BOOLEAN",
        },
        .{
            "5; true + false; 5",
            "unknown operator: BOOLEAN + BOOLEAN",
        },
        .{
            "if (10 > 1) { true + false; }",
            "unknown operator: BOOLEAN + BOOLEAN",
        },
        .{
            \\if (10 > 1) {
            \\  if (10 > 1) {
            \\    return true + false;
            \\  }
            \\  return 1;
            \\}
            ,
            "unknown operator: BOOLEAN + BOOLEAN",
        },
        .{
            "foobar",
            "identifier not found: foobar",
        },
        .{
            "\"Hello\" - \"World\"",
            "unknown operator: STRING - STRING",
        },
        .{
            "{\"name\": \"Monkey\"}[fn(x) { x }];",
            "unusable as hash key: FUNCTION",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.@"error".message;
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}

test "TestLetStatements" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "let a = 5; a;", 5 },
        .{ "let a = 5 * 5; a;", 25 },
        .{ "let a = 5; let b = a; b;", 5 },
        .{ "let a = 5; let b = a; let c = a + b + 5; c;", 15 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestFunctionObject" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const input = "fn(x) { x + 2; };";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const result = try eval(node_program, env);

    {
        const expected = 1;
        const actual = result.?.function.parameters.items.len;
        try std.testing.expectEqual(expected, actual);
    }

    {
        const expected = "x";
        const actual = result.?.function.parameters.items[0].value;
        try std.testing.expectEqualStrings(expected, actual);
    }

    {
        const expected = "(x + 2)";
        var buffer: [256]u8 = undefined;
        var buffer_writer = std.Io.Writer.fixed(&buffer);
        try result.?.function.body.string(&buffer_writer);
        const actual = buffer_writer.buffered();
        try std.testing.expectEqualStrings(expected, actual);
    }
}

test "TestFunctionApplication" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{ "let identity = fn(x) { x; }; identity(5);", 5 },
        .{ "let identity = fn(x) { return x; }; identity(5);", 5 },
        .{ "let double = fn(x) { x * 2; }; double(5);", 10 },
        .{ "let add = fn(x, y) { x + y; }; add(5, 5);", 10 },
        .{ "let add = fn(x, y) { x + y; }; add(5 + 5, add(5, 5));", 20 },
        .{ "fn(x) { x; }(5)", 5 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            const actual = result.?.integer.value;
            try std.testing.expectEqual(expected, actual);
        }
    }
}

test "TestClosures" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const input =
        \\let newAdder = fn(x) {
        \\  fn(y) { x + y };
        \\};
        \\
        \\let addTwo = newAdder(2);
        \\addTwo(2);
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const result = try eval(node_program, env);

    {
        const expected: i64 = 4;
        const actual = result.?.integer.value;
        try std.testing.expectEqual(expected, actual);
    }
}

test "TestStringLiteral" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const input =
        \\"Hello World!"
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const result = try eval(node_program, env);

    {
        const expected = "Hello World!";
        const actual = result.?.string.value;
        try std.testing.expectEqualStrings(expected, actual);
    }
}

test "TestStringConcatenation" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const input =
        \\"Hello" + " " + "World!";
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const result = try eval(node_program, env);

    {
        const expected = "Hello World!";
        const actual = result.?.string.value;
        try std.testing.expectEqualStrings(expected, actual);
    }
}

test "TestBuiltinFunctions" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const Types1 = union(enum) {
        string: []const u8,
        integer: i64,
    };
    const Test = struct {
        []const u8,
        Types1,
    };
    const tests = [_]Test{
        .{ "len(\"\")", .{ .integer = 0 } },
        .{ "len(\"four\")", .{ .integer = 4 } },
        .{ "len(\"hello world\")", .{ .integer = 11 } },
        .{ "len(1)", .{ .string = "argument to `len` not supported, got INTEGER" } },
        .{ "len(\"one\", \"two\")", .{ .string = "wrong number of arguments. got=2, want=1" } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            switch (result.?.*) {
                .integer => |x| {
                    const expected = t[1].integer;
                    const actual = x.value;
                    try std.testing.expectEqual(expected, actual);
                },
                .@"error" => |x| {
                    const expected = t[1].string;
                    const actual = x.message;
                    try std.testing.expectEqualStrings(expected, actual);
                },
                else => unreachable,
            }
        }
    }
}

test "TestArrayLiterals" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const input = "[1, 2 * 2, 3 + 3]";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const result = try eval(node_program, env);

    {
        const expected: i64 = 1;
        const actual = result.?.array.elements.items[0].integer.value;
        try std.testing.expectEqual(expected, actual);
    }
    {
        const expected: i64 = 4;
        const actual = result.?.array.elements.items[1].integer.value;
        try std.testing.expectEqual(expected, actual);
    }
    {
        const expected: i64 = 6;
        const actual = result.?.array.elements.items[2].integer.value;
        try std.testing.expectEqual(expected, actual);
    }
}

test "TestArrayIndexExpressions" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const null_value = -256;
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            "[1, 2, 3][0]",
            1,
        },
        .{
            "[1, 2, 3][1]",
            2,
        },
        .{
            "[1, 2, 3][2]",
            3,
        },
        .{
            "let i = 0; [1][i];",
            1,
        },
        .{
            "[1, 2, 3][1 + 1];",
            3,
        },
        .{
            "let myArray = [1, 2, 3]; myArray[2];",
            3,
        },
        .{
            "let myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];",
            6,
        },
        .{
            "let myArray = [1, 2, 3]; let i = myArray[0]; myArray[i]",
            2,
        },
        .{
            "[1, 2, 3][3]",
            null_value,
        },
        .{
            "[1, 2, 3][-1]",
            null_value,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            switch (result.?.*) {
                .integer => |x| {
                    const actual = x.value;
                    try std.testing.expectEqual(expected, actual);
                },
                .null => {
                    try std.testing.expectEqual(expected, null_value);
                },
                else => unreachable,
            }
        }
    }
}

test "TestHashLiterals" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const HashType = std.HashMap(Object.HashKey, i64, Object.Context, std.hash_map.default_max_load_percentage);
    const S = struct {
        var obj1: Object.Object = undefined;
        var obj2: Object.Object = undefined;
        var obj3: Object.Object = undefined;
        var obj4: Object.Object = undefined;
        var obj5: Object.Object = undefined;
        var obj6: Object.Object = undefined;
        fn createHashMap(a: std.mem.Allocator) anyerror!HashType {
            obj1 = blk: {
                const new_string_obj = try a.create(Object.String);
                new_string_obj.value = "one";
                break :blk Object.Object{ .string = new_string_obj };
            };
            obj2 = blk: {
                const new_string_obj = try a.create(Object.String);
                new_string_obj.value = "two";
                break :blk Object.Object{ .string = new_string_obj };
            };
            obj3 = blk: {
                const new_string_obj = try a.create(Object.String);
                new_string_obj.value = "three";
                break :blk Object.Object{ .string = new_string_obj };
            };
            obj4 = blk: {
                const new_integer_obj = try a.create(Object.Integer);
                new_integer_obj.value = 4;
                break :blk Object.Object{ .integer = new_integer_obj };
            };
            obj5 = blk: {
                const new_boolean_obj = try a.create(Object.Boolean);
                new_boolean_obj.value = true;
                break :blk Object.Object{ .boolean = new_boolean_obj };
            };
            obj6 = blk: {
                const new_boolean_obj = try a.create(Object.Boolean);
                new_boolean_obj.value = false;
                break :blk Object.Object{ .boolean = new_boolean_obj };
            };

            var hash = std.HashMap(Object.HashKey, i64, Object.Context, std.hash_map.default_max_load_percentage).init(a);
            try hash.put(Object.hashKey(obj1), 1);
            try hash.put(Object.hashKey(obj1), 1);
            try hash.put(Object.hashKey(obj2), 2);
            try hash.put(Object.hashKey(obj3), 3);
            try hash.put(Object.hashKey(obj4), 4);
            try hash.put(Object.hashKey(obj5), 5);
            try hash.put(Object.hashKey(obj6), 6);
            return hash;
        }
    };
    const input =
        \\     let two = "two";
        \\ {
        \\     "one": 10 - 9,
        \\     two: 1 + 1,
        \\     "thr" + "ee": 6 / 2,
        \\     4: 4,
        \\     true: 5,
        \\     false: 6
        \\ }
    ;

    const env = try Environment.init(arena_allocator);

    const lexer = Lexer.init(input);
    var parser = try Parser.init(arena_allocator, lexer);
    const node_program = try parser.parseProgram();

    Parser.checkParserErrors(parser);

    init(arena_allocator);

    const evaluated = try eval(node_program, env);
    const result = evaluated.?.hash;

    var expected = try S.createHashMap(arena_allocator);

    try std.testing.expectEqual(expected.count(), result.pairs.count());

    var iterator = expected.iterator();
    while (iterator.next()) |entry| {
        const expected_key = entry.key_ptr.*;
        const expected_value = entry.value_ptr.*;

        const pair = result.pairs.get(expected_key).?;
        try std.testing.expectEqual(expected_value, pair.value.integer.value);
    }
}

test "TestHashIndexExpressions" {
    const Lexer = @import("Lexer.zig");
    const Parser = @import("Parser.zig");

    const null_value = -256;
    const Test = struct {
        []const u8,
        i64,
    };
    const tests = [_]Test{
        .{
            "{\"foo\": 5}[\"foo\"]",
            5,
        },
        .{
            "{\"foo\": 5}[\"bar\"]",
            null_value,
        },
        .{
            "let key = \"foo\"; {\"foo\": 5}[key]",
            5,
        },
        .{
            "{}[\"foo\"]",
            null_value,
        },
        .{
            "{5: 5}[5]",
            5,
        },
        .{
            "{true: 5}[true]",
            5,
        },
        .{
            "{false: 5}[false]",
            5,
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const arena_allocator = arena.allocator();

    const env = try Environment.init(arena_allocator);

    for (tests) |t| {
        const lexer = Lexer.init(t[0]);
        var parser = try Parser.init(arena_allocator, lexer);
        const node_program = try parser.parseProgram();

        Parser.checkParserErrors(parser);

        init(arena_allocator);

        const result = try eval(node_program, env);

        {
            const expected = t[1];
            switch (result.?.*) {
                .integer => |x| {
                    const actual = x.value;
                    try std.testing.expectEqual(expected, actual);
                },
                .null => {
                    try std.testing.expectEqual(expected, null_value);
                },
                else => unreachable,
            }
        }
    }
}
