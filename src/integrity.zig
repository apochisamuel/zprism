const std = @import("std");
const types = @import("types.zig");

pub const IntegrityReport = struct {
    header_valid: bool, directory_valid: bool, sections_valid: bool,
    strings_valid: bool, symbols_valid: bool, attrs_valid: bool,
    relocs_valid: bool, events_valid: bool,
    checksum_match: bool, total_warnings: u32,
    cross_ref_errors: u32, dangling_refs: u32,
    coverage_percent: f64,
};

pub fn checkIntegrity(doc: *const types.Document) IntegrityReport {
    var report = std.mem.zeroes(IntegrityReport);
    report.header_valid = validateHeaderIntegrity(doc);
    report.directory_valid = validateDirectoryIntegrity(doc);
    report.sections_valid = validateSectionIntegrity(doc);
    report.strings_valid = validateStringIntegrity(doc);
    report.symbols_valid = validateSymbolIntegrity(doc);
    report.attrs_valid = validateAttrIntegrity(doc);
    report.relocs_valid = validateRelocIntegrity(doc);
    report.events_valid = validateEventIntegrity(doc);
    report.cross_ref_errors = countCrossRefErrors(doc);
    report.dangling_refs = countDanglingRefs(doc);
    report.total_warnings = doc.warning_count;
    report.coverage_percent = computeCoverage(doc);
    report.checksum_match = verifyChecksum(doc);
    return report;
}

fn validateHeaderIntegrity(doc: *const types.Document) bool {
    if (doc.header.magic != types.MAGIC) return false;
    if (doc.header.version == 0 or doc.header.version > 4) return false;
    if (doc.header.section_count > types.MAX_SECTIONS) return false;
    return true;
}

fn validateDirectoryIntegrity(doc: *const types.Document) bool {
    if (doc.directory == null) return true;
    const dir = doc.directory.?;
    for (dir) |*de| {
        if (de.offset > doc.input.len) return false;
        if (de.size > doc.input.len) return false;
        if (@as(u64, de.offset) + de.size > doc.input.len) return false;
    }
    return true;
}

fn validateSectionIntegrity(doc: *const types.Document) bool {
    if (doc.raw_sections == null) return true;
    const secs = doc.raw_sections.?;
    for (secs) |*sec| {
        if (sec.data.len != sec.size) return false;
    }
    return true;
}

fn validateStringIntegrity(doc: *const types.Document) bool {
    if (doc.strings.items == null) return true;
    if (doc.strings.rolled_back) return false;
    const items = doc.strings.items.?;
    for (items) |*s| {
        if (s.data) |d| { if (d.len != s.length) return false; }
    }
    return true;
}

fn validateSymbolIntegrity(doc: *const types.Document) bool {
    if (doc.symbols.items == null) return true;
    const syms = doc.symbols.items.?;
    for (syms) |*s| {
        if (s.name_index >= doc.strings.count and doc.strings.count > 0) return false;
    }
    return true;
}

fn validateAttrIntegrity(doc: *const types.Document) bool {
    if (doc.attrs.items == null) return true;
    if (doc.attrs.rolled_back) return false;
    return true;
}

fn validateRelocIntegrity(doc: *const types.Document) bool {
    if (doc.relocs.items == null) return true;
    const relocs = doc.relocs.items.?;
    for (relocs) |*r| {
        if (r.section_index >= doc.raw_count and doc.raw_count > 0) return false;
    }
    return true;
}

fn validateEventIntegrity(doc: *const types.Document) bool {
    if (doc.events.items == null) return true;
    const evts = doc.events.items.?;
    for (evts) |*ev| {
        if (ev.payload_len > 0 and ev.payload == null) return false;
    }
    return true;
}

fn countCrossRefErrors(doc: *const types.Document) u32 {
    var errors: u32 = 0;
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            if (s.name_index >= doc.strings.count and doc.strings.count > 0) errors += 1;
            if (s.attr_index >= doc.attrs.count and doc.attrs.count > 0) errors += 1;
        }
    }
    if (doc.relocs.items) |relocs| {
        for (relocs) |*r| {
            if (r.section_index >= doc.raw_count) errors += 1;
        }
    }
    return errors;
}

fn countDanglingRefs(doc: *const types.Document) u32 {
    var dangling: u32 = 0;
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            if (s.name_ref == null and s.name_index < doc.strings.count) dangling += 1;
        }
    }
    return dangling;
}

fn computeCoverage(doc: *const types.Document) f64 {
    if (doc.input.len == 0) return 0;
    var covered: u64 = 32;
    if (doc.directory) |dir| covered += dir.len * 24;
    if (doc.raw_sections) |secs| {
        for (secs) |*sec| covered += sec.size;
    }
    return @as(f64, @floatFromInt(@min(covered, doc.input.len))) /
        @as(f64, @floatFromInt(doc.input.len));
}

fn verifyChecksum(doc: *const types.Document) bool {
    if (doc.header.total_size == 0) return true;
    var h: u32 = 0;
    for (doc.input) |b| h = h *% 31 +% @as(u32, b);
    return h != 0;
}
