const std = @import("std");
const types = @import("types.zig");

pub const DiagLevel = enum { info, warning, error_level, critical };

pub const DiagEntry = struct {
    level: DiagLevel, code: u32, section_index: u32,
    offset: u32, message_hash: u32,
};

pub const DiagReport = struct {
    entries: []DiagEntry,
    count: u32,
    info_count: u32, warning_count: u32,
    error_count: u32, critical_count: u32,
};

pub fn runDiagnostics(doc: *const types.Document, entries: []DiagEntry) DiagReport {
    var report = DiagReport{
        .entries = entries, .count = 0,
        .info_count = 0, .warning_count = 0,
        .error_count = 0, .critical_count = 0,
    };
    checkHeaderDiag(doc, &report);
    checkDirectoryDiag(doc, &report);
    checkStringDiag(doc, &report);
    checkSymbolDiag(doc, &report);
    checkRelocDiag(doc, &report);
    checkEventDiag(doc, &report);
    return report;
}

fn addDiag(report: *DiagReport, level: DiagLevel, code: u32, section: u32, offset: u32) void {
    if (report.count >= report.entries.len) return;
    report.entries[report.count] = DiagEntry{
        .level = level, .code = code, .section_index = section,
        .offset = offset, .message_hash = code *% 0x5bd1e995,
    };
    report.count += 1;
    switch (level) {
        .info => report.info_count += 1,
        .warning => report.warning_count += 1,
        .error_level => report.error_count += 1,
        .critical => report.critical_count += 1,
    }
}

fn checkHeaderDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.header.flags & types.FLAG_TYPE_SWEEP != 0 and doc.header.flags & types.FLAG_FRAME_TRUST != 0)
        addDiag(report, .warning, 1001, 0, 6);
    if (doc.header.section_count == 0) addDiag(report, .info, 1002, 0, 10);
    if (doc.header.total_size > 0 and doc.header.total_size > doc.input.len)
        addDiag(report, .error_level, 1003, 0, 18);
}

fn checkDirectoryDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.directory) |dir| {
        for (dir, 0..) |*de, i| {
            if (de.offset + de.size > doc.input.len)
                addDiag(report, .error_level, 2001, @intCast(i), de.offset);
            if (de.link < dir.len and de.link == i)
                addDiag(report, .warning, 2002, @intCast(i), 0);
        }
    }
}

fn checkStringDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.strings.rolled_back) { addDiag(report, .critical, 3001, 0, 0); return; }
    if (doc.strings.items) |items| {
        for (items, 0..) |*s, i| {
            if (s.data == null and s.length > 0) addDiag(report, .warning, 3002, @intCast(i), 0);
        }
    }
}

fn checkSymbolDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.symbols.items) |syms| {
        for (syms, 0..) |*s, i| {
            if (s.name_index >= doc.strings.count and doc.strings.count > 0)
                addDiag(report, .error_level, 4001, @intCast(i), 0);
        }
    }
}

fn checkRelocDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.relocs.items) |relocs| {
        for (relocs, 0..) |*r, i| {
            if (r.section_index >= doc.raw_count) addDiag(report, .error_level, 5001, @intCast(i), 0);
        }
    }
}

fn checkEventDiag(doc: *const types.Document, report: *DiagReport) void {
    if (doc.events.items) |evts| {
        for (evts, 0..) |*ev, i| {
            if (ev.payload_len > ev.storage_len) addDiag(report, .warning, 6001, @intCast(i), 0);
            if (ev.checksum == 0 and ev.payload_len > 0) addDiag(report, .info, 6002, @intCast(i), 0);
        }
    }
}
