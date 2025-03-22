const std = @import("std");
const Ast = @import("expression.zig").Ast;
const Expr = @import("expression.zig").Expr;
const Token = @import("tokenizer.zig").Token;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const String = ArrayList(u8);
const Writer = std.io.getStdOut().writer();

const Error = error{};

pub const AstPrinter = struct {
    source: [:0]const u8,
    output: String,

    const Visitor = Expr.Visitor(
        AstPrinter,
        Output,
        Error,
        visit_binary_expr,
        visit_grouping_expr,
        visit_literal_expr,
        visit_unary_expr,
    );

    const Output = void;

    fn visitor(self: *AstPrinter) Visitor {
        return .{ .context = self };
    }

    pub fn init(source: [:0]const u8, allocator: Allocator) AstPrinter {
        return .{
            .source = source,
            .output = String.init(allocator),
        };
    }

    pub fn deinit(self: *AstPrinter) void {
        self.output.deinit();
    }

    pub fn print(self: *AstPrinter, ast: *const Ast) void {
        const v = self.visitor();
        const root = ast.root();
        const stdout = std.io.getStdOut().writer();

        ast.accept(Output, Error, root, v) catch unreachable;
        stdout.print("{s}\n", .{self.output.items}) catch {};
    }

    fn visit_binary_expr(self: *AstPrinter, ast: *const Ast, expr: Expr.Binary) Error!Output {
        const v = self.visitor();
        self.output.appendSlice(self.get_lexeme(expr.operator)) catch {};
        self.output.append(' ') catch {};
        try ast.accept(Output, Error, expr.left, v);
        self.output.append(' ') catch {};
        try ast.accept(Output, Error, expr.right, v);
    }

    fn visit_grouping_expr(self: *AstPrinter, ast: *const Ast, expr: Expr.Grouping) Error!Output {
        self.output.append('(') catch {};
        const v = self.visitor();
        try ast.accept(Output, Error, expr.expression, v);
        self.output.append(')') catch {};
    }

    fn visit_literal_expr(self: *AstPrinter, expr: Expr.Literal) Error!Output {
        self.output.appendSlice(self.get_lexeme(expr.value)) catch {};
    }

    fn visit_unary_expr(self: *AstPrinter, ast: *const Ast, expr: Expr.Unary) Error!Output {
        const v = self.visitor();

        self.output.appendSlice(self.get_lexeme(expr.operator)) catch {};
        try ast.accept(Output, Error, expr.right, v);
    }

    fn get_lexeme(self: *const AstPrinter, token: Token) []const u8 {
        return self.source[token.lexeme.start..token.lexeme.end];
    }
};
