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

    pub fn new(typ: type, data: anytype) TypeError!Self {
        return if (typ == Type.Number)
            number(data)
        else if (typ == Type.String)
            string(data)
        else if (typ == Type.Bool)
            boolean(data)
        else if (typ == Type.Nil)
            nil()
        else
            TypeError.invalid_lexeme;
    }

    fn number(data: anytype) TypeError!Self {
        const T = @TypeOf(data);
        const value = switch (@typeInfo(T)) {
            .pointer => |lexeme| switch (lexeme.size) {
                .Slice => try Type.Number.init(data),
                else => @compileError("Expect []const u8 when creating number"),
            },
            else => @compileError("Expect []const u8 when creating number"),
        };

        return .{
            .id = .number,
            .value = Value{ .number = value },
        };
    }

    fn string(data: anytype) TypeError!Self {
        const T = @TypeOf(data);
        const value = switch (@typeInfo(T)) {
            .pointer => |lexeme| switch (lexeme.size) {
                .Slice => try Type.String.init(data),
                else => @compileError("Expect []const u8 when creating string"),
            },
            else => @compileError("Expect []const u8 when creating string"),
        };

        return .{
            .id = .string,
            .value = Value{ .string = value },
        };
    }

    fn boolean(data: anytype) Self {
        const T = @TypeOf(data);

        if (@typeInfo(T) == .bool) {
            return .{
                .id = .bool,
                .value = Value{ .bool = Type.Bool.init(data) },
            };
        } else {
            @compileError("Expect boolean when creating boolean");
        }
    }

    fn nil() Self {
        return .{
            .id = .nil,
            .value = .{
                .nil = null,
            },
        };
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

        fn init(value: bool) Self {
            return .{ .value = value };
        }
    };

    pub const Nil = struct {};
};
