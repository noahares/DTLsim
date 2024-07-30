const std = @import("std");
const Tree = @import("tree.zig").Tree;
const TreeNode = @import("tree_node.zig").TreeNode;
const AllocError = std.mem.Allocator.Error;
const BufPrintError = std.fmt.BufPrintError;
const utils = @import("utils.zig");

pub const DTL_event = union(enum) {
    duplication,
    transfer,
    loss,
    speciation,
    highway: usize,
};

pub const TransferConstraint = enum {
    parent,
    dated,
    none,
};

pub const EventCounts = struct {
    duplication: usize = 0,
    transfer: usize = 0,
    loss: usize = 0,
    speciation: usize = 0,
    highway_transfer: usize = 0,

    pub fn print(self: *EventCounts, writer: anytype, id: usize) !void {
        try writer.print("G{}\tD: {}, T: {}, L: {}, H: {}, S: {}\n", .{
            id,
            self.duplication,
            self.transfer,
            self.loss,
            self.highway_transfer,
            self.speciation,
        });
    }

    pub fn reset(self: *EventCounts) void {
        self.duplication = 0;
        self.transfer = 0;
        self.loss = 0;
        self.speciation = 0;
        self.highway_transfer = 0;
    }
};

pub const Highway = struct {
    recipient: usize,
    probability: f32,
};

pub const SimulatorError = error{
    TransferConstraintNotSupported,
    BranchModifierParseError,
} || AllocError;

pub const SimulatorRunError = AllocError || BufPrintError;

