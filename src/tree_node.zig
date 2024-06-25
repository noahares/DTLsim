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

    pub fn print(self: *TreeNode) void {
        if (self.left_child) |c| {
            std.debug.print("(", .{});
            c.print();
        }
        if (self.right_child) |c| {
            std.debug.print(",", .{});
            c.print();
            std.debug.print(")", .{});
        }
        if (self.name) |name| {
            std.debug.print("{s}", .{name});
        }
        // std.debug.print("_{}", .{self.id});
        if (self.branch_length) |b| {
            std.debug.print(":{d:.2}", .{b});
        }
    }
};
