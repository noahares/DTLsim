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
    // var n_nodes: usize = 0;
    // for (input) |c| {
    //     if (c == ',') {
    //         n_nodes += 1;
    //     }
    // }
    // n_nodes = n_nodes * 2 + 1;
    // std.debug.print("Number of nodes: {}\n", .{n_nodes});
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
                var end = cursor;
                while (input[end] != '(' and
                    input[end] != ',' and
                    input[end] != ';' and
                    input[end] != ' ' and
                    input[end] != ')') : (end += 1)
                {}
                const brlen_str = input[cursor..end];
                current_node.branch_length = try std.fmt.parseFloat(f32, brlen_str);
                cursor = end;
            },
            ';' => {
                break;
            },
            else => {
                var end = cursor;
                while (input[end] != ':' and
                    input[end] != ',' and
                    input[end] != ';' and
                    input[end] != ' ' and
                    input[end] != ')') : (end += 1)
                {}
                const name = input[cursor..end];
                current_node.name = name;
                cursor = end;
            },
        }
    } else unreachable;
    return tree;
}
