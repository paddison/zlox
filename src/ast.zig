const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const ArrayList = @import("std").ArrayList;

pub const ExprIdx = usize;

pub const Ast = struct {
    expressions: ArrayList(Expr),

    const Self = @This();

    pub fn root(self: *const Self) ExprIdx {
        std.debug.assert(self.expressions.items.len > 0);
        return self.expressions.items.len - 1;
    }

    pub fn get(self: *const Self, expr: ExprIdx) Expr {
        return self.expressions.items[expr];
    }

    pub fn add(self: *Self, expression: Expr) !ExprIdx {
        const idx = self.expressions.items.len;
        try self.expressions.append(expression);
        return idx;
    }

    pub fn accept(
        self: *const Self,
        comptime Output: type,
        expr: ExprIdx,
        visitor: anytype,
    ) Output {
        return switch (self.expressions.items[expr]) {
            .binary => |e| visitor.visit_binary_expr(self, e),
            .grouping => |e| visitor.visit_grouping_expr(self, e),
            .literal => |e| visitor.visit_literal_expr(e),
            .unary => |e| visitor.visit_unary_expr(self, e),
        };
    }

    pub fn init_binary(self: *Self, left: ExprIdx, operator: Token, right: ExprIdx) !ExprIdx {
        const expr = Expr{
            .binary = Expr.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            },
        };
        return self.add(expr);
    }

    pub fn init_grouping(self: *Self, expression: ExprIdx) !ExprIdx {
        const expr = Expr{
            .grouping = .{
                .expression = expression,
            },
        };

        return self.add(expr);
    }

    pub fn init_literal(self: *Self, value: Token) !ExprIdx {
        const expr = Expr{
            .literal = .{
                .value = value,
            },
        };

        return self.add(expr);
    }

    pub fn init_unary(self: *Self, operator: Token, right: ExprIdx) !ExprIdx {
        const expr = Expr{
            .unary = .{
                .operator = operator,
                .right = right,
            },
        };

        return self.add(expr);
    }

    pub fn deinit(self: *const Self) void {
        self.expressions.deinit();
    }
};

pub const Expr = union(enum) {
    binary: Binary,
    grouping: Grouping,
    literal: Literal,
    unary: Unary,

    const Self = @This();

    pub const Binary = struct { left: ExprIdx, operator: Token, right: ExprIdx };
    pub const Grouping = struct { expression: ExprIdx };
    pub const Literal = struct { value: Token };
    pub const Unary = struct { operator: Token, right: ExprIdx };
};

pub fn VisitorFns(Context: type, Output: type) type {
    return struct {
        visit_binary_expr_fn: fn (*Context, *const Ast, Expr.Binary) Output,
        visit_grouping_expr_fn: fn (*Context, *const Ast, Expr.Grouping) Output,
        visit_literal_expr_fn: fn (*Context, Expr.Literal) Output,
        visit_unary_expr_fn: fn (*Context, *const Ast, Expr.Unary) Output,
    };
}

pub fn Visitor(
    comptime T: type,
    comptime Context: type,
    vTable: VisitorFns(Context, T),
) type {
    return struct {
        context: *Context,

        const fns = vTable;
        const Self = @This();

        fn visit_binary_expr(self: *const Self, ast: *const Ast, expr: Expr.Binary) T {
            return fns.visit_binary_expr_fn(self.context, ast, expr);
        }

        fn visit_grouping_expr(self: *const Self, ast: *const Ast, expr: Expr.Grouping) T {
            return fns.visit_grouping_expr_fn(self.context, ast, expr);
        }

        fn visit_literal_expr(self: *const Self, expr: Expr.Literal) T {
            return fns.visit_literal_expr_fn(self.context, expr);
        }

        fn visit_unary_expr(self: *const Self, ast: *const Ast, expr: Expr.Unary) T {
            return fns.visit_unary_expr_fn(self.context, ast, expr);
        }
    };
}
