const std = @import("std");
const types = @import("types.zig");

pub fn captureSections(
    allocator: std.mem.Allocator,
    data: []const u8,
    header: *const types.Header,
    directory: ?[]const types.DirectoryEntry,
) types.ParseError!?[]types.RawSection {
    if (directory == null) return null;
    const dir = directory.?;
    const count = header.section_count;
    if (count == 0) return null;
    if (count > types.MAX_SECTIONS) return error.TooManySections;

    const sections = allocator.alloc(types.RawSection, count) catch return error.AllocationFailed;

    var captured: u32 = 0;
    for (0..@min(count, @as(u16, @intCast(dir.len)))) |i| {
        const de = &dir[i];
        const off: usize = de.offset;
        const sz: usize = de.size;
        if (off >= data.len) continue;
        const end = @min(off + sz, data.len);
        sections[captured] = types.RawSection{
            .section_type = de.section_type,
            .data = data[off..end],
            .offset = de.offset,
            .size = @intCast(end - off),
            .index = @intCast(i),
        };
        captured += 1;
    }

    return sections[0..captured];
}

pub fn sectionByIndex(doc: *types.Document, index: u32) ?*types.RawSection {
    if (doc.raw_sections == null) return null;
    const sections = doc.raw_sections.?;
    if (index >= sections.len) return null;
    return &sections[index];
}

pub fn sectionByType(doc: *types.Document, section_type: types.SectionType) ?*types.RawSection {
    if (doc.raw_sections == null) return null;
    const sections = doc.raw_sections.?;
    for (sections) |*sec| {
        if (sec.section_type == section_type) return sec;
    }
    return null;
}
