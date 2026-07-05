const std = @import("std");
const types = @import("types.zig");
const strings = @import("strings.zig");

pub const QueryOp = enum { eq, ne, gt, lt, ge, le, contains, starts_with };
pub const QueryField = enum { name_index, attr_index, klass, sym_flags, derived_score };

pub const QueryPredicate = struct {
    field: QueryField, op: QueryOp, value: u32,
    string_pattern: ?[]const u8,
};

pub fn querySymbols(doc: *const types.Document, predicate: QueryPredicate, results: []u32) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var count: u32 = 0;
    for (syms, 0..) |*sym, i| {
        if (count >= results.len) break;
        const field_val = switch (predicate.field) {
            .name_index => sym.name_index,
            .attr_index => sym.attr_index,
            .klass => @as(u32, sym.klass),
            .sym_flags => @as(u32, sym.sym_flags),
            .derived_score => sym.derived_score,
        };
        const matches = switch (predicate.op) {
            .eq => field_val == predicate.value,
            .ne => field_val != predicate.value,
            .gt => field_val > predicate.value,
            .lt => field_val < predicate.value,
            .ge => field_val >= predicate.value,
            .le => field_val <= predicate.value,
            .contains, .starts_with => blk: {
                if (predicate.string_pattern) |pattern| {
                    if (sym.name_ref) |ref| {
                        break :blk if (predicate.op == .contains) containsSubstring(ref, pattern) else startsWith(ref, pattern);
                    }
                }
                break :blk false;
            },
        };
        if (matches) { results[count] = @intCast(i); count += 1; }
    }
    return count;
}

pub fn queryRelocs(doc: *const types.Document, section_type: types.SectionType, results: []u32) u32 {
    if (doc.relocs.items == null or doc.raw_sections == null) return 0;
    const relocs = doc.relocs.items.?;
    const secs = doc.raw_sections.?;
    var count: u32 = 0;
    for (relocs, 0..) |*rel, i| {
        if (count >= results.len) break;
        if (rel.section_index < secs.len and secs[rel.section_index].section_type == section_type) {
            results[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

pub fn queryEvents(doc: *const types.Document, min_timestamp: u64, max_timestamp: u64, results: []u32) u32 {
    if (doc.events.items == null) return 0;
    const evts = doc.events.items.?;
    var count: u32 = 0;
    for (evts, 0..) |*ev, i| {
        if (count >= results.len) break;
        if (ev.timestamp >= min_timestamp and ev.timestamp <= max_timestamp) {
            results[count] = @intCast(i); count += 1;
        }
    }
    return count;
}

pub fn aggregateByClass(doc: *const types.Document, histogram: []u32) void {
    if (doc.symbols.items == null) return;
    const syms = doc.symbols.items.?;
    for (syms) |*sym| {
        const bucket = sym.klass % @as(u16, @intCast(histogram.len));
        histogram[bucket] +|= 1;
    }
}

pub fn computeHistogram(doc: *const types.Document, field: QueryField, buckets: u32, output: []u32) void {
    if (doc.symbols.items == null or buckets == 0) return;
    const syms = doc.symbols.items.?;
    var mx: u32 = 1;
    for (syms) |*sym| {
        const v = switch (field) {
            .name_index => sym.name_index,
            .attr_index => sym.attr_index,
            .klass => @as(u32, sym.klass),
            .sym_flags => @as(u32, sym.sym_flags),
            .derived_score => sym.derived_score,
        };
        if (v > mx) mx = v;
    }
    for (syms) |*sym| {
        const v = switch (field) {
            .name_index => sym.name_index,
            .attr_index => sym.attr_index,
            .klass => @as(u32, sym.klass),
            .sym_flags => @as(u32, sym.sym_flags),
            .derived_score => sym.derived_score,
        };
        const bucket = v / (mx / buckets + 1);
        if (bucket < output.len) output[bucket] +|= 1;
    }
}

fn containsSubstring(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i..][0..needle.len], needle)) return true;
    }
    return false;
}

fn startsWith(data: []const u8, prefix: []const u8) bool {
    if (prefix.len > data.len) return false;
    return std.mem.eql(u8, data[0..prefix.len], prefix);
}
