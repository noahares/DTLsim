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

pub const FamilySimulator = struct {
    species_tree: *Tree,
    origination_rates: []f32,
    duplication_rates: []f32,
    transfer_rates_from: []f32,
    transfer_rates_to: []f32,
    loss_rates: []f32,
    transfer_constraint: TransferConstraint = TransferConstraint.parent,
    allocator: *const std.mem.Allocator,
    rand: std.Random,
    event_counts: EventCounts,

    pub fn init(species_tree: *Tree, allocator: *const std.mem.Allocator) !*FamilySimulator {
        const O_r = 1.0;
        var D: f32 = 0.1;
        var T: f32 = 0.1;
        var L: f32 = 0.1;
        const sum = 1.0 + D + T + L;
        D /= sum;
        T /= sum;
        L /= sum;

        const num_species_nodes = species_tree.numNodes();
        const origination_rates = try allocator.alloc(f32, num_species_nodes);
        const duplication_rates = try allocator.alloc(f32, num_species_nodes);
        const transfer_rates_from = try allocator.alloc(f32, num_species_nodes);
        const transfer_rates_to = try allocator.alloc(f32, num_species_nodes);
        const loss_rates = try allocator.alloc(f32, num_species_nodes);

        for (origination_rates, duplication_rates, transfer_rates_from, transfer_rates_to, loss_rates) |*o, *d, *tf, *tt, *l| {
            o.* = (1.0 - O_r) / @as(f32, @floatFromInt(num_species_nodes - 1));
            // TODO: for more general case, these need to be normalized for each node!
            d.* = D;
            tf.* = T;
            tt.* = T;
            l.* = L;
        }
        origination_rates[0] = O_r;
        var prng = std.rand.DefaultPrng.init(2);
        const rand = prng.random();
        const event_counts = EventCounts{};
        const simulator = try allocator.create(FamilySimulator);
        simulator.* = FamilySimulator{ .species_tree = species_tree, .origination_rates = origination_rates, .duplication_rates = duplication_rates, .transfer_rates_from = transfer_rates_from, .transfer_rates_to = transfer_rates_to, .loss_rates = loss_rates, .allocator = allocator, .rand = rand, .event_counts = event_counts };
        return simulator;
    }

    // pub fn deinit(self: *FamilySimulator) void {
    // self.allocator.destroy(self.origination_rates);
    // self.allocator.destroy(self.duplication_rates);
    // self.allocator.destroy(self.transfer_rates);
    // self.allocator.destroy(self.loss_rates);
    // }

    pub fn simulate_family(self: *FamilySimulator) !Tree {
        self.event_counts.reset();
        var gene_tree = Tree.init(self.allocator);
        const gene_origination = self.species_tree.post_order_nodes.items[self.rand.weightedIndex(f32, self.origination_rates)];
        const gene_root = try gene_tree.newNode(null, null, null);
        gene_tree.setRoot(gene_root);
        try self.process_species_node(&gene_tree, gene_root, gene_origination);
        self.event_counts.print();
        return gene_tree;
    }

    pub fn process_species_node(self: *FamilySimulator, gene_tree: *Tree, parent_gene_node: *TreeNode, species_node: *TreeNode) !void {
        const node_id = species_node.id;
        const d = self.duplication_rates[node_id];
        const dt = d + self.transfer_rates_from[node_id];
        const dtl = dt + self.loss_rates[node_id];
        const event = blk: {
            const p = self.rand.float(f32);
            if (p <= d) {
                break :blk DTL_event.duplication;
            } else if (p <= dt) {
                break :blk DTL_event.transfer;
            } else if (p <= dtl) {
                break :blk DTL_event.loss;
            } else {
                break :blk DTL_event.speciation;
            }
        };
        switch (event) {
            .duplication => {
                std.debug.print("Duplication above node {}\n", .{node_id});
                self.event_counts.duplication += 1;
                parent_gene_node.name = "D";
                const first_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const second_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = first_copy;
                parent_gene_node.right_child = second_copy;
                try self.process_species_node(gene_tree, first_copy, species_node);
                try self.process_species_node(gene_tree, second_copy, species_node);
            },
            .transfer => {
                const recipient = try self.sample_transfer_node(species_node);
                std.debug.print("Transfer above node {} to node {}\n", .{ node_id, recipient.id });
                self.event_counts.transfer += 1;
                const buf = try self.allocator.alloc(u8, 100);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "T@{}->@{}", .{ node_id, recipient.id });
                const donor_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const recipient_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = donor_copy;
                parent_gene_node.right_child = recipient_copy;
                try self.process_species_node(gene_tree, donor_copy, species_node);
                try self.process_species_node(gene_tree, recipient_copy, recipient);
            },
            .loss => {
                std.debug.print("Loss above node {}\n", .{node_id});
                self.event_counts.loss += 1;
                parent_gene_node.name = "L";
                gene_tree.restore_bifurcation(parent_gene_node);
            },
            .speciation => {
                if (species_node.left_child != null) {
                    self.event_counts.speciation += 1;
                    parent_gene_node.name = "S";
                    std.debug.print("Speciation at node {}\n", .{node_id});
                    const left_child = try gene_tree.newNode(null, null, parent_gene_node);
                    const right_child = try gene_tree.newNode(null, null, parent_gene_node);
                    parent_gene_node.left_child = left_child;
                    parent_gene_node.right_child = right_child;
                    try self.process_species_node(gene_tree, left_child, species_node.left_child.?);
                    try self.process_species_node(gene_tree, right_child, species_node.right_child.?);
                } else {
                    std.debug.print("Leaf at node {}\n", .{node_id});
                    parent_gene_node.name = species_node.name;
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
                propose_target: while (true) {
                    const transfer_candidate = self.species_tree.post_order_nodes.items[self.rand.weightedIndex(f32, self.transfer_rates_to)];
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
                return self.species_tree.post_order_nodes.items[self.rand.weightedIndex(f32, self.transfer_rates_to)];
            },
        }
    }
};
