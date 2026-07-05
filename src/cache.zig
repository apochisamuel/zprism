const std = @import("std");
const types = @import("types.zig");
const strings_mod = @import("strings.zig");

pub fn buildCache(doc: *types.Document) void {
    var h = buildNameIndex(doc);

    // Compute string table integrity hash
    if (doc.strings.items) |items| {
        for (items) |*s| {
            if (s.data) |data| {
                h = mixU32(h, hashBytes(data));
            }
        }
    }

    // Mix in symbol scores
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            h = mixU32(h, s.derived_score);
        }
    }

    // Mix in event checksums
    if (doc.events.items) |evts| {
        for (evts) |*ev| {
            h = mixU32(h, ev.checksum);
        }
    }

    // Mix in alias view hashes
    if (doc.cache.alias_views) |views| {
        if (doc.cache.alias_gen_snap != doc.aliases.generation) {
            doc.cache.alias_view_count = 0;
        }
        var i: u32 = 0;
        while (i < doc.cache.alias_view_count) : (i += 1) {
            if (views[i]) |view| {
                if (doc.cache.alias_view_lens) |lens| {
                    const len = lens[i];
                    if (len > 0) {
                        h = mixU32(h, hashBytes(view[0..len]));
                    }
                }
            }
        }
    }

    doc.cache.combined_hash = h;
    doc.cache.integrity_score = h ^ @as(u32, @truncate(doc.header.file_id));
}

fn buildNameIndex(doc: *types.Document) u32 {
    if (doc.strings.rolled_back) return 0;
    const str_table = doc.cache.primary_strings orelse return 0;
    const items = str_table.items orelse return 0;

    var h: u32 = 0;
    for (items) |*s| {
        if (s.data) |data| {
            h = mixU32(h, s.hash ^ strings_mod.scoreString(data, s.length));
        }
    }
    return h;
}

pub fn freeCache(allocator: std.mem.Allocator, doc: *types.Document) void {
    // Release cache-owned alias data
    if (doc.cache.owned_aliases) |owned| {
        for (owned[0..doc.cache.owned_alias_count]) |maybe_blob| {
            if (maybe_blob) |blob| {
                if (blob.bytes) |bytes| {
                    allocator.free(bytes);
                }
                allocator.destroy(blob);
            }
        }
        allocator.free(owned);
    }

    if (doc.cache.alias_views) |views| allocator.free(views);
    if (doc.cache.alias_view_lens) |lens| allocator.free(lens);
    if (doc.cache.name_index) |idx| allocator.free(idx);

    doc.cache = std.mem.zeroes(types.Cache);
}

fn hashBytes(data: []const u8) u32 {
    var h: u32 = 0;
    for (data) |b| {
        h = h *% 31 +% @as(u32, b);
    }
    return h;
}

fn mixU32(a: u32, b: u32) u32 {
    var h = a;
    h ^= b;
    h *%= 0x5bd1e995;
    h ^= h >> 13;
    h *%= 0x5bd1e995;
    h ^= h >> 15;
    return h;
}

pub fn cacheValid(doc: *const types.Document) bool {
    if (doc.strings.rolled_back and doc.cache.primary_strings != null) return false;
    if (doc.attrs.rolled_back) return false;
    return true;
}

pub fn cacheSize(doc: *const types.Document) u32 {
    var size: u32 = 0;
    if (doc.cache.name_index != null) size += doc.cache.name_count * 8;
    if (doc.cache.alias_views != null) size += doc.cache.alias_view_count * 12;
    if (doc.cache.owned_aliases != null) size += doc.cache.owned_alias_count * 8;
    return size;
}

pub fn cacheCoverage(doc: *const types.Document) f64 {
    const total: u32 = doc.symbols.count + doc.strings.count + doc.aliases.count;
    if (total == 0) return 0;
    const cached: u32 = doc.cache.name_count + doc.cache.alias_view_count;
    return @as(f64, @floatFromInt(cached)) / @as(f64, @floatFromInt(total));
}
