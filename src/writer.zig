const std = @import("std");
const types = @import("types.zig");

pub const Writer = struct {
    buffer: []u8,
    pos: usize,
    capacity: usize,

    pub fn init(buffer: []u8) Writer {
        return Writer{ .buffer = buffer, .pos = 0, .capacity = buffer.len };
    }

    pub fn writeU8(self: *Writer, val: u8) bool {
        if (self.pos >= self.capacity) return false;
        self.buffer[self.pos] = val;
        self.pos += 1;
        return true;
    }

    pub fn writeU16(self: *Writer, val: u16) bool {
        if (self.pos + 2 > self.capacity) return false;
        self.buffer[self.pos] = @truncate(val);
        self.buffer[self.pos + 1] = @truncate(val >> 8);
        self.pos += 2;
        return true;
    }

    pub fn writeU32(self: *Writer, val: u32) bool {
        if (self.pos + 4 > self.capacity) return false;
        self.buffer[self.pos] = @truncate(val);
        self.buffer[self.pos + 1] = @truncate(val >> 8);
        self.buffer[self.pos + 2] = @truncate(val >> 16);
        self.buffer[self.pos + 3] = @truncate(val >> 24);
        self.pos += 4;
        return true;
    }

    pub fn writeU64(self: *Writer, val: u64) bool {
        if (self.pos + 8 > self.capacity) return false;
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            self.buffer[self.pos + i] = @truncate(val >> @intCast(i * 8));
        }
        self.pos += 8;
        return true;
    }

    pub fn writeBytes(self: *Writer, data: []const u8) bool {
        if (self.pos + data.len > self.capacity) return false;
        @memcpy(self.buffer[self.pos..self.pos + data.len], data);
        self.pos += data.len;
        return true;
    }

    pub fn writeHeader(self: *Writer, header: *const types.Header) bool {
        if (!self.writeU32(header.magic)) return false;
        if (!self.writeU16(header.version)) return false;
        if (!self.writeU32(header.flags)) return false;
        if (!self.writeU16(header.section_count)) return false;
        if (!self.writeU16(header.directory_count)) return false;
        if (!self.writeU32(header.file_id)) return false;
        if (!self.writeU32(header.total_size)) return false;
        if (!self.writeBytes(&header.reserved)) return false;
        return true;
    }

    pub fn writeDirectoryEntry(self: *Writer, de: *const types.DirectoryEntry) bool {
        if (!self.writeU8(@intFromEnum(de.section_type))) return false;
        if (!self.writeU32(de.offset)) return false;
        if (!self.writeU32(de.size)) return false;
        if (!self.writeU32(de.count)) return false;
        if (!self.writeU32(de.link)) return false;
        if (!self.writeU32(de.aux)) return false;
        return true;
    }

    pub fn pad(self: *Writer, alignment: usize) bool {
        while (self.pos % alignment != 0) {
            if (!self.writeU8(0)) return false;
        }
        return true;
    }

    pub fn remaining(self: *const Writer) usize { return self.capacity - self.pos; }
    pub fn written(self: *const Writer) usize { return self.pos; }

    pub fn seek(self: *Writer, pos: usize) bool {
        if (pos > self.capacity) return false;
        self.pos = pos;
        return true;
    }

    pub fn patchU32(self: *Writer, offset: usize, val: u32) bool {
        if (offset + 4 > self.capacity) return false;
        self.buffer[offset] = @truncate(val);
        self.buffer[offset + 1] = @truncate(val >> 8);
        self.buffer[offset + 2] = @truncate(val >> 16);
        self.buffer[offset + 3] = @truncate(val >> 24);
        return true;
    }
};

pub fn serializeDocument(doc: *const types.Document, buffer: []u8) usize {
    var w = Writer.init(buffer);
    if (!w.writeHeader(&doc.header)) return 0;
    if (doc.directory) |dir| {
        for (dir) |*de| {
            if (!w.writeDirectoryEntry(de)) return w.written();
        }
    }
    return w.written();
}

pub fn computeSerializedSize(doc: *const types.Document) usize {
    var size: usize = 32;
    size += @as(usize, doc.directory_count) * 24;
    if (doc.raw_sections) |secs| {
        for (secs) |*sec| size += sec.size;
    }
    return size;
}
