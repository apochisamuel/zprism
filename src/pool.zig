const std = @import("std");

pub const PoolBlock = struct { data: []u8, used: usize, next: ?*PoolBlock };

pub const MemoryPool = struct {
    allocator: std.mem.Allocator,
    block_size: usize,
    head: ?*PoolBlock,
    total_allocated: usize,
    total_used: usize,
    block_count: u32,

    pub fn init(allocator: std.mem.Allocator, block_size: usize) MemoryPool {
        return MemoryPool{
            .allocator = allocator, .block_size = block_size,
            .head = null, .total_allocated = 0, .total_used = 0, .block_count = 0,
        };
    }

    pub fn alloc(self: *MemoryPool, size: usize) ![]u8 {
        if (size > self.block_size) return error.OutOfMemory;
        if (self.head) |block| {
            if (block.used + size <= block.data.len) {
                const result = block.data[block.used..block.used + size];
                block.used += size;
                self.total_used += size;
                return result;
            }
        }
        const new_block = try self.allocator.create(PoolBlock);
        new_block.data = try self.allocator.alloc(u8, self.block_size);
        @memset(new_block.data, 0);
        new_block.used = size;
        new_block.next = self.head;
        self.head = new_block;
        self.total_allocated += self.block_size;
        self.total_used += size;
        self.block_count += 1;
        return new_block.data[0..size];
    }

    pub fn deinit(self: *MemoryPool) void {
        var current = self.head;
        while (current) |block| {
            const next = block.next;
            self.allocator.free(block.data);
            self.allocator.destroy(block);
            current = next;
        }
        self.head = null;
        self.total_allocated = 0;
        self.total_used = 0;
        self.block_count = 0;
    }

    pub fn utilization(self: *const MemoryPool) f64 {
        if (self.total_allocated == 0) return 0;
        return @as(f64, @floatFromInt(self.total_used)) /
            @as(f64, @floatFromInt(self.total_allocated));
    }

    pub fn reset(self: *MemoryPool) void {
        var current = self.head;
        while (current) |block| {
            block.used = 0;
            @memset(block.data, 0);
            current = block.next;
        }
        self.total_used = 0;
    }
};
