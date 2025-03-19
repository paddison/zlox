const ast = @import("ast.zig");
const Visitor = ast.Visitor;
const Ast = ast.Ast;
const ExprIdx = ast.ExprIdx;
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
        return astt.accept(Output, astt.root(), v);
    }

    fn visitor(self: *Self) Visitor(Output, Self, visitorFns) {
        return Visitor(Output, Self, visitorFns){ .context = self };
    }

    pub fn visit_binary_expr(self: *Self, astt: *const Ast, expr: Expr.Binary) Output {
        const left = self.evaluate(astt, expr.left);
        const right = self.evaluate(astt, expr.right);

        return switch (expr.operator.t_type) {
            .greater => left.greater(&right),
            .greater_equal => left.greater_equal(&right),
            .less => left.less(&right),
            .less_equal => left.less_equal(&right),
            .minus => left.sub(&right),
            .plus => if (left.instance_of(Type.number) and right.instance_of(Type.number))
                left.add(&right)
            else if (left.instance_of(Type.string) and right.instance_of(Type.string))
                left.concat(&right)
            else
                unreachable,
            .slash => left.div(&right),
            .star => left.mul(&right),
            .bang_equal => right.equals(&left).bnegate(),
            .equal_equal => right.equals(&left),
            else => unreachable,
        };
    }

    pub fn visit_grouping_expr(self: *Self, astt: *const Ast, expr: Expr.Grouping) Output {
        return evaluate(self, astt, expr.expression);
    }

    pub fn visit_literal_expr(self: *Self, expr: Expr.Literal) Output {
        const lexeme = self.source[expr.value.lexeme.start..expr.value.lexeme.end];

        const value = switch (expr.value.t_type) {
            .number => Object.new(Type.Number, lexeme),
            .string => Object.new(Type.String, lexeme),
            .nil => Object.new(Type.Nil, .{}),
            .true => Object.new(Type.Bool, true),
            .false => Object.new(Type.Bool, false),
            else => unreachable,
        };

        if (value) |v| {
            return v;
        } else |err| {
            @import("std").debug.print("error when interpreting literal expr {!}", .{err});
        }

        return Object{
            .nil = {},
        };
    }

    pub fn visit_unary_expr(self: *Self, astt: *const Ast, expr: Expr.Unary) Output {
        const right = evaluate(self, astt, expr.right);

        return switch (expr.operator.t_type) {
            .bang => right.is_truthy().bnegate(), // maybe make negate function generic over type
            .minus => right.negate(),
            else => unreachable,
        };
    }

    fn evaluate(self: *Self, astt: *const Ast, expr_idx: ExprIdx) Object {
        return astt.accept(Output, expr_idx, self);
    }
};
