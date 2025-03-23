const std = @import("std");
const typing = @import("typing.zig");
const tknzr = @import("tokenizer.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const String = []const u8;
const Object = typing.Object;
const Token = tknzr.Token;

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
        return self.stack.items[self.stack.items.len - 1].values.get(name);
    }

    pub fn define(self: *Environment, name: String, value: Object) Allocator.Error!void {
        try self.stack.items[self.stack.items.len - 1].values.put(name, value);
    }

    pub fn push_scope(self: *Environment) Allocator.Error!void {
        try self.stack.append(EnvNode{ .values = StringHashMap(Object).init(self.allocator) });
    }
};

const EnvNode = struct {
    values: StringHashMap(Object),
};
