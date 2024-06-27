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
    var current_node = tree.root.?;
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
    }
    return tree;
}
