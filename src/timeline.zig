const std = @import("std");
const types = @import("types.zig");

pub const TimelineEntry = struct { timestamp: u64, event_index: u32, keyframe_index: u32, stream_id: u32, entry_type: EntryType };
pub const EntryType = enum { event, keyframe, stream_start, stream_end };

pub fn buildTimeline(doc: *const types.Document, entries: []TimelineEntry) u32 {
    var count: u32 = 0;
    if (doc.events.items) |evts| {
        for (evts, 0..) |*ev, i| {
            if (count >= entries.len) break;
            entries[count] = TimelineEntry{
                .timestamp = ev.timestamp, .event_index = @intCast(i),
                .keyframe_index = 0, .stream_id = 0, .entry_type = .event,
            };
            count += 1;
        }
    }
    if (count > 1) {
        std.sort.insertion(TimelineEntry, entries[0..count], {}, struct {
            fn lessThan(_: void, a: TimelineEntry, b: TimelineEntry) bool { return a.timestamp < b.timestamp; }
        }.lessThan);
    }
    return count;
}

pub fn computeTimeSpan(doc: *const types.Document) u64 {
    if (doc.events.items == null or doc.events.count == 0) return 0;
    const evts = doc.events.items.?;
    var min_ts: u64 = std.math.maxInt(u64);
    var max_ts: u64 = 0;
    for (evts) |*ev| {
        if (ev.timestamp < min_ts) min_ts = ev.timestamp;
        if (ev.timestamp > max_ts) max_ts = ev.timestamp;
    }
    return max_ts - min_ts;
}

pub fn computeEventRate(doc: *const types.Document) f64 {
    const span = computeTimeSpan(doc);
    if (span == 0) return 0;
    return @as(f64, @floatFromInt(doc.events.count)) / @as(f64, @floatFromInt(span));
}

pub fn findBurst(doc: *const types.Document, window: u64) u32 {
    if (doc.events.items == null or doc.events.count < 2) return 0;
    const evts = doc.events.items.?;
    var max_burst: u32 = 0;
    for (evts, 0..) |*ev, i| {
        var burst: u32 = 1;
        for (evts[i + 1 ..]) |*other| {
            if (other.timestamp > ev.timestamp + window) break;
            burst += 1;
        }
        if (burst > max_burst) max_burst = burst;
    }
    return max_burst;
}

pub fn gapAnalysis(doc: *const types.Document, gaps: []u64) u32 {
    if (doc.events.items == null or doc.events.count < 2) return 0;
    const evts = doc.events.items.?;
    var count: u32 = 0;
    for (1..evts.len) |i| {
        if (count >= gaps.len) break;
        gaps[count] = evts[i].timestamp -| evts[i - 1].timestamp;
        count += 1;
    }
    return count;
}
