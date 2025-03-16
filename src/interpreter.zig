const ast = @import("ast.zig");
const Visitor = ast.Visitor;
const Ast = ast.Ast;
const typing = @import("typing.zig");
const Object = typing.Object;
const Type = typing.Type;
const Value = typing.Value;
const Expr = ast.Expr;

pub const Interpreter = struct {
    source: []const u8,

    const Self = @This();
    const Output = Object;

    const visitorFns: ast.VisitorFns(Self, Output) = .{
        .visit_binary_expr_fn = visit_binary_expr,
        .visit_grouping_expr_fn = visit_grouping_expr,
        .visit_literal_expr_fn = visit_literal_expr,
        .visit_unary_expr_fn = visit_unary_expr,
    };

    pub fn interpret(self: *Self, astt: Ast) Output {
        const v = self.visitor();
        const root = astt.accept(Output, astt.root(), v);
        _ = root;

        return Object{
            .id = Type.nil,
            .value = .{
                .nil = null,
            },
        };
    }

    fn visitor(self: *Self) Visitor(Output, Self, visitorFns) {
        return Visitor(Output, Self, visitorFns){ .context = self };
    }

    fn visit_binary_expr(self: *Self, astt: *const Ast, expr: Expr.Binary) Output {
        _ = self;
        _ = astt;
        _ = expr;
        return Object{
            .id = Type.nil,
            .value = .{
                .nil = null,
            },
        };
    }

    fn visit_grouping_expr(self: *Self, astt: *const Ast, expr: Expr.Grouping) Output {
        _ = self;
        _ = astt;
        _ = expr;
        return Object{
            .id = Type.nil,
            .value = .{
                .nil = null,
            },
        };
    }

    fn visit_literal_expr(self: *Self, expr: Expr.Literal) Output {
        _ = self;
        switch (expr.value.t_type) {
            .number => {},
            .string => {},
            .nil => {},
            .true => {},
            .false => {},
            else => {},
        }

        return Object{
            .id = Type.nil,
            .value = .{
                .nil = null,
            },
        };
    }

    fn visit_unary_expr(self: *Self, astt: *const Ast, expr: Expr.Unary) Output {
        _ = self;
        _ = astt;
        _ = expr;
        return Object{
            .id = Type.nil,
            .value = .{
                .nil = null,
            },
        };
    }
};
