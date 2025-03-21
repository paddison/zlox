const std = @import("std");
const Allocator = std.mem.Allocator;
const ast = @import("ast.zig");
const Ast = ast.Ast;
const ExprIdx = ast.ExprIdx;
const typing = @import("typing.zig");
const Object = typing.Object;
const Type = typing.Type;
const Value = typing.Value;
const Expr = ast.Expr;
const Token = @import("tokenizer.zig").Token;

const number_operands_error_msg = "Operands must be numbers";

pub const Error = error{
    runtime_error,
    OutOfMemory,
};

pub const ErrorPayload = struct {
    message: []const u8,
    token: Token,
};

pub const Interpreter = struct {
    source: []const u8,
    error_payload: ?ErrorPayload,

    const Self = @This();
    const Output = Object;

    const visitorFns: Expr.VisitorFns(Self, Output, Error) = .{
        .visit_binary_expr_fn = visit_binary_expr,
        .visit_grouping_expr_fn = visit_grouping_expr,
        .visit_literal_expr_fn = visit_literal_expr,
        .visit_unary_expr_fn = visit_unary_expr,
    };

    pub fn interpret(self: *Self, astt: Ast, allocator: Allocator) Error![]const u8 {
        const v = self.visitor();
        return if (astt.accept(Output, Error, astt.root(), v)) |object|
            stringify(object, allocator)
        else |err|
            err;
    }

    fn visitor(self: *Self) Expr.Visitor(Output, Self, Error, visitorFns) {
        return Expr.Visitor(Output, Self, Error, visitorFns){ .context = self };
    }

    pub fn visit_binary_expr(self: *Self, astt: *const Ast, expr: Expr.Binary) Error!Output {
        const left = try self.evaluate(astt, expr.left);
        const right = try self.evaluate(astt, expr.right);

        return switch (expr.operator.t_type) {
            .greater => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.greater(&right);
            },
            .greater_equal => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.greater_equal(&right);
            },
            .less => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.less(&right);
            },
            .less_equal => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.less_equal(&right);
            },
            .minus => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.sub(&right);
            },
            .plus => if (left.instance_of(Type.number) and right.instance_of(Type.number))
                left.add(&right)
            else if (left.instance_of(Type.string) and right.instance_of(Type.string))
                if (left.concat(&right)) |o| o else |_| return Error.OutOfMemory
            else {
                self.error_payload = .{
                    .message = "Operators must be two numbers or two strings",
                    .token = expr.operator,
                };
                return Error.runtime_error;
            },
            .slash => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.div(&right);
            },
            .star => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk left.mul(&right);
            },
            .bang_equal => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk right.equals(&left).bnegate();
            },
            .equal_equal => blk: {
                try self.check_number_operands(expr.operator, &left, &right);
                break :blk right.equals(&left);
            },
            else => unreachable,
        };
    }

    pub fn visit_grouping_expr(self: *Self, astt: *const Ast, expr: Expr.Grouping) Error!Output {
        return evaluate(self, astt, expr.expression);
    }

    pub fn visit_literal_expr(self: *Self, expr: Expr.Literal) Error!Output {
        const lexeme = self.source[expr.value.lexeme.start..expr.value.lexeme.end];

        const value = switch (expr.value.t_type) {
            .number => Object.new(Type.Number, lexeme),
            .string => Object.new(Type.String, lexeme),
            .nil => Object.new(Type.Nil, .{}),
            .true => Object.new(Type.Bool, true),
            .false => Object.new(Type.Bool, false),
            else => unreachable,
        };

        if (value) |v| {
            return v;
        } else |err| {
            @import("std").debug.print("error when interpreting literal expr {!}", .{err});
        }

        return Object{
            .nil = {},
        };
    }

    pub fn visit_unary_expr(self: *Self, astt: *const Ast, expr: Expr.Unary) Error!Output {
        const right = try evaluate(self, astt, expr.right);

        return switch (expr.operator.t_type) {
            .bang => right.is_truthy().bnegate(), // maybe make negate function generic over type
            .minus => right.negate(),
            else => unreachable,
        };
    }

    fn evaluate(self: *Self, astt: *const Ast, expr_idx: ExprIdx) Error!Object {
        return astt.accept(Output, Error, expr_idx, self);
    }

    fn check_number_operands(self: *Self, operator: Token, left: *const Object, right: *const Object) Error!void {
        if (left.instance_of(Type.number) and right.instance_of(Type.number))
            return
        else {
            self.error_payload = .{
                .message = number_operands_error_msg,
                .token = operator,
            };
            return Error.runtime_error;
        }
    }

    fn stringify(object: Object, allocator: Allocator) Error![]const u8 {
        return switch (object) {
            .nil => std.fmt.allocPrint(allocator, "nil", .{}),
            .number => std.fmt.allocPrint(allocator, "{d}", .{object.number.value}),
            .string => std.fmt.allocPrint(allocator, "{s}", .{object.string.value.items}),
            .bool => if (object.bool.value)
                std.fmt.allocPrint(allocator, "true", .{})
            else
                std.fmt.allocPrint(allocator, "false", .{}),
        };
    }
};