pub const FamilySimulator = struct {
    species_tree: *Tree,
    origination_rates: []f32,
    duplication_rates: []f32,
    transfer_rates_from: []f32,
    transfer_rates_to: []f32,
    loss_rates: []f32,
    num_gene_copies: []usize,
    transfer_constraint: TransferConstraint,
    post_transfer_loss_factor: f32,
    allocator: *const std.mem.Allocator,
    rand: std.rand.Xoshiro256,
    seed: u64,
    event_counts: EventCounts,
    highways: std.AutoHashMap(usize, std.ArrayList(*Highway)),

    pub fn init(species_tree: *Tree, allocator: *const std.mem.Allocator, d: f32, t: f32, l: f32, o: f32, seed: u64, transfer_constraint: TransferConstraint, post_transfer_loss_factor: f32, branch_modifiers: []const []const u8) SimulatorError!*FamilySimulator {
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

        const o_b = (1.0 - O_r) / @as(f32, @floatFromInt(num_species_nodes - 1));
        @memset(origination_rates, o_b);
        @memset(duplication_rates, D);
        @memset(transfer_rates_from, T);
        @memset(transfer_rates_to, T);
        @memset(loss_rates, L);
        @memset(num_gene_copies, 0);

        for (branch_modifiers) |mod| {
            if (!utils.expect_token(mod, ':', 3)) return SimulatorError.BranchModifierParseError;
            var it = std.mem.tokenizeScalar(u8, mod, ':');
            const rate_type = utils.parse_rate_type(it.next()) catch return SimulatorError.BranchModifierParseError;
            const branch_id = utils.parse_id_or_name(species_tree, it.next()) catch return SimulatorError.BranchModifierParseError;
            const value = std.fmt.parseFloat(f32, it.next() orelse return SimulatorError.BranchModifierParseError) catch return SimulatorError.BranchModifierParseError;
            switch (rate_type) {
                'd' => duplication_rates[branch_id] = value,
                't' => transfer_rates_from[branch_id] = value,
                'r' => transfer_rates_to[branch_id] = value,
                'l' => loss_rates[branch_id] = value,
                'o' => origination_rates[branch_id] = value,
                else => return SimulatorError.BranchModifierParseError,
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
            .transfer_constraint = blk: {
                if (transfer_constraint == .dated) {
                    return SimulatorError.TransferConstraintNotSupported;
                } else {
                    break :blk transfer_constraint;
                }
            },
            .post_transfer_loss_factor = post_transfer_loss_factor,
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

    pub fn simulate_family(self: *FamilySimulator) SimulatorRunError!struct { gene_tree: *Tree, event_counts: EventCounts } {
        defer self.event_counts.reset();
        @memset(self.num_gene_copies, 0);
        self.seed += 1;
        self.rand.seed(self.seed);
        const gene_tree = try Tree.init(self.allocator);
        const gene_origination = self.species_tree.post_order_nodes.items[self.rand.random().weightedIndex(f32, self.origination_rates)];
        const gene_root = gene_tree.root.?;
        try self.process_species_node(gene_tree, gene_root, gene_origination, false);
        return .{ .gene_tree = gene_tree, .event_counts = self.event_counts };
    }

    pub fn process_species_node(self: *FamilySimulator, gene_tree: *Tree, parent_gene_node: *TreeNode, species_node: *TreeNode, transfer_recipient: bool) SimulatorRunError!void {
        const node_id = species_node.id;
        var d = self.duplication_rates[node_id];
        var t = self.transfer_rates_from[node_id];
        var l = self.loss_rates[node_id];

        if (transfer_recipient) {
            l *= self.post_transfer_loss_factor;
        }

        const highways = self.highways.get(node_id);

        var sum = 1.0 + d + t + l;
        if (highways) |hws| {
            for (hws.items) |highway| {
                sum += highway.probability;
            }
        }
        d /= sum;
        t /= sum;
        l /= sum;
        const s = 1.0 / sum;

        const highway_probabilities = blk: {
            if (highways) |hws| {
                const hp = try self.allocator.alloc(f32, hws.items.len);
                for (hws.items, 0..) |highway, i| {
                    hp[i] = highway.probability / sum;
                }
                break :blk hp;
            } else break :blk null;
        };

        const p = self.rand.random().float(f32);
        const event = blk: {
            if (p <= d) {
                break :blk DTL_event.duplication;
            } else if (p <= d + t) {
                break :blk DTL_event.transfer;
            } else if (p <= d + t + l) {
                break :blk DTL_event.loss;
            } else if (p <= d + t + l + s) {
                break :blk DTL_event.speciation;
            } else {
                var prob_sum = d + t + l + s;
                for (highway_probabilities.?, highways.?.items) |proba, hw| {
                    prob_sum += proba;
                    if (p <= prob_sum) {
                        break :blk DTL_event{ .highway = hw.recipient };
                    }
                } else unreachable;
            }
        };

        const buf = try self.allocator.alloc(u8, 1024);
        switch (event) {
            .duplication => {
                // std.debug.print("Duplication above node {}\n", .{node_id});
                self.event_counts.duplication += 1;
                const buf2 = try self.allocator.alloc(u8, 1024);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "D@{s}", .{try species_node.name_or_id(buf2)});
                const first_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const second_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = first_copy;
                parent_gene_node.right_child = second_copy;
                try self.process_species_node(gene_tree, first_copy, species_node, false);
                try self.process_species_node(gene_tree, second_copy, species_node, false);
            },
            .transfer => {
                const recipient = try self.sample_transfer_node(species_node);
                // std.debug.print("Transfer above node {} to node {}\n", .{ node_id, recipient.id });
                self.event_counts.transfer += 1;
                // TODO: this seems a bit ugly.. can be done better?
                const buf2 = try self.allocator.alloc(u8, 1024);
                const buf3 = try self.allocator.alloc(u8, 1024);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "T@{s}->{s}", .{ try species_node.name_or_id(buf2), try recipient.name_or_id(buf3) });
                const donor_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const recipient_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = donor_copy;
                parent_gene_node.right_child = recipient_copy;
                try self.process_species_node(gene_tree, donor_copy, species_node, false);
                try self.process_species_node(gene_tree, recipient_copy, recipient, true);
            },
            .loss => {
                // std.debug.print("Loss above node {}\n", .{node_id});
                self.event_counts.loss += 1;
                // parent_gene_node.name = "L";
                gene_tree.restore_bifurcation(parent_gene_node);
                if (parent_gene_node.parent) |grandparent| {
                    if (grandparent.name) |name| {
                        switch (name[0]) {
                            'D' => self.event_counts.duplication -= 1,
                            'T' => self.event_counts.transfer -= 1,
                            'H' => self.event_counts.highway_transfer -= 1,
                            else => self.event_counts.speciation -= 1,
                        }
                    } else {
                        self.event_counts.speciation -= 1;
                    }
                }
            },
            .speciation => {
                self.event_counts.speciation += 1;
                if (species_node.left_child != null) {
                    // parent_gene_node.name = "S";
                    // std.debug.print("Speciation at node {}\n", .{node_id});
                    const left_child = try gene_tree.newNode(null, null, parent_gene_node);
                    const right_child = try gene_tree.newNode(null, null, parent_gene_node);
                    parent_gene_node.left_child = left_child;
                    parent_gene_node.right_child = right_child;
                    try self.process_species_node(gene_tree, left_child, species_node.left_child.?, false);
                    try self.process_species_node(gene_tree, right_child, species_node.right_child.?, false);
                } else {
                    // std.debug.print("Leaf at node {}\n", .{node_id});
                    const species_name = species_node.name orelse "species";
                    parent_gene_node.name = try std.fmt.bufPrint(buf, "{s}_{}", .{ species_name, self.num_gene_copies[node_id] });
                    self.num_gene_copies[node_id] += 1;
                }
            },
            .highway => |recipient_id| {
                const recipient = self.species_tree.post_order_nodes.items[recipient_id];
                self.event_counts.highway_transfer += 1;
                // TODO: this seems a bit ugly.. can be done better?
                const buf2 = try self.allocator.alloc(u8, 1024);
                const buf3 = try self.allocator.alloc(u8, 1024);
                parent_gene_node.name = try std.fmt.bufPrint(buf, "H@{s}->{s}", .{ try species_node.name_or_id(buf2), try recipient.name_or_id(buf3) });
                const donor_copy = try gene_tree.newNode(null, null, parent_gene_node);
                const recipient_copy = try gene_tree.newNode(null, null, parent_gene_node);
                parent_gene_node.left_child = donor_copy;
                parent_gene_node.right_child = recipient_copy;
                try self.process_species_node(gene_tree, donor_copy, species_node, false);
                try self.process_species_node(gene_tree, recipient_copy, recipient, true);
            },
        }
    }

    fn sample_transfer_node(self: *FamilySimulator, transfer_origin: *TreeNode) AllocError!*TreeNode {
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
                    const transfer_candidate = self.species_tree.post_order_nodes.items[self.rand.random().weightedIndex(f32, self.transfer_rates_to)];
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

    pub fn addHighway(self: *FamilySimulator, source: usize, target: usize, probability: f32) !void {
        const map_entry = try self.highways.getOrPutValue(source, std.ArrayList(*Highway).init(self.allocator.*));
        const highway = try self.allocator.create(Highway);
        highway.* = Highway{
            .recipient = target,
            .probability = probability,
        };
        try map_entry.value_ptr.append(highway);
    }
};
