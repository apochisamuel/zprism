const std = @import("std");
const types = @import("types.zig");

pub const SnapshotField = enum { symbols, strings, attrs, relocs, events, all };

pub const Snapshot = struct {
    symbol_scores: ?[]u32,
    string_hashes: ?[]u32,
    attr_values: ?[]u32,
    reloc_hashes: ?[]u32,
    event_checksums: ?[]u32,
    timestamp: u64,
    document_hash: u32,
    field_mask: u32,
};

pub fn takeSnapshot(allocator: std.mem.Allocator, doc: *const types.Document, fields: SnapshotField) !Snapshot {
    var snap = std.mem.zeroes(Snapshot);
    snap.timestamp = 0;
    snap.document_hash = doc.cache.combined_hash;
    
    const capture_all = fields == .all;
    
    if (capture_all or fields == .symbols) {
        if (doc.symbols.items) |syms| {
            snap.symbol_scores = try allocator.alloc(u32, syms.len);
            for (syms, 0..) |*s, i| snap.symbol_scores.?[i] = s.derived_score;
            snap.field_mask |= 0x01;
        }
    }
    
    if (capture_all or fields == .strings) {
        if (doc.strings.items) |items| {
            snap.string_hashes = try allocator.alloc(u32, items.len);
            for (items, 0..) |*s, i| snap.string_hashes.?[i] = s.hash;
            snap.field_mask |= 0x02;
        }
    }
    
    if (capture_all or fields == .attrs) {
        if (doc.attrs.items) |items| {
            snap.attr_values = try allocator.alloc(u32, items.len);
            for (items, 0..) |*a, i| snap.attr_values.?[i] = a.value;
            snap.field_mask |= 0x04;
        }
    }
    
    if (capture_all or fields == .relocs) {
        if (doc.relocs.items) |items| {
            snap.reloc_hashes = try allocator.alloc(u32, items.len);
            for (items, 0..) |*r, i| snap.reloc_hashes.?[i] = r.resolved_hash;
            snap.field_mask |= 0x08;
        }
    }
    
    if (capture_all or fields == .events) {
        if (doc.events.items) |items| {
            snap.event_checksums = try allocator.alloc(u32, items.len);
            for (items, 0..) |*e, i| snap.event_checksums.?[i] = e.checksum;
            snap.field_mask |= 0x10;
        }
    }
    
    return snap;
}

pub fn freeSnapshot(allocator: std.mem.Allocator, snap: *Snapshot) void {
    if (snap.symbol_scores) |s| allocator.free(s);
    if (snap.string_hashes) |s| allocator.free(s);
    if (snap.attr_values) |s| allocator.free(s);
    if (snap.reloc_hashes) |s| allocator.free(s);
    if (snap.event_checksums) |s| allocator.free(s);
    snap.* = std.mem.zeroes(Snapshot);
}

pub fn compareSnapshots(a: *const Snapshot, b: *const Snapshot) f64 {
    var total: u32 = 0;
    var matching: u32 = 0;
    
    if (a.symbol_scores) |sa| {
        if (b.symbol_scores) |sb| {
            const n = @min(sa.len, sb.len);
            for (0..n) |i| {
                total += 1;
                if (sa[i] == sb[i]) matching += 1;
            }
        }
    }
    
    if (a.string_hashes) |sa| {
        if (b.string_hashes) |sb| {
            const n = @min(sa.len, sb.len);
            for (0..n) |i| { total += 1; if (sa[i] == sb[i]) matching += 1; }
        }
    }
    
    if (a.attr_values) |sa| {
        if (b.attr_values) |sb| {
            const n = @min(sa.len, sb.len);
            for (0..n) |i| { total += 1; if (sa[i] == sb[i]) matching += 1; }
        }
    }
    
    if (total == 0) return if (a.document_hash == b.document_hash) 1.0 else 0.0;
    return @as(f64, @floatFromInt(matching)) / @as(f64, @floatFromInt(total));
}

pub fn snapshotDrift(a: *const Snapshot, b: *const Snapshot) u32 {
    var drift: u32 = 0;
    if (a.symbol_scores) |sa| {
        if (b.symbol_scores) |sb| {
            const n = @min(sa.len, sb.len);
            for (0..n) |i| {
                if (sa[i] != sb[i]) drift += 1;
            }
        }
    }
    return drift;
}
