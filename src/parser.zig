const std = @import("std");
const tkn = @import("tokenizer.zig");
const astt = @import("ast.zig");

const ArrayList = std.ArrayList;
const Token = tkn.Token;
const TokenType = tkn.TokenType;
const Expr = astt.Expr;
const Ast = astt.Ast;
const ExprIdx = astt.ExprIdx;
const lox_error = @import("main.zig").@"error";

pub const ParseError = error{
    invalid_token,
    OutOfMemory,
};

// TODO: Check that returning references does not cause issues.
pub const Parser = struct {
    tokens: ArrayList(Token),
    source: []const u8,
    current: usize,
    ast: Ast,

    const Self = @This();

    pub fn init(tokens: ArrayList(Token), source: []const u8) Self {
        const allocator = std.heap.page_allocator;
        return .{
            .tokens = tokens,
            .source = source,
            .current = 0,
            .ast = Ast{
                .expressions = ArrayList(Expr).init(allocator),
            },
        };
    }

    /// Caller owns the returned Ast
    pub fn parse(self: *Self) ?Ast {
        if (self.expression()) |_| {
            return self.ast;
        } else |_| {
            return null;
        }
    }

    /// experssion -> equality ;
    fn expression(self: *Self) ParseError!ExprIdx {
        return self.equality();
    }

    fn equality(self: *Self) ParseError!ExprIdx {
        var expr = try self.comparison();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.comparison();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn comparison(self: *Self) ParseError!ExprIdx {
        var expr = try self.term();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.term();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn term(self: *Self) ParseError!ExprIdx {
        var expr = try self.factor();

        while (self.match(.minus) or self.match(.plus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.factor();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn factor(self: *Self) ParseError!ExprIdx {
        var expr = try self.unary();

        while (self.match(.slash) or self.match(.star)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn unary(self: *Self) ParseError!ExprIdx {
        if (self.match(.bang) or self.match(.minus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary();
            const expr = try self.ast.init_unary(operator, right);

            return expr;
        }

        return try self.primary();
    }

    fn primary(self: *Self) ParseError!ExprIdx {
        var ret: ?ExprIdx = null;
        if (self.match(.false) or self.match(.true) or self.match(.nil) or self.match(.number) or self.match(.string)) {
            ret = try self.ast.init_literal(self.tokens.items[self.current]);
            self.current += 1;
        }

        if (self.match(.left_paren)) {
            self.current += 1;
            std.debug.print("matched left paren: {d}\n", .{self.current});

            const expr = try self.expression();

            std.debug.print("parsed expression: {d}\n", .{self.current});

            try self.consume(.right_paren, "Expect ')' after expression.");
            std.debug.print("consumed right paren: {d}\n", .{self.current});
            ret = try self.ast.init_grouping(expr);
        }

        return ret orelse
            self.@"error"(self.tokens.items[self.current], "Expect expression.");
    }

    fn match(self: *Self, token_type: TokenType) bool {
        return if (self.current < self.tokens.items.len)
            self.tokens.items[self.current].t_type == token_type
        else
            false;
    }

    fn consume(self: *Self, token_type: TokenType, msg: []const u8) ParseError!void {
        if (self.match(token_type)) {
            self.current += 1;
        } else {
            return self.@"error"(self.tokens.items[self.current], msg);
        }
    }

    fn @"error"(self: *Self, token: Token, message: []const u8) ParseError {
        const lexeme = self.source[token.lexeme.start..token.lexeme.end];
        lox_error(token, lexeme, message);
        return ParseError.invalid_token;
    }

    fn synchronize(self: *Self) void {
        self.current += 1;

        while (!self.is_at_end()) : (self.current += 1) {
            if (self.tokens.items[self.current - 1].t_type == .semicolon) return;

            switch (self.tokens.items[self.current].t_type) {
                .class, .fun, .@"var", .@"for", .@"if", .@"while", .print, .@"return" => return,
                else => {},
            }
        }
    }
};
