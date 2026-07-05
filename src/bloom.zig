const std = @import("std");

pub const BloomFilter = struct {
    bits: [1024]u8,
    hash_count: u32,
    item_count: u32,
    capacity: u32,

    pub fn init(hash_count: u32) BloomFilter {
        return BloomFilter{
            .bits = std.mem.zeroes([1024]u8),
            .hash_count = @min(hash_count, 8),
            .item_count = 0,
            .capacity = 1024 * 8,
        };
    }

    pub fn insert(self: *BloomFilter, data: []const u8) void {
        const h1 = fnv(data);
        const h2 = murmur(data);
        for (0..self.hash_count) |i| {
            const bit = (h1 +% @as(u32, @intCast(i)) *% h2) % self.capacity;
            self.bits[bit / 8] |= @as(u8, 1) << @intCast(bit % 8);
        }
        self.item_count += 1;
    }

    pub fn contains(self: *const BloomFilter, data: []const u8) bool {
        const h1 = fnv(data);
        const h2 = murmur(data);
        for (0..self.hash_count) |i| {
            const bit = (h1 +% @as(u32, @intCast(i)) *% h2) % self.capacity;
            if (self.bits[bit / 8] & (@as(u8, 1) << @intCast(bit % 8)) == 0) return false;
        }
        return true;
    }

    pub fn falsePositiveRate(self: *const BloomFilter) f64 {
        var set_bits: u32 = 0;
        for (self.bits) |b| set_bits += @popCount(b);
        const p = @as(f64, @floatFromInt(set_bits)) / @as(f64, @floatFromInt(self.capacity));
        var result: f64 = 1.0;
        for (0..self.hash_count) |_| result *= p;
        return result;
    }

    pub fn clear(self: *BloomFilter) void {
        @memset(&self.bits, 0);
        self.item_count = 0;
    }

    pub fn loadFactor(self: *const BloomFilter) f64 {
        var set: u32 = 0;
        for (self.bits) |b| set += @popCount(b);
        return @as(f64, @floatFromInt(set)) / @as(f64, @floatFromInt(self.capacity));
    }

    pub fn merge(self: *BloomFilter, other: *const BloomFilter) void {
        for (&self.bits, other.bits) |*a, b| a.* |= b;
        self.item_count += other.item_count;
    }

    pub fn intersect(self: *BloomFilter, other: *const BloomFilter) void {
        for (&self.bits, other.bits) |*a, b| a.* &= b;
    }

    pub fn jaccard(self: *const BloomFilter, other: *const BloomFilter) f64 {
        var union_bits: u32 = 0;
        var inter_bits: u32 = 0;
        for (self.bits, other.bits) |a, b| {
            union_bits += @popCount(a | b);
            inter_bits += @popCount(a & b);
        }
        if (union_bits == 0) return 0;
        return @as(f64, @floatFromInt(inter_bits)) / @as(f64, @floatFromInt(union_bits));
    }
};

fn fnv(data: []const u8) u32 {
    var h: u32 = 0x811c9dc5;
    for (data) |b| { h ^= @as(u32, b); h *%= 0x01000193; }
    return h;
}

fn murmur(data: []const u8) u32 {
    var h: u32 = 0x12345678;
    for (data) |b| { h ^= @as(u32, b); h *%= 0x5bd1e995; h ^= h >> 15; }
    return h;
}
