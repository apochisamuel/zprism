const std = @import("std");

pub fn fnv1a32(data: []const u8) u32 {
    var h: u32 = 0x811c9dc5;
    for (data) |b| { h ^= @as(u32, b); h *%= 0x01000193; }
    return h;
}

pub fn fnv1a64(data: []const u8) u64 {
    var h: u64 = 0xcbf29ce484222325;
    for (data) |b| { h ^= @as(u64, b); h *%= 0x100000001b3; }
    return h;
}

pub fn murmur3_32(data: []const u8, seed: u32) u32 {
    var h: u32 = seed;
    const nblocks = data.len / 4;
    for (0..nblocks) |i| {
        var k: u32 = @as(u32, data[i * 4]) | (@as(u32, data[i * 4 + 1]) << 8) |
            (@as(u32, data[i * 4 + 2]) << 16) | (@as(u32, data[i * 4 + 3]) << 24);
        k *%= 0xcc9e2d51; k = std.math.rotl(u32, k, 15); k *%= 0x1b873593;
        h ^= k; h = std.math.rotl(u32, h, 13); h = h *% 5 +% 0xe6546b64;
    }
    var tail: u32 = 0;
    const tail_start = nblocks * 4;
    if (data.len - tail_start >= 3) tail ^= @as(u32, data[tail_start + 2]) << 16;
    if (data.len - tail_start >= 2) tail ^= @as(u32, data[tail_start + 1]) << 8;
    if (data.len - tail_start >= 1) {
        tail ^= @as(u32, data[tail_start]);
        tail *%= 0xcc9e2d51; tail = std.math.rotl(u32, tail, 15); tail *%= 0x1b873593;
        h ^= tail;
    }
    h ^= @as(u32, @intCast(data.len));
    h ^= h >> 16; h *%= 0x85ebca6b; h ^= h >> 13; h *%= 0xc2b2ae35; h ^= h >> 16;
    return h;
}

pub fn xxhash32(data: []const u8, seed: u32) u32 {
    const p1: u32 = 0x9E3779B1; const p2: u32 = 0x85EBCA77;
    const p3: u32 = 0xC2B2AE3D; const p4: u32 = 0x27D4EB2F; const p5: u32 = 0x165667B1;
    var h: u32 = seed +% p5 +% @as(u32, @intCast(data.len));
    var i: usize = 0;
    while (i + 4 <= data.len) : (i += 4) {
        var k: u32 = @as(u32, data[i]) | (@as(u32, data[i + 1]) << 8) |
            (@as(u32, data[i + 2]) << 16) | (@as(u32, data[i + 3]) << 24);
        k *%= p3; h +%= k; h = std.math.rotl(u32, h, 17) *% p4;
    }
    while (i < data.len) : (i += 1) {
        h +%= @as(u32, data[i]) *% p5;
        h = std.math.rotl(u32, h, 11) *% p1;
    }
    h ^= h >> 15; h *%= p2; h ^= h >> 13; h *%= p3; h ^= h >> 16;
    return h;
}

pub fn crc32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;
    for (data) |b| {
        crc ^= @as(u32, b);
        for (0..8) |_| {
            if (crc & 1 != 0) crc = (crc >> 1) ^ 0xEDB88320 else crc >>= 1;
        }
    }
    return ~crc;
}

pub fn adler32(data: []const u8) u32 {
    var a: u32 = 1; var b: u32 = 0;
    for (data) |byte| {
        a = (a + byte) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}

pub fn djb2(data: []const u8) u32 {
    var h: u32 = 5381;
    for (data) |b| h = ((h << 5) +% h) +% @as(u32, b);
    return h;
}

pub fn sdbm(data: []const u8) u32 {
    var h: u32 = 0;
    for (data) |b| h = @as(u32, b) +% (h << 6) +% (h << 16) -% h;
    return h;
}

pub fn pearsonHash(data: []const u8) u8 {
    const table = [256]u8{
        98,6,85,150,36,23,112,164,135,207,169,5,26,64,165,219,
        61,20,68,89,130,63,52,102,24,229,132,245,80,216,195,115,
        90,168,156,203,177,120,2,190,188,7,100,185,174,243,162,10,
        237,18,253,225,8,208,172,244,255,126,101,79,145,235,228,121,
        123,251,67,250,161,0,107,97,241,111,181,82,249,33,69,55,
        59,153,29,9,213,167,84,93,30,46,94,75,151,114,73,222,
        197,96,210,45,16,227,248,202,51,152,252,125,81,206,215,186,
        39,158,178,187,131,136,1,49,50,17,141,91,47,129,60,99,
        154,35,86,171,105,34,38,200,147,58,77,118,173,246,76,254,
        133,232,196,144,198,124,53,4,108,74,223,234,134,230,157,139,
        189,205,199,128,176,19,211,236,127,192,231,70,233,88,146,44,
        183,201,22,83,13,214,116,109,159,32,95,226,140,220,57,12,
        221,31,209,182,143,92,149,184,148,62,113,65,37,27,106,166,
        3,14,204,72,21,41,56,66,28,193,40,217,25,54,179,117,
        238,87,240,155,180,170,242,212,191,163,78,218,137,194,175,110,
        43,119,224,71,122,142,42,160,104,48,247,103,15,11,138,239,
    };
    var h: u8 = 0;
    for (data) |b| h = table[h ^ b];
    return h;
}

pub fn bloomFilterInsert(filter: []u8, data: []const u8) void {
    const h1 = fnv1a32(data);
    const h2 = murmur3_32(data, 0x12345);
    const bits = @as(u32, @intCast(filter.len)) * 8;
    if (bits == 0) return;
    for (0..4) |i| {
        const bit = (h1 +% @as(u32, @intCast(i)) *% h2) % bits;
        filter[bit / 8] |= @as(u8, 1) << @intCast(bit % 8);
    }
}

pub fn bloomFilterCheck(filter: []const u8, data: []const u8) bool {
    const h1 = fnv1a32(data);
    const h2 = murmur3_32(data, 0x12345);
    const bits = @as(u32, @intCast(filter.len)) * 8;
    if (bits == 0) return false;
    for (0..4) |i| {
        const bit = (h1 +% @as(u32, @intCast(i)) *% h2) % bits;
        if (filter[bit / 8] & (@as(u8, 1) << @intCast(bit % 8)) == 0) return false;
    }
    return true;
}
