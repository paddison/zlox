const std = @import("std");
const exprs = @import("expression.zig");
const stmts = @import("statement.zig");
const typing = @import("typing.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Gpa = std.heap.GeneralPurposeAllocator;
const Expr = exprs.Expr;
const ExprIdx = exprs.ExprIdx;
const Object = typing.Object;
const Type = typing.Type;
const Value = typing.Value;
const ExprNode = exprs.Expr.ExprNode;
const Token = @import("tokenizer.zig").Token;
const Stmt = stmts.Stmt;
const Environment = @import("environment.zig").Environment;

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
    environment: Environment,

    const ExprVisitor = Expr.Visitor(
        Interpreter,
        ExprOutput,
        Error,
        visit_binary_expr,
        visit_grouping_expr,
        visit_literal_expr,
        visit_unary_expr,
        visit_variable_expr,
        visit_assign_expr,
    );
    const StmtVisitor = Stmt.Visitor(
        Interpreter,
        StmtOutput,
        Error,
        visit_expression_stmt,
        visit_print_stmt,
        visit_var_stmt,
        visit_block_stmt,
    );
    const ExprOutput = Object;
    const StmtOutput = void;

    pub fn interpret(self: *Interpreter, statements: []const Stmt) Error!void {
        for (statements) |statement| {
            self.execute(statement) catch {};
        }
    }

    fn expr_visitor(self: *Interpreter) ExprVisitor {
        return .{ .context = self };
    }

    fn stmt_visitor(self: *Interpreter) StmtVisitor {
        return .{ .context = self };
    }

    pub fn visit_binary_expr(self: *Interpreter, astt: *const Expr, expr: ExprNode.Binary) Error!ExprOutput {
        const left = try self.evaluate(astt, expr.left);
        const right = try self.evaluate(astt, expr.right);

        switch (expr.operator.t_type) {
            .greater => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.greater(&right);
            },
            .greater_equal => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.greater_equal(&right);
            },
            .less => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.less(&right);
            },
            .less_equal => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.less_equal(&right);
            },
            .minus => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.sub(&right);
            },
            .plus => if (left.instance_of(Type.number) and right.instance_of(Type.number)) {
                return left.add(&right);
            } else if (left.instance_of(Type.string) and right.instance_of(Type.string)) {
                return left.concat(&right);
            } else {
                self.error_payload = .{
                    .message = "Operators must be two numbers or two strings",
                    .token = expr.operator,
                };
                return Error.runtime_error;
            },
            .slash => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.div(&right);
            },
            .star => {
                try self.check_number_operands(expr.operator, &left, &right);
                return left.mul(&right);
            },
            .bang_equal => {
                try self.check_number_operands(expr.operator, &left, &right);
                return right.equals(&left).bnegate();
            },
            .equal_equal => {
                try self.check_number_operands(expr.operator, &left, &right);
                return right.equals(&left);
            },
            else => unreachable,
        }
    }

    pub fn visit_grouping_expr(self: *Interpreter, astt: *const Expr, expr: ExprNode.Grouping) Error!ExprOutput {
        return evaluate(self, astt, expr.expression);
    }

    pub fn visit_literal_expr(self: *Interpreter, expr: ExprNode.Literal) Error!ExprOutput {
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

    pub fn visit_unary_expr(self: *Interpreter, astt: *const Expr, expr: ExprNode.Unary) Error!ExprOutput {
        const right = try evaluate(self, astt, expr.right);

        return switch (expr.operator.t_type) {
            .bang => right.is_truthy().bnegate(), // maybe make negate function generic over type
            .minus => right.negate(),
            else => unreachable,
        };
    }

    pub fn visit_variable_expr(
        self: *Interpreter,
        expr: *const Expr,
        expr_node: ExprNode.Variable,
    ) Error!ExprOutput {
        _ = expr;
        return self.environment.get(self.source[expr_node.name.lexeme.start..expr_node.name.lexeme.end]) orelse
            Error.runtime_error;
    }

    pub fn visit_assign_expr(
        self: *Interpreter,
        expr: *const Expr,
        node: ExprNode.Assign,
    ) Error!ExprOutput {
        const value = try self.evaluate(expr, node.value);

        self.environment.assign(self.source[node.name.lexeme.start..node.name.lexeme.end], value) catch {
            self.error_payload = .{
                .message = "Undefined variable.",
                .token = node.name,
            };
            return Error.runtime_error;
        };
        return value;
    }

    fn evaluate(self: *Interpreter, astt: *const Expr, expr_idx: ExprIdx) Error!Object {
        return astt.accept(ExprOutput, Error, expr_idx, self.expr_visitor());
    }

    fn execute(self: *Interpreter, statement: Stmt) Error!StmtOutput {
        return statement.accept(StmtOutput, Error, self.stmt_visitor());
    }

    fn execut_block(self: *Interpreter, statements: ArrayList(Stmt)) Error!void {
        try self.environment.push_scope();
        defer self.environment.pop_scope();

        for (statements.items) |statement| {
            try self.execute(statement);
        }
    }

    pub fn visit_block_stmt(self: *Interpreter, statement: Stmt.Block) Error!StmtOutput {
        return self.execut_block(statement.statements);
    }

    pub fn visit_expression_stmt(self: *Interpreter, stmt: Stmt.Expression) Error!StmtOutput {
        _ = try self.evaluate(&stmt.expression, stmt.expression.root());
    }

    pub fn visit_print_stmt(self: *Interpreter, stmt: Stmt.Print) Error!StmtOutput {
        const value = try self.evaluate(&stmt.expression, stmt.expression.root());
        const stdout = std.io.getStdIn().writer();
        const value_string = try self.stringify(value);
        defer self.allocator.free(value_string);

        stdout.print("{s}\n", .{value_string}) catch {}; //discard the error for now
    }

    pub fn visit_var_stmt(self: *Interpreter, stmt: Stmt.Var) Error!StmtOutput {
        const value = if (stmt.initializer) |initializer|
            try self.evaluate(&initializer, initializer.root())
        else
            typing.Object.init_nil();

        //std.debug.print("{any}\n", .{stmt});
        //std.debug.print("{s}\n", .{value.string.value.items});
        try self.environment.define(self.source[stmt.name.lexeme.start..stmt.name.lexeme.end], value);
    }

    fn check_number_operands(self: *Interpreter, operator: Token, left: *const Object, right: *const Object) Error!void {
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

    fn stringify(self: *const Interpreter, object: Object) Error![]const u8 {
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
