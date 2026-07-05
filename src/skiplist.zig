const std = @import("std");

pub const MAX_LEVEL: u32 = 16;

pub const SkipNode = struct {
    key: u32,
    value: u32,
    forward: [MAX_LEVEL]?*SkipNode,
    level: u32,
};

pub const SkipList = struct {
    allocator: std.mem.Allocator,
    header: *SkipNode,
    level: u32,
    count: u32,
    seed: u32,

    pub fn init(allocator: std.mem.Allocator) !SkipList {
        const header = try allocator.create(SkipNode);
        header.* = std.mem.zeroes(SkipNode);
        header.key = 0;
        header.level = MAX_LEVEL;
        return SkipList{
            .allocator = allocator, .header = header,
            .level = 1, .count = 0, .seed = 42,
        };
    }

    pub fn insert(self: *SkipList, key: u32, value: u32) !void {
        var update: [MAX_LEVEL]?*SkipNode = std.mem.zeroes([MAX_LEVEL]?*SkipNode);
        var current = self.header;
        var i = self.level;
        while (i > 0) {
            i -= 1;
            while (current.forward[i]) |next| {
                if (next.key >= key) break;
                current = next;
            }
            update[i] = current;
        }
        if (current.forward[0]) |next| {
            if (next.key == key) { next.value = value; return; }
        }
        const new_level = randomLevel(self);
        if (new_level > self.level) {
            for (self.level..new_level) |l| update[l] = self.header;
            self.level = new_level;
        }
        const node = try self.allocator.create(SkipNode);
        node.* = std.mem.zeroes(SkipNode);
        node.key = key;
        node.value = value;
        node.level = new_level;
        for (0..new_level) |l| {
            if (update[l]) |u| {
                node.forward[l] = u.forward[l];
                u.forward[l] = node;
            }
        }
        self.count += 1;
    }

    pub fn search(self: *const SkipList, key: u32) ?u32 {
        var current = self.header;
        var i = self.level;
        while (i > 0) {
            i -= 1;
            while (current.forward[i]) |next| {
                if (next.key >= key) break;
                current = next;
            }
        }
        if (current.forward[0]) |next| {
            if (next.key == key) return next.value;
        }
        return null;
    }

    pub fn remove(self: *SkipList, key: u32) bool {
        var update: [MAX_LEVEL]?*SkipNode = std.mem.zeroes([MAX_LEVEL]?*SkipNode);
        var current = self.header;
        var i = self.level;
        while (i > 0) {
            i -= 1;
            while (current.forward[i]) |next| {
                if (next.key >= key) break;
                current = next;
            }
            update[i] = current;
        }
        if (current.forward[0]) |target| {
            if (target.key != key) return false;
            for (0..self.level) |l| {
                if (update[l]) |u| {
                    if (u.forward[l] == target) u.forward[l] = target.forward[l];
                }
            }
            self.allocator.destroy(target);
            self.count -= 1;
            while (self.level > 1 and self.header.forward[self.level - 1] == null) self.level -= 1;
            return true;
        }
        return false;
    }

    pub fn deinit(self: *SkipList) void {
        var current = self.header.forward[0];
        while (current) |node| {
            const next = node.forward[0];
            self.allocator.destroy(node);
            current = next;
        }
        self.allocator.destroy(self.header);
    }

    pub fn len(self: *const SkipList) u32 { return self.count; }

    pub fn rangeQuery(self: *const SkipList, lo: u32, hi: u32, output: []u32) u32 {
        var current = self.header;
        var i = self.level;
        while (i > 0) { i -= 1;
            while (current.forward[i]) |next| { if (next.key >= lo) break; current = next; }
        }
        var c: u32 = 0;
        var node = current.forward[0];
        while (node) |n| {
            if (n.key > hi) break;
            if (c < output.len) { output[c] = n.value; c += 1; }
            node = n.forward[0];
        }
        return c;
    }
};

fn randomLevel(sl: *SkipList) u32 {
    var level: u32 = 1;
    sl.seed = sl.seed *% 1103515245 +% 12345;
    var r = sl.seed;
    while (r & 1 == 0 and level < MAX_LEVEL) : (level += 1) r >>= 1;
    return level;
}
