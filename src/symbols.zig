const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");
const strings = @import("strings.zig");

pub fn parseSymbols(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .symbols) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_SYMBOLS) return;

    const items = allocator.alloc(types.Symbol, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 12 <= data.len) {
        const name_idx = std.mem.readInt(u32, data[offset..][0..4], .little);
        const attr_idx = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
        const klass = std.mem.readInt(u16, data[offset + 8 ..][0..2], .little);
        const sym_flags = std.mem.readInt(u16, data[offset + 10 ..][0..2], .little);

        items[parsed] = types.Symbol{
            .name_index = name_idx,
            .attr_index = attr_idx,
            .klass = klass,
            .sym_flags = sym_flags,
            .derived_score = 0,
            .name_ref = strings.lookupString(&doc.*, name_idx),
            .cached_attr = null,
        };

        offset += 12;
        parsed += 1;
    }

    doc.symbols.items = items[0..parsed];
    doc.symbols.count = parsed;
    doc.symbols.capacity = count;

    // Link cached_attr pointers
    if (doc.attrs.items) |attrs| {
        for (items[0..parsed]) |*sym| {
            if (sym.attr_index < attrs.len) {
                sym.cached_attr = &attrs[sym.attr_index];
            }
        }
    }

    // Compute derived scores
    for (items[0..parsed]) |*sym| {
        var score: u32 = sym.klass;
        score = mixU32(score, sym.name_index);
        if (sym.name_ref) |ref| {
            score = mixU32(score, strings.scoreString(ref, sym.name_index));
        }
        if (sym.cached_attr) |attr| {
            score = mixU32(score, attr.value ^ attr.flags);
        }
        sym.derived_score = score;
    }
}

pub fn freeSymbols(allocator: std.mem.Allocator, syms: *types.SymbolTable) void {
    if (syms.items) |items| {
        allocator.free(items);
    }
    syms.items = null;
    syms.count = 0;
}

fn mixU32(a: u32, b: u32) u32 {
    var h = a;
    h ^= b;
    h *%= 0x5bd1e995;
    h ^= h >> 13;
    return h;
}
