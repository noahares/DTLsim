const std = @import("std");
const clap = @import("clap");
const simulator = @import("simulate_family.zig");
const newick_parser = @import("newick_parser.zig");
const utils = @import("utils.zig");

const ParseError = error{
    NoPathProvided,
    ArgumentParseError,
    HighwayParseError,
    IOError,
};
pub const InitializationError = ParseError || newick_parser.NewickParseError || simulator.SimulatorError;

pub const Config = struct {
    num_gene_families: usize,
    post_transfer_loss_gamma: struct { shape: f32, scale: f32 },
    out_prefix: []const u8,
    redo: bool,
};

pub fn parse(allocator: *std.mem.Allocator) InitializationError!?struct { config: Config, simulator: *simulator.FamilySimulator } {
    const params = comptime clap.parseParamsComptime(
        \\--help                                Display this help and exit.
        \\-i, --species-tree <FILE>             Path to the species tree
        \\-p, --prefix <DIR>                    Prefix directory for the output files (default: $CWD)
        \\--redo                                Override existing output files
        \\-s, --seed <u64>                      RNG seed (default: 42)
        \\-n, --num-gene-families <usize>       Number of gene families to generate (default: 100)
        \\-d, --duplication-rate <f32>          Duplication rate (default: 0.1)
        \\-t, --transfer-rate <f32>             Transfer rate (default: 0.1)
        \\-l, --loss-rate <f32>                 Loss rate (default: 0.1)
        \\-o, --root-origination <f32>          Root origination rate (default: 1.0)
        \\-b, --branch-rate-modifier <MOD>...   Individual values for DTL rates on specific species tree branches
        \\                                      (format <type>:<branch_id>:<value> where type is one of {d, t, r, l, o})
        \\-h, --highway <HIGHWAY>...            Defines a transfer highway between two species tree branches
        \\                                      (format <source_id>:<target_id>:<source_multiplier>:<target_multiplier>)
        \\-c, --transfer-constraint <CONSTR>    Transfer constraint, either parent, dated or none (default: parent)
        \\-x, --post-transfer-loss <f32>        Factor for changing the loss rate after receiving a gene via transfer (default: 1.0)
    );

    const parsers = comptime .{
        .MOD = clap.parsers.string,
        .HIGHWAY = clap.parsers.string,
        .FILE = clap.parsers.string,
        .DIR = clap.parsers.string,
        .usize = clap.parsers.int(usize, 10),
        .u64 = clap.parsers.int(u64, 10),
        .f32 = clap.parsers.float(f32),
        .CONSTR = clap.parsers.enumeration(simulator.TransferConstraint),
    };
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diag,
        .allocator = allocator.*,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return ParseError.ArgumentParseError;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{}) catch return ParseError.ArgumentParseError;
        return null;
    }

    const species_tree_path = blk: {
        if (res.args.@"species-tree") |path| {
            break :blk path;
        } else {
            return ParseError.NoPathProvided;
        }
    };
    const newick_string = (read_first_line_from_file(allocator, species_tree_path) catch return InitializationError.IOError).?;
    const species_tree = try newick_parser.parseNewickString(allocator, newick_string);
    const num_gene_families = res.args.@"num-gene-families" orelse 100;
    const sim = try simulator.FamilySimulator.init(
        species_tree,
        allocator,
        res.args.@"duplication-rate" orelse 0.1,
        res.args.@"transfer-rate" orelse 0.1,
        res.args.@"loss-rate" orelse 0.1,
        res.args.@"root-origination" orelse 1.0,
        res.args.seed orelse 42,
        res.args.@"transfer-constraint" orelse simulator.TransferConstraint.parent,
        res.args.@"post-transfer-loss" orelse 1.0,
        res.args.@"branch-rate-modifier",
    );
    for (res.args.highway) |highway| {
        if (!utils.expect_token(highway, ':', 3)) return ParseError.HighwayParseError;
        var it = std.mem.tokenizeScalar(u8, highway, ':');
        const source = std.fmt.parseInt(usize, it.next().?, 10) catch return ParseError.HighwayParseError;
        const target = std.fmt.parseInt(usize, it.next().?, 10) catch return ParseError.HighwayParseError;
        const probability = std.fmt.parseFloat(f32, it.next().?) catch return ParseError.HighwayParseError;
        sim.addHighway(source, target, probability) catch return ParseError.HighwayParseError;
    }
    return .{
        .config = Config{
            .num_gene_families = num_gene_families,
            .post_transfer_loss_gamma = .{ .shape = 1.0, .scale = 1.0 },
            .out_prefix = res.args.prefix orelse ".",
            .redo = res.args.redo != 0,
        },
        .simulator = sim,
    };
}

fn read_first_line_from_file(allocator: *std.mem.Allocator, path: []const u8) !?[]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const file_size = (try file.stat()).size + 1;
    return file.reader().readUntilDelimiterOrEofAlloc(allocator.*, '\n', file_size);
}
