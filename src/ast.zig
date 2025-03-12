const Token = @import("tokenizer.zig").Token;
const ArrayList = @import("std").ArrayList;

pub const Expr = union(enum) {
    binary: *const Binary,
    grouping: *const Grouping,
    literal: *const Literal,
    unary: *const Unary,

    const Self = @This();

    pub const Binary = struct { left: Expr, operator: Token, right: Expr };
    pub const Grouping = struct { expression: Expr };
    pub const Literal = struct { value: Token };
    pub const Unary = struct { operator: Token, right: Expr };

    pub fn accept(
        self: *const Self,
        comptime T: type,
        visitor: anytype,
    ) T {
        return switch (self.*) {
            .binary => visitor.visit_binary_expr(self.*),
            .grouping => visitor.visit_grouping_expr(self.*),
            .literal => visitor.visit_literal_expr(self.*),
            .unary => visitor.visit_unary_expr(self.*),
        };
    }
};

pub fn VisitorFns(Context: type, Output: type) type {
    return struct {
        visit_binary_expr_fn: fn (ctx: *Context, Expr) Output,
        visit_grouping_expr_fn: fn (ctx: *Context, Expr) Output,
        visit_literal_expr_fn: fn (ctx: *Context, Expr) Output,
        visit_unary_expr_fn: fn (ctx: *Context, Expr) Output,
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

        fn visit_binary_expr(self: *const Self, expr: Expr) T {
            return fns.visit_binary_expr_fn(self.context, expr);
        }

        fn visit_grouping_expr(self: *const Self, expr: Expr) T {
            return fns.visit_grouping_expr_fn(self.context, expr);
        }

        fn visit_literal_expr(self: *const Self, expr: Expr) T {
            return fns.visit_literal_expr_fn(self.context, expr);
        }

        fn visit_unary_expr(self: *const Self, expr: Expr) T {
            return fns.visit_unary_expr_fn(self.context, expr);
        }
    };
}
