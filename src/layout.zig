const std = @import("std");
const types = @import("types.zig");

pub const LayoutRegion = struct {
    start: u32, end: u32, size: u32,
    region_type: RegionType, section_index: u32,
    alignment: u32, padding_before: u32,
};

pub const RegionType = enum { header, directory, section_data, padding, unmapped };

pub const LayoutMap = struct {
    regions: [256]LayoutRegion,
    count: u32,
    total_size: u32,
    mapped_bytes: u32,
    unmapped_bytes: u32,
    padding_bytes: u32,
    alignment_violations: u32,
};

pub fn analyzeLayout(doc: *const types.Document) LayoutMap {
    var map = std.mem.zeroes(LayoutMap);
    map.total_size = @intCast(doc.input.len);
    addRegion(&map, 0, 32, .header, 0);
    if (doc.directory) |dir| {
        const dir_start: u32 = 32;
        const dir_size: u32 = @intCast(dir.len * 24);
        addRegion(&map, dir_start, dir_start + dir_size, .directory, 0);
    }
    if (doc.raw_sections) |secs| {
        for (secs, 0..) |*sec, i| {
            addRegion(&map, sec.offset, sec.offset + sec.size, .section_data, @intCast(i));
        }
    }
    sortRegions(&map);
    findGaps(&map);
    computeStats(&map);
    return map;
}

fn addRegion(map: *LayoutMap, start: u32, end: u32, rtype: RegionType, sec_idx: u32) void {
    if (map.count >= 256) return;
    map.regions[map.count] = LayoutRegion{
        .start = start, .end = end, .size = end -| start,
        .region_type = rtype, .section_index = sec_idx,
        .alignment = computeAlignment(start), .padding_before = 0,
    };
    map.count += 1;
}

fn sortRegions(map: *LayoutMap) void {
    if (map.count < 2) return;
    for (0..map.count) |i| {
        for (i + 1..map.count) |j| {
            if (map.regions[j].start < map.regions[i].start) {
                const tmp = map.regions[i];
                map.regions[i] = map.regions[j];
                map.regions[j] = tmp;
            }
        }
    }
}

fn findGaps(map: *LayoutMap) void {
    if (map.count < 2) return;
    var insert_count = map.count;
    for (1..map.count) |i| {
        if (map.regions[i].start > map.regions[i - 1].end and insert_count < 256) {
            map.regions[insert_count] = LayoutRegion{
                .start = map.regions[i - 1].end,
                .end = map.regions[i].start,
                .size = map.regions[i].start - map.regions[i - 1].end,
                .region_type = .padding,
                .section_index = 0, .alignment = 1, .padding_before = 0,
            };
            insert_count += 1;
        }
    }
    map.count = insert_count;
}

fn computeStats(map: *LayoutMap) void {
    for (map.regions[0..map.count]) |*r| {
        switch (r.region_type) {
            .section_data, .header, .directory => map.mapped_bytes += r.size,
            .padding => map.padding_bytes += r.size,
            .unmapped => map.unmapped_bytes += r.size,
        }
        if (r.alignment < 4 and r.region_type == .section_data) map.alignment_violations += 1;
    }
}

fn computeAlignment(offset: u32) u32 {
    if (offset == 0) return 0;
    var alignment: u32 = 1;
    while (alignment < 4096 and offset % (alignment * 2) == 0) alignment *= 2;
    return alignment;
}

pub fn layoutEfficiency(map: *const LayoutMap) f64 {
    if (map.total_size == 0) return 0;
    return @as(f64, @floatFromInt(map.mapped_bytes)) / @as(f64, @floatFromInt(map.total_size));
}

pub fn findLargestGap(map: *const LayoutMap) u32 {
    var max_gap: u32 = 0;
    for (map.regions[0..map.count]) |*r| {
        if (r.region_type == .padding and r.size > max_gap) max_gap = r.size;
    }
    return max_gap;
}

pub fn overlapCheck(map: *const LayoutMap) u32 {
    var overlaps: u32 = 0;
    for (0..map.count) |i| {
        for (i + 1..map.count) |j| {
            if (map.regions[i].start < map.regions[j].end and
                map.regions[j].start < map.regions[i].end)
            {
                overlaps += 1;
            }
        }
    }
    return overlaps;
}
