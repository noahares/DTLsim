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
        switch (err) {
            cmdline.InitializationError.NoPathProvided => {
                try std.io.getStdErr().writer().print("Please specify an input species tree with -i\n", .{});
                return;
            },
            cmdline.InitializationError.TransferConstraintNotSupported => {
                try std.io.getStdErr().writer().print("Currently dated transfer contraints are unsupported!\n", .{});
                return;
            },
            cmdline.InitializationError.BranchModifierParseError => {
                try std.io.getStdErr().writer().print("Please stick to a valid branch modifier definition! See --help or the README\n", .{});
                return;
            },
            cmdline.InitializationError.HighwayParseError => {
                try std.io.getStdErr().writer().print("Please stick to a valid highway definition! See --help or the README\n", .{});
                return;
            },
            cmdline.InitializationError.IOError => {
                try std.io.getStdErr().writer().print("Could not read input species tree!\n", .{});
                return;
            },
            cmdline.InitializationError.ArgumentParseError => {
                try std.io.getStdErr().writer().print("Some arguments could not be parsed! See --help or the README\n", .{});
                return;
            },
            cmdline.InitializationError.OutOfMemory => {
                try std.io.getStdErr().writer().print("This is concerning, if your machine has a reasonable amount of RAM, this should not happen... Please report a bug!\n", .{});
                return;
            },
            cmdline.InitializationError.UnexpectedToken => {
                try std.io.getStdErr().writer().print("Please check the validity of your input species tree!\n", .{});
                return;
            },
            cmdline.InitializationError.FileEmpty => {
                try std.io.getStdErr().writer().print("Input species tree file in empty!\n", .{});
                return;
            },
        }
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

    const species_tree_file = dir.createFile("species_tree.nwk", .{ .exclusive = !config.redo });
    if (species_tree_file) |file| {
        defer file.close();
        var species_tree_writer = std.io.bufferedWriter(file.writer());
        try sim.species_tree.print(&species_tree_writer.writer(), true);
        try species_tree_writer.flush();
    } else |err| {
        const out = std.io.getStdErr().writer();
        try out.print("{}: could not create <prefix>/species_tree.nwk\n If it already exists, make sure to run the program with --redo\nPrinting species tree here: \n", .{err});
        try sim.species_tree.print(&out, true);
    }

    const parameter_file = dir.createFile("parameters.txt", .{ .exclusive = !config.redo });
    if (parameter_file) |file| {
        defer file.close();
        var parameter_writer = std.io.bufferedWriter(file.writer());
        for (std.os.argv) |arg| {
            try parameter_writer.writer().print("{s} ", .{arg});
        }
        try parameter_writer.flush();
    } else |err| {
        const out = std.io.getStdErr().writer();
        try out.print("{}: could not create <prefix>/parameters.txt\n If it already exists, make sure to run the program with --redo\n", .{err});
    }

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
            try std.io.getStdErr().writer().print("{}: during gene family simulation\nThis is weird and should not happen, please report a bug!", .{err});
            return;
        };
        // defer gene_tree.deinit();
        try res.event_counts.print(&event_writer.writer(), i);
        try res.gene_tree.print(&buf_writer.writer(), false);
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
