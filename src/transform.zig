const std = @import("std");
const types = @import("types.zig");

pub const TransformOp = enum { xor_mask, rotate_left, rotate_right, byte_swap, complement, add_const, sub_const, scale };

pub fn transformPayload(payload: []u8, op: TransformOp, param: u32) void {
    switch (op) {
        .xor_mask => for (payload) |*b| { b.* ^= @as(u8, @truncate(param)); },
        .rotate_left => {
            const shift: u3 = @intCast(param & 7);
            for (payload) |*b| { b.* = std.math.rotl(u8, b.*, shift); }
        },
        .rotate_right => {
            const shift: u3 = @intCast(param & 7);
            for (payload) |*b| { b.* = std.math.rotr(u8, b.*, shift); }
        },
        .byte_swap => {
            var i: usize = 0;
            while (i + 1 < payload.len) : (i += 2) {
                const tmp = payload[i];
                payload[i] = payload[i + 1];
                payload[i + 1] = tmp;
            }
        },
        .complement => for (payload) |*b| { b.* = ~b.*; },
        .add_const => for (payload) |*b| { b.* +%= @as(u8, @truncate(param)); },
        .sub_const => for (payload) |*b| { b.* -%= @as(u8, @truncate(param)); },
        .scale => for (payload) |*b| { b.* = @truncate(@as(u16, b.*) *% @as(u16, @truncate(param))); },
    }
}

pub fn computeEntropy(data: []const u8) f64 {
    if (data.len == 0) return 0;
    var freq = [_]u32{0} ** 256;
    for (data) |b| freq[b] += 1;
    var entropy: f64 = 0;
    const n = @as(f64, @floatFromInt(data.len));
    for (freq) |f| {
        if (f > 0) {
            const p = @as(f64, @floatFromInt(f)) / n;
            entropy -= p * @log2(p);
        }
    }
    return entropy;
}

pub fn computeChecksum(data: []const u8) u32 {
    var h: u32 = 0x811c9dc5;
    for (data) |b| {
        h ^= @as(u32, b);
        h *%= 0x01000193;
    }
    return h;
}

pub fn computeCRC32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |b| {
        crc ^= @as(u32, b);
        for (0..8) |_| {
            if (crc & 1 != 0) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc >>= 1;
            }
        }
    }
    return ~crc;
}

pub fn runLengthEncode(input: []const u8, output: []u8) u32 {
    if (input.len == 0) return 0;
    var i: usize = 0;
    var out_pos: u32 = 0;
    while (i < input.len) {
        const b = input[i];
        var count: u32 = 1;
        while (i + count < input.len and input[i + count] == b and count < 255) count += 1;
        if (out_pos + 2 > output.len) break;
        output[out_pos] = @intCast(count);
        output[out_pos + 1] = b;
        out_pos += 2;
        i += count;
    }
    return out_pos;
}

pub fn deltaEncode(data: []u32) void {
    if (data.len < 2) return;
    var i = data.len - 1;
    while (i > 0) : (i -= 1) {
        data[i] -%= data[i - 1];
    }
}

pub fn deltaDecode(data: []u32) void {
    for (1..data.len) |i| {
        data[i] +%= data[i - 1];
    }
}

pub fn normalizeScores(scores: []u32) void {
    if (scores.len == 0) return;
    var mx: u32 = 0;
    for (scores) |s| { if (s > mx) mx = s; }
    if (mx == 0) return;
    for (scores) |*s| {
        s.* = @intCast(@as(u64, s.*) * 1000 / mx);
    }
}

pub fn medianScore(scores: []const u32) u32 {
    if (scores.len == 0) return 0;
    var sorted: [4096]u32 = undefined;
    const n = @min(scores.len, 4096);
    @memcpy(sorted[0..n], scores[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    return sorted[n / 2];
}

pub fn transpose2D(data: []u32, rows: u32, cols: u32, output: []u32) void {
    for (0..rows) |r| {
        for (0..cols) |c| {
            const src_idx = r * cols + c;
            const dst_idx = c * rows + r;
            if (src_idx < data.len and dst_idx < output.len)
                output[dst_idx] = data[src_idx];
        }
    }
}

pub fn rotate90(data: []u32, n: u32, output: []u32) void {
    for (0..n) |r| {
        for (0..n) |c| {
            const src = r * n + c;
            const dst = c * n + (n - 1 - r);
            if (src < data.len and dst < output.len) output[dst] = data[src];
        }
    }
}

pub fn mirror(data: []u32, cols: u32) void {
    const rows = data.len / @max(cols, 1);
    for (0..rows) |r| {
        var lo: usize = r * cols;
        var hi: usize = lo + cols - 1;
        while (lo < hi and hi < data.len) {
            const tmp = data[lo]; data[lo] = data[hi]; data[hi] = tmp;
            lo += 1; hi -= 1;
        }
    }
}

pub fn histogram_equalize(data: []u32, max_val: u32) void {
    if (data.len == 0 or max_val == 0) return;
    var hist = [_]u32{0} ** 256;
    const m = @min(max_val, 255);
    for (data) |d| { if (d <= m) hist[d] += 1; }
    var cdf: [256]u32 = undefined;
    cdf[0] = hist[0];
    for (1..256) |i| cdf[i] = cdf[i - 1] + hist[i];
    const total = @as(u32, @intCast(data.len));
    for (data) |*d| {
        if (d.* <= m) d.* = cdf[d.*] * m / total;
    }
}

pub fn clampArray(data: []u32, lo: u32, hi: u32) void {
    for (data) |*d| d.* = @max(lo, @min(hi, d.*));
}

pub fn scaleArray(data: []u32, factor_num: u32, factor_den: u32) void {
    if (factor_den == 0) return;
    for (data) |*d| d.* = @as(u32, @intCast(@as(u64, d.*) * factor_num / factor_den));
}

pub fn diffArray(data: []const u32, output: []i32) u32 {
    if (data.len < 2) return 0;
    var count: u32 = 0;
    for (1..data.len) |i| {
        if (count >= output.len) break;
        output[count] = @as(i32, @intCast(data[i])) - @as(i32, @intCast(data[i - 1]));
        count += 1;
    }
    return count;
}

pub fn absArray(data: []i32) void { for (data) |*d| d.* = if (d.* < 0) -d.* else d.*; }
pub fn sumArray(data: []const u32) u64 { var s: u64 = 0; for (data) |d| s += d; return s; }


pub fn maxArray(data: []const u32) u32 { var m: u32 = 0; for (data) |d| { if (d > m) m = d; } return m; }
pub fn minArray(data: []const u32) u32 { var m: u32 = std.math.maxInt(u32); for (data) |d| { if (d < m) m = d; } return m; }
pub fn rangeArray(data: []const u32) u32 { return maxArray(data) -| minArray(data); }

