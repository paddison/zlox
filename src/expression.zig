const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const ArrayList = @import("std").ArrayList;
const Allocator = std.mem.Allocator;

pub const ExprIdx = usize;

pub const Expr = struct {
    expressions: ArrayList(ExprNode),

    pub fn root(self: *const Expr) ExprIdx {
        std.debug.assert(self.expressions.items.len > 0);
        return self.expressions.items.len - 1;
    }

    pub fn get(self: *const Expr, expr: ExprIdx) ExprNode {
        return self.expressions.items[expr];
    }

    pub fn add(self: *Expr, expression: ExprNode) !ExprIdx {
        const idx = self.expressions.items.len;
        try self.expressions.append(expression);
        return idx;
    }

    pub fn accept(
        self: *const Expr,
        comptime Output: type,
        comptime Error: type,
        expr: ExprIdx,
        visitor: anytype,
    ) Error!Output {
        return switch (self.expressions.items[expr]) {
            .binary => |e| visitor.visit_binary_expr(self, e),
            .grouping => |e| visitor.visit_grouping_expr(self, e),
            .literal => |e| visitor.visit_literal_expr(e),
            .unary => |e| visitor.visit_unary_expr(self, e),
        };
    }

    pub fn init_binary(self: *Expr, left: ExprIdx, operator: Token, right: ExprIdx) !ExprIdx {
        const expr = ExprNode{
            .binary = ExprNode.Binary{
                .left = left,
                .operator = operator,
                .right = right,
            },
        };
        return self.add(expr);
    }

    pub fn init_grouping(self: *Expr, expression: ExprIdx) !ExprIdx {
        const expr = ExprNode{
            .grouping = .{
                .expression = expression,
            },
        };

        return self.add(expr);
    }

    pub fn init_literal(self: *Expr, value: Token) !ExprIdx {
        const expr = ExprNode{
            .literal = .{
                .value = value,
            },
        };

        return self.add(expr);
    }

    pub fn init_unary(self: *Expr, operator: Token, right: ExprIdx) !ExprIdx {
        const expr = ExprNode{
            .unary = .{
                .operator = operator,
                .right = right,
            },
        };

        return self.add(expr);
    }

    pub fn init(allocator: Allocator) Expr {
        return .{
            .expressions = ArrayList(ExprNode).init(allocator),
        };
    }

    pub fn deinit(self: *const Expr) void {
        self.expressions.deinit();
    }
    pub const ExprNode = union(enum) {
        binary: Binary,
        grouping: Grouping,
        literal: Literal,
        unary: Unary,

        pub const Binary = struct { left: ExprIdx, operator: Token, right: ExprIdx };
        pub const Grouping = struct { expression: ExprIdx };
        pub const Literal = struct { value: Token };
        pub const Unary = struct { operator: Token, right: ExprIdx };
    };

    pub fn Visitor(
        comptime Context: type,
        comptime Output: type,
        comptime Error: type,
        comptime visit_binary_expr_fn: fn (*Context, *const Expr, ExprNode.Binary) Error!Output,
        comptime visit_grouping_expr_fn: fn (*Context, *const Expr, ExprNode.Grouping) Error!Output,
        comptime visit_literal_expr_fn: fn (*Context, ExprNode.Literal) Error!Output,
        comptime visit_unary_expr_fn: fn (*Context, *const Expr, ExprNode.Unary) Error!Output,
    ) type {
        return struct {
            context: *Context,

            const V = @This();

            fn visit_binary_expr(self: *const V, ast: *const Expr, expr: ExprNode.Binary) Error!Output {
                return visit_binary_expr_fn(self.context, ast, expr);
            }

            fn visit_grouping_expr(self: *const V, ast: *const Expr, expr: ExprNode.Grouping) Error!Output {
                return visit_grouping_expr_fn(self.context, ast, expr);
            }

            fn visit_literal_expr(self: *const V, expr: ExprNode.Literal) Error!Output {
                return visit_literal_expr_fn(self.context, expr);
            }

            fn visit_unary_expr(self: *const V, ast: *const Expr, expr: ExprNode.Unary) Error!Output {
                return visit_unary_expr_fn(self.context, ast, expr);
            }
        };
    }
};
