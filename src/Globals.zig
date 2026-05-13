const std = @import("std");

const Ast = @import("Ast.zig");
const Object = @import("Object.zig");
const Environment = @import("Environment.zig");

var allocator: std.mem.Allocator = undefined;
pub var node_list: std.ArrayList(*Ast.Node) = undefined;
pub var object_list: std.ArrayList(*Object.Object) = undefined;
pub var env_list: std.ArrayList(*Environment) = undefined;
pub var args_list: std.ArrayList(std.ArrayList(*Object.Object)) = undefined;
pub var node_program_list: std.ArrayList(*Ast.Node) = undefined;
pub var line_list: std.ArrayList([]const u8) = undefined;
pub var string_list: std.ArrayList([]const u8) = undefined;

pub fn init(global_allocator: std.mem.Allocator) !void {
    allocator = global_allocator;
    node_list = try .initCapacity(allocator, 0);
    object_list = try .initCapacity(allocator, 0);
    env_list = try .initCapacity(allocator, 0);
    args_list = try .initCapacity(allocator, 0);
    node_program_list = try .initCapacity(allocator, 0);
    line_list = try .initCapacity(allocator, 0);
    string_list = try .initCapacity(allocator, 0);
}

pub fn deinit() void {
    // object_list
    for (object_list.items) |item| {
        switch (item.*) {
            .integer => |x| allocator.destroy(x),
            .boolean => |x| allocator.destroy(x),
            .null => |x| allocator.destroy(x),
            .return_value => |x| allocator.destroy(x),
            .@"error" => |x| {
                allocator.free(x.message);
                allocator.destroy(x);
            },
            .function => |x| allocator.destroy(x),
            .string => |x| allocator.destroy(x),
            .builtin => |x| allocator.destroy(x),
            .array => |x| {
                x.elements.deinit(allocator);
                allocator.destroy(x);
            },
            .hash => |x| {
                x.pairs.deinit();
                allocator.destroy(x);
            },
        }
        allocator.destroy(item);
    }
    object_list.deinit(allocator);

    // node_list
    for (node_list.items) |item| {
        allocator.destroy(item);
    }
    node_list.deinit(allocator);

    // env_list
    for (env_list.items) |item| {
        var iterator = item.store.iterator();
        while (iterator.next()) |entry| {
            item.store.allocator.free(entry.key_ptr.*);
        }

        item.store.deinit();
        allocator.destroy(item);
    }
    env_list.deinit(allocator);

    // args_list
    for (args_list.items) |*item| {
        item.deinit(allocator);
    }
    args_list.deinit(allocator);

    // node_program_list
    for (node_program_list.items) |item| {
        item.deinit();
    }
    node_program_list.deinit(allocator);

    // line_list
    for (line_list.items) |item| {
        allocator.free(item);
    }
    line_list.deinit(allocator);

    // string_list
    for (string_list.items) |item| {
        allocator.free(item);
    }
    string_list.deinit(allocator);
}

pub fn nodeAppend(node: *Ast.Node) void {
    node_list.append(allocator, node) catch @panic("OOM");
}

pub fn objectAppend(obj: *Object.Object) void {
    object_list.append(allocator, obj) catch @panic("OOM");
}

pub fn envAppend(env: *Environment) void {
    env_list.append(allocator, env) catch @panic("OOM");
}

pub fn argsAppend(args: std.ArrayList(*Object.Object)) void {
    args_list.append(allocator, args) catch @panic("OOM");
}

pub fn nodeProgramAppend(node_program: *Ast.Node) void {
    node_program_list.append(allocator, node_program) catch @panic("OOM");
}

pub fn lineAppend(line: []const u8) void {
    line_list.append(allocator, line) catch @panic("OOM");
}

pub fn stringAppend(string: []const u8) void {
    string_list.append(allocator, string) catch @panic("OOM");
}
