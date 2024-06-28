pub fn expect_token(str: []const u8, delim: u8, n: usize) bool {
    var n_tokens: usize = 1;
    for (str) |c| {
        if (c == delim) n_tokens += 1;
    }
    return n_tokens == n;
}
