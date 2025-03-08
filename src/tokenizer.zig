const std = @import("std");

pub const TokenType = enum {
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

    // Special.
    eof,
    invalid,
};

// zig fmt: off
pub const keywords = std.StaticStringMap(TokenType).initComptime(.{
    .{"and", .@"and"},
    .{"class", .@"class"},
    .{"else", .@"else"},
    .{"false", .@"false"},
    .{"fun", .fun},
    .{"for", .@"for"},
    .{"if", .@"if"},
    .{"nil", .nil},
    .{"or", .@"or"},
    .{"print", .print},
    .{"return", .@"return"},
    .{"super", .super},
    .{"this", .this},
    .{"true", .true},
    .{"bar", .bar},
    .{"while", .@"while"}
});
// zig fmt: on

const Token = struct {
    t_type: TokenType,
    lexeme: Lexeme,
    line: usize,
};

const Lexeme = struct {
    start: usize,
    end: usize,
};

// zig fmt: off
const TokenizerState = enum {
    start,
    bang,
    equal,
    greater,
    less,
    invalid,
    number,
    number_period,
    float,
    identifier,
    string,
};
// zig fmt: on

// TODO: add error handling for null byte and invalid state
pub const Tokenizer = struct {
    source: [:0]const u8,
    start: usize,
    current: usize,
    line: usize,

    const Self = @This();

    pub fn next(self: *Self) Token {
        var next_token: Token = undefined;

        state: switch (TokenizerState.start) {
            .start => switch (self.consume()) {
                0 => if (self.is_at_end()) {
                    self.make_token(&next_token, .eof);
                } else {
                    continue :state .invalid;
                },
                // handle single character tokens
                '(', ')', '{', '}', ',', '.', '-', '+', ';', '*' => {
                    self.parse_single_character_token(self.source[self.current], &next_token);
                },
                '\n' => {
                    self.line += 1;
                    continue :state .start;
                },
                ' ' => continue :state .start,
                '!' => continue :state .bang,
                '=' => continue :state .equal,
                '>' => continue :state .greater,
                '<' => continue :state .less,
                '0'...'9' => continue :state .number,
                '_', 'a'...'z', 'A'...'Z' => continue :state .identifier,
                '"' => continue :state .string,
                else => continue :state .invalid,
            },
            // invalid token handling: parse until eof or eol
            .invalid => switch (self.peek()) {
                0 => if (self.is_at_end()) {
                    self.make_token(&next_token, .invalid);
                } else {
                    continue :state .invalid;
                },
                '\n' => {
                    self.line += 1;
                    self.make_token(&next_token, .invalid);
                },
                else => continue :state .invalid,
            },
            // two character tokens
            .bang => if (self.match('=')) {
                self.advance();
                self.make_token(&next_token, .bang_equal);
            } else self.make_token(&next_token, .bang),
            .equal => if (self.match('=')) {
                self.advance();
                self.make_token(&next_token, .equal_equal);
            } else self.make_token(&next_token, .equal),
            .less => if (self.match('=')) {
                self.advance();
                self.make_token(&next_token, .less_equal);
            } else self.make_token(&next_token, .less),
            .greater => if (self.match('=')) {
                self.advance();
                self.make_token(&next_token, .greater_equal);
            } else self.make_token(&next_token, .greater),
            // literals
            .number => {
                switch (self.peek()) {
                    '0'...'9' => {
                        self.advance();
                        continue :state .number;
                    },
                    '.' => {
                        self.advance(); // advance past the '.'
                        continue :state .number_period;
                    },
                    else => self.make_token(&next_token, .number),
                }
            },
            .number_period => switch (self.peek()) {
                '0'...'9' => {
                    self.advance();
                    continue :state .number_period;
                },
                else => self.retreat(),
            },
            .float => switch (self.peek()) {
                '0'...'9' => {
                    self.advance();
                    continue :state .float;
                },
                else => {
                    self.make_token(&next_token, .number);
                },
            },
            .identifier => switch (self.peek()) {
                '_', 'a'...'z', 'A'...'Z', '0'...'9' => {
                    self.advance();
                    continue :state .identifier;
                },
                else => {
                    if (keywords.get(self.source[self.start..self.current])) |keyword|
                        self.make_token(&next_token, keyword)
                    else
                        self.make_token(&next_token, .identifier);
                },
            },
            .string => switch (self.consume()) {
                0 => if (!self.is_at_end()) {
                    self.make_token(&next_token, .invalid);
                } else {
                    continue :state .invalid;
                },
                '\n' => self.make_token(&next_token, .invalid),
                '"' => self.make_token(&next_token, .string),
                else => continue :state .string,
            },
        }
        self.start = self.current;
        return next_token;
    }

    fn parse_single_character_token(self: *const Self, c: u8, token: *Token) void {
        switch (c) {
            '(' => self.make_token(token, .right_paren),
            ')' => self.make_token(token, .left_paren),
            '{' => self.make_token(token, .left_brace),
            '}' => self.make_token(token, .right_brace),
            ',' => self.make_token(token, .comma),
            '.' => self.make_token(token, .dot),
            '-' => self.make_token(token, .minus),
            '+' => self.make_token(token, .plus),
            ';' => self.make_token(token, .semicolon),
            '*' => self.make_token(token, .star),
            else => unreachable,
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

    fn retreat(self: *Self) void {
        self.current -= 1;
    }

    fn peek(self: *Self) u8 {
        return self.source[self.current];
    }

    fn peek_next(self: *Self) u8 {
        return self.source[self.current + 1];
    }

    fn consume(self: *Self) u8 {
        defer self.current += 1;
        return self.peek();
    }

    fn match(self: *Self, char: u8) bool {
        return self.peek() == char;
    }

    fn is_at_end(self: *const Self) bool {
        return self.current >= self.source.len;
    }
};
