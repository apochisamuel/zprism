const std = @import("std");

pub const TrieNode = struct {
    children: [26]?*TrieNode,
    is_end: bool,
    count: u32,
    depth: u32,
    value: u32,
};

pub const Trie = struct {
    allocator: std.mem.Allocator,
    root: *TrieNode,
    node_count: u32,
    word_count: u32,
    max_depth: u32,

    pub fn init(allocator: std.mem.Allocator) !Trie {
        const root = try allocator.create(TrieNode);
        root.* = std.mem.zeroes(TrieNode);
        return Trie{
            .allocator = allocator, .root = root,
            .node_count = 1, .word_count = 0, .max_depth = 0,
        };
    }

    pub fn insert(self: *Trie, word: []const u8, value: u32) !void {
        var node = self.root;
        for (word, 0..) |ch, depth| {
            const idx = charToIndex(ch) orelse continue;
            if (node.children[idx] == null) {
                const child = try self.allocator.create(TrieNode);
                child.* = std.mem.zeroes(TrieNode);
                child.depth = @intCast(depth + 1);
                node.children[idx] = child;
                self.node_count += 1;
            }
            node = node.children[idx].?;
        }
        if (!node.is_end) self.word_count += 1;
        node.is_end = true;
        node.count += 1;
        node.value = value;
        if (word.len > self.max_depth) self.max_depth = @intCast(word.len);
    }

    pub fn search(self: *const Trie, word: []const u8) ?u32 {
        var node = self.root;
        for (word) |ch| {
            const idx = charToIndex(ch) orelse return null;
            node = node.children[idx] orelse return null;
        }
        return if (node.is_end) node.value else null;
    }

    pub fn startsWith(self: *const Trie, prefix: []const u8) bool {
        var node = self.root;
        for (prefix) |ch| {
            const idx = charToIndex(ch) orelse return false;
            node = node.children[idx] orelse return false;
        }
        return true;
    }

    pub fn countPrefix(self: *const Trie, prefix: []const u8) u32 {
        var node = self.root;
        for (prefix) |ch| {
            const idx = charToIndex(ch) orelse return 0;
            node = node.children[idx] orelse return 0;
        }
        return countNodes(node);
    }

    pub fn deinit(self: *Trie) void {
        freeNode(self.allocator, self.root);
    }
};

fn charToIndex(ch: u8) ?usize {
    if (ch >= 'a' and ch <= 'z') return ch - 'a';
    if (ch >= 'A' and ch <= 'Z') return ch - 'A';
    return null;
}

fn countNodes(node: *const TrieNode) u32 {
    var count: u32 = node.count;
    for (node.children) |child| {
        if (child) |c| count += countNodes(c);
    }
    return count;
}

fn freeNode(allocator: std.mem.Allocator, node: *TrieNode) void {
    for (&node.children) |*child| {
        if (child.*) |c| { freeNode(allocator, c); child.* = null; }
    }
    allocator.destroy(node);
}

pub fn buildTrieFromStrings(allocator: std.mem.Allocator, strings: []const []const u8) !Trie {
    var trie = try Trie.init(allocator);
    for (strings, 0..) |s, i| try trie.insert(s, @intCast(i));
    return trie;
}

pub fn longestCommonPrefix(words: []const []const u8) u32 {
    if (words.len == 0) return 0;
    var prefix_len: u32 = 0;
    const first = words[0];
    outer: for (0..first.len) |i| {
        for (words[1..]) |w| {
            if (i >= w.len or w[i] != first[i]) break :outer;
        }
        prefix_len += 1;
    }
    return prefix_len;
}
