const std = @import("std");
const types = @import("types.zig");

pub const DiffType = enum { added, removed, modified, unchanged };

pub const DiffEntry = struct {
    diff_type: DiffType, section: types.SectionType,
    index_a: u32, index_b: u32, similarity: f64,
};

pub fn diffSymbols(a: ?[]const types.Symbol, b: ?[]const types.Symbol, output: []DiffEntry) u32 {
    var count: u32 = 0;
    if (a) |sa| {
        for (sa, 0..) |*sym_a, i| {
            if (count >= output.len) break;
            var best_match: u32 = std.math.maxInt(u32);
            var best_sim: f64 = 0;
            if (b) |sb| {
                for (sb, 0..) |*sym_b, j| {
                    const sim = symbolSimilarity(sym_a, sym_b);
                    if (sim > best_sim) { best_sim = sim; best_match = @intCast(j); }
                }
            }
            if (best_sim > 0.9) {
                output[count] = DiffEntry{ .diff_type = .unchanged, .section = .symbols, .index_a = @intCast(i), .index_b = best_match, .similarity = best_sim };
            } else if (best_sim > 0.5) {
                output[count] = DiffEntry{ .diff_type = .modified, .section = .symbols, .index_a = @intCast(i), .index_b = best_match, .similarity = best_sim };
            } else {
                output[count] = DiffEntry{ .diff_type = .removed, .section = .symbols, .index_a = @intCast(i), .index_b = 0, .similarity = 0 };
            }
            count += 1;
        }
    }
    if (b) |sb| {
        for (sb, 0..) |_, j| {
            if (count >= output.len) break;
            var matched = false;
            for (output[0..count]) |*entry| {
                if (entry.index_b == j and entry.diff_type != .removed) { matched = true; break; }
            }
            if (!matched) {
                output[count] = DiffEntry{ .diff_type = .added, .section = .symbols, .index_a = 0, .index_b = @intCast(j), .similarity = 0 };
                count += 1;
            }
        }
    }
    return count;
}

fn symbolSimilarity(a: *const types.Symbol, b: *const types.Symbol) f64 {
    var score: f64 = 0;
    if (a.name_index == b.name_index) score += 0.4;
    if (a.klass == b.klass) score += 0.2;
    if (a.attr_index == b.attr_index) score += 0.2;
    if (a.sym_flags == b.sym_flags) score += 0.1;
    const score_diff = if (a.derived_score > b.derived_score) a.derived_score - b.derived_score else b.derived_score - a.derived_score;
    if (score_diff < 100) score += 0.1;
    return score;
}

pub fn computeEditDistance(a: []const u8, b: []const u8) u32 {
    if (a.len == 0) return @intCast(b.len);
    if (b.len == 0) return @intCast(a.len);
    const m = @min(a.len, 128);
    const n = @min(b.len, 128);
    var prev: [129]u32 = undefined;
    var curr: [129]u32 = undefined;
    for (0..n + 1) |j| prev[j] = @intCast(j);
    for (1..m + 1) |i| {
        curr[0] = @intCast(i);
        for (1..n + 1) |j| {
            const cost: u32 = if (a[i - 1] == b[j - 1]) 0 else 1;
            curr[j] = @min(@min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
        }
        @memcpy(prev[0..n + 1], curr[0..n + 1]);
    }
    return prev[n];
}

pub fn diffSummary(entries: []const DiffEntry, count: u32) [4]u32 {
    var summary = [_]u32{0} ** 4;
    for (entries[0..count]) |*e| {
        switch (e.diff_type) {
            .added => summary[0] += 1, .removed => summary[1] += 1,
            .modified => summary[2] += 1, .unchanged => summary[3] += 1,
        }
    }
    return summary;
}
