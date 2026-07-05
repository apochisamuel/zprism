const std = @import("std");

pub const CompressResult = struct { output_size: u32, ratio: f64, method: Method };
pub const Method = enum { none, rle, lz_simple, delta, huffman_approx };

pub fn compressRLE(input: []const u8, output: []u8) u32 {
    if (input.len == 0) return 0;
    var ipos: usize = 0;
    var opos: u32 = 0;
    while (ipos < input.len) {
        const b = input[ipos];
        var run: u32 = 1;
        while (ipos + run < input.len and input[ipos + run] == b and run < 255) run += 1;
        if (opos + 2 > output.len) break;
        output[opos] = @intCast(run);
        output[opos + 1] = b;
        opos += 2;
        ipos += run;
    }
    return opos;
}

pub fn decompressRLE(input: []const u8, output: []u8) u32 {
    var ipos: usize = 0;
    var opos: u32 = 0;
    while (ipos + 1 < input.len) {
        const run = input[ipos];
        const val = input[ipos + 1];
        ipos += 2;
        var i: u32 = 0;
        while (i < run and opos < output.len) : (i += 1) {
            output[opos] = val;
            opos += 1;
        }
    }
    return opos;
}

pub fn compressLZSimple(input: []const u8, output: []u8) u32 {
    if (input.len == 0) return 0;
    var ipos: usize = 0;
    var opos: u32 = 0;
    while (ipos < input.len) {
        var best_offset: u32 = 0;
        var best_length: u32 = 0;
        const window_start = if (ipos > 4096) ipos - 4096 else 0;
        var search: usize = window_start;
        while (search < ipos) : (search += 1) {
            var match_len: u32 = 0;
            while (ipos + match_len < input.len and search + match_len < ipos and
                input[search + match_len] == input[ipos + match_len] and match_len < 255)
            {
                match_len += 1;
            }
            if (match_len > best_length) {
                best_length = match_len;
                best_offset = @intCast(ipos - search);
            }
        }
        if (best_length >= 3 and opos + 3 <= output.len) {
            output[opos] = 0xFF;
            output[opos + 1] = @intCast(best_offset & 0xFF);
            output[opos + 2] = @intCast(best_length);
            opos += 3;
            ipos += best_length;
        } else {
            if (opos + 1 > output.len) break;
            output[opos] = input[ipos];
            opos += 1;
            ipos += 1;
        }
    }
    return opos;
}

pub fn decompressLZSimple(input: []const u8, output: []u8) u32 {
    var ipos: usize = 0;
    var opos: u32 = 0;
    while (ipos < input.len) {
        if (input[ipos] == 0xFF and ipos + 2 < input.len) {
            const offset = input[ipos + 1];
            const length = input[ipos + 2];
            ipos += 3;
            if (offset <= opos) {
                var src = opos - offset;
                var i: u32 = 0;
                while (i < length and opos < output.len) : (i += 1) {
                    output[opos] = output[src];
                    opos += 1;
                    src += 1;
                }
            }
        } else {
            if (opos >= output.len) break;
            output[opos] = input[ipos];
            opos += 1;
            ipos += 1;
        }
    }
    return opos;
}

pub fn compressDelta(input: []const u8, output: []u8) u32 {
    if (input.len == 0) return 0;
    if (output.len == 0) return 0;
    output[0] = input[0];
    var opos: u32 = 1;
    for (1..input.len) |i| {
        if (opos >= output.len) break;
        output[opos] = input[i] -% input[i - 1];
        opos += 1;
    }
    return opos;
}

pub fn decompressDelta(input: []const u8, output: []u8) u32 {
    if (input.len == 0) return 0;
    if (output.len == 0) return 0;
    output[0] = input[0];
    var opos: u32 = 1;
    for (1..input.len) |i| {
        if (opos >= output.len) break;
        output[opos] = input[i] +% output[opos - 1];
        opos += 1;
    }
    return opos;
}

pub fn estimateCompressibility(data: []const u8) f64 {
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
    return 1.0 - entropy / 8.0;
}

pub fn selectBestMethod(data: []const u8) Method {
    if (data.len < 8) return .none;
    var run_score: u32 = 0;
    var delta_score: u32 = 0;
    for (1..data.len) |i| {
        if (data[i] == data[i - 1]) run_score += 1;
        const diff = if (data[i] > data[i - 1]) data[i] - data[i - 1] else data[i - 1] - data[i];
        if (diff < 4) delta_score += 1;
    }
    if (run_score > data.len / 2) return .rle;
    if (delta_score > data.len * 3 / 4) return .delta;
    if (data.len > 64) return .lz_simple;
    return .none;
}

pub fn autoCompress(input: []const u8, output: []u8) CompressResult {
    const method = selectBestMethod(input);
    const size = switch (method) {
        .rle => compressRLE(input, output),
        .lz_simple => compressLZSimple(input, output),
        .delta => compressDelta(input, output),
        else => blk: {
            const n = @min(input.len, output.len);
            @memcpy(output[0..n], input[0..n]);
            break :blk @as(u32, @intCast(n));
        },
    };
    return CompressResult{
        .output_size = size,
        .ratio = if (input.len > 0) @as(f64, @floatFromInt(size)) / @as(f64, @floatFromInt(input.len)) else 1.0,
        .method = method,
    };
}
