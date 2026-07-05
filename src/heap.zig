const std = @import("std");

pub fn MinHeap(comptime T: type, comptime N: usize) type {
    return struct {
        data: [N]T,
        count: usize,

        const Self = @This();

        pub fn init() Self { return Self{ .data = undefined, .count = 0 }; }

        pub fn insert(self: *Self, val: T) bool {
            if (self.count >= N) return false;
            self.data[self.count] = val;
            self.count += 1;
            siftUp(self, self.count - 1);
            return true;
        }

        pub fn extractMin(self: *Self) ?T {
            if (self.count == 0) return null;
            const min = self.data[0];
            self.count -= 1;
            if (self.count > 0) {
                self.data[0] = self.data[self.count];
                siftDown(self, 0);
            }
            return min;
        }

        pub fn peekMin(self: *const Self) ?T {
            if (self.count == 0) return null;
            return self.data[0];
        }

        fn siftUp(self: *Self, idx: usize) void {
            var i = idx;
            while (i > 0) {
                const parent = (i - 1) / 2;
                if (self.data[i] >= self.data[parent]) break;
                const tmp = self.data[i]; self.data[i] = self.data[parent]; self.data[parent] = tmp;
                i = parent;
            }
        }

        fn siftDown(self: *Self, idx: usize) void {
            var i = idx;
            while (true) {
                var smallest = i;
                const left = 2 * i + 1;
                const right = 2 * i + 2;
                if (left < self.count and self.data[left] < self.data[smallest]) smallest = left;
                if (right < self.count and self.data[right] < self.data[smallest]) smallest = right;
                if (smallest == i) break;
                const tmp = self.data[i]; self.data[i] = self.data[smallest]; self.data[smallest] = tmp;
                i = smallest;
            }
        }

        pub fn isEmpty(self: *const Self) bool { return self.count == 0; }
        pub fn len(self: *const Self) usize { return self.count; }

        pub fn heapSort(self: *Self, output: []T) u32 {
            var c: u32 = 0;
            while (self.extractMin()) |val| {
                if (c >= output.len) break;
                output[c] = val;
                c += 1;
            }
            return c;
        }
    };
}

pub const U32MinHeap256 = MinHeap(u32, 256);
pub const U32MinHeap1024 = MinHeap(u32, 1024);

pub fn topK(data: []const u32, k: u32, output: []u32) u32 {
    var heap = MinHeap(u32, 256).init();
    for (data) |d| {
        if (heap.count < k) { _ = heap.insert(d); }
        else if (d > (heap.peekMin() orelse 0)) {
            _ = heap.extractMin();
            _ = heap.insert(d);
        }
    }
    return heap.heapSort(output);
}

pub fn bottomK(data: []const u32, k: u32, output: []u32) u32 {
    var sorted: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    @memcpy(sorted[0..n], data[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    const m = @min(k, @as(u32, @intCast(n)));
    @memcpy(output[0..m], sorted[0..m]);
    return m;
}
