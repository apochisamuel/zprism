const std = @import("std");
const types = @import("types.zig");
const strings = @import("strings.zig");

pub const AnalysisResult = struct {
    total_symbols: u32, total_strings: u32, total_attrs: u32,
    total_relocs: u32, total_events: u32, total_keyframes: u32,
    total_streams: u32, total_aliases: u32,
    symbol_coverage: f64, attr_density: f64,
    avg_string_length: f64, max_string_length: u32,
    reloc_density: f64, event_throughput: f64,
    complexity_score: u32, risk_score: u32,
    dominant_section: types.SectionType,
    has_circular_refs: bool, has_orphan_symbols: bool,
};

pub fn analyzeDocument(doc: *const types.Document) AnalysisResult {
    var result = std.mem.zeroes(AnalysisResult);
    result.total_symbols = doc.symbols.count;
    result.total_strings = doc.strings.count;
    result.total_attrs = doc.attrs.count;
    result.total_relocs = doc.relocs.count;
    result.total_events = doc.events.count;
    result.total_keyframes = doc.keyframes.count;
    result.total_streams = doc.streams.count;
    result.total_aliases = doc.aliases.count;

    if (doc.symbols.count > 0 and doc.attrs.count > 0) {
        result.symbol_coverage = @as(f64, @floatFromInt(doc.symbols.count)) /
            @as(f64, @floatFromInt(doc.attrs.count));
    }
    if (doc.attrs.count > 0 and doc.raw_count > 0) {
        result.attr_density = @as(f64, @floatFromInt(doc.attrs.count)) /
            @as(f64, @floatFromInt(doc.raw_count));
    }

    result.avg_string_length = computeAvgStringLen(doc);
    result.max_string_length = computeMaxStringLen(doc);
    result.reloc_density = computeRelocDensity(doc);
    result.event_throughput = computeEventThroughput(doc);
    result.complexity_score = computeComplexity(doc);
    result.risk_score = computeRisk(doc);
    result.dominant_section = findDominantSection(doc);
    result.has_circular_refs = detectCircularRefs(doc);
    result.has_orphan_symbols = detectOrphanSymbols(doc);
    return result;
}

fn computeAvgStringLen(doc: *const types.Document) f64 {
    if (doc.strings.items == null or doc.strings.count == 0) return 0;
    const items = doc.strings.items.?;
    var total: u64 = 0;
    for (items) |*s| total += s.length;
    return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(items.len));
}

fn computeMaxStringLen(doc: *const types.Document) u32 {
    if (doc.strings.items == null) return 0;
    const items = doc.strings.items.?;
    var mx: u32 = 0;
    for (items) |*s| { if (s.length > mx) mx = s.length; }
    return mx;
}

fn computeRelocDensity(doc: *const types.Document) f64 {
    if (doc.relocs.count == 0 or doc.symbols.count == 0) return 0;
    return @as(f64, @floatFromInt(doc.relocs.count)) /
        @as(f64, @floatFromInt(doc.symbols.count));
}

fn computeEventThroughput(doc: *const types.Document) f64 {
    if (doc.events.items == null or doc.events.count == 0) return 0;
    const items = doc.events.items.?;
    var total_payload: u64 = 0;
    for (items) |*ev| total_payload += ev.payload_len;
    return @as(f64, @floatFromInt(total_payload)) / @as(f64, @floatFromInt(items.len));
}

fn computeComplexity(doc: *const types.Document) u32 {
    var score: u32 = 0;
    score +|= doc.symbols.count * 3;
    score +|= doc.relocs.count * 5;
    score +|= doc.events.count * 2;
    score +|= doc.keyframes.count * 4;
    score +|= doc.streams.count * 7;
    score +|= doc.aliases.count * 6;
    if (doc.directory) |dir| {
        for (dir) |*de| {
            if (de.link != std.math.maxInt(u32) and de.link < dir.len)
                score +|= 10;
        }
    }
    return score;
}

fn computeRisk(doc: *const types.Document) u32 {
    var risk: u32 = 0;
    if (doc.header.flags & types.FLAG_TYPE_SWEEP != 0) risk += 20;
    if (doc.header.flags & types.FLAG_FRAME_TRUST != 0) risk += 15;
    if (doc.header.flags & types.FLAG_COMPACT_ARENA != 0) risk += 25;
    if (doc.relocs.count > doc.symbols.count * 4) risk += 30;
    if (doc.strings.items) |items| {
        var empty: u32 = 0;
        for (items) |*s| { if (s.data == null) empty += 1; }
        if (doc.strings.count > 0 and empty * 2 > doc.strings.count) risk += 40;
    }
    return risk;
}

