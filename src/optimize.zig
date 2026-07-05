const std = @import("std");
const types = @import("types.zig");

pub const OptimizeResult = struct {
    symbols_deduped: u32, strings_deduped: u32,
    relocs_compacted: u32, bytes_saved: u64,
    passes_run: u32,
};

pub fn optimizeDocument(doc: *const types.Document) OptimizeResult {
    var result = std.mem.zeroes(OptimizeResult);
    result.symbols_deduped = countDuplicateSymbols(doc);
    result.strings_deduped = countDuplicateStrings(doc);
    result.relocs_compacted = countRedundantRelocs(doc);
    result.bytes_saved = estimateSavings(doc, &result);
    result.passes_run = 1;
    return result;
}

fn countDuplicateSymbols(doc: *const types.Document) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var dups: u32 = 0;
    for (syms, 0..) |*a, i| {
        for (syms[i + 1 ..]) |*b| {
            if (a.name_index == b.name_index and a.klass == b.klass and a.attr_index == b.attr_index) {
                dups += 1; break;
            }
        }
    }
    return dups;
}

fn countDuplicateStrings(doc: *const types.Document) u32 {
    if (doc.strings.items == null) return 0;
    const items = doc.strings.items.?;
    var dups: u32 = 0;
    for (items, 0..) |*a, i| {
        if (a.data == null) continue;
        for (items[i + 1 ..]) |*b| {
            if (b.data) |bd| {
                if (a.data) |ad| {
                    if (ad.len == bd.len and std.mem.eql(u8, ad, bd)) { dups += 1; break; }
                }
            }
        }
    }
    return dups;
}

fn countRedundantRelocs(doc: *const types.Document) u32 {
    if (doc.relocs.items == null) return 0;
    const relocs = doc.relocs.items.?;
    var redundant: u32 = 0;
    for (relocs, 0..) |*a, i| {
        for (relocs[i + 1 ..]) |*b| {
            if (a.section_index == b.section_index and a.symbol_index == b.symbol_index and a.target == b.target) {
                redundant += 1; break;
            }
        }
    }
    return redundant;
}

fn estimateSavings(doc: *const types.Document, result: *const OptimizeResult) u64 {
    var savings: u64 = 0;
    savings += @as(u64, result.symbols_deduped) * 12;
    savings += @as(u64, result.strings_deduped) * 16;
    savings += @as(u64, result.relocs_compacted) * 16;
    _ = doc;
    return savings;
}

pub fn computeFragmentation(doc: *const types.Document) f64 {
    if (doc.raw_sections == null or doc.raw_count < 2) return 0;
    const secs = doc.raw_sections.?;
    var gaps: u64 = 0;
    var total: u64 = 0;
    for (1..secs.len) |i| {
        const prev_end = @as(u64, secs[i - 1].offset) + secs[i - 1].size;
        const curr_start = @as(u64, secs[i].offset);
        if (curr_start > prev_end) gaps += curr_start - prev_end;
        total += secs[i].size;
    }
    if (total == 0) return 0;
    return @as(f64, @floatFromInt(gaps)) / @as(f64, @floatFromInt(total));
}

pub fn compactionScore(doc: *const types.Document) u32 {
    var score: u32 = 0;
    score += countDuplicateSymbols(doc) * 3;
    score += countDuplicateStrings(doc) * 5;
    score += countRedundantRelocs(doc) * 2;
    return score;
}
