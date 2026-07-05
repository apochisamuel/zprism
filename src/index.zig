const std = @import("std");
const types = @import("types.zig");

pub const IndexEntry = struct { key: u32, value: u32, hash: u32 };

pub const HashIndex = struct {
    entries: []IndexEntry,
    count: u32,
    capacity: u32,
    load_factor: f64,

    pub fn init(allocator: std.mem.Allocator, capacity: u32) !HashIndex {
        const entries = try allocator.alloc(IndexEntry, capacity);
        for (entries) |*e| { e.key = std.math.maxInt(u32); e.value = 0; e.hash = 0; }
        return HashIndex{ .entries = entries, .count = 0, .capacity = capacity, .load_factor = 0 };
    }

    pub fn insert(self: *HashIndex, key: u32, value: u32) bool {
        if (self.count >= self.capacity * 3 / 4) return false;
        const hash = fnvHash(key);
        var idx = hash % self.capacity;
        var probes: u32 = 0;
        while (probes < self.capacity) : (probes += 1) {
            if (self.entries[idx].key == std.math.maxInt(u32)) {
                self.entries[idx] = IndexEntry{ .key = key, .value = value, .hash = hash };
                self.count += 1;
                self.load_factor = @as(f64, @floatFromInt(self.count)) / @as(f64, @floatFromInt(self.capacity));
                return true;
            }
            idx = (idx + 1) % self.capacity;
        }
        return false;
    }

    pub fn lookup(self: *const HashIndex, key: u32) ?u32 {
        const hash = fnvHash(key);
        var idx = hash % self.capacity;
        var probes: u32 = 0;
        while (probes < self.capacity) : (probes += 1) {
            if (self.entries[idx].key == key) return self.entries[idx].value;
            if (self.entries[idx].key == std.math.maxInt(u32)) return null;
            idx = (idx + 1) % self.capacity;
        }
        return null;
    }

    pub fn remove(self: *HashIndex, key: u32) bool {
        const hash = fnvHash(key);
        var idx = hash % self.capacity;
        var probes: u32 = 0;
        while (probes < self.capacity) : (probes += 1) {
            if (self.entries[idx].key == key) {
                self.entries[idx].key = std.math.maxInt(u32);
                self.count -= 1;
                return true;
            }
            if (self.entries[idx].key == std.math.maxInt(u32)) return false;
            idx = (idx + 1) % self.capacity;
        }
        return false;
    }

    pub fn deinit(self: *HashIndex, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
    }
};

pub fn buildSymbolIndex(allocator: std.mem.Allocator, doc: *const types.Document) !HashIndex {
    const cap = @max(doc.symbols.count * 2, 64);
    var idx = try HashIndex.init(allocator, cap);
    if (doc.symbols.items) |syms| {
        for (syms, 0..) |*sym, i| {
            _ = idx.insert(sym.name_index, @intCast(i));
        }
    }
    return idx;
}

pub fn buildRelocIndex(allocator: std.mem.Allocator, doc: *const types.Document) !HashIndex {
    const cap = @max(doc.relocs.count * 2, 64);
    var idx = try HashIndex.init(allocator, cap);
    if (doc.relocs.items) |relocs| {
        for (relocs, 0..) |*rel, i| {
            _ = idx.insert(rel.symbol_index, @intCast(i));
        }
    }
    return idx;
}

fn fnvHash(key: u32) u32 {
    var h: u32 = 0x811c9dc5;
    h ^= key & 0xFF; h *%= 0x01000193;
    h ^= (key >> 8) & 0xFF; h *%= 0x01000193;
    h ^= (key >> 16) & 0xFF; h *%= 0x01000193;
    h ^= (key >> 24) & 0xFF; h *%= 0x01000193;
    return h;
}
