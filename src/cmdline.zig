const std = @import("std");
const clap = @import("clap");
const FamilySimulator = @import("simulate_family.zig").FamilySimulator;
const newick_parser = @import("newick_parser.zig");

pub const ParserError = error{NoPathProvided};

pub fn parse(allocator: *std.mem.Allocator) !?struct { num_gene_families: usize, simulator: *FamilySimulator } {
    const params = comptime clap.parseParamsComptime(
        \\--help                                Display this help and exit.
        \\-i, --species-tree <str>              Path to the species tree
        \\-s, --seed <u64>                      RNG seed (default: 42)
        \\-n, --num-gene-families <usize>       Number of gene families to generate (default: 100)
        \\-d, --duplication-rate <f32>          Duplication rate (default: 0.1)
        \\-t, --transfer-rate <f32>             Transfer rate (default: 0.1)
        \\-l, --loss-rate <f32>                 Loss rate (default: 0.1)
        \\-o, --root-origination <f32>          Root origination rate (default: 1.0)
        \\-b, --branch-rate-modifier <str>...   Individual values for DTL rates on specific species tree branches
        \\                                      (format <type>:<branch_id>:<value> where type is one of {d, t, r, l, o})
        \\-h, --highway <str>...                Defines a transfer highway between two species tree branches
        \\                                      (format <source_id>:<target_id>:<source_multiplier>:<target_multiplier>)
    );

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator.*,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        return null;
    }

    const species_tree_path = blk: {
        if (res.args.@"species-tree") |path| {
            break :blk path;
        } else {
            return ParserError.NoPathProvided;
        }
    };
    const file = try std.fs.cwd().openFile(species_tree_path, .{});
    defer file.close();
    const newick_string = (try file.reader().readUntilDelimiterOrEofAlloc(allocator.*, '\n', 2048)).?;
    var species_tree = try newick_parser.parseNewickString(allocator, newick_string);
    species_tree.print();
    const num_gene_families = res.args.@"num-gene-families" orelse 100;
    const sim = try FamilySimulator.init(
        species_tree,
        allocator,
        res.args.@"duplication-rate" orelse 0.1,
        res.args.@"transfer-rate" orelse 0.1,
        res.args.@"loss-rate" orelse 0.1,
        res.args.@"root-origination" orelse 0.1,
        res.args.seed orelse 42,
        res.args.@"branch-rate-modifier",
    );
    for (res.args.highway) |highway| {
        var it = std.mem.tokenizeScalar(u8, highway, ':');
        const source = try std.fmt.parseInt(usize, it.next().?, 10);
        const target = try std.fmt.parseInt(usize, it.next().?, 10);
        const source_multiplier = try std.fmt.parseFloat(f32, it.next().?);
        const target_multiplier = try std.fmt.parseFloat(f32, it.next().?);
        try sim.addHighway(source, target, source_multiplier, target_multiplier);
    }
    return .{ .num_gene_families = num_gene_families, .simulator = sim };
}
