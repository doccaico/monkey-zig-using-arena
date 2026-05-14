const std = @import("std");

const Ast = @import("Ast.zig");
const Environment = @import("Environment.zig");
const Object = @import("Object.zig");

pub inline fn createNode(allocator: std.mem.Allocator) anyerror!*Ast.Node {
    const new_node = try allocator.create(Ast.Node);
    return new_node;
}

pub inline fn createEnvironment(allocator: std.mem.Allocator) anyerror!*Environment {
    const new_env = try allocator.create(Environment);
    return new_env;
}

pub inline fn createObject(allocator: std.mem.Allocator) anyerror!*Object.Object {
    const new_obj = try allocator.create(Object.Object);
    return new_obj;
}

pub inline fn createBoolean(allocator: std.mem.Allocator) anyerror!*Object.Boolean {
    const new_obj = try allocator.create(Object.Boolean);
    return new_obj;
}

pub inline fn createNull(allocator: std.mem.Allocator) anyerror!*Object.Null {
    const new_obj = try allocator.create(Object.Null);
    return new_obj;
}

pub inline fn createBuiltin(allocator: std.mem.Allocator) anyerror!*Object.Builtin {
    const new_obj = try allocator.create(Object.Builtin);
    return new_obj;
}

pub inline fn createReturnValue(allocator: std.mem.Allocator) anyerror!*Object.ReturnValue {
    const new_obj = try allocator.create(Object.ReturnValue);
    return new_obj;
}

pub inline fn createInteger(allocator: std.mem.Allocator) anyerror!*Object.Integer {
    const new_obj = try allocator.create(Object.Integer);
    return new_obj;
}

pub inline fn createFunction(allocator: std.mem.Allocator) anyerror!*Object.Function {
    const new_obj = try allocator.create(Object.Function);
    return new_obj;
}

pub inline fn createString(allocator: std.mem.Allocator) anyerror!*Object.String {
    const new_obj = try allocator.create(Object.String);
    return new_obj;
}

pub inline fn createArray(allocator: std.mem.Allocator) anyerror!*Object.Array {
    const new_obj = try allocator.create(Object.Array);
    return new_obj;
}

pub inline fn createHash(allocator: std.mem.Allocator) anyerror!*Object.Hash {
    const new_obj = try allocator.create(Object.Hash);
    return new_obj;
}

pub fn createError(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) anyerror!*Object.Object {
    const message = try std.fmt.allocPrint(allocator, format, args);

    const new_error_obj = try allocator.create(Object.Error);
    new_error_obj.message = message;

    const new_obj = try createObject(allocator);
    new_obj.* = .{ .@"error" = new_error_obj };
    return new_obj;
}
