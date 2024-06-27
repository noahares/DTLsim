const std = @import("std");
const newick_parser = @import("newick_parser.zig");
const simulator = @import("simulate_family.zig");
const cmdline = @import("cmdline.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    const parse_res = try cmdline.parse(&alloc);
    if (parse_res == null) return;
    const config = parse_res.?.config;
    const sim = parse_res.?.simulator;
    defer sim.deinit();
    var dir = try std.fs.cwd().makeOpenPath(config.out_prefix, .{});
    defer dir.close();
    const event_file = dir.createFile("event_counts.txt", .{ .exclusive = !config.redo });
    defer event_file.close();
    var event_writer = std.io.bufferedWriter(event_file.writer());
    const filename_buf = try alloc.alloc(u8, std.fs.MAX_PATH_BYTES);
    for (0..config.num_gene_families) |i| {
        const out_file_name = try std.fmt.bufPrint(filename_buf, "family{}.nwk", .{i});
        const out_file = try dir.createFile(out_file_name, .{ .exclusive = !config.redo });
        defer out_file.close();
        var buf_writer = std.io.bufferedWriter(out_file.writer());
        var res = try sim.simulate_family();
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
