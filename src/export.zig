const std = @import("std");
const types = @import("types.zig");

pub const ExportFormat = enum { json_like, csv, binary, text };

pub fn exportSymbols(doc: *const types.Document, format: ExportFormat, buf: []u8) usize {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var pos: usize = 0;
    switch (format) {
        .csv => {
            pos += writeStr(buf[pos..], "index,name_idx,attr_idx,class,flags,score\n");
            for (syms, 0..) |*sym, i| {
                pos += writeU32(buf[pos..], @intCast(i));
                pos += writeStr(buf[pos..], ",");
                pos += writeU32(buf[pos..], sym.name_index);
                pos += writeStr(buf[pos..], ",");
                pos += writeU32(buf[pos..], sym.attr_index);
                pos += writeStr(buf[pos..], ",");
                pos += writeU32(buf[pos..], @as(u32, sym.klass));
                pos += writeStr(buf[pos..], ",");
                pos += writeU32(buf[pos..], @as(u32, sym.sym_flags));
                pos += writeStr(buf[pos..], ",");
                pos += writeU32(buf[pos..], sym.derived_score);
                pos += writeStr(buf[pos..], "\n");
            }
        },
        .text => {
            for (syms, 0..) |*sym, i| {
                pos += writeStr(buf[pos..], "sym[");
                pos += writeU32(buf[pos..], @intCast(i));
                pos += writeStr(buf[pos..], "]: name=");
                pos += writeU32(buf[pos..], sym.name_index);
                pos += writeStr(buf[pos..], " score=");
                pos += writeU32(buf[pos..], sym.derived_score);
                pos += writeStr(buf[pos..], "\n");
            }
        },
        else => {},
    }
    return pos;
}

pub fn exportRelocs(doc: *const types.Document, buf: []u8) usize {
    if (doc.relocs.items == null) return 0;
    const relocs = doc.relocs.items.?;
    var pos: usize = 0;
    pos += writeStr(buf[pos..], "section,symbol,target,hash\n");
    for (relocs) |*rel| {
        pos += writeU32(buf[pos..], rel.section_index);
        pos += writeStr(buf[pos..], ",");
        pos += writeU32(buf[pos..], rel.symbol_index);
        pos += writeStr(buf[pos..], ",");
        pos += writeU32(buf[pos..], rel.target);
        pos += writeStr(buf[pos..], ",");
        pos += writeU32(buf[pos..], rel.resolved_hash);
        pos += writeStr(buf[pos..], "\n");
    }
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
