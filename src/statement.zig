const expressions = @import("expression.zig");
const tknzr = @import("tokenizer.zig");
const std = @import("std");

const Expr = expressions.Expr;
const Token = tknzr.Token;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Stmt = union(enum) {
    expression: Expression,
    @"if": If,
    print: Print,
    @"var": Var,
    block: Block,

    pub const Expression = struct { expression: Expr };
    pub const If = struct {
        condition: Expr,
        then_branch: *const Stmt,
        else_branch: ?*const Stmt,
        alloc: Allocator,
    };
    pub const Print = struct { expression: Expr };
    pub const Var = struct { name: Token, initializer: ?Expr };
    pub const Block = struct { statements: ArrayList(Stmt) };

    pub fn accept(
        self: *const Stmt,
        comptime Output: type,
        comptime Error: type,
        visitor: anytype,
    ) Error!Output {
        return switch (self.*) {
            .expression => |s| visitor.visit_expression_stmt(s),
            .@"if" => |s| visitor.visit_if_stmt(s),
            .print => |s| visitor.visit_print_stmt(s),
            .@"var" => |s| visitor.visit_var_stmt(s),
            .block => |s| visitor.visit_block_stmt(s),
        };
    }

    pub fn Visitor(
        comptime Context: type,
        comptime Output: type,
        comptime Error: type,
        comptime visit_expression_stmt_fn: fn (*Context, Stmt.Expression) Error!Output,
        comptime visit_print_stmt_fn: fn (*Context, Stmt.Print) Error!Output,
        comptime visit_var_stmt_fn: fn (*Context, Stmt.Var) Error!Output,
        comptime visit_block_stmt_fn: fn (*Context, Stmt.Block) Error!Output,
        comptime visit_if_stmt_fn: fn (*Context, Stmt.If) Error!Output,
    ) type {
        return struct {
            context: *Context,

            const Self = @This();

            fn visit_expression_stmt(self: *const Self, stmt: Stmt.Expression) Error!Output {
                return visit_expression_stmt_fn(self.context, stmt);
            }

            fn visit_if_stmt(self: *const Self, stmt: Stmt.If) Error!Output {
                return visit_if_stmt_fn(self.context, stmt);
            }

            fn visit_print_stmt(self: *const Self, stmt: Stmt.Print) Error!Output {
                return visit_print_stmt_fn(self.context, stmt);
            }

            fn visit_var_stmt(self: *const Self, stmt: Stmt.Var) Error!Output {
                return visit_var_stmt_fn(self.context, stmt);
            }

            fn visit_block_stmt(self: *const Self, stmt: Stmt.Block) Error!Output {
                return visit_block_stmt_fn(self.context, stmt);
            }
        };
    }
};
