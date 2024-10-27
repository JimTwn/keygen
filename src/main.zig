const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    const exe_path = args.next() orelse return error.MissingExeName;
    var output: OutputType = .raw;
    var size: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-base64")) {
            output = .base64;
            continue;
        }

        if (std.mem.eql(u8, arg, "-hex")) {
            output = .hex;
            continue;
        }

        size = try std.fmt.parseUnsigned(usize, arg, 10);
        break;
    }

    if (size == 0) {
        std.log.err("invalid size", .{});
        try usage(exe_path);
        std.process.exit(1);
    }

    const buf = try alloc.alloc(u8, size);
    defer alloc.free(buf);

    std.crypto.random.bytes(buf);

    var stdout = std.io.getStdOut();
    var w = stdout.writer();

    switch (output) {
        .raw => _ = try w.write(buf),
        .base64 => {
            var fb = std.io.fixedBufferStream(buf);
            const fbr = fb.reader();

            var lr = std.io.limitedReader(fbr, size);
            const lrr = lr.reader();

            try std.base64.standard.Encoder.encodeFromReaderToWriter(w, lrr);
        },
        .hex => {
            try w.print("{}", .{std.fmt.fmtSliceHexLower(buf)});
        },
    }
}

/// usage prints usage information.
fn usage(exe: []const u8) !void {
    var stderr = std.io.getStdErr();

    var bw = std.io.bufferedWriter(stderr.writer());
    const w = bw.writer();

    try w.print("{s} [options] <size>\n\n", .{exe});
    try w.print(" -base32:  Encode the result as base32.\n", .{});
    try w.print(" -base64:  Encode the result as base64.\n", .{});
    try w.print(" -hex:     Encode the result as a hex string.\n", .{});
    try bw.flush();
}

const OutputType = enum {
    raw,
    base64,
    hex,
};
