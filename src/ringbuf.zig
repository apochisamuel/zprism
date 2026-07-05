const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime N: usize) type {
    return struct {
        data: [N]T,
        head: usize,
        tail: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .data = std.mem.zeroes([N]T),
                .head = 0, .tail = 0, .count = 0,
            };
        }

        pub fn push(self: *Self, item: T) bool {
            if (self.count >= N) return false;
            self.data[self.tail] = item;
            self.tail = (self.tail + 1) % N;
            self.count += 1;
            return true;
        }

        pub fn pop(self: *Self) ?T {
            if (self.count == 0) return null;
            const item = self.data[self.head];
            self.head = (self.head + 1) % N;
            self.count -= 1;
            return item;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.count == 0) return null;
            return self.data[self.head];
        }

        pub fn peekBack(self: *const Self) ?T {
            if (self.count == 0) return null;
            return self.data[(self.tail + N - 1) % N];
        }

        pub fn isFull(self: *const Self) bool { return self.count >= N; }
        pub fn isEmpty(self: *const Self) bool { return self.count == 0; }
        pub fn len(self: *const Self) usize { return self.count; }
        pub fn capacity() usize { return N; }

        pub fn clear(self: *Self) void {
            self.head = 0; self.tail = 0; self.count = 0;
        }

        pub fn at(self: *const Self, index: usize) ?T {
            if (index >= self.count) return null;
            return self.data[(self.head + index) % N];
        }

        pub fn toSlice(self: *const Self, output: []T) u32 {
            var c: u32 = 0;
            var i = self.head;
            while (c < self.count and c < output.len) {
                output[c] = self.data[i];
                i = (i + 1) % N;
                c += 1;
            }
            return c;
        }

        pub fn sum(self: *const Self) u64 {
            var s: u64 = 0;
            var i = self.head;
            var c: usize = 0;
            while (c < self.count) : (c += 1) {
                s += self.data[i];
                i = (i + 1) % N;
            }
            return s;
        }

        pub fn movingAvg(self: *const Self) f64 {
            if (self.count == 0) return 0;
            return @as(f64, @floatFromInt(self.sum())) / @as(f64, @floatFromInt(self.count));
        }
    };
}

pub const U32Ring64 = RingBuffer(u32, 64);
pub const U32Ring256 = RingBuffer(u32, 256);
pub const U8Ring1024 = RingBuffer(u8, 1024);
