const std = @import("std");
const types = @import("types.zig");

pub const CorrelationMatrix = struct {
    values: [16][16]f64,
    labels: [16][]const u8,
    dim: u32,
};

pub fn buildCorrelationMatrix(doc: *const types.Document) CorrelationMatrix {
    var mat = std.mem.zeroes(CorrelationMatrix);
    mat.dim = 0;
    
    var vectors: [16][4096]u32 = undefined;
    var lengths: [16]u32 = undefined;
    
    if (doc.symbols.items) |syms| {
        const n = @min(syms.len, 4096);
        for (0..n) |i| vectors[0][i] = syms[i].derived_score;
        lengths[0] = @intCast(n);
        mat.labels[0] = "score";
        for (0..n) |i| vectors[1][i] = syms[i].name_index;
        lengths[1] = @intCast(n);
        mat.labels[1] = "name_idx";
        for (0..n) |i| vectors[2][i] = syms[i].attr_index;
        lengths[2] = @intCast(n);
        mat.labels[2] = "attr_idx";
        for (0..n) |i| vectors[3][i] = @as(u32, syms[i].klass);
        lengths[3] = @intCast(n);
        mat.labels[3] = "class";
        mat.dim = 4;
    }
    
    for (0..mat.dim) |i| {
        for (0..mat.dim) |j| {
            mat.values[i][j] = pearsonCorrelation(
                vectors[i][0..lengths[i]], vectors[j][0..lengths[j]]);
        }
    }
    
    return mat;
}

fn pearsonCorrelation(x: []const u32, y: []const u32) f64 {
    const n = @min(x.len, y.len);
    if (n < 2) return 0;
    var sum_x: f64 = 0; var sum_y: f64 = 0;
    var sum_xy: f64 = 0; var sum_x2: f64 = 0; var sum_y2: f64 = 0;
    for (0..n) |i| {
        const fx = @as(f64, @floatFromInt(x[i]));
        const fy = @as(f64, @floatFromInt(y[i]));
        sum_x += fx; sum_y += fy; sum_xy += fx * fy;
        sum_x2 += fx * fx; sum_y2 += fy * fy;
    }
    const nf = @as(f64, @floatFromInt(n));
    const num = nf * sum_xy - sum_x * sum_y;
    const den = @sqrt((nf * sum_x2 - sum_x * sum_x) * (nf * sum_y2 - sum_y * sum_y));
    if (den == 0) return 0;
    return num / den;
}

pub fn spearmanCorrelation(x: []const u32, y: []const u32) f64 {
    const n = @min(x.len, y.len);
    if (n < 2) return 0;
    var rank_x: [4096]u32 = undefined;
    var rank_y: [4096]u32 = undefined;
    computeRanks(x[0..n], rank_x[0..n]);
    computeRanks(y[0..n], rank_y[0..n]);
    return pearsonCorrelation(rank_x[0..n], rank_y[0..n]);
}

fn computeRanks(values: []const u32, ranks: []u32) void {
    for (0..values.len) |i| {
        var rank: u32 = 1;
        for (0..values.len) |j| {
            if (values[j] < values[i] or (values[j] == values[i] and j < i)) rank += 1;
        }
        ranks[i] = rank;
    }
}

pub fn mutualInformation(x: []const u32, y: []const u32, bins: u32) f64 {
    const n = @min(x.len, y.len);
    if (n == 0 or bins == 0) return 0;
    var joint: [64][64]u32 = std.mem.zeroes([64][64]u32);
    var mx: u32 = 1; var my: u32 = 1;
    for (0..n) |i| { if (x[i] > mx) mx = x[i]; if (y[i] > my) my = y[i]; }
    const actual_bins = @min(bins, 64);
    for (0..n) |i| {
        const bx = x[i] / (mx / actual_bins + 1);
        const by = y[i] / (my / actual_bins + 1);
        if (bx < actual_bins and by < actual_bins) joint[bx][by] += 1;
    }
    var mi: f64 = 0;
    const nf = @as(f64, @floatFromInt(n));
    for (0..actual_bins) |i| {
        var row_sum: u32 = 0;
        for (0..actual_bins) |j| row_sum += joint[i][j];
        for (0..actual_bins) |j| {
            if (joint[i][j] == 0) continue;
            var col_sum: u32 = 0;
            for (0..actual_bins) |k| col_sum += joint[k][j];
            if (row_sum == 0 or col_sum == 0) continue;
            const pxy = @as(f64, @floatFromInt(joint[i][j])) / nf;
            const px = @as(f64, @floatFromInt(row_sum)) / nf;
            const py = @as(f64, @floatFromInt(col_sum)) / nf;
            mi += pxy * @log2(pxy / (px * py));
        }
    }
    return mi;
}
