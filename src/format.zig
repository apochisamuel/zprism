const std = @import("std");
const types = @import("types.zig");

pub fn formatHeader(header: *const types.Header, buf: []u8) usize {
    var pos: usize = 0;
    pos += writeStr(buf[pos..], "PRISM v");
    pos += writeU32(buf[pos..], @as(u32, header.version));
    pos += writeStr(buf[pos..], " flags=0x");
    pos += writeHex(buf[pos..], header.flags);
    pos += writeStr(buf[pos..], " sections=");
    pos += writeU32(buf[pos..], @as(u32, header.section_count));
    pos += writeStr(buf[pos..], " dir=");
    pos += writeU32(buf[pos..], @as(u32, header.directory_count));
    return pos;
}

pub fn formatSectionType(st: types.SectionType) []const u8 {
    return switch (st) {
        .invalid => "invalid", .strings => "strings", .symbols => "symbols",
        .attrs => "attrs", .relocs => "relocs", .events => "events",
        .keyframes => "keyframes", .streams => "streams", .aliases => "aliases",
        .directory => "directory", _ => "unknown",
    };
}

pub fn formatDocSummary(doc: *const types.Document, buf: []u8) usize {
    var pos: usize = 0;
    pos += writeStr(buf[pos..], "Document: ");
    pos += writeU32(buf[pos..], doc.symbols.count);
    pos += writeStr(buf[pos..], " symbols, ");
    pos += writeU32(buf[pos..], doc.strings.count);
    pos += writeStr(buf[pos..], " strings, ");
    pos += writeU32(buf[pos..], doc.attrs.count);
    pos += writeStr(buf[pos..], " attrs, ");
    pos += writeU32(buf[pos..], doc.relocs.count);
    pos += writeStr(buf[pos..], " relocs, ");
    pos += writeU32(buf[pos..], doc.events.count);
    pos += writeStr(buf[pos..], " events");
    return pos;
}

fn writeStr(buf: []u8, s: []const u8) usize {
    const n = @min(s.len, buf.len);
    @memcpy(buf[0..n], s[0..n]);
    return n;
}

fn writeU32(buf: []u8, val: u32) usize {
    var v = val;
    var digits: [10]u8 = undefined;
    var len: usize = 0;
    if (v == 0) { if (buf.len > 0) { buf[0] = '0'; return 1; } return 0; }
    while (v > 0) : (len += 1) { digits[len] = @intCast(v % 10 + '0'); v /= 10; }
    const n = @min(len, buf.len);
    for (0..n) |i| buf[i] = digits[len - 1 - i];
    return n;
}

fn writeHex(buf: []u8, val: u32) usize {
    const hex = "0123456789abcdef";
    var v = val;
    var digits: [8]u8 = undefined;
    var len: usize = 0;
    if (v == 0) { if (buf.len > 0) { buf[0] = '0'; return 1; } return 0; }
    while (v > 0) : (len += 1) { digits[len] = hex[@intCast(v & 0xf)]; v >>= 4; }
    const n = @min(len, buf.len);
    for (0..n) |i| buf[i] = digits[len - 1 - i];
    return n;
}

pub fn hexDump(data: []const u8, output: []u8) usize {
    const hex = "0123456789abcdef";
    var pos: usize = 0;
    for (data) |b| {
        if (pos + 3 > output.len) break;
        output[pos] = hex[b >> 4]; pos += 1;
        output[pos] = hex[b & 0x0f]; pos += 1;
        output[pos] = ' '; pos += 1;
    }
    return pos;
}
