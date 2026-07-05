const std = @import("std");
const types = @import("types.zig");

pub const DocumentStats = struct {
    min_score: u32, max_score: u32, mean_score: f64,
    variance: f64, std_dev: f64,
    p25: u32, p50: u32, p75: u32, p90: u32, p99: u32,
    skewness: f64, kurtosis: f64,
    unique_classes: u32, unique_flags: u32,
    entropy_bits: f64,
};

pub fn computeStats(doc: *const types.Document) DocumentStats {
    var s = std.mem.zeroes(DocumentStats);
    if (doc.symbols.items == null or doc.symbols.count == 0) return s;
    const syms = doc.symbols.items.?;
    s.min_score = std.math.maxInt(u32);
    var sum: u64 = 0;
    for (syms) |*sym| {
        if (sym.derived_score < s.min_score) s.min_score = sym.derived_score;
        if (sym.derived_score > s.max_score) s.max_score = sym.derived_score;
        sum += sym.derived_score;
    }
    s.mean_score = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(syms.len));
    var var_sum: f64 = 0;
    for (syms) |*sym| {
        const diff = @as(f64, @floatFromInt(sym.derived_score)) - s.mean_score;
        var_sum += diff * diff;
    }
    s.variance = var_sum / @as(f64, @floatFromInt(syms.len));
    s.std_dev = @sqrt(s.variance);
    s.p50 = computePercentile(syms, 50);
    s.p25 = computePercentile(syms, 25);
    s.p75 = computePercentile(syms, 75);
    s.p90 = computePercentile(syms, 90);
    s.p99 = computePercentile(syms, 99);
    s.unique_classes = countUniqueClasses(syms);
    s.unique_flags = countUniqueFlags(syms);
    s.entropy_bits = computeScoreEntropy(syms);
    return s;
}

fn computePercentile(syms: []const types.Symbol, pct: u32) u32 {
    var scores: [4096]u32 = undefined;
    const n = @min(syms.len, 4096);
    for (0..n) |i| scores[i] = syms[i].derived_score;
    std.sort.insertion(u32, scores[0..n], {}, std.sort.asc(u32));
    const idx = (n * pct) / 100;
    return scores[@min(idx, n - 1)];
}

fn countUniqueClasses(syms: []const types.Symbol) u32 {
    var seen = [_]bool{false} ** 256;
    var count: u32 = 0;
    for (syms) |*sym| {
        const bucket = @as(u8, @truncate(sym.klass));
        if (!seen[bucket]) { seen[bucket] = true; count += 1; }
    }
    return count;
}

fn countUniqueFlags(syms: []const types.Symbol) u32 {
    var seen = [_]bool{false} ** 256;
    var count: u32 = 0;
    for (syms) |*sym| {
        const bucket = @as(u8, @truncate(sym.sym_flags));
        if (!seen[bucket]) { seen[bucket] = true; count += 1; }
    }
    return count;
}

fn computeScoreEntropy(syms: []const types.Symbol) f64 {
    var freq = [_]u32{0} ** 256;
    for (syms) |*sym| {
        freq[@as(u8, @truncate(sym.derived_score))] += 1;
    }
    var entropy: f64 = 0;
    const n = @as(f64, @floatFromInt(syms.len));
    for (freq) |f| {
        if (f > 0) {
            const p = @as(f64, @floatFromInt(f)) / n;
            entropy -= p * @log2(p);
        }
    }
    return entropy;
}

pub fn correlationCoeff(x: []const u32, y: []const u32) f64 {
    const n = @min(x.len, y.len);
    if (n < 2) return 0;
    var sum_x: f64 = 0; var sum_y: f64 = 0;
    var sum_xy: f64 = 0; var sum_x2: f64 = 0; var sum_y2: f64 = 0;
    for (0..n) |i| {
        const fx = @as(f64, @floatFromInt(x[i]));
        const fy = @as(f64, @floatFromInt(y[i]));
        sum_x += fx; sum_y += fy;
        sum_xy += fx * fy;
        sum_x2 += fx * fx; sum_y2 += fy * fy;
    }
    const nf = @as(f64, @floatFromInt(n));
    const num = nf * sum_xy - sum_x * sum_y;
    const den = @sqrt((nf * sum_x2 - sum_x * sum_x) * (nf * sum_y2 - sum_y * sum_y));
    if (den == 0) return 0;
    return num / den;
}
