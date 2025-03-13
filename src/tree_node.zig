const std = @import("std");

pub const TreeNode = struct {
    id: usize,
    name: ?[]const u8,
    branch_length: ?f32,
    parent: ?*TreeNode,
    left_child: ?*TreeNode,
    right_child: ?*TreeNode,

    pub fn init(id: usize, name: ?[]const u8, branch_length: ?f32, parent: ?*TreeNode) TreeNode {
        return TreeNode{
            .id = id,
            .name = name,
            .branch_length = branch_length,
            .parent = parent,
            .left_child = null,
            .right_child = null,
        };
    }

    pub fn deinit(self: *TreeNode) void {
        if (self.left_child) |c| {
            c.deinit();
        }
        if (self.right_child) |c| {
            c.deinit();
        }
        self.left_child = null;
        self.right_child = null;
        self.parent = null;
    }

    pub fn print(self: *TreeNode, writer: anytype, print_leaf_id: bool) !void {
        if (self.left_child) |c| {
            try writer.print("(", .{});
            try c.print(writer, print_leaf_id);
        }
        if (self.right_child) |c| {
            try writer.print(",", .{});
            try c.print(writer, print_leaf_id);
            try writer.print(")", .{});
        }
        if (self.name) |name| {
            try writer.print("{s}", .{name});
            if (print_leaf_id) {
                try writer.print(".{}", .{self.id});
            }
        } else if (self.left_child) |_| {
            try writer.print(".{}", .{self.id});
        }
        try writer.print(":{d:.2}", .{self.branch_length orelse 1.0});
    }

    pub fn name_or_id(self: *TreeNode, buf: []u8) std.fmt.BufPrintError![]u8 {
        if (self.name) |name| {
            return std.fmt.bufPrint(buf, "{s}", .{name});
        } else {
            return std.fmt.bufPrint(buf, ".{}", .{self.id});
        }
    }
};
