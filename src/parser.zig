const std = @import("std");
const tkn = @import("tokenizer.zig");
const expressions = @import("expression.zig");
const stmts = @import("statement.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Token = tkn.Token;
const TokenType = tkn.TokenType;
const ExprNode = expressions.ExprNode;
const Stmt = stmts.Stmt;
const Expr = expressions.Expr;
const ExprIdx = expressions.ExprIdx;
const lox_error = @import("main.zig").@"error";

pub const ParseError = error{
    invalid_token,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: ArrayList(Token),
    source: []const u8,
    current: usize,
    ast: Expr,

    pub fn init(tokens: ArrayList(Token), source: []const u8) Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .current = 0,
            .ast = undefined,
        };
    }

    /// Caller owns the returned Ast
    pub fn parse(self: *Parser, allocator: Allocator) ArrayList(Stmt) {
        var statements = ArrayList(Stmt).init(allocator);
        while (!(self.tokens.items[self.current].t_type == .eof)) {
            // each statement that gets parsed gets its own expression tree
            self.ast = Expr.init(std.heap.page_allocator);
            const s = self.statement() catch unreachable;
            statements.append(s) catch unreachable;
        }
        return statements;
    }

    /// experssion -> equality ;
    fn expression(self: *Parser) ParseError!ExprIdx {
        return self.equality();
    }

    fn statement(self: *Parser) ParseError!Stmt {
        if (self.match(.print)) {
            self.current += 1;
            return self.print_statement();
        } else {
            return self.expression_statement();
        }
    }

    fn print_statement(self: *Parser) ParseError!Stmt {
        _ = try self.expression();
        try self.consume(.semicolon, "Expect ';' after value.");
        return Stmt{ .print = .{ .expression = self.ast } }; // this moves the expression tree into the stmt
    }

    fn expression_statement(self: *Parser) ParseError!Stmt {
        _ = try self.expression();
        try self.consume(.semicolon, "Expect ';' after expression.");
        return Stmt{ .expression = .{ .expression = self.ast } }; //this moves the expression tree into the stmt
    }

    fn equality(self: *Parser) ParseError!ExprIdx {
        var expr = try self.comparison();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.comparison();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn comparison(self: *Parser) ParseError!ExprIdx {
        var expr = try self.term();

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.term();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn term(self: *Parser) ParseError!ExprIdx {
        var expr = try self.factor();

        while (self.match(.minus) or self.match(.plus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.factor();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn factor(self: *Parser) ParseError!ExprIdx {
        var expr = try self.unary();

        while (self.match(.slash) or self.match(.star)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary();
            expr = try self.ast.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn unary(self: *Parser) ParseError!ExprIdx {
        if (self.match(.bang) or self.match(.minus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary();
            const expr = try self.ast.init_unary(operator, right);

            return expr;
        }

        return try self.primary();
    }

    fn primary(self: *Parser) ParseError!ExprIdx {
        var ret: ?ExprIdx = null;
        if (self.match(.false) or self.match(.true) or self.match(.nil) or self.match(.number) or self.match(.string)) {
            ret = try self.ast.init_literal(self.tokens.items[self.current]);
            self.current += 1;
        }

        if (self.match(.left_paren)) {
            self.current += 1;
            const expr = try self.expression();
            try self.consume(.right_paren, "Expect ')' after expression.");
            ret = try self.ast.init_grouping(expr);
        }

        return ret orelse
            self.@"error"(self.tokens.items[self.current], "Expect expression.");
    }

    fn match(self: *Parser, token_type: TokenType) bool {
        return if (self.current < self.tokens.items.len)
            self.tokens.items[self.current].t_type == token_type
        else
            false;
    }

    fn consume(self: *Parser, token_type: TokenType, msg: []const u8) ParseError!void {
        if (self.match(token_type)) {
            self.current += 1;
        } else {
            return self.@"error"(self.tokens.items[self.current], msg);
        }
    }

    fn @"error"(self: *Parser, token: Token, message: []const u8) ParseError {
        const lexeme = self.source[token.lexeme.start..token.lexeme.end];
        lox_error(token, lexeme, message);
        return ParseError.invalid_token;
    }

    fn synchronize(self: *Parser) void {
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
