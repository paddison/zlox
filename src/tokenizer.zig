const TokenType = enum {
    // Single-character tokens.
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // One or two character tokens.
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    // Literals.
    identifier,
    string,
    number,

    // Keywords.
    @"and",
    class,
    @"else",
    false,
    fun,
    @"for",
    @"if",
    nil,

    @"or",
    print,
    @"return",
    super,
    this,
    true,
    bar,
    @"while",
    eof,
};

const Token = struct {
    t_type: TokenType,
    lexeme: Lexeme,
    line: usize,
};

const Lexeme = struct {
    start: usize,
    end: usize,
};

const TokenizerState = enum {
    start,
    bang,
    equal,
    greater,
    less,
};

const Tokenizer = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: usize,

    const Self = @This();

    fn next(self: *Self) Token {
        var next_token: Token = undefined;

        transition: switch (TokenizerState.start) {
            .start => switch (self.consume()) {
                // handle single character tokens
                '(', ')', '{', '}', ',', '.', '-', '+', ';', '*' => {
                    self.advance();
                    self.parse_single_character_token(self.source[self.current], &next_token);
                },
                '\n' => {
                    self.advance();
                    self.line += 1;
                    continue :transition .start;
                },
                ' ' => {
                    self.advance();
                    continue :transition .start;
                },
                '!' => {
                    self.advance();
                    continue :transition .bang;
                },
                '=' => {
                    self.advance();
                    continue :transition .equal;
                },
                '>' => {
                    self.advance();
                    continue :transition .greater;
                },
                '<' => {
                    self.advance();
                    continue :transition .less;
                },
            },
            .bang => switch (self.peek()) {
                '!' => {
                    self.advance();
                    self.make_token(next_token, .bang_equal);
                },
                else => continue :transition .start,
            },
            .equal => switch (self.peek()) {
                '=' => {
                    self.advance();
                    self.make_token(next_token, .equal_equal);
                },
                else => continue :transition .start,
            },
            .less => switch (self.peek()) {
                '=' => {
                    self.advance();
                    self.make_token(next_token, .less_equal);
                },
                else => continue :transition .start,
            },
            .greater => switch (self.peek()) {
                '=' => {
                    self.advance();
                    self.make_token(next_token, .greater_equal);
                },
                else => continue :transition .start,
            },
        }
        self.start = self.current;
        return next_token;
    }

    fn parse_single_character_token(self: *const Self, c: u8, token: *Token) void {
        switch (c) {
            '(' => self.make_token(&token, .right_paren),
            ')' => self.make_token(&token, .left_paren),
            '{' => self.make_token(&token, .left_brace),
            '}' => self.make_token(&token, .right_brace),
            ',' => self.make_token(&token, .comma),
            '.' => self.make_token(&token, .dot),
            '-' => self.make_token(&token, .minus),
            '+' => self.make_token(&token, .plus),
            ';' => self.make_token(&token, .semicolon),
            '*' => self.make_token(&token, .star),
        }
    }

    fn make_token(self: *const Self, token: *Token, t_type: TokenType) void {
        token.t_type = t_type;
        token.line = self.line;
        token.lexeme = Lexeme{
            .start = self.start,
            .end = self.current,
        };
    }

    fn advance(self: *Self) void {
        self.current += 1;
    }

    fn peek(self: *Self) u8 {
        return self.source[self.current];
    }

    fn consume(self: *Self) u8 {
        defer self.current += 1;
        return self.peek;
    }

    fn is_at_end(self: *const Self) bool {
        return self.current >= self.source.len;
    }
};
