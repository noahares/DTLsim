const std = @import("std");
const newick_parser = @import("newick_parser.zig");
const simulator = @import("simulate_family.zig");

pub fn main() !void {
    const input = "(((a, b), (c, d)), e);";
    // const input = "(((5,4),(1,(2,3))),(((((17,(10,14)),((9,(7,28)),(23,27))),18),(((20,(24,19)),((16,8),13)),((26,(29,25)),(15,11)))),(30,(12,((6,21),22)))));";
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();
    var tree = try newick_parser.parseNewickString(&alloc, input);
    defer tree.deinit();
    tree.print();
    const sim = try simulator.FamilySimulator.init(&tree, &alloc, 42);
    try sim.addHighway(3, 5, 10.0, 100.0);
    // try sim.addHighway(3, 8, 5.0, 50.0);
    // try sim.addHighway(4, 7, 1.5, 10.0);
    // std.debug.print("{?}", .{sim.highways.get(3).?});
    // defer sim.deinit();
    for (0..10) |_| {
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