fn findDominantSection(doc: *const types.Document) types.SectionType {
    if (doc.raw_sections == null) return .invalid;
    const secs = doc.raw_sections.?;
    var max_size: u32 = 0;
    var dominant: types.SectionType = .invalid;
    for (secs) |*sec| {
        if (sec.size > max_size) { max_size = sec.size; dominant = sec.section_type; }
    }
    return dominant;
}

fn detectCircularRefs(doc: *const types.Document) bool {
    if (doc.directory == null) return false;
    const dir = doc.directory.?;
    var visited = [_]bool{false} ** types.MAX_DIRECTORY;
    for (0..dir.len) |start| {
        for (&visited) |*v| v.* = false;
        var idx: u32 = @intCast(start);
        var steps: u32 = 0;
        while (idx < dir.len and steps < 32) : (steps += 1) {
            if (visited[idx]) return true;
            visited[idx] = true;
            const link = dir[idx].link;
            if (link >= dir.len or link == std.math.maxInt(u32)) break;
            idx = link;
        }
    }
    return false;
}

fn detectOrphanSymbols(doc: *const types.Document) bool {
    if (doc.symbols.items == null or doc.relocs.items == null) return false;
    const syms = doc.symbols.items.?;
    const relocs = doc.relocs.items.?;
    var referenced = [_]bool{false} ** types.MAX_SYMBOLS;
    for (relocs) |*rel| {
        if (rel.symbol_index < types.MAX_SYMBOLS) referenced[rel.symbol_index] = true;
    }
    for (0..syms.len) |i| {
        if (i < types.MAX_SYMBOLS and !referenced[i]) return true;
    }
    return false;
}

pub fn documentQualityScore(doc: *const types.Document) f64 {
    var score: f64 = 0;
    if (doc.symbols.count > 0) score += 10.0;
    if (doc.strings.count > 0 and !doc.strings.rolled_back) score += 15.0;
    if (doc.attrs.count > 0 and !doc.attrs.rolled_back) score += 10.0;
    if (doc.relocs.count > 0) score += 5.0;
    if (doc.events.count > 0) score += 10.0;
    if (doc.keyframes.count > 0) score += 5.0;
    if (doc.cache.combined_hash != 0) score += 20.0;
    if (doc.warning_count == 0) { score += 25.0; } else if (doc.warning_count < 5) { score += 15.0; }
    return score;
}

pub fn sectionDistribution(doc: *const types.Document) [10]f64 {
    var dist = [_]f64{0} ** 10;
    var total: u64 = 0;
    if (doc.raw_sections) |secs| {
        for (secs) |*sec| total += sec.size;
        if (total == 0) return dist;
        for (secs) |*sec| {
            const idx = @intFromEnum(sec.section_type);
            if (idx < 10) dist[idx] += @as(f64, @floatFromInt(sec.size)) / @as(f64, @floatFromInt(total));
        }
    }
    return dist;
}

pub fn symbolDensity(doc: *const types.Document) f64 {
    if (doc.input.len == 0) return 0;
    return @as(f64, @floatFromInt(doc.symbols.count)) / @as(f64, @floatFromInt(doc.input.len)) * 1000.0;
}

pub fn relocCoverage(doc: *const types.Document) f64 {
    if (doc.symbols.count == 0) return 0;
    if (doc.relocs.items == null) return 0;
    const relocs = doc.relocs.items.?;
    var referenced = [_]bool{false} ** types.MAX_SYMBOLS;
    for (relocs) |*r| {
        if (r.symbol_index < types.MAX_SYMBOLS) referenced[r.symbol_index] = true;
    }
    var covered: u32 = 0;
    for (0..@min(doc.symbols.count, types.MAX_SYMBOLS)) |i| {
        if (referenced[i]) covered += 1;
    }
    return @as(f64, @floatFromInt(covered)) / @as(f64, @floatFromInt(doc.symbols.count));
}

pub fn eventPayloadStats(doc: *const types.Document) [3]u32 {
    if (doc.events.items == null) return [_]u32{0} ** 3;
    const evts = doc.events.items.?;
    var min_p: u32 = std.math.maxInt(u32);
    var max_p: u32 = 0;
    var total: u64 = 0;
    for (evts) |*ev| {
        if (ev.payload_len < min_p) min_p = ev.payload_len;
        if (ev.payload_len > max_p) max_p = ev.payload_len;
        total += ev.payload_len;
    }
    const avg: u32 = if (evts.len > 0) @intCast(total / evts.len) else 0;
    return .{ min_p, max_p, avg };
}
