const std = @import("std");
const ArrayList = std.ArrayList;
const Literal = @import("ast.zig").Expr.Literal;

const TypeError = error{
    invalid_lexeme,
    OutOfMemory,
};

pub const Object = struct {
    id: Type,
    value: Value,

    const Self = @This();

    pub fn from_literal(lexeme: []const u8, typ: Type) TypeError!Self {
        var obj = Object{
            .id = typ,
            .value = undefined,
        };
        switch (typ) {
            .nil => obj.value.nil = null,
            .number => obj.value.number = try Type.Number.init(lexeme),
            .string => obj.value.string = try Type.String.init(lexeme),
            .bool => obj.value.bool = try Type.Bool.init(lexeme),
        }

        return obj;
    }

    pub fn instance_of(self: *const Self, id: Type) bool {
        return id == self.id;
    }

    pub fn equals(self: *const Self, other: Self) bool {
        return if (self.id == other.id)
            switch (self.id) {
                .nil => true,
                .number => self.value.number.value == self.value.number.value,
                .string => std.mem.eql(u8, self.value.string.value.items, other.value.string.value.items),
                .bool => self.value.bool.value == other.value.bool.value,
            }
        else
            false;
    }
};

pub const Value = union(Type) {
    nil: ?void,
    number: Type.Number,
    string: Type.String,
    bool: Type.Bool,
};

pub const Type = enum {
    nil,
    number,
    string,
    bool,

    pub const Number = struct {
        value: f32,

        const Self = @This();

        fn init(lexeme: []const u8) TypeError!Self {
            return if (std.fmt.parseFloat(f32, lexeme)) |n|
                .{ .value = n }
            else |_|
                TypeError.invalid_lexeme;
        }
    };

    pub const String = struct {
        value: ArrayList(u8),

        const Self = @This();

        fn init(lexeme: []const u8) TypeError!Self {
            const allocator = std.heap.page_allocator;
            var value = ArrayList(u8).init(allocator);
            return if (value.appendSlice(lexeme))
                .{ .value = value }
            else |_|
                TypeError.OutOfMemory;
        }
    };

    pub const Bool = struct {
        value: bool,

        const Self = @This();

        fn init(lexeme: []const u8) TypeError!Self {
            return if (std.mem.eql(u8, lexeme, "true"))
                .{ .value = true }
            else if (std.mem.eql(u8, lexeme, "false"))
                .{ .value = false }
            else
                TypeError.invalid_lexeme;
        }
    };
};
