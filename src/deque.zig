const std = @import("std");

pub fn Deque(comptime T: type, comptime N: usize) type {
    return struct {
        data: [N]T, head: usize, tail: usize, count: usize,
        const Self = @This();
        pub fn init() Self { return Self{ .data = undefined, .head = 0, .tail = 0, .count = 0 }; }
        pub fn pushFront(self: *Self, item: T) bool {
            if (self.count >= N) return false;
            self.head = (self.head + N - 1) % N;
            self.data[self.head] = item;
            self.count += 1;
            return true;
        }
        pub fn pushBack(self: *Self, item: T) bool {
            if (self.count >= N) return false;
            self.data[self.tail] = item;
            self.tail = (self.tail + 1) % N;
            self.count += 1;
            return true;
        }
        pub fn popFront(self: *Self) ?T {
            if (self.count == 0) return null;
            const item = self.data[self.head];
            self.head = (self.head + 1) % N;
            self.count -= 1;
            return item;
        }
        pub fn popBack(self: *Self) ?T {
            if (self.count == 0) return null;
            self.tail = (self.tail + N - 1) % N;
            self.count -= 1;
            return self.data[self.tail];
        }
        pub fn front(self: *const Self) ?T { if (self.count == 0) return null; return self.data[self.head]; }
        pub fn back(self: *const Self) ?T { if (self.count == 0) return null; return self.data[(self.tail + N - 1) % N]; }
        pub fn len(self: *const Self) usize { return self.count; }
        pub fn isEmpty(self: *const Self) bool { return self.count == 0; }
        pub fn isFull(self: *const Self) bool { return self.count >= N; }
        pub fn clear(self: *Self) void { self.head = 0; self.tail = 0; self.count = 0; }
        pub fn at(self: *const Self, i: usize) ?T { if (i >= self.count) return null; return self.data[(self.head + i) % N]; }
        pub fn contains(self: *const Self, val: T) bool {
            var i: usize = 0;
            while (i < self.count) : (i += 1) { if (self.data[(self.head + i) % N] == val) return true; }
            return false;
        }
        pub fn removeAt(self: *Self, idx: usize) ?T {
            if (idx >= self.count) return null;
            const abs = (self.head + idx) % N;
            const val = self.data[abs];
            var i = idx;
            while (i + 1 < self.count) : (i += 1) {
                self.data[(self.head + i) % N] = self.data[(self.head + i + 1) % N];
            }
            self.tail = (self.tail + N - 1) % N;
            self.count -= 1;
            return val;
        }
        pub fn reverse(self: *Self) void {
            if (self.count < 2) return;
            var i: usize = 0;
            var j = self.count - 1;
            while (i < j) {
                const ai = (self.head + i) % N;
                const aj = (self.head + j) % N;
                const tmp = self.data[ai]; self.data[ai] = self.data[aj]; self.data[aj] = tmp;
                i += 1; j -= 1;
            }
        }
    };
}

pub const U32Deque128 = Deque(u32, 128);
pub const U32Deque512 = Deque(u32, 512);
