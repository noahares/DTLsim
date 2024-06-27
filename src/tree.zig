const std = @import("std");
const TreeNode = @import("tree_node.zig").TreeNode;

pub const Tree = struct {
    root: ?*TreeNode,
    allocator: *const std.mem.Allocator,
    post_order_nodes: std.ArrayList(*TreeNode),
    _next_node_id: usize,

    pub fn init(allocator: *const std.mem.Allocator) std.mem.Allocator.Error!*Tree {
        const tree = try allocator.create(Tree);
        tree.* = Tree{ .root = null, .allocator = allocator, .post_order_nodes = std.ArrayList(*TreeNode).init(allocator.*), ._next_node_id = 0 };
        const root = try tree.newNode(null, null, null);
        tree.root = root;
        return tree;
    }

    pub fn deinit(self: *Tree) void {
        self.root = null;
        self.post_order_nodes.clearAndFree();
        self._next_node_id = 0;
    }

    pub fn newNode(self: *Tree, name: ?[]const u8, branch_length: ?f32, parent: ?*TreeNode) std.mem.Allocator.Error!*TreeNode {
        const node = try self.allocator.create(TreeNode);
        node.* = TreeNode.init(self._next_node_id, name, branch_length, parent);
        self._next_node_id += 1;
        try self.post_order_nodes.append(node);
        return node;
    }

    pub fn numNodes(self: *Tree) usize {
        return self._next_node_id;
    }

    pub fn print(self: *Tree, writer: anytype) !void {
        if (self.root) |node| {
            try node.print(writer);
            try writer.print(";\n", .{});
        } else {
            try writer.print("();\n", .{});
        }
    }

    pub fn restore_bifurcation(self: *Tree, node: *TreeNode) void {
        if (node.parent) |parent| {
            if (parent.left_child.?.id == node.id) {
                if (parent.parent) |grandparent| {
                    parent.right_child.?.parent = grandparent;
                    if (grandparent.left_child.?.id == parent.id) {
                        grandparent.left_child = parent.right_child;
                    } else {
                        grandparent.right_child = parent.right_child;
                    }
                } else {
                    self.root = parent.right_child;
                }
            } else {
                if (parent.parent) |grandparent| {
                    parent.left_child.?.parent = grandparent;
                    if (grandparent.left_child.?.id == parent.id) {
                        grandparent.left_child = parent.left_child;
                    } else {
                        grandparent.right_child = parent.left_child;
                    }
                } else {
                    self.root = parent.left_child;
                }
            }
        } else {
            self.root = null;
        }
    }
};
