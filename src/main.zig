const std = @import("std");
const File = std.fs.File;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenType = @import("tokenizer.zig").TokenType;
const Token = @import("tokenizer.zig").Token;
const AstPrinter = @import("ast_printer.zig").AstPrinter;
const Expr = @import("ast.zig").Expr;
const Lexeme = @import("tokenizer.zig").Lexeme;
const Allocator = std.heap.page_allocator;

const InterpretingError = error{
    default,
};

const ExitCode = enum(u8) {
    ok = 0,
    too_many_arguments = 1,
    write_error = 2,
    file_error = 3,
};

const REPL_BUFFER_SIZE: usize = 1024;
const FILE_BUFFER_SIZE: usize = 8192;

var had_error = false;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    var exit_code: ExitCode = .ok;

    if (args.len > 2) {
        var out = std.io.getStdOut();
        _ = try out.write("Usage: jlox [script]");
        exit_code = .too_many_arguments;
    } else if (args.len == 1) {
        if (true) { //if (std.mem.eql(u8, "test", args[1])) {
            // zig fmt: off
            const source = "(1 + 2)";
            const expr = Expr{ 
                .grouping = &Expr.Grouping{ 
                    .expression = Expr {
                        .binary = &Expr.Binary {
                            .left = Expr {
                                .literal = &Expr.Literal {
                                    .value = Token {
                                        .t_type = TokenType.number,
                                        .lexeme = Lexeme {
                                            .start = 1,
                                            .end = 2,
                                        },
                                        .line = 0,
                                    }
                                }
                            },
                            .operator = Token {
                                .t_type = TokenType.plus,
                                .lexeme = Lexeme {
                                    .start = 3,
                                    .end = 4,
                                },
                                .line = 0,
                            },
                            .right = Expr {
                                .literal = &Expr.Literal {
                                    .value = Token {
                                        .t_type = TokenType.number,
                                        .lexeme = Lexeme {
                                            .start = 5,
                                            .end = 6,
                                        },
                                        .line = 0,
                                    }
                                }
                            }
                        }
                    }
                } 
            };
            // zig fmt: on
            var printer = AstPrinter.new(source, gpa.allocator());
            printer.print(expr);
        } else {
            run_file(args[1]) catch |err| {
                var out = std.io.getStdOut().writer();
                out.print("Unable to run file: {!}", .{err}) catch {};
                exit_code = .file_error;
            };
        }
    } else {
        run_prompt() catch {
            exit_code = .write_error;
        };
    }

    return @intFromEnum(exit_code);
}

fn run_file(path: [:0]const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var file_buffer: [FILE_BUFFER_SIZE:0]u8 = [_:0]u8{0} ** FILE_BUFFER_SIZE;
    const bytes_read = try file.reader().readAll(&file_buffer);

    run(file_buffer[0..bytes_read :0]);

    if (@atomicLoad(bool, &had_error, std.builtin.AtomicOrder.seq_cst)) {
        return InterpretingError.default;
    }
}

fn run_prompt() !void {
    var stdout = std.io.getStdOut();
    const writer = stdout.writer();
    var stdin = std.io.getStdIn();
    const reader = stdin.reader();
    var input_buffer = try std.BoundedArray(u8, REPL_BUFFER_SIZE).init(0);

    while (true) {
        _ = try writer.print("> ", .{});
        if (reader.streamUntilDelimiter(input_buffer.writer(), '\n', REPL_BUFFER_SIZE - 1)) {
            input_buffer.append(0) catch unreachable; // zero terminate
            const s = input_buffer.slice()[0 .. input_buffer.len - 1 :0];
            run(s);
        } else |err| {
            try std.io.getStdErr()
                .writer()
                .print("{!}: input too long, more than {d} bytes\n", .{ err, REPL_BUFFER_SIZE });
            break;
        }
        input_buffer.resize(0) catch unreachable;
        @atomicStore(bool, &had_error, false, std.builtin.AtomicOrder.seq_cst);
    }
}

fn run(source: [:0]u8) void {
    var tokenizer = Tokenizer{
        .source = source,
        .current = 0,
        .start = 0,
        .line = 0,
    };
    std.io.getStdOut().writer().print("{s}\n", .{source}) catch {};
    while (true) {
        const token = tokenizer.next();
        std.debug.print("{any}\n", .{token});
        if (token.t_type == .eof) {
            break;
        }
    }
}

fn @"error"(line: usize, message: []const u8) void {
    report(line, "", message);
}

fn report(line: usize, where: []const u8, message: []const u8) void {
    var stderr = std.io.getStdErr().writer();

    stderr.print("[line {d}] Error {s}: {s}", .{ line, where, message }) catch {};
    @atomicStore(bool, &had_error, true, std.builtin.AtomicOrder.seq_cst);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
