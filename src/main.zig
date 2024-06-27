const std = @import("std");
const newick_parser = @import("newick_parser.zig");
const simulator = @import("simulate_family.zig");
const cmdline = @import("cmdline.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    const parse_res = cmdline.parse(&alloc) catch |err| {
        try std.io.getStdErr().writer().print("{}: during parsing and initialization\n", .{err});
        return;
    };
    if (parse_res == null) return;
    const config = parse_res.?.config;
    const sim = parse_res.?.simulator;
    defer sim.deinit();
    var dir = std.fs.cwd().makeOpenPath(config.out_prefix, .{}) catch |err| {
        try std.io.getStdErr().writer().print("{}: cannot create directory {s}\n", .{ err, config.out_prefix });
        return;
    };
    defer dir.close();
    const event_file = dir.createFile("event_counts.txt", .{ .exclusive = !config.redo }) catch |err| {
        try std.io.getStdErr().writer().print("{}: could not create <prefix>/event_counts.txt\n If it already exists, make sure to run the program with --redo\n", .{err});
        return;
    };

    defer event_file.close();
    var event_writer = std.io.bufferedWriter(event_file.writer());
    const filename_buf = try alloc.alloc(u8, std.fs.MAX_PATH_BYTES);
    for (0..config.num_gene_families) |i| {
        const out_file_name = try std.fmt.bufPrint(filename_buf, "family{}.nwk", .{i});
        const out_file = dir.createFile(out_file_name, .{ .exclusive = !config.redo }) catch |err| {
            try std.io.getStdErr().writer().print("{}: could not create <prefix>/family{}.nwk\n If it already exists, make sure to run the program with --redo\n", .{ err, i });
            return;
        };
        defer out_file.close();
        var buf_writer = std.io.bufferedWriter(out_file.writer());
        var res = sim.simulate_family() catch |err| {
            try std.io.getStdErr().writer().print("{}: during gene family simulation\n", .{err});
            return;
        };
        // defer gene_tree.deinit();
        try res.event_counts.print(&event_writer.writer(), i);
        try res.gene_tree.print(&buf_writer.writer());
        try buf_writer.flush();
    }
    try event_writer.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
