const std = @import("std");
const TreeNode = @import("tree_node.zig").TreeNode;

pub const Tree = struct {
    root: ?*TreeNode,
    allocator: *const std.mem.Allocator,
    post_order_nodes: std.ArrayList(*TreeNode),
    _next_node_id: usize,

    pub fn init(allocator: *const std.mem.Allocator) Tree {
        return Tree{ .root = null, .allocator = allocator, .post_order_nodes = std.ArrayList(*TreeNode).init(allocator.*), ._next_node_id = 0 };
    }

    pub fn deinit(self: *Tree) void {
        self.root = null;
        self.post_order_nodes.clearAndFree();
        self._next_node_id = 0;
    }

    pub fn setRoot(self: *Tree, root: *TreeNode) void {
        self.root = root;
    }

    pub fn newNode(self: *Tree, name: ?[]const u8, branch_length: ?f32, parent: ?*TreeNode) !*TreeNode {
        const node = try self.allocator.create(TreeNode);
        node.* = TreeNode.init(self._next_node_id, name, branch_length, parent);
        self._next_node_id += 1;
        try self.post_order_nodes.append(node);
        return node;
    }

    pub fn numNodes(self: *Tree) usize {
        return self._next_node_id;
    }

    pub fn print(self: *Tree) void {
        self.root.?.print();
        std.debug.print(";\n", .{});
        // std.debug.print("Number of nodes: {}\n", .{self.numNodes()});
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
                        grandparent.right_child = parent.right_child;
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
