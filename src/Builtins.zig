const std = @import("std");

const Allocation = @import("Allocation.zig");
const Environment = @import("Environment.zig");
const Object = @import("Object.zig");

const Builtins = @This();

var allocator: std.mem.Allocator = undefined;
pub var bfs_obj_map: std.StringHashMap(*Object.Object) = undefined;
pub const bfs = std.StaticStringMap(Object.BuiltinFunction).initComptime(.{
    .{ "len", builtinFunctionLen },
    .{ "first", builtinFunctionFirst },
    .{ "last", builtinFunctionLast },
    .{ "rest", builtinFunctionRest },
    .{ "push", builtinFunctionPush },
    .{ "puts", builtinFunctionPuts },
});

pub fn init(builtins_allocator: std.mem.Allocator) void {
    allocator = builtins_allocator;
    bfs_obj_map = std.StringHashMap(*Object.Object).init(allocator);

    for (bfs.keys()) |k| {
        const new_builtin_obj = allocator.create(Object.Builtin) catch @panic("OOM");
        new_builtin_obj.function = bfs.get(k).?;

        const new_obj = allocator.create(Object.Object) catch @panic("OOM");
        new_obj.* = Object.Object{ .builtin = new_builtin_obj };

        bfs_obj_map.put(k, new_obj) catch @panic("OOM");
    }
}

// builtin functions

fn builtinFunctionLen(args: std.ArrayList(*Object.Object)) *Object.Object {
    if (args.items.len != 1) {
        return Allocation.createErrorMsg(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    switch (args.items[0].*) {
        .array => |x| {
            const new_integer_obj = allocator.create(Object.Integer) catch @panic("OOM");
            new_integer_obj.value = @intCast(x.elements.items.len);

            const new_obj = allocator.create(Object.Object) catch @panic("OOM");
            new_obj.* = Object.Object{ .integer = new_integer_obj };

            return new_obj;
        },
        .string => |x| {
            const new_integer_obj = allocator.create(Object.Integer) catch @panic("OOM");
            new_integer_obj.value = @intCast(x.value.len);

            const new_obj = allocator.create(Object.Object) catch @panic("OOM");
            new_obj.* = Object.Object{ .integer = new_integer_obj };

            return new_obj;
        },
        else => return Allocation.createErrorMsg(allocator, "argument to `len` not supported, got {s}", .{args.items[0].getType()}),
    }
}

fn builtinFunctionFirst(args: std.ArrayList(*Object.Object)) *Object.Object {
    if (args.items.len != 1) {
        return Allocation.createErrorMsg(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return Allocation.createErrorMsg(allocator, "argument to `first` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    if (arr.elements.items.len > 0) {
        return arr.elements.items[0];
    }

    return Environment.NULL;
}

fn builtinFunctionLast(args: std.ArrayList(*Object.Object)) *Object.Object {
    if (args.items.len != 1) {
        return Allocation.createErrorMsg(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return Allocation.createErrorMsg(allocator, "argument to `last` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;
    if (length > 0) {
        return arr.elements.items[length - 1];
    }

    return Environment.NULL;
}

fn builtinFunctionRest(args: std.ArrayList(*Object.Object)) *Object.Object {
    if (args.items.len != 1) {
        return Allocation.createErrorMsg(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return Allocation.createErrorMsg(allocator, "argument to `rest` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;
    if (length > 0) {
        var new_elements = std.ArrayList(*Object.Object).initCapacity(allocator, length - 1) catch @panic("OOM");
        new_elements.appendSliceAssumeCapacity(arr.elements.items[1..length]);

        const new_array_obj = allocator.create(Object.Array) catch @panic("OOM");
        new_array_obj.elements = new_elements;

        const new_obj = allocator.create(Object.Object) catch @panic("OOM");
        new_obj.* = Object.Object{ .array = new_array_obj };

        return new_obj;
    }

    return Environment.NULL;
}

fn builtinFunctionPush(args: std.ArrayList(*Object.Object)) *Object.Object {
    if (args.items.len != 2) {
        return Allocation.createErrorMsg(allocator, "wrong number of arguments. got={d}, want=2", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return Allocation.createErrorMsg(allocator, "argument to `push` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;

    var new_elements = std.ArrayList(*Object.Object).initCapacity(allocator, length + 1) catch @panic("OOM");
    new_elements.appendSliceAssumeCapacity(arr.elements.items);
    new_elements.items.len = length + 1;
    new_elements.items[length] = args.items[1];

    const new_array_obj = allocator.create(Object.Array) catch @panic("OOM");
    new_array_obj.elements = new_elements;

    const new_obj = allocator.create(Object.Object) catch @panic("OOM");
    new_obj.* = Object.Object{ .array = new_array_obj };

    return new_obj;
}

fn builtinFunctionPuts(args: std.ArrayList(*Object.Object)) *Object.Object {
    var stdout_buf: [1024]u8 = undefined;
    var stdout: std.Io.Writer = .fixed(&stdout_buf);
    for (args.items) |arg| {
        // TODO
        arg.inspect(&stdout) catch {};
        stdout.writeByte('\n') catch {};
    }

    return Environment.NULL;
}
