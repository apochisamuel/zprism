const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");

pub fn parseAttrs(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .attrs) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_ATTRS) return;

    const items = allocator.alloc(types.Attr, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 12 <= data.len) {
        items[parsed] = types.Attr{
            .value = std.mem.readInt(u32, data[offset..][0..4], .little),
            .flags = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little),
            .tag = std.mem.readInt(u16, data[offset + 8 ..][0..2], .little),
            .reserved = std.mem.readInt(u16, data[offset + 10 ..][0..2], .little),
        };
        offset += 12;
        parsed += 1;
    }

    doc.attrs.items = items[0..parsed];
    doc.attrs.count = parsed;
    doc.attrs.capacity = count;
    doc.attrs.rolled_back = false;
}

pub fn rollbackAttrTable(doc: *types.Document) void {
    if (doc.attrs.items == null) return;
    const items = doc.attrs.items.?;
    doc.allocator.free(items);
    doc.attrs.rolled_back = true;
}

pub fn freeAttrs(allocator: std.mem.Allocator, attrs: *types.AttrTable) void {
    if (attrs.items) |items| {
        if (!attrs.rolled_back) {
            allocator.free(items);
        }
    }
    attrs.items = null;
    attrs.count = 0;
}

pub fn attrStats(doc: *const types.Document) [4]u32 {
    if (doc.attrs.items == null) return [_]u32{0} ** 4;
    const items = doc.attrs.items.?;
    var min_v: u32 = std.math.maxInt(u32);
    var max_v: u32 = 0;
    var sum: u64 = 0;
    var unique_flags: u32 = 0;
    var seen = [_]bool{false} ** 256;
    for (items) |*a| {
        if (a.value < min_v) min_v = a.value;
        if (a.value > max_v) max_v = a.value;
        sum += a.value;
        const fb: u8 = @truncate(a.flags);
        if (!seen[fb]) { seen[fb] = true; unique_flags += 1; }
    }
    return .{ min_v, max_v, @intCast(sum / @max(items.len, 1)), unique_flags };
}

pub fn attrHash(doc: *const types.Document) u32 { if (doc.attrs.items == null) return 0; var h: u32 = 0; for (doc.attrs.items.?) |*a| { h ^= a.value; h *%= 0x5bd1e995; h ^= a.flags; h ^= h >> 13; } return h; }

// EOF
