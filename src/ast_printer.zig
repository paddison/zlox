const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("tokenizer.zig").Token;

const Gpa = std.heap.GeneralPurposeAllocator(.{});
const ArrayList = std.ArrayList;
const String = ArrayList(u8);

pub const AstPrinter = struct {
    source: [:0]u8,
    output: String,

    const Self = @This();
    const T = void;

    fn visitor() ast.Visitor(T) {
        return ast.Visitor(T){
            .visit_binary_expr = visit_binary_expr,
            .visit_grouping_expr = visit_grouping_expr,
            .visit_literal_expr = visit_literal_expr,
            .visit_unary_expr = visit_unary_expr,
        };
    }

    pub fn print(source: [:0]const u8, expr: ast.Expr) void {
        const v = visitor();
        const printer = AstPrinter{
            .source = source,
            .output = String.init(Gpa{}),
        };

        expr.accept(T, v);
        std.debug.print("{s}\n", .{printer.output.items});
    }

    fn visit_binary_expr(self: *const Self, expr: ast.Expr.Binary) T {
        const v = visitor();
        expr.accept(T, v);
        self.output.append(self.get_lexeme(expr.operator)) catch {};
    }

    fn visit_grouping_expr(self: *const Self, expr: ast.Expr.Grouping) T {
        self.output.append('(') catch {};
        expr.expression.accept(visitor());
        self.output.append(')') catch {};
    }

    fn visit_literal_expr(self: *const Self, expr: ast.Expr.Literal) T {
        self.output.appendSlice(self.get_lexeme(expr.value)) catch {};
    }

    fn visit_unary_expr(self: *const Self, expr: ast.Expr.Unary) T {
        self.output.appendSlice(self.get_lexeme(expr.operator)) catch {};
        expr.accept(T, visitor());
    }

    fn get_lexeme(self: *const Self, token: Token) []const u8 {
        return self.source[token.value.lexeme.start..token.value.lexeme.end];
    }
};
