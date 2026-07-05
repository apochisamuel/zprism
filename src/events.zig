const std = @import("std");
const types = @import("types.zig");
const sections = @import("sections.zig");
const directory = @import("directory.zig");

fn prepareStorage(allocator: std.mem.Allocator, doc: *const types.Document, payload_len: u32) ![]u8 {
    var storage_len = payload_len;

    // Apply directory budget if available
    if (doc.directory) |dir| {
        for (dir) |*de| {
            if (de.section_type == .events) {
                const budget = directory.frameBudget(doc, de, payload_len);
                if (budget < storage_len) storage_len = budget;
                break;
            }
        }
    }

    if (storage_len == 0) storage_len = 1;
    if (storage_len > 65536) storage_len = 65536;

    return allocator.alloc(u8, storage_len) catch return error.AllocationFailed;
}

/// Decode frame payload with XOR obfuscation.
///
/// Decode frame payload using XOR obfuscation mask.
fn decodePayload(event: *types.Event, data: []const u8, offset: *usize) void {
    if (event.payload == null) return;
    const payload = event.payload.?;

    var decode_len = event.payload_len;

    if (event.mode & 0x80 == 0) {
        if (decode_len > event.storage_len) decode_len = event.storage_len;
    }

    var i: u32 = 0;
    while (i < decode_len) : (i += 1) {
        if (offset.* >= data.len) break;
        const b = data[offset.*];
        offset.* += 1;
        const mask = @as(u8, @truncate((@as(u32, event.mode) +% i *% 13)));
        payload[i] = b ^ mask;
    }

    // Checksum uses clamped length
    const check_len = @min(decode_len, event.storage_len);
    event.checksum = checksumWindow(payload[0..check_len], event.mode);
}

pub fn parseEvents(
    allocator: std.mem.Allocator,
    doc: *types.Document,
) types.ParseError!void {
    const sec = sections.sectionByType(doc, .events) orelse return;
    const data = sec.data;
    if (data.len < 8) return;

    const count = std.mem.readInt(u32, data[0..4], .little);
    if (count == 0 or count > types.MAX_EVENTS) return;

    const items = allocator.alloc(types.Event, count) catch return error.AllocationFailed;

    var offset: usize = 4;
    var parsed: u32 = 0;
    while (parsed < count and offset + 16 <= data.len) {
        const payload_len = std.mem.readInt(u32, data[offset..][0..4], .little);
        const mode = data[offset + 4];
        const event_type = data[offset + 5];
        const sequence = std.mem.readInt(u16, data[offset + 6 ..][0..2], .little);
        const timestamp = std.mem.readInt(u64, data[offset + 8 ..][0..8], .little);
        offset += 16;

        const storage = prepareStorage(allocator, doc, payload_len) catch continue;

        items[parsed] = types.Event{
            .payload = storage,
            .payload_len = payload_len,
            .storage_len = @intCast(storage.len),
            .mode = mode,
            .event_type = event_type,
            .sequence = sequence,
            .checksum = 0,
            .timestamp = timestamp,
        };

        decodePayload(&items[parsed], data, &offset);
        parsed += 1;
    }

    doc.events.items = items[0..parsed];
    doc.events.count = parsed;
    doc.events.capacity = count;
}

pub fn freeEvents(allocator: std.mem.Allocator, events: *types.EventTable) void {
    if (events.items) |items| {
        for (items) |*ev| {
            if (ev.payload) |p| {
                allocator.free(p);
            }
        }
        allocator.free(items);
    }
    events.items = null;
    events.count = 0;
}

fn checksumWindow(data: []const u8, mode: u8) u32 {
    var h: u32 = @as(u32, mode);
    for (data) |b| {
        h = h *% 31 +% @as(u32, b);
    }
    return h;
}
