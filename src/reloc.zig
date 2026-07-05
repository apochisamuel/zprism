const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");
const directory = @import("directory.zig");

pub fn parseRelocs(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .relocs) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_RELOCS) return;

    const items = allocator.alloc(types.Reloc, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 16 <= data.len) {
        items[parsed] = types.Reloc{
            .section_index = std.mem.readInt(u32, data[offset..][0..4], .little),
            .symbol_index = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little),
            .target = std.mem.readInt(u32, data[offset + 8 ..][0..4], .little),
            .reloc_type = std.mem.readInt(u16, data[offset + 12 ..][0..2], .little),
            .reloc_flags = std.mem.readInt(u16, data[offset + 14 ..][0..2], .little),
            .resolved_hash = 0,
        };
        offset += 16;
        parsed += 1;
    }

    doc.relocs.items = items[0..parsed];
    doc.relocs.count = parsed;
    doc.relocs.capacity = count;
}

/// Apply relocations by resolving symbol indices against source sections.
///
/// Resolve relocation entries against source section symbol data.
pub fn applyRelocations(doc: *types.Document) u32 {
    if (doc.relocs.items == null) return 0;
    const relocs = doc.relocs.items.?;

    var applied: u32 = 0;
    for (relocs) |*rel| {
        const source = directory.validateRelocSource(doc, rel.section_index) orelse continue;
        if (source.data.len < 4) continue;

        // Compute element budget
        var budget: u32 = @intCast((source.data.len - 4) / @sizeOf(types.DiskSymbol));

        if (doc.header.flags & types.FLAG_TYPE_SWEEP != 0) {
            if (doc.directory) |dir| {
                for (dir) |*de| {
                    if (de.offset == source.offset) {
                        if (de.count > 0) {
                            budget = de.count;
                        }
                        break;
                    }
                }
            }
        }

        if (rel.symbol_index >= budget) continue;

        const disk_base = source.data[4..];
        const sym_offset = @as(usize, rel.symbol_index) * @sizeOf(types.DiskSymbol);

        const pick: *const types.DiskSymbol = @ptrCast(@alignCast(disk_base.ptr + sym_offset));
        const h = mixU32(pick.name_index, pick.aux ^ rel.target);
        rel.resolved_hash = h;
        if (h != 0) applied += 1;
    }
    return applied;
}

pub fn freeRelocs(allocator: std.mem.Allocator, relocs: *types.RelocTable) void {
    if (relocs.items) |items| {
        allocator.free(items);
    }
    relocs.items = null;
    relocs.count = 0;
}

fn mixU32(a: u32, b: u32) u32 {
    var h = a;
    h ^= b;
    h *%= 0x5bd1e995;
    h ^= h >> 13;
    h *%= 0x5bd1e995;
    h ^= h >> 15;
    return h;
}
