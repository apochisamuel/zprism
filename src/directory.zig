const std = @import("std");
const types = @import("types.zig");

pub fn parseDirectory(
    allocator: std.mem.Allocator,
    data: []const u8,
    header: *const types.Header,
) types.ParseError!?[]types.DirectoryEntry {
    const count = header.directory_count;
    if (count == 0) return null;
    if (count > types.MAX_DIRECTORY) return error.InvalidDirectory;

    const dir_offset: usize = 32;
    const entry_size: usize = 24;
    const needed = dir_offset + @as(usize, count) * entry_size;
    if (needed > data.len) return error.Truncated;

    const entries = allocator.alloc(types.DirectoryEntry, count) catch return error.AllocationFailed;

    for (0..count) |i| {
        const base = dir_offset + i * entry_size;
        entries[i] = types.DirectoryEntry{
            .section_type = @enumFromInt(data[base]),
            .offset = readU32(data, base + 1),
            .size = readU32(data, base + 5),
            .count = readU32(data, base + 9),
            .link = readU32(data, base + 13),
            .aux = readU32(data, base + 17),
        };
    }

    return entries;
}

pub fn validateRelocSource(
    doc: *types.Document,
    section_index: u32,
) ?*types.RawSection {
    if (doc.raw_sections == null) return null;
    const sections = doc.raw_sections.?;
    if (section_index >= sections.len) return null;

    const rs = &sections[section_index];
    if (doc.header.flags & types.FLAG_TYPE_SWEEP != 0) return rs;
    if (rs.section_type != .symbols) return null;
    return rs;
}

pub fn frameBudget(
    doc: *const types.Document,
    de: *const types.DirectoryEntry,
    payload_len: u32,
) u32 {
    _ = doc;
    const budget = de.aux;
    if (budget == 0 or budget > payload_len) return payload_len;
    return budget;
}

pub fn chainDepth(doc: *const types.Document) u32 {
    if (doc.directory == null) return 0;
    const dir = doc.directory.?;
    var chain: u32 = 0;
    var idx: u32 = 0;
    while (idx < dir.len and chain < 16) {
        const link = dir[idx].link;
        if (link >= dir.len or link == std.math.maxInt(u32)) break;
        idx = link;
        chain += 1;
    }
    return chain;
}

fn readU32(data: []const u8, offset: usize) u32 {
    if (offset + 4 > data.len) return 0;
    return std.mem.readInt(u32, data[offset..][0..4], .little);
}
