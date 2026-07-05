const std = @import("std");

pub const BitReader = struct {
    data: []const u8,
    byte_pos: usize,
    bit_pos: u3,
    
    pub fn init(data: []const u8) BitReader {
        return BitReader{ .data = data, .byte_pos = 0, .bit_pos = 0 };
    }
    
    pub fn readBit(self: *BitReader) ?u1 {
        if (self.byte_pos >= self.data.len) return null;
        const bit: u1 = @truncate((self.data[self.byte_pos] >> (7 - @as(u3, self.bit_pos))) & 1);
        if (self.bit_pos == 7) { self.byte_pos += 1; self.bit_pos = 0; }
        else { self.bit_pos += 1; }
        return bit;
    }
    
    pub fn readBits(self: *BitReader, count: u5) ?u32 {
        var result: u32 = 0;
        for (0..count) |_| {
            const bit = self.readBit() orelse return null;
            result = (result << 1) | @as(u32, bit);
        }
        return result;
    }
    
    pub fn readByte(self: *BitReader) ?u8 {
        return @truncate(self.readBits(8) orelse return null);
    }
    
    pub fn readU16(self: *BitReader) ?u16 {
        return @truncate(self.readBits(16) orelse return null);
    }
    
    pub fn remaining(self: *const BitReader) usize {
        if (self.byte_pos >= self.data.len) return 0;
        return (self.data.len - self.byte_pos) * 8 - self.bit_pos;
    }
    
    pub fn skip(self: *BitReader, bits: u32) void {
        var b = bits;
        while (b > 0 and self.byte_pos < self.data.len) {
            if (b >= 8 and self.bit_pos == 0) { self.byte_pos += 1; b -= 8; }
            else { _ = self.readBit(); b -= 1; }
        }
    }
    
    pub fn align_to_byte(self: *BitReader) void {
        if (self.bit_pos != 0) { self.byte_pos += 1; self.bit_pos = 0; }
    }
};

pub const BitWriter = struct {
    data: []u8,
    byte_pos: usize,
    bit_pos: u3,
    
    pub fn init(data: []u8) BitWriter {
        @memset(data, 0);
        return BitWriter{ .data = data, .byte_pos = 0, .bit_pos = 0 };
    }
    
    pub fn writeBit(self: *BitWriter, bit: u1) bool {
        if (self.byte_pos >= self.data.len) return false;
        self.data[self.byte_pos] |= @as(u8, bit) << (7 - @as(u3, self.bit_pos));
        if (self.bit_pos == 7) { self.byte_pos += 1; self.bit_pos = 0; }
        else { self.bit_pos += 1; }
        return true;
    }
    
    pub fn writeBits(self: *BitWriter, value: u32, count: u5) bool {
        var i: u5 = count;
        while (i > 0) {
            i -= 1;
            if (!self.writeBit(@truncate((value >> i) & 1))) return false;
        }
        return true;
    }
    
    pub fn writeByte(self: *BitWriter, value: u8) bool {
        return self.writeBits(@as(u32, value), 8);
    }
    
    pub fn written_bits(self: *const BitWriter) usize {
        return self.byte_pos * 8 + self.bit_pos;
    }
    
    pub fn written_bytes(self: *const BitWriter) usize {
        return if (self.bit_pos > 0) self.byte_pos + 1 else self.byte_pos;
    }
};

pub fn huffmanFrequencies(data: []const u8, freq: *[256]u32) void {
    for (freq) |*f| f.* = 0;
    for (data) |b| freq[b] += 1;
}

pub fn estimateHuffmanSize(freq: *const [256]u32, total: u32) u32 {
    if (total == 0) return 0;
    var sorted_freq: [256]u32 = freq.*;
    std.sort.insertion(u32, &sorted_freq, {}, std.sort.desc(u32));
    var bits: u64 = 0;
    var code_len: u32 = 1;
    for (sorted_freq) |f| {
        if (f == 0) break;
        bits += @as(u64, f) * code_len;
        if (code_len < 16) code_len += 1;
    }
    return @intCast((bits + 7) / 8);
}

pub fn computeBitEntropy(data: []const u8) f64 {
    var ones: u64 = 0;
    const total: u64 = @as(u64, data.len) * 8;
    for (data) |b| ones += @popCount(b);
    if (total == 0) return 0;
    const p1 = @as(f64, @floatFromInt(ones)) / @as(f64, @floatFromInt(total));
    const p0 = 1.0 - p1;
    if (p0 <= 0 or p1 <= 0) return 0;
    return -(p0 * @log2(p0) + p1 * @log2(p1));
}
