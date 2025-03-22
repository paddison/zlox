const std = @import("std");
const exprs = @import("expression.zig");
const stmts = @import("statement.zig");
const typing = @import("typing.zig");

const Allocator = std.mem.Allocator;
const ExprTree = exprs.ExprTree;
const ExprIdx = exprs.ExprIdx;
const Object = typing.Object;
const Type = typing.Type;
const Value = typing.Value;
const Expr = exprs.Expr;
const Token = @import("tokenizer.zig").Token;
const Stmt = stmts.Stmt;

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
    allocator: Allocator,

    const Self = @This();
    const ExprOutput = Object;
    const StmtOutput = void;

    const expr_visitor_fns: Expr.VisitorFns(Self, ExprOutput, Error) = .{
        .visit_binary_expr_fn = visit_binary_expr,
        .visit_grouping_expr_fn = visit_grouping_expr,
        .visit_literal_expr_fn = visit_literal_expr,
        .visit_unary_expr_fn = visit_unary_expr,
    };

    const stmt_visitor_fns: Stmt.VisitorFns(Self, StmtOutput, Error) = .{
        .visit_expression_stmt_fn = visit_expression_stmt,
        .visit_print_stmt_fn = visit_print_stmt,
    };

    pub fn interpret(self: *Self, statements: []const Stmt) Error!void {
        for (statements) |statement| {
            self.execute(statement) catch {};
        }
    }

    fn visitor(self: *Self) Expr.Visitor(ExprOutput, Self, Error, expr_visitor_fns) {
        return Expr.Visitor(ExprOutput, Self, Error, expr_visitor_fns){ .context = self };
    }

    fn stmt_visitor(self: *Self) Stmt.Visitor(StmtOutput, Self, Error, stmt_visitor_fns) {
        return Stmt.Visitor(StmtOutput, Self, Error, stmt_visitor_fns){ .context = self };
    }

    pub fn visit_binary_expr(self: *Self, astt: *const ExprTree, expr: Expr.Binary) Error!ExprOutput {
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

    pub fn visit_grouping_expr(self: *Self, astt: *const ExprTree, expr: Expr.Grouping) Error!ExprOutput {
        return evaluate(self, astt, expr.expression);
    }

    pub fn visit_literal_expr(self: *Self, expr: Expr.Literal) Error!ExprOutput {
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

    pub fn visit_unary_expr(self: *Self, astt: *const ExprTree, expr: Expr.Unary) Error!ExprOutput {
        const right = try evaluate(self, astt, expr.right);

        return switch (expr.operator.t_type) {
            .bang => right.is_truthy().bnegate(), // maybe make negate function generic over type
            .minus => right.negate(),
            else => unreachable,
        };
    }

    fn evaluate(self: *Self, astt: *const ExprTree, expr_idx: ExprIdx) Error!Object {
        return astt.accept(ExprOutput, Error, expr_idx, self.visitor());
    }

    fn execute(self: *Self, statement: Stmt) Error!StmtOutput {
        return statement.accept(StmtOutput, Error, self.stmt_visitor());
    }

    pub fn visit_expression_stmt(self: *Self, stmt: Stmt.Expression) Error!StmtOutput {
        _ = try self.evaluate(&stmt.expression, stmt.expression.root());
    }

    pub fn visit_print_stmt(self: *Self, stmt: Stmt.Print) Error!StmtOutput {
        const value = try self.evaluate(&stmt.expression, stmt.expression.root());
        const stdout = std.io.getStdIn().writer();
        const value_string = try self.stringify(value);
        defer self.allocator.free(value_string);

        stdout.print("{s}\n", .{value_string}) catch {}; //discard the error for now
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

    fn stringify(self: *const Self, object: Object) Error![]const u8 {
        return switch (object) {
            .nil => std.fmt.allocPrint(self.allocator, "nil", .{}),
            .number => std.fmt.allocPrint(self.allocator, "{d}", .{object.number.value}),
            .string => std.fmt.allocPrint(self.allocator, "{s}", .{object.string.value.items}),
            .bool => if (object.bool.value)
                std.fmt.allocPrint(self.allocator, "true", .{})
            else
                std.fmt.allocPrint(self.allocator, "false", .{}),
        };
    }
};
