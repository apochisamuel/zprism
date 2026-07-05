const std = @import("std");
const types = @import("types.zig");
const strings_mod = @import("strings.zig");
const reloc_mod = @import("reloc.zig");
const streams_mod = @import("streams.zig");

pub fn resolveDocument(doc: *types.Document) void {
    // Phase 1: Apply relocations (may OOB if TYPE_SWEEP + inflated count)
    _ = reloc_mod.applyRelocations(doc);

    // Phase 2: Clean up weak strings
    cleanupWeakStrings(doc);

    // Phase 3: Resolve symbol names
    resolveSymbolNames(doc);

    // Phase 4: Recompute symbol rankings
    recomputeRankings(doc);

    // Phase 5: Materialize streams (reads key_cache)
    _ = streams_mod.materializeStreams(doc);
}

fn cleanupWeakStrings(doc: *types.Document) void {
    if (doc.strings.items == null) return;
    const items = doc.strings.items.?;
    for (items) |*s| {
        if (s.owned and s.length == 0) {
            if (s.data) |d| {
                const ptr: [*]u8 = @constCast(d.ptr);
                doc.allocator.free(ptr[0..d.len]);
                s.data = null;
            }
        }
    }
}

fn resolveSymbolNames(doc: *types.Document) void {
    if (doc.symbols.items == null) return;
    const syms = doc.symbols.items.?;

    for (syms) |*s| {
        var attr_value: u32 = 0;

        if (s.cached_attr) |attr| {
            attr_value = attr.value ^ attr.flags;
        }

        if (s.name_ref) |ref| {
            s.derived_score = strings_mod.scoreString(ref, @intCast(ref.len));
        }

        s.derived_score +%= attr_value;
    }
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

pub fn resolveKeyframeLabels(doc: *types.Document) u32 {
    if (doc.keyframes.items == null) return 0;
    const kfs = doc.keyframes.items.?;
    var resolved: u32 = 0;
    for (kfs) |*kf| {
        if (doc.strings.items) |strings| {
            if (!doc.strings.rolled_back and kf.name_index < strings.len) {
                kf.label = strings[kf.name_index].data;
                if (kf.label != null) resolved += 1;
            }
        }
    }
    return resolved;
}

pub fn resolveStreamKeys(doc: *types.Document) u32 {
    if (doc.streams.items == null) return 0;
    const streams = doc.streams.items.?;
    var resolved: u32 = 0;
    for (streams) |*st| {
        if (doc.keyframes.items) |kfs| {
            if (st.key_index < kfs.len) {
                st.key_cache = &kfs[st.key_index];
                resolved += 1;
            }
        }
    }
    return resolved;
}

pub fn resolveRelocTargets(doc: *types.Document) u32 {
    if (doc.relocs.items == null or doc.symbols.items == null) return 0;
    const relocs = doc.relocs.items.?;
    const syms = doc.symbols.items.?;
    var resolved: u32 = 0;
    for (relocs) |*rel| {
        if (rel.symbol_index < syms.len) {
            const sym = &syms[rel.symbol_index];
            rel.resolved_hash = mixU32(sym.derived_score, rel.target);
            resolved += 1;
        }
    }
    return resolved;
}

pub fn computeResolutionScore(doc: *const types.Document) u32 {
    var score: u32 = 0;
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            if (s.name_ref != null) score += 1;
            if (s.cached_attr != null) score += 1;
        }
    }
    if (doc.keyframes.items) |kfs| {
        for (kfs) |*kf| { if (kf.label != null) score += 1; }
    }
    if (doc.streams.items) |sts| {
        for (sts) |*st| { if (st.key_cache != null) score += 1; }
    }
    return score;
}

pub fn validateResolution(doc: *const types.Document) bool {
    if (doc.symbols.items) |syms| {
        for (syms) |*s| {
            if (s.name_index < doc.strings.count) {
                if (s.name_ref == null and !doc.strings.rolled_back) return false;
            }
            if (s.attr_index < doc.attrs.count) {
                if (s.cached_attr == null and !doc.attrs.rolled_back) return false;
            }
        }
    }
    return true;
}

fn recomputeRankings(doc: *types.Document) void {
    if (doc.symbols.items == null) return;
    const syms = doc.symbols.items.?;
    for (syms) |*s| {
        var rank: u32 = s.derived_score;
        if (s.cached_attr) |attr| {
            rank +%= attr.value *% attr.tag;
        }
        s.derived_score = rank;
    }
}
