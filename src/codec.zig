const std = @import("std");

pub const CodecType = enum { identity, xor, rotate, caesar, vigenere, substitution };

pub fn encode(data: []u8, codec: CodecType, key: u32) void {
    switch (codec) {
        .identity => {},
        .xor => xorEncode(data, key),
        .rotate => rotateEncode(data, key),
        .caesar => caesarEncode(data, key),
        .vigenere => vigenereEncode(data, key),
        .substitution => substitutionEncode(data, key),
    }
}

pub fn decode(data: []u8, codec: CodecType, key: u32) void {
    switch (codec) {
        .identity => {},
        .xor => xorEncode(data, key),
        .rotate => rotateDecode(data, key),
        .caesar => caesarDecode(data, key),
        .vigenere => vigenereDecode(data, key),
        .substitution => substitutionDecode(data, key),
    }
}

fn xorEncode(data: []u8, key: u32) void {
    var k = key;
    for (data) |*b| {
        b.* ^= @as(u8, @truncate(k));
        k = k *% 1103515245 +% 12345;
    }
}

fn rotateEncode(data: []u8, key: u32) void {
    const shift: u3 = @intCast(key % 8);
    for (data) |*b| b.* = std.math.rotl(u8, b.*, shift);
}

fn rotateDecode(data: []u8, key: u32) void {
    const shift: u3 = @intCast(key % 8);
    for (data) |*b| b.* = std.math.rotr(u8, b.*, shift);
}

fn caesarEncode(data: []u8, key: u32) void {
    const shift: u8 = @intCast(key % 26);
    for (data) |*b| {
        if (b.* >= 'A' and b.* <= 'Z') b.* = 'A' + (b.* - 'A' + shift) % 26
        else if (b.* >= 'a' and b.* <= 'z') b.* = 'a' + (b.* - 'a' + shift) % 26;
    }
}

fn caesarDecode(data: []u8, key: u32) void {
    caesarEncode(data, 26 - (key % 26));
}

fn vigenereEncode(data: []u8, key: u32) void {
    var k = key;
    for (data) |*b| {
        const shift: u8 = @intCast(k % 256);
        b.* +%= shift;
        k = k *% 6364136223846793005 +% 1;
    }
}

fn vigenereDecode(data: []u8, key: u32) void {
    var k = key;
    for (data) |*b| {
        const shift: u8 = @intCast(k % 256);
        b.* -%= shift;
        k = k *% 6364136223846793005 +% 1;
    }
}

fn substitutionEncode(data: []u8, key: u32) void {
    var table: [256]u8 = undefined;
    buildSubstitutionTable(&table, key);
    for (data) |*b| b.* = table[b.*];
}

fn substitutionDecode(data: []u8, key: u32) void {
    var table: [256]u8 = undefined;
    var inverse: [256]u8 = undefined;
    buildSubstitutionTable(&table, key);
    for (0..256) |i| inverse[table[i]] = @intCast(i);
    for (data) |*b| b.* = inverse[b.*];
}

fn buildSubstitutionTable(table: *[256]u8, key: u32) void {
    for (0..256) |i| table[i] = @intCast(i);
    var rng = key;
    var i: usize = 255;
    while (i > 0) : (i -= 1) {
        rng = rng *% 1103515245 +% 12345;
        const j = rng % @as(u32, @intCast(i + 1));
        const tmp = table[i]; table[i] = table[j]; table[j] = tmp;
    }
}

pub fn frequencyAnalysis(data: []const u8, freq: *[256]u32) void {
    for (freq) |*f| f.* = 0;
    for (data) |b| freq[b] += 1;
}

pub fn indexOfCoincidence(data: []const u8) f64 {
    var freq: [256]u32 = undefined;
    frequencyAnalysis(data, &freq);
    const n = @as(f64, @floatFromInt(data.len));
    if (n < 2) return 0;
    var sum: f64 = 0;
    for (freq) |f| {
        const fi = @as(f64, @floatFromInt(f));
        sum += fi * (fi - 1.0);
    }
    return sum / (n * (n - 1.0));
}

pub fn estimateKeyLength(data: []const u8, max_len: u32) u32 {
    var best_len: u32 = 1;
    var best_ic: f64 = 0;
    for (1..@min(max_len + 1, data.len / 2)) |kl| {
        var total_ic: f64 = 0;
        for (0..kl) |offset| {
            var stream: [4096]u8 = undefined;
            var sc: u32 = 0;
            var i = offset;
            while (i < data.len and sc < 4096) : (i += kl) {
                stream[sc] = data[i]; sc += 1;
            }
            total_ic += indexOfCoincidence(stream[0..sc]);
        }
        total_ic /= @as(f64, @floatFromInt(kl));
        if (total_ic > best_ic) { best_ic = total_ic; best_len = @intCast(kl); }
    }
    return best_len;
}

pub fn hammingDistance(a: []const u8, b: []const u8) u32 {
    var dist: u32 = 0;
    const n = @min(a.len, b.len);
    for (0..n) |i| dist += @popCount(a[i] ^ b[i]);
    return dist;
}

pub fn normalizedHamming(a: []const u8, b: []const u8) f64 {
    const n = @min(a.len, b.len);
    if (n == 0) return 0;
    return @as(f64, @floatFromInt(hammingDistance(a, b))) / @as(f64, @floatFromInt(n));
}

pub fn detectEncoding(data: []const u8) CodecType {
    const ic = indexOfCoincidence(data);
    if (ic > 0.06) return .caesar;
    if (ic > 0.04) return .vigenere;
    var freq: [256]u32 = undefined;
    frequencyAnalysis(data, &freq);
    var max_freq: u32 = 0;
    for (freq) |f| { if (f > max_freq) max_freq = f; }
    if (data.len > 0 and max_freq * 4 > data.len) return .substitution;
    return .xor;
}
