const std = @import("std");

const Allocation = @import("Allocation.zig");
const Environment = @import("Environment.zig");
const Object = @import("Object.zig");

var allocator: std.mem.Allocator = undefined;
pub var bfs_obj_map: std.StringHashMap(*Object.Object) = undefined;
pub const bfs = std.StaticStringMap(Object.BuiltinFunction).initComptime(.{
    .{ "len", len },
    .{ "first", first },
    .{ "last", last },
    .{ "rest", rest },
    .{ "push", push },
    .{ "puts", puts },
});

pub fn init(builtins_allocator: std.mem.Allocator) anyerror!void {
    allocator = builtins_allocator;
    bfs_obj_map = std.StringHashMap(*Object.Object).init(allocator);

    for (bfs.keys()) |k| {
        const new_builtin_obj = try Allocation.createBuiltin(allocator);
        new_builtin_obj.function = bfs.get(k).?;

        const new_obj = try Allocation.createObject(allocator);
        new_obj.* = Object.Object{ .builtin = new_builtin_obj };

        try bfs_obj_map.put(k, new_obj);
    }
}

// builtin functions

fn len(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 1) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    switch (args.items[0].*) {
        .array => |x| {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = @intCast(x.elements.items.len);

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = Object.Object{ .integer = new_integer_obj };

            return new_obj;
        },
        .string => |x| {
            const new_integer_obj = try Allocation.createInteger(allocator);
            new_integer_obj.value = @intCast(x.value.len);

            const new_obj = try Allocation.createObject(allocator);
            new_obj.* = Object.Object{ .integer = new_integer_obj };

            return new_obj;
        },
        else => return try Allocation.createError(allocator, "argument to `len` not supported, got {s}", .{args.items[0].getType()}),
    }
}

fn first(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 1) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return try Allocation.createError(allocator, "argument to `first` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    if (arr.elements.items.len > 0) {
        return arr.elements.items[0];
    }
    return Environment.NULL;
}

fn last(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 1) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return try Allocation.createError(allocator, "argument to `last` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;
    if (length > 0) {
        return arr.elements.items[length - 1];
    }
    return Environment.NULL;
}

fn rest(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 1) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return try Allocation.createError(allocator, "argument to `rest` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;
    if (length > 0) {
        var new_elements = try std.ArrayList(*Object.Object).initCapacity(allocator, length - 1);
        new_elements.appendSliceAssumeCapacity(arr.elements.items[1..length]);

        const new_array_obj = try Allocation.createArray(allocator);
        new_array_obj.elements = new_elements;

        const new_obj = try Allocation.createObject(allocator);
        new_obj.* = Object.Object{ .array = new_array_obj };

        return new_obj;
    }
    return Environment.NULL;
}

fn push(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 2) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=2", .{args.items.len});
    }
    if (!std.mem.eql(u8, args.items[0].getType(), Object.ARRAY_OBJ)) {
        return try Allocation.createError(allocator, "argument to `push` must be ARRAY, got {s}", .{args.items[0].getType()});
    }

    const arr = args.items[0].array;
    const length = arr.elements.items.len;

    var new_elements = try std.ArrayList(*Object.Object).initCapacity(allocator, length + 1);
    new_elements.appendSliceAssumeCapacity(arr.elements.items);
    new_elements.items.len = length + 1;
    new_elements.items[length] = args.items[1];

    const new_array_obj = try Allocation.createArray(allocator);
    new_array_obj.elements = new_elements;

    const new_obj = try Allocation.createObject(allocator);
    new_obj.* = Object.Object{ .array = new_array_obj };
    return new_obj;
}

fn puts(args: std.ArrayList(*Object.Object)) anyerror!*Object.Object {
    if (args.items.len != 1) {
        return try Allocation.createError(allocator, "wrong number of arguments. got={d}, want=1", .{args.items.len});
    }

    const obj = args.items[0];
    switch (obj.*) {
        .integer, .string => {
            return obj;
        },
        else => {
            return try Allocation.createError(allocator, "wrong type. got={s}, want={s}, {s}", .{ obj.getType(), Object.INTEGER_OBJ, Object.STRING_OBJ });
        },
    }
    return Environment.NULL;
}
