const std = @import("std");
const types = @import("types.zig");

pub const MergeStrategy = enum { union_all, intersect, left_only, right_only };

pub const MergeResult = struct {
    symbols_merged: u32, strings_merged: u32,
    conflicts: u32, duplicates_removed: u32,
};

pub fn mergeSymbolTables(a: ?[]const types.Symbol, b: ?[]const types.Symbol,
    output: []types.Symbol, strategy: MergeStrategy) MergeResult {
    var result = std.mem.zeroes(MergeResult);
    var pos: u32 = 0;

    switch (strategy) {
        .union_all => {
            if (a) |sa| for (sa) |*sym| {
                if (pos < output.len) { output[pos] = sym.*; pos += 1; result.symbols_merged += 1; }
            };
            if (b) |sb| for (sb) |*sym| {
                var dup = false;
                for (output[0..pos]) |*existing| {
                    if (existing.name_index == sym.name_index and existing.klass == sym.klass) {
                        dup = true; result.duplicates_removed += 1; break;
                    }
                }
                if (!dup and pos < output.len) { output[pos] = sym.*; pos += 1; result.symbols_merged += 1; }
            };
        },
        .intersect => {
            if (a) |sa| for (sa) |*sym_a| {
                if (b) |sb| for (sb) |*sym_b| {
                    if (sym_a.name_index == sym_b.name_index and sym_a.klass == sym_b.klass) {
                        if (pos < output.len) { output[pos] = sym_a.*; pos += 1; result.symbols_merged += 1; }
                    }
                };
            };
        },
        .left_only => {
            if (a) |sa| for (sa) |*sym_a| {
                var found = false;
                if (b) |sb| for (sb) |*sym_b| {
                    if (sym_a.name_index == sym_b.name_index) { found = true; break; }
                };
                if (!found and pos < output.len) { output[pos] = sym_a.*; pos += 1; result.symbols_merged += 1; }
            };
        },
        .right_only => {
            if (b) |sb| for (sb) |*sym_b| {
                var found = false;
                if (a) |sa| for (sa) |*sym_a| {
                    if (sym_b.name_index == sym_a.name_index) { found = true; break; }
                };
                if (!found and pos < output.len) { output[pos] = sym_b.*; pos += 1; result.symbols_merged += 1; }
            };
        },
    }
    return result;
}

pub fn mergeAttrTables(a: ?[]const types.Attr, b: ?[]const types.Attr, output: []types.Attr) u32 {
    var pos: u32 = 0;
    if (a) |sa| for (sa) |*attr| {
        if (pos < output.len) { output[pos] = attr.*; pos += 1; }
    };
    if (b) |sb| for (sb) |*attr| {
        var dup = false;
        for (output[0..pos]) |*existing| {
            if (existing.value == attr.value and existing.flags == attr.flags) { dup = true; break; }
        }
        if (!dup and pos < output.len) { output[pos] = attr.*; pos += 1; }
    };
    return pos;
}

pub fn computeMergeComplexity(a: *const types.Document, b: *const types.Document) u32 {
    var complexity: u32 = 0;
    complexity += a.symbols.count * b.symbols.count / 100;
    complexity += a.strings.count * b.strings.count / 100;
    complexity += a.relocs.count + b.relocs.count;
    return complexity;
}
