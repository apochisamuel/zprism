const std = @import("std");

pub const InternEntry = struct { hash: u64, offset: u32, length: u32 };

pub const StringIntern = struct {
    allocator: std.mem.Allocator,
    entries: []InternEntry,
    entry_count: u32,
    capacity: u32,
    buffer: []u8,
    buf_used: u32,
    buf_cap: u32,

    pub fn init(allocator: std.mem.Allocator, capacity: u32, buf_size: u32) !StringIntern {
        return StringIntern{
            .allocator = allocator,
            .entries = try allocator.alloc(InternEntry, capacity),
            .entry_count = 0, .capacity = capacity,
            .buffer = try allocator.alloc(u8, buf_size),
            .buf_used = 0, .buf_cap = buf_size,
        };
    }

    pub fn deinit(self: *StringIntern) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.buffer);
    }

    pub fn intern(self: *StringIntern, data: []const u8) ?[]const u8 {
        const hash = computeHash(data);
        for (self.entries[0..self.entry_count]) |*entry| {
            if (entry.hash == hash and entry.length == data.len) {
                const stored = self.buffer[entry.offset..entry.offset + entry.length];
                if (std.mem.eql(u8, stored, data)) return stored;
            }
        }
        if (self.buf_used + data.len > self.buf_cap) return null;
        if (self.entry_count >= self.capacity) return null;
        @memcpy(self.buffer[self.buf_used..self.buf_used + data.len], data);
        self.entries[self.entry_count] = InternEntry{
            .hash = hash, .offset = self.buf_used, .length = @intCast(data.len),
        };
        self.buf_used += @intCast(data.len);
        self.entry_count += 1;
        return self.buffer[self.entries[self.entry_count - 1].offset..][0..data.len];
    }

    pub fn lookup(self: *const StringIntern, data: []const u8) ?[]const u8 {
        const hash = computeHash(data);
        for (self.entries[0..self.entry_count]) |*entry| {
            if (entry.hash == hash and entry.length == data.len) {
                const stored = self.buffer[entry.offset..entry.offset + entry.length];
                if (std.mem.eql(u8, stored, data)) return stored;
            }
        }
        return null;
    }

    pub fn count(self: *const StringIntern) u32 { return self.entry_count; }
    pub fn memoryUsed(self: *const StringIntern) u32 { return self.buf_used; }
};

fn computeHash(data: []const u8) u64 {
    var h: u64 = 0xcbf29ce484222325;
    for (data) |b| { h ^= @as(u64, b); h *%= 0x100000001b3; }
    return h;
}
