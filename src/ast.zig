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

    pub fn accept(self: *const Self, comptime T: type, visitor: Visitor(T)) T {
        return switch (self.*) {
            .binary => visitor.visit_binary_expr(self.binary.*),
            .grouping => visitor.visit_grouping_expr(self.grouping.*),
            .literal => visitor.visit_literal_expr(self.literal.*),
            .unary => visitor.visit_unary_expr(self.unary.*),
        };
    }
};

pub fn Visitor(T: type) type {
    return struct {
        const Self = @This();
        visit_binary_expr: fn (Expr.Binary) T,
        visit_grouping_expr: fn (Expr.Grouping) T,
        visit_literal_expr: fn (Expr.Literal) T,
        visit_unary_expr: fn (Expr.Unary) T,
    };
}
