const expressions = @import("expression.zig");
const Expr = expressions.Expr;

pub const Stmt = union(enum) {
    expression: Expression,
    print: Print,

    pub const Expression = struct { expression: Expr };
    pub const Print = struct { expression: Expr };

    pub fn accept(
        self: *const Stmt,
        comptime Output: type,
        comptime Error: type,
        visitor: anytype,
    ) Error!Output {
        return switch (self.*) {
            .expression => |s| visitor.visit_expression_stmt(s),
            .print => |s| visitor.visit_print_stmt(s),
        };
    }

    pub fn Visitor(
        comptime Context: type,
        comptime Output: type,
        comptime Error: type,
        comptime visit_expression_stmt_fn: fn (*Context, Stmt.Expression) Error!Output,
        comptime visit_print_stmt_fn: fn (*Context, Stmt.Print) Error!Output,
    ) type {
        return struct {
            context: *Context,

            const Self = @This();

            fn visit_expression_stmt(self: *const Self, stmt: Stmt.Expression) Error!Output {
                return visit_expression_stmt_fn(self.context, stmt);
            }

            fn visit_print_stmt(self: *const Self, stmt: Stmt.Print) Error!Output {
                return visit_print_stmt_fn(self.context, stmt);
            }
        };
    }
};
