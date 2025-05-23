const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Literal = @import("expression.zig").Expr.Literal;
const Interpreter = @import("interpreter.zig").Interpreter;

const TypeError = error{
    invalid_lexeme,
    OutOfMemory,
};

pub const Type = enum {
    nil,
    number,
    string,
    bool,
    callable,

    pub const Number = struct {
        const N = f64;
        value: N,

        const Self = @This();

        fn init(lexeme: []const u8) TypeError!Self {
            return if (std.fmt.parseFloat(N, lexeme)) |n|
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

        fn concat(self: *const Self, other: *const Self) Allocator.Error!Self {
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

    pub const Callable = union(enum) {
        function: Function,
        // builtins
        clock: Clock,

        pub fn arity(self: *const Callable) usize {
            return switch (self.*) {
                .function => |f| f.arity(),
                .clock => |f| f.arity(),
            };
        }

        pub fn call(self: *Callable, interpreter: *Interpreter, arguments: []const Object) Object {
            return switch (self.*) {
                .function => |*f| f.call(interpreter, arguments),
                .clock => |*f| f.call(interpreter, arguments),
            };
        }
    };

    pub const Function = struct {
        pub fn call(self: *Function, interpreter: *Interpreter, arguments: []const Object) Object {
            _ = self;
            _ = interpreter;
            _ = arguments;

            return Object.init_nil();
        }

        pub fn arity(self: *const Function) usize {
            _ = self;
            return 0;
        }
    };

    pub const Clock = struct {
        pub fn call(self: *const Clock, interpreter: *Interpreter, arguments: []const Object) Object {
            _ = self;
            _ = interpreter;
            _ = arguments;
            const time: f64 = @floatFromInt(std.time.milliTimestamp());
            return Object{
                .number = Type.Number{
                    .value = time / 1000.0,
                },
            };
        }

        pub fn arity(self: *const Clock) usize {
            _ = self;
            return 0;
        }
    };
};

pub const Object = union(Type) {
    nil: void,
    number: Type.Number,
    string: Type.String,
    bool: Type.Bool,
    callable: Type.Callable,

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
                .slice => try Type.Number.init(data),
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
                .slice => try Type.String.init(data),
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

    pub fn init_nil() Self {
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

    pub fn concat(self: *const Self, other: *const Self) Allocator.Error!Self {
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
                .callable => unreachable,
            }
        else
            false;

        return .{ .bool = .{ .value = value } };
    }
};
