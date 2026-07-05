const std = @import("std");
const types = @import("types.zig");

pub const SampleMethod = enum { uniform, weighted, stratified, reservoir };

pub fn sampleSymbols(doc: *const types.Document, method: SampleMethod, count: u32, output: []u32) u32 {
    if (doc.symbols.items == null or doc.symbols.count == 0) return 0;
    const syms = doc.symbols.items.?;
    return switch (method) {
        .uniform => uniformSample(syms.len, count, output),
        .weighted => weightedSample(syms, count, output),
        .stratified => stratifiedSample(syms, count, output),
        .reservoir => reservoirSample(syms.len, count, output),
    };
}

fn uniformSample(total: usize, count: u32, output: []u32) u32 {
    if (total == 0) return 0;
    const n = @min(count, @as(u32, @intCast(total)));
    const step = if (n > 0) @as(u32, @intCast(total)) / n else 1;
    var c: u32 = 0;
    var idx: u32 = 0;
    while (c < n and c < output.len) {
        output[c] = idx;
        c += 1;
        idx +|= step;
        if (idx >= total) break;
    }
    return c;
}

fn weightedSample(syms: []const types.Symbol, count: u32, output: []u32) u32 {
    var total_weight: u64 = 0;
    for (syms) |*s| total_weight += s.derived_score;
    if (total_weight == 0) return uniformSample(syms.len, count, output);
    
    var c: u32 = 0;
    const threshold = total_weight / @as(u64, @max(count, 1));
    var accum: u64 = 0;
    for (syms, 0..) |*s, i| {
        accum += s.derived_score;
        if (accum >= threshold and c < count and c < output.len) {
            output[c] = @intCast(i);
            c += 1;
            accum = 0;
        }
    }
    return c;
}

fn stratifiedSample(syms: []const types.Symbol, count: u32, output: []u32) u32 {
    var class_counts = [_]u32{0} ** 256;
    for (syms) |*s| class_counts[@as(u8, @truncate(s.klass))] += 1;
    
    var active_classes: u32 = 0;
    for (class_counts) |cc| { if (cc > 0) active_classes += 1; }
    if (active_classes == 0) return 0;
    
    const per_class = @max(count / active_classes, 1);
    var c: u32 = 0;
    for (0..256) |klass| {
        if (class_counts[klass] == 0) continue;
        var taken: u32 = 0;
        for (syms, 0..) |*s, i| {
            if (@as(u8, @truncate(s.klass)) == klass and taken < per_class and c < output.len) {
                output[c] = @intCast(i);
                c += 1;
                taken += 1;
            }
        }
    }
    return c;
}

fn reservoirSample(total: usize, count: u32, output: []u32) u32 {
    const n = @min(count, @as(u32, @intCast(total)));
    for (0..n) |i| output[i] = @intCast(i);
    var seed: u32 = 42;
    for (n..@intCast(total)) |i| {
        seed = seed *% 1103515245 +% 12345;
        const j = seed % @as(u32, @intCast(i + 1));
        if (j < n) output[j] = @intCast(i);
    }
    return n;
}

pub fn bootstrapEstimate(scores: []const u32, iterations: u32) f64 {
    if (scores.len == 0) return 0;
    var sum: f64 = 0;
    var seed: u32 = 12345;
    for (0..iterations) |_| {
        var sample_sum: u64 = 0;
        for (0..scores.len) |_| {
            seed = seed *% 1103515245 +% 12345;
            const idx = seed % @as(u32, @intCast(scores.len));
            sample_sum += scores[idx];
        }
        sum += @as(f64, @floatFromInt(sample_sum)) / @as(f64, @floatFromInt(scores.len));
    }
    return sum / @as(f64, @floatFromInt(iterations));
}

pub fn jacknifeVariance(scores: []const u32) f64 {
    if (scores.len < 2) return 0;
    const n = scores.len;
    var total: u64 = 0;
    for (scores) |s| total += s;
    const full_mean = @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(n));
    
    var var_sum: f64 = 0;
    for (0..n) |i| {
        const leave_out_sum = total - scores[i];
        const leave_out_mean = @as(f64, @floatFromInt(leave_out_sum)) / @as(f64, @floatFromInt(n - 1));
        const diff = leave_out_mean - full_mean;
        var_sum += diff * diff;
    }
    return var_sum * @as(f64, @floatFromInt(n - 1)) / @as(f64, @floatFromInt(n));
}
