const std = @import("std");
const types = @import("types.zig");

pub const SearchMode = enum { exact, prefix, suffix, substring, fuzzy };

pub fn searchStrings(doc: *const types.Document, pattern: []const u8, mode: SearchMode, results: []u32) u32 {
    if (doc.strings.items == null or doc.strings.rolled_back) return 0;
    const items = doc.strings.items.?;
    var count: u32 = 0;
    for (items, 0..) |*s, i| {
        if (count >= results.len) break;
        if (s.data) |data| {
            const matches = switch (mode) {
                .exact => std.mem.eql(u8, data, pattern),
                .prefix => data.len >= pattern.len and std.mem.eql(u8, data[0..pattern.len], pattern),
                .suffix => data.len >= pattern.len and std.mem.eql(u8, data[data.len - pattern.len ..], pattern),
                .substring => containsSubstr(data, pattern),
                .fuzzy => fuzzyMatch(data, pattern) > 60,
            };
            if (matches) { results[count] = @intCast(i); count += 1; }
        }
    }
    return count;
}

pub fn searchSymbolsByScore(doc: *const types.Document, min_score: u32, max_score: u32, results: []u32) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var count: u32 = 0;
    for (syms, 0..) |*sym, i| {
        if (count >= results.len) break;
        if (sym.derived_score >= min_score and sym.derived_score <= max_score) {
            results[count] = @intCast(i); count += 1;
        }
    }
    return count;
}

fn containsSubstr(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.mem.eql(u8, haystack[i..][0..needle.len], needle)) return true;
    }
    return false;
}

fn fuzzyMatch(text: []const u8, pattern: []const u8) u32 {
    if (pattern.len == 0) return 100;
    if (text.len == 0) return 0;
    var matched: u32 = 0;
    var ti: usize = 0;
    for (pattern) |pc| {
        while (ti < text.len) : (ti += 1) {
            if (text[ti] == pc or (text[ti] >= 'A' and text[ti] <= 'Z' and text[ti] + 32 == pc) or
                (text[ti] >= 'a' and text[ti] <= 'z' and text[ti] - 32 == pc))
            {
                matched += 1; ti += 1; break;
            }
        }
    }
    return matched * 100 / @as(u32, @intCast(pattern.len));
}

pub fn buildInvertedIndex(doc: *const types.Document, index: []u32) u32 {
    if (doc.strings.items == null) return 0;
    const items = doc.strings.items.?;
    var pos: u32 = 0;
    for (items, 0..) |*s, i| {
        if (s.data) |data| {
            const hash = computeNGramHash(data, 3);
            if (pos < index.len) {
                index[pos] = hash ^ @as(u32, @intCast(i));
                pos += 1;
            }
        }
    }
    if (pos > 1) std.sort.insertion(u32, index[0..pos], {}, std.sort.asc(u32));
    return pos;
}

fn computeNGramHash(data: []const u8, n: u32) u32 {
    if (data.len < n) return 0;
    var h: u32 = 0;
    var i: usize = 0;
    while (i + n <= data.len) : (i += 1) {
        var nh: u32 = 0;
        for (0..n) |j| nh = nh *% 31 +% @as(u32, data[i + j]);
        h ^= nh;
    }
    return h;
}
