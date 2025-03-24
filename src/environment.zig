const std = @import("std");
const typing = @import("typing.zig");
const tknzr = @import("tokenizer.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const String = []const u8;
const Object = typing.Object;
const Token = tknzr.Token;

const Error = error{
    undefined_variable,
    OutOfMemory,
};

pub const Environment = struct {
    stack: ArrayList(EnvNode),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Allocator.Error!Environment {
        var env = Environment{
            .stack = ArrayList(EnvNode).init(allocator),
            .allocator = allocator,
        };
        try env.push_scope();

        return env;
    }

    pub fn get(self: *Environment, name: String) ?Object {
        const number_of_envs = self.stack.items.len;

        for (1..number_of_envs + 1) |current_env| {
            const env = self.stack.items[number_of_envs - current_env].values;
            var iter = env.keyIterator();
            while (iter.next()) |key| {
                _ = key;
                //std.debug.print("{s}\n", .{key.*});
            }
            if (self.stack.items[number_of_envs - current_env].values.get(name)) |value|
                return value;
        }

        return null;
    }

    pub fn assign(self: *Environment, name: String, value: Object) Error!void {
        std.debug.assert(self.stack.items.len > 0);
        const number_of_envs = self.stack.items.len;

        for (1..number_of_envs + 1) |current_env| {
            var current = self.stack.items[number_of_envs - current_env];
            if (current.values.contains(name)) {
                try current.values.put(name, value);
                return;
            }
        }

        return Error.undefined_variable;
    }

    pub fn define(self: *Environment, name: String, value: Object) Allocator.Error!void {
        //std.debug.print("define: {s}\n", .{name});
        try self.stack.items[self.stack.items.len - 1].values.put(name, value);
    }

    pub fn push_scope(self: *Environment) Allocator.Error!void {
        try self.stack.append(EnvNode{ .values = StringHashMap(Object).init(self.allocator) });
    }

    pub fn pop_scope(self: *Environment) void {
        std.debug.assert(self.stack.items.len > 1);
        var env = self.stack.pop();
        env.values.deinit();
    }
};

const EnvNode = struct {
    values: StringHashMap(Object),
};
