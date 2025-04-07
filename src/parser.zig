const std = @import("std");
const tkn = @import("tokenizer.zig");
const expressions = @import("expression.zig");
const stmts = @import("statement.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Token = tkn.Token;
const TokenType = tkn.TokenType;
const ExprNode = expressions.Expr.ExprNode;
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

    pub fn init(tokens: ArrayList(Token), source: []const u8) Parser {
        return .{
            .tokens = tokens,
            .source = source,
            .current = 0,
        };
    }

    /// Caller owns the returned Ast
    pub fn parse(self: *Parser, allocator: Allocator) ?ArrayList(Stmt) {
        var statements = ArrayList(Stmt).init(allocator);
        var had_error = false;
        while (!(self.tokens.items[self.current].t_type == .eof)) {
            if (self.declaration()) |stmt| {
                statements.append(stmt) catch {}; // TODO: think about if this should return an error
            } else |_| {
                had_error = true;
                self.synchronize();
            }
        }
        return if (had_error) null else statements;
    }

    /// experssion -> equality ;
    fn expression_p(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        return self.assignment(expression);
    }

    fn declaration(self: *Parser) ParseError!Stmt {
        if (self.match(.@"var")) {
            self.current += 1;
            return self.var_declaration();
        } else {
            return self.statement();
        }
    }

    fn statement(self: *Parser) ParseError!Stmt {
        if (self.match(.print)) {
            self.current += 1;
            return self.print_statement();
        } else if (self.match(.@"while")) {
            self.current += 1;
            return self.while_statement();
        } else if (self.match(.@"if")) {
            self.current += 1;
            return self.if_statement();
        } else if (self.match(.@"for")) {
            self.current += 1;
            return self.for_statement();
        } else if (self.match(.left_brace)) {
            self.current += 1;
            return Stmt{
                .block = Stmt.Block{ .statements = try self.block() },
            };
        } else {
            return self.expression_statement();
        }
    }

    fn print_statement(self: *Parser) ParseError!Stmt {
        var expression = Expr.init(std.heap.page_allocator);
        _ = try self.expression_p(&expression);
        _ = try self.consume(.semicolon, "Expect ';' after value.");
        return Stmt{ .print = .{ .expression = expression } }; // this moves the expression tree into the stmt
    }

    fn while_statement(self: *Parser) ParseError!Stmt {
        _ = try self.consume(.left_paren, "Expect '(' after 'while'.");
        var condition = Expr.init(std.heap.page_allocator);
        _ = try self.expression_p(&condition);
        _ = try self.consume(.right_paren, "Expect ')' after condition.");
        const body = try self.statement();
        const alloc = std.heap.page_allocator;
        const body_ptr = try alloc.create(Stmt);
        body_ptr.* = body;

        return Stmt{
            .@"while" = .{
                .condition = condition,
                .body = body_ptr,
                .alloc = alloc,
            },
        };
    }

    fn if_statement(self: *Parser) ParseError!Stmt {
        const alloc = std.heap.page_allocator;
        _ = try self.consume(.left_paren, "Expect '(' after 'if'");
        var condition = Expr.init(std.heap.page_allocator);
        _ = try self.expression_p(&condition);
        _ = try self.consume(.right_paren, "Expect ')' after if condition");

        const then_branch: *Stmt = try alloc.create(Stmt);
        errdefer alloc.destroy(then_branch);
        then_branch.* = try self.statement();

        var else_branch: ?*Stmt = null;

        if (self.match(.@"else")) {
            self.current += 1;
            else_branch = try alloc.create(Stmt);
            errdefer alloc.destroy(else_branch.?);
            else_branch.?.* = try self.statement();
        }

        return Stmt{
            .@"if" = .{
                .condition = condition,
                .then_branch = then_branch,
                .else_branch = else_branch,
                .alloc = alloc,
            },
        };
    }

    fn for_statement(self: *Parser) ParseError!Stmt {
        _ = try self.consume(.left_paren, "Expect '(' after 'for'.");

        var initializer: ?Stmt = undefined;

        if (self.match(.semicolon)) {
            self.current += 1;
            initializer = null;
        } else if (self.match(.@"var")) {
            self.current += 1;
            initializer = try self.var_declaration();
        } else {
            initializer = try self.expression_statement();
        }

        var condition: ?Expr = null;

        if (!self.match(.semicolon)) {
            condition = Expr.init(std.heap.page_allocator);
            _ = try self.expression_p(&(condition.?));
        }

        _ = try self.consume(.semicolon, "Expect ';' after loop condition");

        var increment: ?Expr = null;
        if (!self.match(.right_paren)) {
            increment = Expr.init(std.heap.page_allocator);
            _ = try self.expression_p(&(increment.?));
        }

        _ = try self.consume(.right_paren, "Expect ')' after for clauses");

        var body = try self.statement();
        if (increment) |incr| {
            var statements = ArrayList(Stmt).init(std.heap.page_allocator);
            try statements.append(body);
            try statements.append(
                Stmt{
                    .expression = .{ .expression = incr },
                },
            );
            body = Stmt{ .block = .{ .statements = statements } };
        }

        return body;
    }

    fn var_declaration(self: *Parser) ParseError!Stmt {
        const name = try self.consume(.identifier, "Expect variable name.");

        var initializer: ?Expr = null;

        if (self.match(.equal)) {
            self.current += 1;
            initializer = Expr.init(std.heap.page_allocator);
            _ = try self.expression_p(&(initializer.?));
        }
        _ = try self.consume(.semicolon, "Expect ';' after variable declaration.");

        return Stmt{ .@"var" = .{ .name = name, .initializer = initializer } };
    }

    fn expression_statement(self: *Parser) ParseError!Stmt {
        var expression = Expr.init(std.heap.page_allocator);

        _ = try self.expression_p(&expression);
        _ = try self.consume(.semicolon, "Expect ';' after expression.");
        return Stmt{ .expression = .{ .expression = expression } };
    }

    fn block(self: *Parser) ParseError!ArrayList(Stmt) {
        var statements = ArrayList(Stmt).init(std.heap.page_allocator);

        while (!self.match(.right_brace) and !(self.tokens.items[self.current].t_type == .eof)) {
            try statements.append(try self.declaration());
        }

        _ = try self.consume(.right_brace, "Expect '}' after block.");

        return statements;
    }

    fn assignment(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        const expr = try self.@"or"(expression);

        if (self.match(.equal)) {
            const equals = self.tokens.items[self.current];
            // move past the equal token
            self.current += 1;
            const value = try self.assignment(expression);

            if (expression.get(value) == .variable) {
                return expression.init_assign(expression.get(value).variable.name, value);
            }

            return self.@"error"(equals, "Invalid assignment target\n.");
        }

        return expr;
    }

    fn @"or"(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.@"and"(expression);

        while (self.match(.@"or")) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.@"and"(expression);
            expr = try expression.init_logical(expr, operator, right);
        }

        return expr;
    }

    fn @"and"(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.equality(expression);

        while (self.match(.@"and")) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.equality(expression);
            const node = ExprNode{
                .logical = .{
                    .left = expr,
                    .operator = operator,
                    .right = right,
                },
            };
            expr = try expression.add(node);
        }

        return expr;
    }

    fn equality(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.comparison(expression);

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.comparison(expression);
            expr = try expression.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn comparison(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.term(expression);

        while (self.match(.bang_equal) or self.match(.equal_equal)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.term(expression);
            expr = try expression.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn term(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.factor(expression);

        while (self.match(.minus) or self.match(.plus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.factor(expression);
            expr = try expression.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn factor(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var expr = try self.unary(expression);

        while (self.match(.slash) or self.match(.star)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary(expression);
            expr = try expression.init_binary(expr, operator, right);
        }

        return expr;
    }

    fn unary(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        if (self.match(.bang) or self.match(.minus)) {
            const operator = self.tokens.items[self.current];
            self.current += 1;
            const right = try self.unary(expression);
            const expr = try expression.init_unary(operator, right);

            return expr;
        }

        return try self.primary(expression);
    }

    fn primary(self: *Parser, expression: *Expr) ParseError!ExprIdx {
        var ret: ?ExprIdx = null;
        if (self.match(.false) or self.match(.true) or self.match(.nil) or self.match(.number) or self.match(.string)) {
            ret = try expression.init_literal(self.tokens.items[self.current]);
            self.current += 1;
        } else if (self.match(.identifier)) {
            ret = try expression.init_variable(self.tokens.items[self.current]);
            self.current += 1;
        } else if (self.match(.left_paren)) {
            self.current += 1;
            const expr = try self.expression_p(expression);
            _ = try self.consume(.right_paren, "Expect ')' after expression.");
            ret = try expression.init_grouping(expr);
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

    fn consume(self: *Parser, token_type: TokenType, msg: []const u8) ParseError!Token {
        if (self.match(token_type)) {
            defer self.current += 1;
            return self.tokens.items[self.current];
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

        while (self.tokens.items[self.current].t_type != .eof) : (self.current += 1) {
            if (self.tokens.items[self.current - 1].t_type == .semicolon) return;

            switch (self.tokens.items[self.current].t_type) {
                .class, .fun, .@"var", .@"for", .@"if", .@"while", .print, .@"return" => return,
                else => {},
            }
        }
    }
};
