const std = @import("std");
const build_options = @import("build_options");

const OutputType = union(enum) {
    raw: usize,
    base64: usize,
    hex: usize,
    words: WordOptions,
};

// WordOptions defines all properties related to word list keys.
const WordOptions = struct {
    word_list: []const u8,
    word_count: usize,
    separator: []const u8,
    unique: bool, // Can we accept duplicate words?
    numbered: bool, // Add a single digit toe each word?

    pub fn init() @This() {
        return .{
            .word_list = "",
            .word_count = 0,
            .separator = "-",
            .unique = true,
            .numbered = false,
        };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const alloc = arena.allocator();
    const output = try parseArgs(alloc);

    switch (output) {
        .raw => |v| try generateRaw(alloc, v),
        .base64 => |v| try generateBase64(alloc, v),
        .hex => |v| try generateHex(alloc, v),
        .words => |v| try generateWords(alloc, v),
    }
}

fn generateRaw(alloc: std.mem.Allocator, size: usize) !void {
    var stdout = std.io.getStdOut();
    var w = stdout.writer();

    const buf = try alloc.alloc(u8, size);
    std.crypto.random.bytes(buf);

    _ = try w.write(buf);
}

fn generateBase64(alloc: std.mem.Allocator, size: usize) !void {
    var stdout = std.io.getStdOut();
    const w = stdout.writer();

    const buf = try alloc.alloc(u8, size);
    std.crypto.random.bytes(buf);

    var fb = std.io.fixedBufferStream(buf);
    const fbr = fb.reader();

    var lr = std.io.limitedReader(fbr, size);
    const lrr = lr.reader();

    try std.base64.standard.Encoder.encodeFromReaderToWriter(w, lrr);
}

fn generateHex(alloc: std.mem.Allocator, size: usize) !void {
    var stdout = std.io.getStdOut();
    const w = stdout.writer();

    const buf = try alloc.alloc(u8, size);
    std.crypto.random.bytes(buf);

    try w.print("{}", .{std.fmt.fmtSliceHexLower(buf)});
}

fn generateWords(alloc: std.mem.Allocator, words: WordOptions) !void {
    const word_list = try readWords(alloc, words.word_list);
    defer word_list.deinit();

    var out = std.ArrayList(u8).init(alloc);
    defer out.deinit();

    var i: usize = 0;
    while (i < words.word_count) : (i += 1) {
        if (words.unique) {
            // Repeat this a few times in case we keep getting words we already used.
            // This is likely to happen in short word lists. If, after 100 tries, we
            // still an't find a valid word, we give up.
            var j: usize = 0;
            while (j < 100) : (j += 1) {
                const n = std.crypto.random.uintLessThan(usize, word_list.items.len);
                const new_word = word_list.items[n];

                if (std.mem.indexOf(u8, out.items, new_word) != null)
                    continue;

                try out.appendSlice(new_word);

                if (words.numbered)
                    try out.append(std.crypto.random.intRangeAtMost(u8, '0', '9'));
                break;
            } else {
                std.log.err("unable to generate enough unique words; the word list may be too short", .{});
                std.process.exit(1);
            }
        } else {
            const n = std.crypto.random.uintLessThan(usize, word_list.items.len);
            const new_word = word_list.items[n];

            try out.appendSlice(new_word);

            if (words.numbered)
                try out.append(std.crypto.random.intRangeAtMost(u8, '0', '9'));
        }

        if (i < words.word_count - 1)
            try out.appendSlice(words.separator);
    }

    var stdout = std.io.getStdOut();
    const w = stdout.writer();
    try w.print("{s}", .{out.items});
}

/// readWords reads the given file and splits it into lines.
fn readWords(alloc: std.mem.Allocator, file: []const u8) !std.ArrayList([]const u8) {
    const fd = try std.fs.cwd().openFile(file, .{});
    defer fd.close();

    var buf_reader = std.io.bufferedReader(fd.reader());
    var output = std.ArrayList([]const u8).init(alloc);

    var line = std.ArrayList(u8).init(alloc);
    defer line.deinit();

    const r = buf_reader.reader();
    while (r.streamUntilDelimiter(line.writer(), '\n', null)) {
        defer line.clearRetainingCapacity();
        const word = std.mem.trim(u8, line.items, " \t\r\n");
        if (word.len > 0) try output.append(try alloc.dupe(u8, word));
    } else |err| switch (err) {
        error.EndOfStream => {
            const word = std.mem.trim(u8, line.items, " \t\r\n");
            if (word.len > 0) try output.append(try alloc.dupe(u8, word));
        },
        else => return err,
    }

    return output;
}

/// parseArgs parses commandline arguments and returns the output properties defined in them.
fn parseArgs(alloc: std.mem.Allocator) !OutputType {
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    if (!args.skip()) return error.MissingExeName;
    var output: OutputType = .{ .raw = 0 };
    var size: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-help")) {
            try printUsage();
            std.process.exit(0);
        }

        if (std.mem.eql(u8, arg, "-version")) {
            try printVersion();
            std.process.exit(0);
        }

        if (std.mem.eql(u8, arg, "-base64")) {
            output = .{ .base64 = 0 };
            continue;
        }

        if (std.mem.eql(u8, arg, "-hex")) {
            output = .{ .hex = 0 };
            continue;
        }

        if (std.mem.eql(u8, arg, "-words")) {
            if (output != .words)
                output = .{ .words = WordOptions.init() };
            output.words.word_list = try alloc.dupe(u8, args.next() orelse {
                std.log.err("missing value for -words", .{});
                std.process.exit(1);
            });
            continue;
        }

        if (std.mem.eql(u8, arg, "-not-unique")) {
            if (output != .words)
                output = .{ .words = WordOptions.init() };
            output.words.unique = false;
            continue;
        }

        if (std.mem.eql(u8, arg, "-separator")) {
            if (output != .words)
                output = .{ .words = WordOptions.init() };
            output.words.separator = try alloc.dupe(u8, args.next() orelse {
                std.log.err("missing value for -separator", .{});
                std.process.exit(1);
            });
            continue;
        }

        if (std.mem.eql(u8, arg, "-numbered")) {
            if (output != .words)
                output = .{ .words = WordOptions.init() };
            output.words.numbered = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "-size")) {
            const numStr = try alloc.dupe(u8, args.next() orelse {
                std.log.err("missing value for -size", .{});
                std.process.exit(1);
            });
            size = try std.fmt.parseUnsigned(usize, numStr, 10);
            continue;
        }

        std.log.err("unknown option {s}", .{arg});
        std.process.exit(1);
    }

    if (size == 0) {
        try printUsage();
        std.process.exit(1);
    }

    switch (output) {
        .words => |w| if (w.word_list.len == 0) {
            std.log.err("missing word list", .{});
            std.process.exit(1);
        },
        else => {},
    }

    // @size is to be encoded in the @output value as a union enum.
    return switch (output) {
        .raw => .{ .raw = size },
        .base64 => .{ .base64 = size },
        .hex => .{ .hex = size },
        .words => |w| .{ .words = .{
            .word_list = w.word_list,
            .separator = w.separator,
            .unique = w.unique,
            .numbered = w.numbered,
            .word_count = size,
        } },
    };
}

