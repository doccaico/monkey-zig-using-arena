const std = @import("std");

const Ast = @import("Ast.zig");
const Object = @import("Object.zig");

pub inline fn createNode(allocator: std.mem.Allocator) *Ast.Node {
    const new_node = allocator.create(Ast.Node) catch @panic("OOM");
    return new_node;
}

pub inline fn createObject(allocator: std.mem.Allocator) *Object.Object {
    const new_obj = allocator.create(Object.Object) catch @panic("OOM");
    return new_obj;
}

pub inline fn createReturnValue(allocator: std.mem.Allocator) *Object.ReturnValue {
    const new_obj = allocator.create(Object.ReturnValue) catch @panic("OOM");
    return new_obj;
}

pub inline fn createInteger(allocator: std.mem.Allocator) *Object.Integer {
    const new_obj = allocator.create(Object.Integer) catch @panic("OOM");
    return new_obj;
}

pub inline fn createFunction(allocator: std.mem.Allocator) *Object.Function {
    const new_obj = allocator.create(Object.Function) catch @panic("OOM");
    return new_obj;
}

pub inline fn createString(allocator: std.mem.Allocator) *Object.String {
    const new_obj = allocator.create(Object.String) catch @panic("OOM");
    return new_obj;
}

pub inline fn createArray(allocator: std.mem.Allocator) *Object.Array {
    const new_obj = allocator.create(Object.Array) catch @panic("OOM");
    return new_obj;
}

pub inline fn createHash(allocator: std.mem.Allocator) *Object.Hash {
    const new_obj = allocator.create(Object.Hash) catch @panic("OOM");
    return new_obj;
}

pub fn createError(allocator: std.mem.Allocator, comptime format: []const u8, args: anytype) *Object.Object {
    const message = std.fmt.allocPrint(allocator, format, args) catch @panic("OOM");

    const new_error_obj = allocator.create(Object.Error) catch @panic("OOM");
    new_error_obj.message = message;

    const new_obj = createObject(allocator);
    new_obj.* = .{ .@"error" = new_error_obj };
    return new_obj;
}
