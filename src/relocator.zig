const std = @import("std");
const types = @import("types.zig");

pub const RelocResult = struct {
    applied: u32, skipped: u32, failed: u32,
    total_displacement: u64,
};

pub fn analyzeRelocations(doc: *const types.Document) RelocResult {
    var result = std.mem.zeroes(RelocResult);
    if (doc.relocs.items == null) return result;
    const relocs = doc.relocs.items.?;
    for (relocs) |*rel| {
        if (rel.resolved_hash != 0) {
            result.applied += 1;
            result.total_displacement += rel.target;
        } else if (rel.section_index >= doc.raw_count) {
            result.failed += 1;
        } else {
            result.skipped += 1;
        }
    }
    return result;
}

pub fn groupBySection(doc: *const types.Document, section_counts: []u32) void {
    if (doc.relocs.items == null) return;
    const relocs = doc.relocs.items.?;
    for (relocs) |*rel| {
        if (rel.section_index < section_counts.len)
            section_counts[rel.section_index] +|= 1;
    }
}

pub fn computeRelocEntropy(doc: *const types.Document) f64 {
    if (doc.relocs.items == null or doc.relocs.count == 0) return 0;
    const relocs = doc.relocs.items.?;
    var freq = [_]u32{0} ** 256;
    for (relocs) |*rel| {
        freq[@as(u8, @truncate(rel.target))] += 1;
    }
    var entropy: f64 = 0;
    const n = @as(f64, @floatFromInt(relocs.len));
    for (freq) |f| {
        if (f > 0) {
            const p = @as(f64, @floatFromInt(f)) / n;
            entropy -= p * @log2(p);
        }
    }
    return entropy;
}

pub fn findRelocClusters(doc: *const types.Document, clusters: []u32) u32 {
    if (doc.relocs.items == null or doc.relocs.count < 2) return 0;
    const relocs = doc.relocs.items.?;
    var count: u32 = 0;
    var cluster_start: u32 = 0;
    for (1..relocs.len) |i| {
        if (relocs[i].section_index != relocs[i - 1].section_index or
            relocs[i].target > relocs[i - 1].target + 64)
        {
            if (i - cluster_start > 2 and count < clusters.len) {
                clusters[count] = cluster_start;
                count += 1;
            }
            cluster_start = @intCast(i);
        }
    }
    return count;
}

pub fn validateRelocChain(doc: *const types.Document) bool {
    if (doc.relocs.items == null) return true;
    const relocs = doc.relocs.items.?;
    for (relocs) |*rel| {
        if (rel.section_index >= doc.raw_count) return false;
        if (doc.raw_sections) |secs| {
            const sec = &secs[rel.section_index];
            if (sec.data.len < 4) return false;
        }
    }
    return true;
}
