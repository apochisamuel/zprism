const std = @import("std");
const types = @import("types.zig");

pub const InspectResult = struct {
    section_map: [types.MAX_SECTIONS]SectionInfo,
    section_count: u32,
    total_data_bytes: u64,
    total_metadata_bytes: u64,
    pointer_density: f64,
    cross_section_refs: u32,
    max_nesting_depth: u32,
};

pub const SectionInfo = struct {
    section_type: types.SectionType,
    offset: u32, size: u32,
    record_count: u32, avg_record_size: u32,
    utilization: f64, fragmentation: f64,
};

pub fn inspectDocument(doc: *const types.Document) InspectResult {
    var result = std.mem.zeroes(InspectResult);
    if (doc.raw_sections) |secs| {
        for (secs, 0..) |*sec, i| {
            if (i >= types.MAX_SECTIONS) break;
            result.section_map[i] = inspectSection(doc, sec);
            result.section_count += 1;
            result.total_data_bytes += sec.size;
        }
    }
    result.total_metadata_bytes = 32 + @as(u64, doc.directory_count) * 24;
    result.pointer_density = computePointerDensity(doc);
    result.cross_section_refs = countCrossSectionRefs(doc);
    result.max_nesting_depth = computeNestingDepth(doc);
    return result;
}

fn inspectSection(doc: *const types.Document, sec: *const types.RawSection) SectionInfo {
    var info = std.mem.zeroes(SectionInfo);
    info.section_type = sec.section_type;
    info.offset = sec.offset;
    info.size = sec.size;
    info.record_count = switch (sec.section_type) {
        .symbols => doc.symbols.count,
        .strings => doc.strings.count,
        .attrs => doc.attrs.count,
        .relocs => doc.relocs.count,
        .events => doc.events.count,
        .keyframes => doc.keyframes.count,
        .streams => doc.streams.count,
        .aliases => doc.aliases.count,
        else => 0,
    };
    if (info.record_count > 0) info.avg_record_size = info.size / info.record_count;
    if (info.size > 0 and info.record_count > 0) {
        const used = @as(u64, info.record_count) * info.avg_record_size;
        info.utilization = @as(f64, @floatFromInt(@min(used, info.size))) / @as(f64, @floatFromInt(info.size));
    }
    return info;
}

fn computePointerDensity(doc: *const types.Document) f64 {
    var ptrs: u32 = 0;
    var total: u32 = 0;
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            total += 1;
            if (s.name_ref != null) ptrs += 1;
            if (s.cached_attr != null) ptrs += 1;
        }
    }
    if (total == 0) return 0;
    return @as(f64, @floatFromInt(ptrs)) / @as(f64, @floatFromInt(total));
}

fn countCrossSectionRefs(doc: *const types.Document) u32 {
    var refs: u32 = 0;
    if (doc.relocs.items) |relocs| {
        for (relocs) |*rel| {
            if (rel.section_index < doc.raw_count) refs += 1;
        }
    }
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            if (s.name_index < doc.strings.count) refs += 1;
            if (s.attr_index < doc.attrs.count) refs += 1;
        }
    }
    return refs;
}

fn computeNestingDepth(doc: *const types.Document) u32 {
    if (doc.directory == null) return 0;
    const dir = doc.directory.?;
    var max_depth: u32 = 0;
    for (0..dir.len) |start| {
        var depth: u32 = 0;
        var idx: u32 = @intCast(start);
        while (idx < dir.len and depth < 32) {
            depth += 1;
            const link = dir[idx].link;
            if (link >= dir.len or link == std.math.maxInt(u32)) break;
            idx = link;
        }
        if (depth > max_depth) max_depth = depth;
    }
    return max_depth;
}
