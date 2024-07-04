const std = @import("std");
const Tree = @import("tree.zig").Tree;

const UtilError = error{ BranchParseError, RateParseError };

pub fn expect_token(str: []const u8, delim: u8, n: usize) bool {
    var n_tokens: usize = 1;
    for (str) |c| {
        if (c == delim) n_tokens += 1;
    }
    return n_tokens == n;
}

pub fn parse_id_or_name(tree: *Tree, str: ?[]const u8) UtilError!usize {
    if (str) |s| {
        const id = std.fmt.parseInt(usize, s, 10) catch {
            if (tree.node_id_from_name(s)) |id| {
                return id;
            } else return UtilError.BranchParseError;
        };
        return id;
    }
    return UtilError.BranchParseError;
}

pub fn parse_rate_type(str: ?[]const u8) UtilError!u8 {
    if (str) |s| {
        if (s.len == 1) {
            return std.ascii.toLower(s[0]);
        }
    }
    return UtilError.RateParseError;
}
