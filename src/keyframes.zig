const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");
const strings = @import("strings.zig");

pub fn parseKeyframes(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .keyframes) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_KEYFRAMES) return;

    const items = allocator.alloc(types.Keyframe, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 16 <= data.len) {
        const frame_no = std.mem.readInt(u32, data[offset..][0..4], .little);
        const name_idx = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
        const marker = std.mem.readInt(u32, data[offset + 8 ..][0..4], .little);
        const kf_offset = std.mem.readInt(u32, data[offset + 12 ..][0..4], .little);

        items[parsed] = types.Keyframe{
            .frame_no = frame_no,
            .name_index = name_idx,
            .marker = marker,
            .offset = kf_offset,
            .label = strings.lookupString(&doc.*, name_idx),
        };

        offset += 16;
        parsed += 1;
    }

    doc.keyframes.items = items[0..parsed];
    doc.keyframes.count = parsed;
    doc.keyframes.capacity = count;
}

pub fn freeKeyframes(allocator: std.mem.Allocator, kfs: *types.KeyframeTable) void {
    if (kfs.items) |items| allocator.free(items);
    kfs.items = null;
    kfs.count = 0;
}

pub fn keyframeByIndex(doc: *const types.Document, index: u32) ?*const types.Keyframe {
    if (doc.keyframes.items == null) return null;
    const items = doc.keyframes.items.?;
    if (index >= items.len) return null;
    return &items[index];
}

pub fn countOutliers(doc: *const types.Document) u32 {
    if (doc.keyframes.items == null) return 0;
    const items = doc.keyframes.items.?;
    var outliers: u32 = 0;
    for (items) |*kf| {
        if (kf.marker == 0xdecafbad) outliers += 1;
        if (doc.events.items) |evts| {
            if (kf.frame_no >= evts.len + 1024) outliers += 1;
        }
    }
    return outliers;
}

pub fn computeSpan(doc: *const types.Document) u64 {
    if (doc.keyframes.items == null or doc.keyframes.count < 2) return 0;
    const items = doc.keyframes.items.?;
    var min_frame: u32 = std.math.maxInt(u32);
    var max_frame: u32 = 0;
    for (items) |*kf| {
        if (kf.frame_no < min_frame) min_frame = kf.frame_no;
        if (kf.frame_no > max_frame) max_frame = kf.frame_no;
    }
    return @as(u64, max_frame) - @as(u64, min_frame);
}

fn mixHash(a: u32, b: u32) u32 {
    var h = a;
    h ^= b;
    h *%= 0x5bd1e995;
    h ^= h >> 13;
    return h;
}

pub fn keyframeHash(doc: *const types.Document) u32 {
    if (doc.keyframes.items == null) return 0;
    const items = doc.keyframes.items.?;
    var h: u32 = 0;
    for (items) |*kf| {
        h = mixHash(h, kf.frame_no ^ kf.marker);
        h = mixHash(h, kf.name_index);
    }
    return h;
}

pub fn rollbackKeyframes(doc: *types.Document) void {
    if (doc.keyframes.items == null) return;
    const items = doc.keyframes.items.?;
    doc.allocator.free(items);
    doc.keyframes.count = 0;
}
