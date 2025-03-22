const std = @import("std");
const ArrayList = std.ArrayList;
const Literal = @import("expression.zig").Expr.Literal;

const TypeError = error{
    invalid_lexeme,
    OutOfMemory,
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
            return if (value.appendSlice(lexeme[1 .. lexeme.len - 1])) // strip '"'
                .{ .value = value }
            else |_|
                TypeError.OutOfMemory;
        }

        fn concat(self: *const Self, other: *const Self) TypeError!Self {
            const allocator = std.heap.page_allocator;
            var value = ArrayList(u8).init(allocator);
            try value.appendSlice(self.value.items);
            try value.appendSlice(other.value.items);

            return .{ .value = value };
        }
    };

    pub const Bool = struct {
        value: bool,

        const Self = @This();

        fn init(value: bool) Self {
            return .{ .value = value };
        }
    };

    pub const Nil = struct {};
};

pub const Object = union(Type) {
    nil: void,
    number: Type.Number,
    string: Type.String,
    bool: Type.Bool,

    const Self = @This();

    pub fn new(typ: type, data: anytype) TypeError!Self {
        return if (typ == Type.Number)
            init_number(data)
        else if (typ == Type.String)
            init_string(data)
        else if (typ == Type.Bool)
            init_boolean(data)
        else if (typ == Type.Nil)
            init_nil()
        else
            TypeError.invalid_lexeme;
    }

    fn init_number(data: anytype) TypeError!Self {
        const T = @TypeOf(data);
        const value = switch (@typeInfo(T)) {
            .pointer => |lexeme| switch (lexeme.size) {
                .Slice => try Type.Number.init(data),
                else => @compileError("Expect []const u8 when creating number"),
            },
            else => @compileError("Expect []const u8 when creating number"),
        };

        return .{ .number = value };
    }

    fn init_string(data: anytype) TypeError!Self {
        const T = @TypeOf(data);
        const value = switch (@typeInfo(T)) {
            .pointer => |lexeme| switch (lexeme.size) {
                .Slice => try Type.String.init(data),
                else => @compileError("Expect []const u8 when creating string"),
            },
            else => @compileError("Expect []const u8 when creating string"),
        };

        return .{ .string = value };
    }

    fn init_boolean(data: anytype) Self {
        const T = @TypeOf(data);

        if (@typeInfo(T) == .bool) {
            return .{ .bool = Type.Bool.init(data) };
        } else {
            @compileError("Expect boolean when creating boolean");
        }
    }

    fn init_nil() Self {
        return .{
            .nil = {},
        };
    }

    pub fn instance_of(self: *const Self, id: Type) bool {
        return id == self.*;
    }

    pub fn negate(self: *const Self) Self {
        return .{
            .number = .{ .value = -self.number.value },
        };
    }

    pub fn bnegate(self: *const Self) Self {
        return .{
            .bool = .{
                .value = !self.bool.value,
            },
        };
    }

    pub fn add(self: *const Self, other: *const Self) Self {
        return .{
            .number = .{ .value = self.number.value + other.number.value },
        };
    }

    pub fn sub(self: *const Self, other: *const Self) Self {
        return .{
            .number = .{ .value = self.number.value - other.number.value },
        };
    }

    pub fn div(self: *const Self, other: *const Self) Self {
        return .{
            .number = .{ .value = self.number.value / other.number.value },
        };
    }

    pub fn mul(self: *const Self, other: *const Self) Self {
        return .{
            .number = .{ .value = self.number.value * other.number.value },
        };
    }

    pub fn concat(self: *const Self, other: *const Self) TypeError!Self {
        return .{ .string = try self.string.concat(&other.string) };
    }

    pub fn greater(self: *const Self, other: *const Self) Self {
        return .{
            .bool = .{ .value = self.number.value > other.number.value },
        };
    }

    pub fn greater_equal(self: *const Self, other: *const Self) Self {
        return .{
            .bool = .{ .value = self.number.value >= other.number.value },
        };
    }

    pub fn less(self: *const Self, other: *const Self) Self {
        return .{
            .bool = .{ .value = self.number.value < other.number.value },
        };
    }

    pub fn less_equal(self: *const Self, other: *const Self) Self {
        return .{
            .bool = .{ .value = self.number.value <= other.number.value },
        };
    }

    pub fn is_truthy(self: *const Self) Self {
        const value: Type.Bool = switch (self.*) {
            .nil => .{ .value = false },
            .bool => .{ .value = self.bool.value },
            else => .{ .value = true },
        };

        return .{ .bool = value };
    }

    pub fn equals(self: *const Self, other: *const Self) Self {
        const value = if (self == other)
            switch (self.*) {
                .nil => true,
                .number => self.number.value == self.number.value,
                .string => std.mem.eql(u8, self.string.value.items, other.string.value.items),
                .bool => self.bool.value == other.bool.value,
            }
        else
            false;

        return .{ .bool = .{ .value = value } };
    }
};
