const std = @import("std");
const zprob = @import("zprob");
const coraxlib = @cImport({
    @cInclude("corax/corax.h");
});

pub const NniError = error{
    CoraxlibError,
};

pub fn generate_nni_perturbed_trees(tree: *const coraxlib.corax_utree_t, num_trees: usize, lambda: f32, writer: anytype) !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    // const base_splits = coraxlib.corax_utree_split_create(tree.vroot, tree.tip_count, null);
    // defer coraxlib.corax_utree_split_destroy(base_splits);
    var rand = prng.random();
    var poisson = zprob.Poisson(u32, f32).init(&rand);
    const num_nni_moves = poisson.sample(lambda);
    var tree_count: u32 = 0;
    while (tree_count < num_trees) {
        // var rf_to_base: f32 = 0;
        const new_tree: *coraxlib.corax_utree_t = coraxlib.corax_utree_clone(tree);
        defer coraxlib.corax_utree_destroy(new_tree, null);
        for (0..num_nni_moves) |_| {
            var nni_pivot = new_tree.nodes[0];
            const nni_type = rand.intRangeAtMost(u8, 1, 2);
            while (true) {
                const nni_edge = rand.uintLessThan(u8, 3);
                const r = rand.uintLessThan(u64, new_tree.inner_count);
                nni_pivot = new_tree.nodes[new_tree.tip_count + r];
                for (0..nni_edge) |_| {
                    nni_pivot = nni_pivot.*.next;
                }
                if (nni_pivot.*.back.*.next != null) {
                    break;
                }
            }
            const nni_status = coraxlib.corax_utree_nni(nni_pivot, nni_type, null);
            if (nni_status == coraxlib.CORAX_FAILURE) {
                // const new_splits = coraxlib.corax_utree_split_create(new_tree.vroot, new_tree.tip_count, null);
                // defer coraxlib.corax_utree_split_destroy(new_splits);
                // rf_to_base = @as(f32, @floatFromInt(coraxlib.corax_utree_split_rf_distance(base_splits, new_splits, tree.tip_count))) / @as(f32, @floatFromInt(2 * (tree.tip_count - 3)));
                // if (rf_to_base > max_rf_distance) {
                //     break;
                // }
                std.debug.print("{s}\n", .{coraxlib.corax_errmsg});
                return NniError.CoraxlibError;
            }
        }
        const newick_str = coraxlib.corax_utree_export_newick(new_tree.vroot, null);
        defer std.c.free(newick_str);
        try writer.print("{s}\n", .{newick_str});
        tree_count += 1;
    }
}
