const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");

pub fn loadStrings(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .strings) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_STRINGS) return;

    const items = allocator.alloc(types.PrismString, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 8 <= data.len) {
        const length = std.mem.readInt(u32, data[offset..][0..4], .little);
        const hash = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
        offset += 8;

        const str_data: ?[]const u8 = if (length > 0 and offset + length <= data.len)
            data[offset .. offset + length]
        else
            null;

        items[parsed] = types.PrismString{
            .data = str_data,
            .length = length,
            .hash = hash,
            .arena_offset = @intCast(offset),
            .owned = false,
        };

        if (length > 0) offset += length;
        parsed += 1;
    }

    doc.strings.items = items[0..parsed];
    doc.strings.count = parsed;
    doc.strings.capacity = count;
    doc.strings.rolled_back = false;
    doc.strings.generation = 0;

    doc.cache.primary_strings = &doc.strings;
    doc.cache.string_gen_snap = doc.strings.generation;
}

pub fn lookupString(doc: *const types.Document, index: u32) ?[]const u8 {
    if (doc.strings.items == null or doc.strings.rolled_back) return null;
    const items = doc.strings.items.?;
    if (index >= items.len) return null;
    return items[index].data;
}

pub fn rollbackStringTable(doc: *types.Document) void {
    if (doc.strings.items == null) return;
    const items = doc.strings.items.?;
    for (items) |*s| {
        if (s.owned) {
            if (s.data) |d| {
                // Free owned string data via allocator
                const ptr: [*]u8 = @constCast(d.ptr);
                doc.allocator.free(ptr[0..d.len]);
            }
        }
        s.data = null;
    }
    doc.allocator.free(items);
    doc.strings.rolled_back = true;
    doc.strings.generation += 1;
}

pub fn freeStrings(allocator: std.mem.Allocator, strings: *types.StringTable) void {
    if (strings.items) |items| {
        for (items) |*s| {
            if (s.owned) {
                if (s.data) |d| {
                    const ptr: [*]u8 = @constCast(d.ptr);
                    allocator.free(ptr[0..d.len]);
                }
            }
        }
        if (!strings.rolled_back) {
            allocator.free(items);
        }
    }
    strings.items = null;
    strings.count = 0;
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

pub fn scoreString(data: []const u8, length: u32) u32 {
    var h: u32 = 0;
    const len = @min(length, @as(u32, @intCast(data.len)));
    for (0..len) |i| {
        h = mixU32(h, @as(u32, data[i]) +% @as(u32, @intCast(i)) *% 31);
    }
    return h;
}

pub fn stringTableHash(doc: *const types.Document) u32 {
    if (doc.strings.items == null) return 0;
    const items = doc.strings.items.?;
    var h: u32 = 0;
    for (items) |*s| {
        h = mixU32(h, s.hash);
        h = mixU32(h, s.length);
    }
    return h;
}

pub fn countEmptyStrings(doc: *const types.Document) u32 {
    if (doc.strings.items == null) return 0;
    const items = doc.strings.items.?;
    var count: u32 = 0;
    for (items) |*s| { if (s.data == null or s.length == 0) count += 1; }
    return count;
}

pub fn averageStringLength(doc: *const types.Document) f64 {
    if (doc.strings.items == null or doc.strings.count == 0) return 0;
    const items = doc.strings.items.?;
    var total: u64 = 0;
    for (items) |*s| total += s.length;
    return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(items.len));
}
