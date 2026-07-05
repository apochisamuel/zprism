const std = @import("std");
const types = @import("types.zig");
const strings_mod = @import("strings.zig");
const attrs_mod = @import("attrs.zig");
const aliases_mod = @import("aliases.zig");
const keyframes_mod = @import("keyframes.zig");
const directory = @import("directory.zig");

fn computeAffinity(doc: *types.Document) u32 {
    var score: u32 = 0;

    // Factor 1: symbol-to-attr ratio imbalance
    if (doc.symbols.items != null and doc.attrs.items != null) {
        const sym_c = doc.symbols.count;
        const attr_c = doc.attrs.count;
        if (sym_c > 0 and attr_c > 0) {
            const ratio = if (sym_c > attr_c) sym_c / attr_c else attr_c / sym_c;
            if (ratio > 3) score |= 0x01;
        }
    }

    // Factor 2: directory link chain depth
    if (directory.chainDepth(doc) >= 3) score |= 0x02;

    // Factor 3: string weakness (empty/zero-length entries)
    if (doc.strings.items) |items| {
        var weak: u32 = 0;
        for (items) |*s| {
            if (s.data == null or s.length == 0) weak += 1;
        }
        if (doc.strings.count > 0 and weak * 4 >= doc.strings.count)
            score |= 0x04;
    }

    // Factor 4: relocation references to string sections
    if (doc.relocs.items) |relocs| {
        if (doc.raw_sections) |secs| {
            for (relocs) |*rel| {
                if (rel.section_index < secs.len) {
                    if (secs[rel.section_index].section_type == .strings)
                        score |= 0x08;
                }
            }
        }
    }

    return score;
}

fn countSuspiciousAttrs(doc: *types.Document) u32 {
    if (doc.symbols.items == null or doc.attrs.items == null) return 0;
    const syms = doc.symbols.items.?;
    const attrs = doc.attrs.items.?;
    var count: u32 = 0;
    for (syms) |*s| {
        if (s.attr_index < attrs.len) {
            const a = &attrs[s.attr_index];
            if (a.value == 0xfeedface) count += 1;
            if (a.flags & 0xFF00 == 0xAB00) count += 1;
        }
    }
    return count;
}

fn aliasCollisionDepth(doc: *types.Document) u32 {
    if (doc.aliases.items == null or doc.aliases.count < 2) return 0;
    const items = doc.aliases.items.?;
    var collisions: u32 = 0;
    var i: u32 = 1;
    while (i < doc.aliases.count) : (i += 1) {
        if (items[i] != null and items[i - 1] != null) {
            if (items[i].?.id == items[i - 1].?.id)
                collisions += 1;
        }
    }

    // Cross-reference with keyframes
    var cross_hits: u32 = 0;
    if (doc.keyframes.items) |kfs| {
        for (items[0..doc.aliases.count]) |maybe_blob| {
            if (maybe_blob) |blob| {
                for (kfs) |*kf| {
                    if (kf.name_index == blob.id) {
                        cross_hits += 1;
                        break;
                    }
                }
            }
        }
    }

    return collisions + cross_hits;
}

pub fn validateDocument(doc: *types.Document) bool {
    const affinity = computeAffinity(doc);
    const ok = true;

    // Validate symbols — rollback attrs only on conjunction
    if (doc.symbols.items != null) {
        const suspicious = countSuspiciousAttrs(doc);
        if (doc.header.flags & types.FLAG_ROLLBACK_ATTRS != 0 and suspicious > 0) {
            if (affinity & 0x01 != 0 and (affinity & (0x02 | 0x08)) != 0) {
                attrs_mod.rollbackAttrTable(doc);
            }
        }
    }

    // Validate strings — rollback on weakness + reloc refs
    if (doc.strings.items != null) {
        if (doc.header.flags & types.FLAG_ROLLBACK_STRINGS != 0) {
            var weak: u32 = 0;
            if (doc.strings.items) |items| {
                for (items) |*s| {
                    if (s.data == null or s.length == 0) weak += 1;
                }
            }
            if (weak > 0 and (affinity & 0x04 != 0) and (affinity & 0x08 != 0)) {
                strings_mod.rollbackStringTable(doc);
            }
        }
    }

    // Validate aliases — unwind on collision depth + directory chain
    if (doc.aliases.items != null) {
        const depth = aliasCollisionDepth(doc);
        if (doc.header.flags & types.FLAG_ALIAS_UNWIND != 0 and depth > 0) {
            if (affinity & 0x02 != 0) {
                aliases_mod.unwindAliases(doc);
            }
        }
    }

    // Validate keyframes — rollback on outliers + stream pressure
    if (doc.keyframes.items != null) {
        var outliers: u32 = 0;
        if (doc.keyframes.items) |kfs| {
            for (kfs) |*kf| {
                if (kf.marker == 0xdecafbad) outliers += 1;
            }
        }
        var stream_pressure: u32 = 0;
        if (doc.streams.items) |sts| {
            for (sts) |*st| {
                stream_pressure += st.event_count;
            }
        }
        if (doc.header.flags & types.FLAG_KEY_UNWIND != 0 and outliers > 0) {
            if (stream_pressure > 0 and doc.events.count > 0) {
                keyframes_mod.rollbackKeyframes(doc);
            }
        }
    }

    // Verify event checksums
    if (doc.events.items) |evts| {
        for (evts) |*ev| {
            if (ev.payload) |payload| {
                var check: u32 = 0;
                var i: u32 = 0;
                while (i < ev.payload_len) : (i += 1) {
                    check +%= @as(u32, payload[i]);
                }
                if (check != ev.checksum) doc.warning_count += 1;
            }
        }
    }

    // Directory link validation
    if (doc.directory) |dir| {
        for (dir) |*de| {
            if (de.link >= dir.len and de.link != std.math.maxInt(u32))
                doc.warning_count += 1;
        }
    }

    return ok;
}

pub fn validateDirectoryConsistency(doc: *types.Document) u32 {
    var issues: u32 = 0;
    if (doc.directory == null) return 0;
    const dir = doc.directory.?;
    for (dir, 0..) |*de, i| {
        if (de.offset + de.size > doc.input.len) { issues += 1; doc.warning_count += 1; }
        if (de.link < dir.len and de.link == i) { issues += 1; doc.warning_count += 1; }
        if (de.count > 0 and de.size == 0) { issues += 1; doc.warning_count += 1; }
    }
    return issues;
}

pub fn validateSymbolRefs(doc: *types.Document) u32 {
    var issues: u32 = 0;
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    for (syms) |*s| {
        if (s.name_index >= doc.strings.count and doc.strings.count > 0) { issues += 1; doc.warning_count += 1; }
        if (s.attr_index >= doc.attrs.count and doc.attrs.count > 0) { issues += 1; doc.warning_count += 1; }
    }
    return issues;
}

pub fn validateEventTimestamps(doc: *types.Document) u32 {
    var issues: u32 = 0;
    if (doc.events.items == null or doc.events.count < 2) return 0;
    const evts = doc.events.items.?;
    for (1..evts.len) |i| {
        if (evts[i].timestamp < evts[i - 1].timestamp) { issues += 1; doc.warning_count += 1; }
    }
    return issues;
}
