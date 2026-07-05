const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");
const keyframes = @import("keyframes.zig");

pub fn parseStreams(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .streams) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_STREAMS) return;

    const items = allocator.alloc(types.Stream, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 16 <= data.len) {
        const stream_id = std.mem.readInt(u32, data[offset..][0..4], .little);
        const key_idx = std.mem.readInt(u32, data[offset + 4 ..][0..4], .little);
        const evt_count = std.mem.readInt(u32, data[offset + 8 ..][0..4], .little);
        const flags = std.mem.readInt(u32, data[offset + 12 ..][0..4], .little);

        var key_cache: ?*types.Keyframe = null;
        if (doc.keyframes.items) |kfs| {
            if (key_idx < kfs.len) key_cache = &kfs[key_idx];
        }

        items[parsed] = types.Stream{
            .stream_id = stream_id,
            .key_index = key_idx,
            .event_count = evt_count,
            .flags = flags,
            .key_cache = key_cache,
            .materialized = false,
        };

        offset += 16;
        parsed += 1;
    }

    doc.streams.items = items[0..parsed];
    doc.streams.count = parsed;
    doc.streams.capacity = count;
}

pub fn computeStreamPressure(doc: *const types.Document) u32 {
    if (doc.streams.items == null) return 0;
    const items = doc.streams.items.?;
    var pressure: u32 = 0;
    for (items) |*st| {
        pressure +|= st.event_count;
    }
    return pressure;
}

pub fn materializeStreams(doc: *types.Document) u32 {
    if (doc.streams.items == null) return 0;
    const items = doc.streams.items.?;
    var materialized: u32 = 0;
    for (items) |*st| {
        if (st.key_cache) |kc| {
            if (kc.label) |label| {
                _ = label;
                st.materialized = true;
                materialized += 1;
            }
        }
    }
    return materialized;
}

pub fn freeStreams(allocator: std.mem.Allocator, streams: *types.StreamTable) void {
    if (streams.items) |items| allocator.free(items);
    streams.items = null;
    streams.count = 0;
}

pub fn streamHash(doc: *const types.Document) u32 {
    if (doc.streams.items == null) return 0;
    const items = doc.streams.items.?;
    var h: u32 = 0;
    for (items) |*st| {
        h ^= st.stream_id;
        h *%= 0x5bd1e995;
        h ^= st.event_count;
        h ^= h >> 13;
    }
    return h;
}
