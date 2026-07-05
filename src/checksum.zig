const std = @import("std");

pub fn fletcher16(data: []const u8) u16 {
    var sum1: u16 = 0; var sum2: u16 = 0;
    for (data) |b| { sum1 = (sum1 + b) % 255; sum2 = (sum2 + sum1) % 255; }
    return (sum2 << 8) | sum1;
}

pub fn fletcher32(data: []const u8) u32 {
    var sum1: u32 = 0; var sum2: u32 = 0;
    for (data) |b| { sum1 = (sum1 + b) % 65535; sum2 = (sum2 + sum1) % 65535; }
    return (sum2 << 16) | sum1;
}

pub fn internet_checksum(data: []const u8) u16 {
    var sum: u32 = 0;
    var i: usize = 0;
    while (i + 1 < data.len) : (i += 2) {
        sum += @as(u32, data[i]) << 8 | @as(u32, data[i + 1]);
    }
    if (i < data.len) sum += @as(u32, data[i]) << 8;
    while (sum >> 16 != 0) sum = (sum & 0xffff) + (sum >> 16);
    return @truncate(~sum);
}

pub fn luhn(digits: []const u8) bool {
    if (digits.len == 0) return false;
    var sum: u32 = 0;
    var double_next = false;
    var i = digits.len;
    while (i > 0) {
        i -= 1;
        var d: u32 = if (digits[i] >= '0' and digits[i] <= '9') digits[i] - '0' else return false;
        if (double_next) { d *= 2; if (d > 9) d -= 9; }
        sum += d;
        double_next = !double_next;
    }
    return sum % 10 == 0;
}

pub fn verhoeff(digits: []const u8) bool {
    const d_table = [10][10]u8{
        .{0,1,2,3,4,5,6,7,8,9}, .{1,2,3,4,0,6,7,8,9,5},
        .{2,3,4,0,1,7,8,9,5,6}, .{3,4,0,1,2,8,9,5,6,7},
        .{4,0,1,2,3,9,5,6,7,8}, .{5,9,8,7,6,0,4,3,2,1},
        .{6,5,9,8,7,1,0,4,3,2}, .{7,6,5,9,8,2,1,0,4,3},
        .{8,7,6,5,9,3,2,1,0,4}, .{9,8,7,6,5,4,3,2,1,0},
    };
    const p_table = [8][10]u8{
        .{0,1,2,3,4,5,6,7,8,9}, .{1,5,7,6,2,8,3,0,9,4},
        .{5,8,0,3,7,9,6,1,4,2}, .{8,9,1,6,0,4,3,5,2,7},
        .{9,4,5,3,1,2,6,8,7,0}, .{4,2,8,6,5,7,3,9,0,1},
        .{2,7,9,3,8,0,6,4,1,5}, .{7,0,4,6,9,1,3,2,5,8},
    };
    var c: u8 = 0;
    for (0..digits.len) |i| {
        const idx = digits.len - 1 - i;
        const d: u8 = if (digits[idx] >= '0' and digits[idx] <= '9') digits[idx] - '0' else return false;
        c = d_table[c][p_table[(i + 1) % 8][d]];
    }
    return c == 0;
}

pub fn damm(digits: []const u8) bool {
    const table = [10][10]u8{
        .{0,3,1,7,5,9,8,6,4,2}, .{7,0,9,2,1,5,4,8,6,3},
        .{4,2,0,6,8,7,1,3,5,9}, .{1,7,5,0,9,8,3,4,2,6},
        .{6,1,2,3,0,4,5,9,7,8}, .{3,6,7,4,2,0,9,5,8,1},
        .{5,8,6,9,7,2,0,1,3,4}, .{8,9,4,5,3,6,2,0,1,7},
        .{9,4,3,8,6,1,7,2,0,5}, .{2,5,8,1,4,3,6,7,9,0},
    };
    var interim: u8 = 0;
    for (digits) |ch| {
        const d: u8 = if (ch >= '0' and ch <= '9') ch - '0' else return false;
        interim = table[interim][d];
    }
    return interim == 0;
}

pub fn isbn10(digits: []const u8) bool {
    if (digits.len != 10) return false;
    var sum: u32 = 0;
    for (0..10) |i| {
        const d: u32 = if (digits[i] >= '0' and digits[i] <= '9') digits[i] - '0'
            else if (i == 9 and digits[i] == 'X') 10
            else return false;
        sum += d * @as(u32, @intCast(10 - i));
    }
    return sum % 11 == 0;
}

pub fn isbn13(digits: []const u8) bool {
    if (digits.len != 13) return false;
    var sum: u32 = 0;
    for (0..13) |i| {
        const d: u32 = if (digits[i] >= '0' and digits[i] <= '9') digits[i] - '0' else return false;
        sum += if (i % 2 == 0) d else d * 3;
    }
    return sum % 10 == 0;
}

pub fn xorChecksum(data: []const u8) u8 {
    var cs: u8 = 0;
    for (data) |b| cs ^= b;
    return cs;
}

pub fn twoComplement(data: []const u8) u8 {
    var sum: u16 = 0;
    for (data) |b| sum +%= b;
    return @truncate((~sum +% 1));
}
