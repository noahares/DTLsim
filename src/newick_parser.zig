const std = @import("std");
const Regex = @import("regex").Regex;
const Captures = @import("regex").Captures;

const TreeNode = @import("tree_node.zig").TreeNode;
const Tree = @import("tree.zig").Tree;

const TokenType = enum {
    OpenParen,
    CloseParen,
    Comma,
    Branch,
    Taxon,
};

const Token = union(TokenType) {
    OpenParen: void,
    CloseParen: void,
    Comma: void,
    Branch: f32,
    Taxon: []const u8,
};

pub fn parseNewickString(allocator: *std.mem.Allocator, input: []const u8) !*Tree {
    const tree = try Tree.init(allocator);
    const root = try tree.newNode(null, null, null);
    tree.setRoot(root);
    var current_node = root;
    var name_re = try Regex.compile(allocator.*, "([A-Za-z0-9_|]+)");
    // var n_nodes: usize = 0;
    // for (input) |c| {
    //     if (c == ',') {
    //         n_nodes += 1;
    //     }
    // }
    // n_nodes = n_nodes * 2 + 1;
    // std.debug.print("Number of nodes: {}\n", .{n_nodes});
    defer name_re.deinit();
    var brlen_re = try Regex.compile(allocator.*, "(^[0-9.+eE-]+)");
    defer brlen_re.deinit();
    var cursor: usize = 0;
    while (true) {
        switch (input[cursor]) {
            '(' => {
                cursor += 1;
                const child = try tree.newNode(null, null, current_node);
                current_node.left_child = child;
                current_node = child;
            },
            ')' => {
                cursor += 1;
                current_node = current_node.parent.?;
            },
            ',' => {
                cursor += 1;
                current_node = current_node.parent.?;
                const child = try tree.newNode(null, null, current_node);
                current_node.right_child = child;
                current_node = child;
            },
            ' ' => {
                cursor += 1;
            },
            ':' => {
                cursor += 1;
                const brlen_cap = (try brlen_re.captures(input[cursor..])).?;
                const brlen_str = brlen_cap.sliceAt(1).?;
                current_node.branch_length = try std.fmt.parseFloat(f32, brlen_str);
                cursor += brlen_str.len;
            },
            ';' => {
                break;
            },
            else => {
                const name_cap = (try name_re.captures(input[cursor..])).?;
                const name = name_cap.sliceAt(1).?;
                current_node.name = name;
                cursor += name.len;
            },
        }
    } else unreachable;
    return tree;
}
