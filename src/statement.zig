const expressions = @import("expression.zig");
const ExprTree = expressions.ExprTree;

pub const Stmt = union(enum) {
    expression: Expression,
    print: Print,

    pub const Expression = struct { expression: ExprTree };
    pub const Print = struct { expression: ExprTree };

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

    pub fn VisitorFns(comptime Context: type, comptime Output: type, Error: type) type {
        return struct {
            visit_expression_stmt_fn: fn (*Context, Stmt.Expression) Error!Output,
            visit_print_stmt_fn: fn (*Context, Stmt.Print) Error!Output,
        };
    }

    pub fn Visitor(
        comptime T: type,
        comptime Context: type,
        comptime E: type,
        vTable: Stmt.VisitorFns(Context, T, E),
    ) type {
        return struct {
            context: *Context,

            const fns = vTable;
            const Self = @This();

            fn visit_expression_stmt(self: *const Self, stmt: Stmt.Expression) E!T {
                return fns.visit_expression_stmt_fn(self.context, stmt);
            }

            fn visit_print_stmt(self: *const Self, stmt: Stmt.Print) E!T {
                return fns.visit_print_stmt_fn(self.context, stmt);
            }
        };
    }
};
