const std = @import("std");
const types = @import("types.zig");

pub fn parseHeader(data: []const u8) types.ParseError!types.Header {
    if (data.len < 32) return error.Truncated;

    var header: types.Header = undefined;
    header.magic = readU32(data, 0);
    if (header.magic != types.MAGIC) return error.InvalidMagic;

    header.version = readU16(data, 4);
    if (header.version == 0 or header.version > 4) return error.InvalidVersion;

    header.flags = readU32(data, 6);
    header.section_count = readU16(data, 10);
    header.directory_count = readU16(data, 12);
    header.file_id = readU32(data, 14);
    header.total_size = readU32(data, 18);

    if (header.section_count > types.MAX_SECTIONS) return error.TooManySections;
    if (header.directory_count > types.MAX_DIRECTORY) return error.TooManySections;

    @memcpy(&header.reserved, data[22..30]);

    return header;
}

pub fn validateHeader(header: *const types.Header, data_len: usize) bool {
    if (header.magic != types.MAGIC) return false;
    if (header.total_size > 0 and header.total_size > data_len) return false;
    return true;
}

fn readU32(data: []const u8, offset: usize) u32 {
    if (offset + 4 > data.len) return 0;
    return std.mem.readInt(u32, data[offset..][0..4], .little);
}

fn readU16(data: []const u8, offset: usize) u16 {
    if (offset + 2 > data.len) return 0;
    return std.mem.readInt(u16, data[offset..][0..2], .little);
}
