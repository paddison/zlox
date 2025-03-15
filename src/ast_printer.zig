const std = @import("std");
const Ast = @import("ast.zig").Ast;
const Expr = @import("ast.zig").Expr;
const VisitorFns = @import("ast.zig").VisitorFns;
const Visitor = @import("ast.zig").Visitor;
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

    const visitor_fns = VisitorFns(Self, Output){
        .visit_binary_expr_fn = visit_binary_expr,
        .visit_grouping_expr_fn = visit_grouping_expr,
        .visit_literal_expr_fn = visit_literal_expr,
        .visit_unary_expr_fn = visit_unary_expr,
    };

    fn visitor(self: *Self) Visitor(Output, Self, visitor_fns) {
        return Visitor(Output, Self, visitor_fns){
            .context = self,
        };
    }

    pub fn init(source: [:0]const u8, allocator: Allocator) Self {
        return .{
            .source = source,
            .output = String.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.output.deinit();
    }

    pub fn print(self: *Self, ast: *const Ast) void {
        const v = self.visitor();
        const root = ast.root();
        const stdout = std.io.getStdOut().writer();

        ast.accept(Output, root, v);
        stdout.print("{s}\n", .{self.output.items}) catch {};
    }

    fn visit_binary_expr(self: *Self, ast: *const Ast, expr: Expr.Binary) Output {
        const v = self.visitor();
        self.output.appendSlice(self.get_lexeme(expr.operator)) catch {};
        self.output.append(' ') catch {};
        ast.accept(Output, expr.left, v);
        self.output.append(' ') catch {};
        ast.accept(Output, expr.right, v);
    }

    fn visit_grouping_expr(self: *Self, ast: *const Ast, expr: Expr.Grouping) Output {
        self.output.append('(') catch {};
        const v = self.visitor();
        ast.accept(Output, expr.expression, v);
        self.output.append(')') catch {};
    }

    fn visit_literal_expr(self: *Self, expr: Expr.Literal) Output {
        self.output.appendSlice(self.get_lexeme(expr.value)) catch {};
    }

    fn visit_unary_expr(self: *Self, ast: *const Ast, expr: Expr.Unary) Output {
        const v = self.visitor();

        self.output.appendSlice(self.get_lexeme(expr.operator)) catch {};
        ast.accept(Output, expr.right, v);
    }

    fn get_lexeme(self: *const Self, token: Token) []const u8 {
        return self.source[token.lexeme.start..token.lexeme.end];
    }
};
