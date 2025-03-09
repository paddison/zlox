const std = @import("std");
const ast = @import("ast.zig");

pub const AstPrinter = struct {
    const Self = @This();
    const T = []const u8;

    fn visitor() ast.Visitor(T) {
        return ast.Visitor(T){
            .visit_binary_expr = visit_binary_expr,
            .visit_grouping_expr = visit_grouping_expr,
            .visit_literal_expr = visit_literal_expr,
            .visit_unary_expr = visit_unary_expr,
        };
    }

    pub fn print(expr: ast.Expr) void {
        const v = visitor();
        const s = expr.accept(T, v);
        std.debug.print("{s}", .{s});
    }

    fn visit_binary_expr(expr: ast.Expr.Binary) T {
        _ = expr;
        return &.{};
    }

    fn visit_grouping_expr(expr: ast.Expr.Grouping) T {
        _ = expr;
        return &.{};
    }

    fn visit_literal_expr(expr: ast.Expr.Literal) T {
        _ = expr;
        return "literal";
    }

    fn visit_unary_expr(expr: ast.Expr.Unary) T {
        _ = expr;
        return &.{};
    }
};