/// Print version information.
fn printVersion() !void {
    var stderr = std.io.getStdErr();
    var bw = std.io.bufferedWriter(stderr.writer());
    const w = bw.writer();
    try w.print("{s} {}, {s}\n", .{
        build_options.app_name,
        build_options.app_version,
        build_options.app_vendor,
    });
    try bw.flush();
}

/// Prints usage information.
fn printUsage() !void {
    var stderr = std.io.getStdErr();

    var bw = std.io.bufferedWriter(stderr.writer());
    const w = bw.writer();

    try w.print("usage: {s} [options]\n", .{build_options.app_name});
    try w.print("\nFor the raw byte output, @size refers to the number of bytes in the output.\n", .{});

    try w.print("\nFor the following forms, @size refers to the number of bytes before encoding is applied.\n", .{});
    try w.print(" -base64  : Encode the result as base64. @size defines the number of bytes before encoding.\n", .{});
    try w.print(" -hex     : Encode the result as a hex string. @size defines the number of bytes before encoding.\n", .{});

    try w.print("\nFor the following form, @size refers to the number of words in the output.\n", .{});
    try w.print(" -words <wordlist>       : Generate a key from one or more words in the provided list.\n", .{});
    try w.print(" -not-unique             : If set, the output can contain the same word more than once.\n", .{});
    try w.print(" -separator <separator>  : Defines the separator to be used between each word. Defaults to '-'.\n", .{});
    try w.print(" -numbered               : Append a random single digit to each word.\n", .{});

    try w.print("\n", .{});
    try w.print(" -help     : Display this help.\n", .{});
    try w.print(" -version  : Display version information.\n", .{});
    try bw.flush();
}
