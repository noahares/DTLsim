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
    const num_gene_families = parse_res.?.num_gene_families;
    const sim = parse_res.?.simulator;
    defer sim.deinit();
    for (0..num_gene_families) |_| {
        var gene_tree = try sim.simulate_family();
        defer gene_tree.deinit();
        gene_tree.print();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
