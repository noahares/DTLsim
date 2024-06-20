const std = @import("std");
const newick_parser = @import("newick_parser.zig");
const simulator = @import("simulate_family.zig");

pub fn main() !void {
    const input = "(((a, b)x:1.0, (c:3, d)), e);";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    var tree = try newick_parser.parseNewickString(&alloc, input);
    defer tree.deinit();
    tree.print();
    var sim = try simulator.FamilySimulator.init(&tree, &alloc);
    // defer sim.deinit();
    var gene_tree = try sim.simulate_family();
    defer gene_tree.deinit();
    gene_tree.print();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
