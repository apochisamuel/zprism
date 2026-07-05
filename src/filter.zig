const std = @import("std");
const types = @import("types.zig");

pub const FilterOp = enum { include, exclude };
pub const FilterCriteria = struct {
    op: FilterOp, min_score: u32, max_score: u32,
    required_class: ?u16, required_flags: ?u16,
    min_name_length: u32, max_name_length: u32,
};

pub fn filterSymbols(doc: *const types.Document, criteria: FilterCriteria, output: []u32) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var count: u32 = 0;
    for (syms, 0..) |*sym, i| {
        if (count >= output.len) break;
        const matches = checkCriteria(sym, &criteria, doc);
        const include = switch (criteria.op) {
            .include => matches, .exclude => !matches,
        };
        if (include) { output[count] = @intCast(i); count += 1; }
    }
    return count;
}

fn checkCriteria(sym: *const types.Symbol, criteria: *const FilterCriteria, doc: *const types.Document) bool {
    if (sym.derived_score < criteria.min_score) return false;
    if (criteria.max_score > 0 and sym.derived_score > criteria.max_score) return false;
    if (criteria.required_class) |klass| { if (sym.klass != klass) return false; }
    if (criteria.required_flags) |flags| { if (sym.sym_flags & flags != flags) return false; }
    if (criteria.min_name_length > 0 or criteria.max_name_length > 0) {
        if (doc.strings.items) |strings| {
            if (sym.name_index < strings.len) {
                const len = strings[sym.name_index].length;
                if (len < criteria.min_name_length) return false;
                if (criteria.max_name_length > 0 and len > criteria.max_name_length) return false;
            }
        }
    }
    return true;
}

pub fn filterEvents(doc: *const types.Document, min_ts: u64, max_ts: u64, event_type: ?u8, output: []u32) u32 {
    if (doc.events.items == null) return 0;
    const evts = doc.events.items.?;
    var count: u32 = 0;
    for (evts, 0..) |*ev, i| {
        if (count >= output.len) break;
        if (ev.timestamp < min_ts or ev.timestamp > max_ts) continue;
        if (event_type) |et| { if (ev.event_type != et) continue; }
        output[count] = @intCast(i); count += 1;
    }
    return count;
}

pub fn filterRelocs(doc: *const types.Document, section_type: ?types.SectionType, min_target: u32, output: []u32) u32 {
    if (doc.relocs.items == null) return 0;
    const relocs = doc.relocs.items.?;
    var count: u32 = 0;
    for (relocs, 0..) |*rel, i| {
        if (count >= output.len) break;
        if (rel.target < min_target) continue;
        if (section_type) |st| {
            if (doc.raw_sections) |secs| {
                if (rel.section_index < secs.len and secs[rel.section_index].section_type != st) continue;
            }
        }
        output[count] = @intCast(i); count += 1;
    }
    return count;
}

pub fn chainFilters(indices_a: []const u32, indices_b: []const u32, output: []u32) u32 {
    var count: u32 = 0;
    for (indices_a) |a| {
        for (indices_b) |b| {
            if (a == b and count < output.len) { output[count] = a; count += 1; break; }
        }
    }
    return count;
}
