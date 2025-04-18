const std = @import("std");
const ArrayList = std.ArrayList;
const File = std.fs.File;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const TokenType = @import("tokenizer.zig").TokenType;
const Token = @import("tokenizer.zig").Token;
const interpeter = @import("interpreter.zig");
const Interpreter = interpeter.Interpreter;
const Expr = @import("expression.zig").ExprNode;
const Lexeme = @import("tokenizer.zig").Lexeme;
const Allocator = std.heap.page_allocator;
const Parser = @import("parser.zig").Parser;
const typing = @import("typing.zig");
const Environment = @import("environment.zig").Environment;

const InterpretingError = error{
    static,
    runtime,
    OutOfMemory,
};

const ExitCode = enum(u8) {
    ok = 0,
    too_many_arguments = 1,
    write_error = 2,
    file_error = 3,
    runtime_error = 4,
};

const REPL_BUFFER_SIZE: usize = 1024;
const FILE_BUFFER_SIZE: usize = 8192;

var had_error = false;
var had_runtime_error = false;

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
    } else if (args.len == 2) {
        run_file(args[1]) catch |err| {
            var out = std.io.getStdErr().writer();
            switch (err) {
                InterpretingError.static => {
                    exit_code = .file_error;
                    out.print("Unable to run file: {!}", .{err}) catch {};
                },
                InterpretingError.runtime => {
                    out.print("Unable to execute file: {!}", .{err}) catch {};
                    exit_code = .runtime_error;
                },
                else => unreachable,
            }
        };
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

    try run(file_buffer[0..bytes_read :0]);

    if (@atomicLoad(bool, &had_error, std.builtin.AtomicOrder.seq_cst)) {
        return InterpretingError.static;
    } else if (@atomicLoad(bool, &had_runtime_error, std.builtin.AtomicOrder.seq_cst)) {
        return InterpretingError.runtime;
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
            try run(s);
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

fn run(source: [:0]u8) !void {
    var tokenizer = Tokenizer{
        .source = source,
        .current = 0,
        .start = 0,
        .line = 0,
    };
    const allocator = std.heap.page_allocator;
    var tokens = ArrayList(Token).init(allocator);
    defer tokens.deinit();

    while (true) {
        const token = tokenizer.next();
        //std.debug.print("{any}: {s}\n", .{ token.t_type, source[token.lexeme.start..token.lexeme.end] });
        try tokens.append(token);

        if (token.t_type == .eof) {
            break;
        }
    }

    var p = Parser.init(tokens, source);
    const statements = p.parse(allocator) orelse return;
    defer statements.deinit();
    var interpreter = try Interpreter.init(source, allocator);

    _ = interpreter.interpret(statements.items) catch |e| {
        std.log.err("Error while executing: {!}\n", .{e});
        if (interpreter.error_payload) |payload| {
            runtime_error(payload.token, payload.message);
        }
    };
}

pub fn @"error"(token: Token, lexeme: []const u8, message: []const u8) void {
    if (token.t_type == TokenType.eof) {
        report(token.line, "end", message);
    } else {
        report(token.line, lexeme, message);
    }
}

pub fn runtime_error(token: Token, message: []const u8) void {
    var stderr = std.io.getStdErr().writer();

    stderr.print("{s}\n[line {d}]", .{ message, token.line }) catch {};
    @atomicStore(bool, &had_runtime_error, true, std.builtin.AtomicOrder.seq_cst);
}

fn report(line: usize, lexeme: []const u8, message: []const u8) void {
    var stderr = std.io.getStdErr().writer();

    stderr.print("[line {d}] Error at '{s}': {s}\n", .{ line, lexeme, message }) catch {};
    @atomicStore(bool, &had_error, true, std.builtin.AtomicOrder.seq_cst);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
