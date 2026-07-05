const std = @import("std");

pub fn base64Encode(input: []const u8, output: []u8) u32 {
    const table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var pos: u32 = 0;
    var i: usize = 0;
    while (i + 2 < input.len) {
        if (pos + 4 > output.len) break;
        const a = input[i]; const b = input[i + 1]; const c = input[i + 2];
        output[pos] = table[@as(usize, a >> 2)];
        output[pos + 1] = table[@as(usize, ((a & 3) << 4) | (b >> 4))];
        output[pos + 2] = table[@as(usize, ((b & 0xf) << 2) | (c >> 6))];
        output[pos + 3] = table[@as(usize, c & 0x3f)];
        pos += 4; i += 3;
    }
    if (i < input.len and pos + 4 <= output.len) {
        const a = input[i];
        output[pos] = table[@as(usize, a >> 2)];
        if (i + 1 < input.len) {
            const b = input[i + 1];
            output[pos + 1] = table[@as(usize, ((a & 3) << 4) | (b >> 4))];
            output[pos + 2] = table[@as(usize, (b & 0xf) << 2)];
        } else {
            output[pos + 1] = table[@as(usize, (a & 3) << 4)];
            output[pos + 2] = '=';
        }
        output[pos + 3] = '=';
        pos += 4;
    }
    return pos;
}

pub fn base64Decode(input: []const u8, output: []u8) u32 {
    var pos: u32 = 0;
    var i: usize = 0;
    while (i + 3 < input.len) {
        if (pos + 3 > output.len) break;
        const a = decodeChar(input[i]);
        const b = decodeChar(input[i + 1]);
        const c = decodeChar(input[i + 2]);
        const d = decodeChar(input[i + 3]);
        if (a >= 64 or b >= 64) break;
        output[pos] = (a << 2) | (b >> 4);
        pos += 1;
        if (c < 64) {
            output[pos] = ((b & 0xf) << 4) | (c >> 2);
            pos += 1;
            if (d < 64) {
                output[pos] = ((c & 3) << 6) | d;
                pos += 1;
            }
        }
        i += 4;
    }
    return pos;
}

fn decodeChar(c: u8) u8 {
    if (c >= 'A' and c <= 'Z') return c - 'A';
    if (c >= 'a' and c <= 'z') return c - 'a' + 26;
    if (c >= '0' and c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return 64;
}

pub fn hexEncode(input: []const u8, output: []u8) u32 {
    const hex = "0123456789abcdef";
    var pos: u32 = 0;
    for (input) |b| {
        if (pos + 2 > output.len) break;
        output[pos] = hex[b >> 4];
        output[pos + 1] = hex[b & 0x0f];
        pos += 2;
    }
    return pos;
}

pub fn hexDecode(input: []const u8, output: []u8) u32 {
    var pos: u32 = 0;
    var i: usize = 0;
    while (i + 1 < input.len and pos < output.len) {
        const hi = hexVal(input[i]);
        const lo = hexVal(input[i + 1]);
        if (hi >= 16 or lo >= 16) break;
        output[pos] = (hi << 4) | lo;
        pos += 1; i += 2;
    }
    return pos;
}

fn hexVal(c: u8) u8 {
    if (c >= '0' and c <= '9') return c - '0';
    if (c >= 'a' and c <= 'f') return c - 'a' + 10;
    if (c >= 'A' and c <= 'F') return c - 'A' + 10;
    return 16;
}

pub fn varintEncode(value: u64, output: []u8) u32 {
    var v = value;
    var pos: u32 = 0;
    while (v >= 0x80 and pos < output.len) {
        output[pos] = @as(u8, @truncate(v)) | 0x80;
        v >>= 7; pos += 1;
    }
    if (pos < output.len) { output[pos] = @truncate(v); pos += 1; }
    return pos;
}

pub fn varintDecode(input: []const u8) struct { value: u64, bytes: u32 } {
    var result: u64 = 0;
    var shift: u6 = 0;
    var i: u32 = 0;
    while (i < input.len and i < 10) {
        result |= @as(u64, input[i] & 0x7f) << shift;
        i += 1;
        if (input[i - 1] & 0x80 == 0) break;
        shift += 7;
    }
    return .{ .value = result, .bytes = i };
}

pub fn zigzagEncode(value: i64) u64 {
    return @bitCast((value << 1) ^ (value >> 63));
}

pub fn zigzagDecode(value: u64) i64 {
    return @as(i64, @bitCast(value >> 1)) ^ -@as(i64, @bitCast(value & 1));
}
