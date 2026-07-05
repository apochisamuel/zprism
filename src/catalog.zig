const std = @import("std");
const types = @import("types.zig");

pub const CatalogEntry = struct {
    name_hash: u32, type_hash: u32,
    symbol_index: u32, string_index: u32,
    score: u32, rank: u32,
};

pub fn buildCatalog(doc: *const types.Document, output: []CatalogEntry) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var count: u32 = 0;
    for (syms, 0..) |*sym, i| {
        if (count >= output.len) break;
        output[count] = CatalogEntry{
            .name_hash = fnvHash(sym.name_index),
            .type_hash = fnvHash(@as(u32, sym.klass) | (@as(u32, sym.sym_flags) << 16)),
            .symbol_index = @intCast(i),
            .string_index = sym.name_index,
            .score = sym.derived_score,
            .rank = 0,
        };
        count += 1;
    }
    assignRanks(output[0..count]);
    return count;
}

fn assignRanks(entries: []CatalogEntry) void {
    if (entries.len < 2) { if (entries.len == 1) entries[0].rank = 1; return; }
    var indices: [4096]u32 = undefined;
    const n = @min(entries.len, 4096);
    for (0..n) |i| indices[i] = @intCast(i);
    for (0..n) |i| {
        for (i + 1..n) |j| {
            if (entries[indices[j]].score > entries[indices[i]].score) {
                const tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp;
            }
        }
    }
    for (0..n) |i| entries[indices[i]].rank = @intCast(i + 1);
}

pub fn searchCatalog(catalog: []const CatalogEntry, count: u32, name_hash: u32) ?*const CatalogEntry {
    for (catalog[0..count]) |*entry| {
        if (entry.name_hash == name_hash) return entry;
    }
    return null;
}

pub fn topEntries(catalog: []const CatalogEntry, count: u32, top_n: u32, output: []u32) u32 {
    var result_count: u32 = 0;
    for (1..top_n + 1) |rank| {
        for (catalog[0..count]) |*entry| {
            if (entry.rank == rank and result_count < output.len) {
                output[result_count] = entry.symbol_index;
                result_count += 1;
            }
        }
    }
    return result_count;
}

pub fn catalogCoverage(_: []const CatalogEntry, count: u32, doc: *const types.Document) f64 {
    if (doc.symbols.count == 0) return 0;
    return @as(f64, @floatFromInt(count)) / @as(f64, @floatFromInt(doc.symbols.count));
}

fn fnvHash(key: u32) u32 {
    var h: u32 = 0x811c9dc5;
    h ^= key & 0xFF; h *%= 0x01000193;
    h ^= (key >> 8) & 0xFF; h *%= 0x01000193;
    h ^= (key >> 16) & 0xFF; h *%= 0x01000193;
    h ^= (key >> 24) & 0xFF; h *%= 0x01000193;
    return h;
}
