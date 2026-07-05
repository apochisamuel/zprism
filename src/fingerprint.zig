const std = @import("std");
const types = @import("types.zig");

pub const Fingerprint = struct {
    structure_hash: u64, content_hash: u64,
    section_signature: [8]u8, version_tag: u32,
    feature_bits: u32,
};

pub fn computeFingerprint(doc: *const types.Document) Fingerprint {
    var fp = std.mem.zeroes(Fingerprint);
    fp.structure_hash = computeStructureHash(doc);
    fp.content_hash = computeContentHash(doc);
    fp.section_signature = computeSectionSignature(doc);
    fp.version_tag = doc.header.version;
    fp.feature_bits = computeFeatureBits(doc);
    return fp;
}

fn computeStructureHash(doc: *const types.Document) u64 {
    var h: u64 = 0xcbf29ce484222325;
    h = fnv64(h, doc.header.section_count);
    h = fnv64(h, doc.header.directory_count);
    h = fnv64(h, doc.symbols.count);
    h = fnv64(h, doc.strings.count);
    h = fnv64(h, doc.attrs.count);
    h = fnv64(h, doc.relocs.count);
    h = fnv64(h, doc.events.count);
    h = fnv64(h, doc.keyframes.count);
    h = fnv64(h, doc.streams.count);
    h = fnv64(h, doc.aliases.count);
    return h;
}

fn computeContentHash(doc: *const types.Document) u64 {
    var h: u64 = 0xcbf29ce484222325;
    if (doc.symbols.items) |syms| {
        for (syms) |*s| { h = fnv64(h, s.derived_score); }
    }
    if (doc.events.items) |evts| {
        for (evts) |*ev| { h = fnv64(h, ev.checksum); }
    }
    h = fnv64(h, doc.cache.combined_hash);
    return h;
}

fn computeSectionSignature(doc: *const types.Document) [8]u8 {
    var sig = [_]u8{0} ** 8;
    if (doc.raw_sections) |secs| {
        for (secs, 0..) |*sec, i| {
            if (i >= 8) break;
            sig[i] = @intFromEnum(sec.section_type);
        }
    }
    return sig;
}

fn computeFeatureBits(doc: *const types.Document) u32 {
    var bits: u32 = 0;
    if (doc.symbols.count > 0) bits |= 0x01;
    if (doc.strings.count > 0) bits |= 0x02;
    if (doc.attrs.count > 0) bits |= 0x04;
    if (doc.relocs.count > 0) bits |= 0x08;
    if (doc.events.count > 0) bits |= 0x10;
    if (doc.keyframes.count > 0) bits |= 0x20;
    if (doc.streams.count > 0) bits |= 0x40;
    if (doc.aliases.count > 0) bits |= 0x80;
    if (doc.header.flags & types.FLAG_TYPE_SWEEP != 0) bits |= 0x100;
    if (doc.header.flags & types.FLAG_FRAME_TRUST != 0) bits |= 0x200;
    return bits;
}

fn fnv64(h: u64, val: u32) u64 {
    var hash = h;
    hash ^= @as(u64, val);
    hash *%= 0x100000001b3;
    hash ^= @as(u64, val >> 16);
    hash *%= 0x100000001b3;
    return hash;
}

pub fn fingerprintMatch(a: *const Fingerprint, b: *const Fingerprint) f64 {
    var score: f64 = 0;
    if (a.structure_hash == b.structure_hash) score += 0.4;
    if (a.content_hash == b.content_hash) score += 0.3;
    if (std.mem.eql(u8, &a.section_signature, &b.section_signature)) score += 0.15;
    if (a.version_tag == b.version_tag) score += 0.05;
    var common_bits: u32 = 0;
    var total_bits: u32 = 0;
    var mask: u32 = 1;
    while (mask != 0) : (mask <<= 1) {
        const aa = a.feature_bits & mask != 0;
        const bb = b.feature_bits & mask != 0;
        if (aa or bb) { total_bits += 1; if (aa and bb) common_bits += 1; }
    }
    if (total_bits > 0) score += 0.1 * @as(f64, @floatFromInt(common_bits)) / @as(f64, @floatFromInt(total_bits));
    return score;
}
