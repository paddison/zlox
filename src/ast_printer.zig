const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("tokenizer.zig").Token;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = ArrayList(u8);
const Writer = std.io.getStdOut().writer();

pub const AstPrinter = struct {
    source: [:0]const u8,
    output: String,

    const Self = @This();
    const Output = void;

    const visitor_fns = ast.VisitorFns(Self, Output){
        .visit_binary_expr_fn = visit_binary_expr,
        .visit_grouping_expr_fn = visit_grouping_expr,
        .visit_literal_expr_fn = visit_literal_expr,
        .visit_unary_expr_fn = visit_unary_expr,
    };

    fn visitor(self: *Self) ast.Visitor(Output, Self, visitor_fns) {
        return ast.Visitor(Output, Self, visitor_fns){
            .context = self,
        };
    }

    pub fn new(source: [:0]const u8, allocator: Allocator) Self {
        return .{
            .source = source,
            .output = String.init(allocator),
        };
    }

    pub fn print(self: *Self, expr: ast.Expr) void {
        const v = self.visitor();

        expr.accept(Output, v);
        std.debug.print("{s}\n", .{self.output.items});
    }

    fn visit_binary_expr(self: *Self, expr: ast.Expr) Output {
        const v = self.visitor();
        self.output.appendSlice(self.get_lexeme(expr.binary.operator)) catch {};
        self.output.append(' ') catch {};
        expr.binary.left.accept(Output, v);
        self.output.append(' ') catch {};
        expr.binary.right.accept(Output, v);
    }

    fn visit_grouping_expr(self: *Self, expr: ast.Expr) Output {
        self.output.append('(') catch {};
        const v = self.visitor();
        expr.grouping.expression.accept(Output, v);
        self.output.append(')') catch {};
    }

    fn visit_literal_expr(self: *Self, expr: ast.Expr) Output {
        self.output.appendSlice(self.get_lexeme(expr.literal.value)) catch {};
    }

    fn visit_unary_expr(self: *Self, expr: ast.Expr) Output {
        const v = self.visitor();

        self.output.appendSlice(self.get_lexeme(expr.unary.operator)) catch {};
        expr.unary.right.accept(Output, v);
    }

    fn get_lexeme(self: *const Self, token: Token) []const u8 {
        return self.source[token.lexeme.start..token.lexeme.end];
    }
};
