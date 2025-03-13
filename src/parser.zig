const std = @import("std");
const tkn = @import("tokenizer.zig");
const ast = @import("ast.zig");

const ArrayList = std.ArrayList;
const Token = tkn.Token;
const TokenType = tkn.TokenType;
const Expr = ast.Expr;

pub const Parser = struct {
    tokens: ArrayList(Token),
    current: usize,

    const Self = @This();

    /// experssion -> equality ;
    pub fn expression(self: *Self) Expr {
        return self.equality();
    }

    fn equality(self: *Self) Expr {
        var expr = self.comparison();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            const right = self.comparison();
            expr = Expr{
                .binary = &Expr.Binary{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            };

            self.current += 1;
        }

        return expr;
    }

    fn comparison(self: *Self) Expr {
        var expr = self.term();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            const right = self.comparison();
            expr = Expr{ .binary = &Expr.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };

            self.current += 1;
        }

        return expr;
    }

    fn term(self: *Self) Expr {
        var expr = self.factor();

        while (self.match(.minus) or self.match(.plus)) {
            const operator = self.tokens.items[self.current];
            const right = self.factor();
            expr = Expr{ .binary = &Expr.Binary{
                .left = expr,
                .operator = operator,
                .right = right,
            } };

            self.current += 1;
        }

        return expr;
    }

    fn factor(self: *Self) Expr {
        var expr = self.unary();

        while (self.match(.slash) or self.match(.star)) {
            const operator = self.tokens.items[self.current];
            const right = self.unary();
            expr = Expr{
                .binary = &Expr.Binary{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            };

            self.current += 1;
        }

        return expr;
    }

    fn unary(self: *Self) Expr {
        if (self.match(.bang) or self.match(.minus)) {
            const operator = self.tokens.items[self.current];
            const right = self.unary();
            self.current += 1;
            return Expr{
                .unary = &Expr.Unary{
                    .operator = operator,
                    .right = right,
                },
            };
        }

        return self.primary();
    }

    fn primary(self: *Self) Expr {
        var ret: ?Expr = null;
        if (self.match(.false) or self.match(.true) or self.match(.nil) or self.match(.number) or self.match(.string)) {
            ret = Expr{
                .literal = &Expr.Literal{
                    .value = self.tokens.items[self.current],
                },
            };
        }

        if (self.match(.left_paren)) {
            const expr = self.expression();

            self.consume(.right_paren, "Expect ')' after expression.") catch {};

            ret = Expr{
                .grouping = &Expr.Grouping{
                    .expression = expr,
                },
            };
        }
        self.current += 1;

        return if (ret) |e| e else unreachable;
    }

    fn match(self: *Self, token_type: TokenType) bool {
        return self.tokens.items[self.current].t_type == token_type;
    }

    fn consume(self: *Self, token_type: TokenType, msg: []const u8) !void {
        if (self.match(token_type)) {
            self.current += 1;
        }
        _ = msg;
    }
};
