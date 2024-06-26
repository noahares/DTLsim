const std = @import("std");
const Tree = @import("tree.zig").Tree;
const TreeNode = @import("tree_node.zig").TreeNode;

pub const DTL_event = union(enum) {
    duplication,
    transfer,
    loss,
    speciation,
};

pub const TransferConstraint = union(enum) {
    parent,
    dated,
    none,
};

pub const EventCounts = struct {
    duplication: usize = 0,
    transfer: usize = 0,
    loss: usize = 0,
    speciation: usize = 0,

    pub fn print(self: *EventCounts) void {
        std.debug.print("D: {}, T: {}, L: {}, S: {}\n", self.*);
    }

    pub fn reset(self: *EventCounts) void {
        self.duplication = 0;
        self.transfer = 0;
        self.loss = 0;
        self.speciation = 0;
    }
};

pub const Highway = struct {
    recipient: usize,
    transfer_muliplier: f32,
    recipient_muliplier: f32,
};

pub const FamilySimulator = struct {
    species_tree: *Tree,
    origination_rates: []f32,
    duplication_rates: []f32,
    transfer_rates_from: []f32,
    transfer_rates_to: []f32,
    loss_rates: []f32,
    num_gene_copies: []usize,
    transfer_constraint: TransferConstraint = TransferConstraint.parent,
    allocator: *const std.mem.Allocator,
    rand: std.rand.Xoshiro256,
    seed: u64,
    event_counts: EventCounts,
    highways: std.AutoHashMap(usize, std.ArrayList(*Highway)),

    pub fn init(species_tree: *Tree, allocator: *const std.mem.Allocator, d: f32, t: f32, l: f32, o: f32, seed: u64, branch_modifiers: []const []const u8) !*FamilySimulator {
        const D: f32 = d;
        const T: f32 = t;
        const L: f32 = l;
        const O_r = o;

        const num_species_nodes = species_tree.numNodes();
        const origination_rates = try allocator.alloc(f32, num_species_nodes);
        const duplication_rates = try allocator.alloc(f32, num_species_nodes);
        const transfer_rates_from = try allocator.alloc(f32, num_species_nodes);
        const transfer_rates_to = try allocator.alloc(f32, num_species_nodes);
        const loss_rates = try allocator.alloc(f32, num_species_nodes);
        const num_gene_copies = try allocator.alloc(usize, num_species_nodes);

        // TODO: for more general case, these need to be initialized for each node!
        const o_b = (1.0 - O_r) / @as(f32, @floatFromInt(num_species_nodes - 1));
        @memset(origination_rates, o_b);
        @memset(duplication_rates, D);
        @memset(transfer_rates_from, T);
        @memset(transfer_rates_to, T);
        @memset(loss_rates, L);
        @memset(num_gene_copies, 0);

        for (branch_modifiers) |mod| {
            var it = std.mem.tokenizeScalar(u8, mod, ':');
            const rate_type = it.next().?[0];
            const branch_id = try std.fmt.parseInt(usize, it.next().?, 10);
            const value = try std.fmt.parseFloat(f32, it.next().?);
            switch (rate_type) {
                'd' => duplication_rates[branch_id] = value,
                't' => transfer_rates_from[branch_id] = value,
                'r' => transfer_rates_to[branch_id] = value,
                'l' => loss_rates[branch_id] = value,
                'o' => origination_rates[branch_id] = value,
                else => unreachable,
            }
        }

        origination_rates[0] = O_r;
        const rand = std.rand.DefaultPrng.init(seed);
        const event_counts = EventCounts{};
        const highways = std.AutoHashMap(usize, std.ArrayList(*Highway)).init(allocator.*);
        const simulator = try allocator.create(FamilySimulator);
        simulator.* = FamilySimulator{
            .species_tree = species_tree,
            .origination_rates = origination_rates,
            .duplication_rates = duplication_rates,
            .transfer_rates_from = transfer_rates_from,
            .transfer_rates_to = transfer_rates_to,
            .loss_rates = loss_rates,
            .num_gene_copies = num_gene_copies,
            .allocator = allocator,
            .rand = rand,
            .seed = seed,
            .event_counts = event_counts,
            .highways = highways,
        };
        return simulator;
    }

    pub fn deinit(self: *FamilySimulator) void {
        self.species_tree.deinit();
    }

    pub fn simulate_family(self: *FamilySimulator) !*Tree {
        self.event_counts.reset();
        @memset(self.num_gene_copies, 0);
        self.seed += 1;
        self.rand.seed(self.seed);
        var gene_tree = try Tree.init(self.allocator);
        const gene_origination = self.species_tree.post_order_nodes.items[self.rand.random().weightedIndex(f32, self.origination_rates)];
        const gene_root = try gene_tree.newNode(null, null, null);
        gene_tree.setRoot(gene_root);
        try self.process_species_node(gene_tree, gene_root, gene_origination);
        self.event_counts.print();
        return gene_tree;
    }

    pub fn process_species_node(self: *FamilySimulator, gene_tree: *Tree, parent_gene_node: *TreeNode, species_node: *TreeNode) !void {
        const node_id = species_node.id;
        var d = self.duplication_rates[node_id];
        var t = self.transfer_rates_from[node_id];
        var l = self.loss_rates[node_id];

        var highway_transfer_weight: f32 = 1.0;
        if (self.highways.get(node_id)) |highways| {
            for (highways.items) |highway| {
                highway_transfer_weight += highway.transfer_muliplier;
            }
        }
        t *= highway_transfer_weight;
        const sum = 1.0 + d + t + l;
        d /= sum;
        t /= sum;
        l /= sum;
        const event = blk: {
            const p = self.rand.random().float(f32);

            if (p <= d) {
                break :blk DTL_event.duplication;
            } else if (p <= d + t) {
                break :blk DTL_event.transfer;
            } else if (p <= d + t + l) {
                break :blk DTL_event.loss;
            } else {
                break :blk DTL_event.speciation;
            }
        };

        const buf = try self.allocator.alloc(u8, 100);
        switch (event) {
            .duplication => {
                // std.debug.print("Duplication above node {}\n", .{node_id});
                self.event_counts.duplication += 1;
                const buf2 = try self.allocator.alloc(u8, 100);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "D@{s}", .{try species_node.name_or_id(buf2)});
                const first_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const second_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = first_copy;
                parent_gene_node.right_child = second_copy;
                try self.process_species_node(gene_tree, first_copy, species_node);
                try self.process_species_node(gene_tree, second_copy, species_node);
            },
            .transfer => {
                const recipient = try self.sample_transfer_node(species_node);
                // std.debug.print("Transfer above node {} to node {}\n", .{ node_id, recipient.id });
                self.event_counts.transfer += 1;
                // TODO: this seems a bit ugly.. can be done better?
                const buf2 = try self.allocator.alloc(u8, 100);
                const buf3 = try self.allocator.alloc(u8, 100);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "T@{s}->{s}", .{ try species_node.name_or_id(buf2), try recipient.name_or_id(buf3) });
                const donor_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const recipient_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = donor_copy;
                parent_gene_node.right_child = recipient_copy;
                try self.process_species_node(gene_tree, donor_copy, species_node);
                try self.process_species_node(gene_tree, recipient_copy, recipient);
            },
            .loss => {
                // std.debug.print("Loss above node {}\n", .{node_id});
                self.event_counts.loss += 1;
                // parent_gene_node.name = "L";
                gene_tree.restore_bifurcation(parent_gene_node);
            },
            .speciation => {
                if (species_node.left_child != null) {
                    self.event_counts.speciation += 1;
                    // parent_gene_node.name = "S";
                    // std.debug.print("Speciation at node {}\n", .{node_id});
                    const left_child = try gene_tree.newNode(null, null, parent_gene_node);
                    const right_child = try gene_tree.newNode(null, null, parent_gene_node);
                    parent_gene_node.left_child = left_child;
                    parent_gene_node.right_child = right_child;
                    try self.process_species_node(gene_tree, left_child, species_node.left_child.?);
                    try self.process_species_node(gene_tree, right_child, species_node.right_child.?);
                } else {
                    // std.debug.print("Leaf at node {}\n", .{node_id});
                    const species_name = species_node.name orelse "species";
                    parent_gene_node.name = try std.fmt.bufPrint(buf, "{s}_{}", .{ species_name, self.num_gene_copies[node_id] });
                    self.num_gene_copies[node_id] += 1;
                }
            },
        }
    }

    fn sample_transfer_node(self: *FamilySimulator, transfer_origin: *TreeNode) !*TreeNode {
        switch (self.transfer_constraint) {
            .parent => {
                var current_node = transfer_origin;
                var forbidden_transfers = std.ArrayList(usize).init(self.allocator.*);
                defer forbidden_transfers.deinit();
                try forbidden_transfers.append(current_node.id);
                while (current_node.parent) |parent| {
                    try forbidden_transfers.append(parent.id);
                    current_node = parent;
                }
                const receiving_transfer_rates = blk: {
                    if (self.highways.get(transfer_origin.id)) |highways| {
                        var copied_rates = try self.allocator.alloc(f32, self.transfer_rates_to.len);
                        @memcpy(copied_rates, self.transfer_rates_to);
                        for (highways.items) |highway| {
                            copied_rates[highway.recipient] *= highway.recipient_muliplier;
                        }
                        break :blk copied_rates;
                    } else {
                        break :blk self.transfer_rates_to;
                    }
                };
                propose_target: while (true) {
                    const transfer_candidate = self.species_tree.post_order_nodes.items[self.rand.random().weightedIndex(f32, receiving_transfer_rates)];
                    const candidate_id = transfer_candidate.id;
                    for (forbidden_transfers.items) |forbidden_id| {
                        if (candidate_id > forbidden_id) {
                            return transfer_candidate;
                        } else if (candidate_id == forbidden_id) {
                            continue :propose_target;
                        } else {
                            continue;
                        }
                    }
                }
            },
            .dated => {
                @panic("Dated transfer constraint not yet supported!\n");
            },
            .none => {
                return self.species_tree.post_order_nodes.items[self.rand.random().weightedIndex(f32, self.transfer_rates_to)];
            },
        }
    }

    pub fn addHighway(self: *FamilySimulator, source: usize, target: usize, source_multiplier: f32, target_multiplier: f32) !void {
        const map_entry = try self.highways.getOrPutValue(source, std.ArrayList(*Highway).init(self.allocator.*));
        const highway = try self.allocator.create(Highway);
        highway.* = Highway{
            .recipient = target,
            .transfer_muliplier = source_multiplier,
            .recipient_muliplier = target_multiplier,
        };
        try map_entry.value_ptr.append(highway);
    }
};
