const std = @import("std");

pub fn LRUCache(comptime K: type, comptime V: type, comptime N: usize) type {
    return struct {
        keys: [N]K, values: [N]V, ages: [N]u32, count: usize, clock: u32,
        const Self = @This();
        pub fn init() Self { return Self{ .keys = undefined, .values = undefined, .ages = std.mem.zeroes([N]u32), .count = 0, .clock = 0 }; }
        pub fn get(self: *Self, key: K) ?V {
            for (0..self.count) |i| {
                if (self.keys[i] == key) { self.ages[i] = self.clock; self.clock +%= 1; return self.values[i]; }
            }
            return null;
        }
        pub fn put(self: *Self, key: K, value: V) void {
            for (0..self.count) |i| {
                if (self.keys[i] == key) { self.values[i] = value; self.ages[i] = self.clock; self.clock +%= 1; return; }
            }
            if (self.count < N) {
                self.keys[self.count] = key; self.values[self.count] = value;
                self.ages[self.count] = self.clock; self.clock +%= 1; self.count += 1;
            } else {
                var oldest: usize = 0;
                for (1..self.count) |i| { if (self.ages[i] < self.ages[oldest]) oldest = i; }
                self.keys[oldest] = key; self.values[oldest] = value;
                self.ages[oldest] = self.clock; self.clock +%= 1;
            }
        }
        pub fn remove(self: *Self, key: K) bool {
            for (0..self.count) |i| {
                if (self.keys[i] == key) {
                    self.keys[i] = self.keys[self.count - 1];
                    self.values[i] = self.values[self.count - 1];
                    self.ages[i] = self.ages[self.count - 1];
                    self.count -= 1; return true;
                }
            }
            return false;
        }
        pub fn contains(self: *const Self, key: K) bool {
            for (0..self.count) |i| { if (self.keys[i] == key) return true; }
            return false;
        }
        pub fn len(self: *const Self) usize { return self.count; }
        pub fn clear(self: *Self) void { self.count = 0; self.clock = 0; }
        pub fn hitRate(self: *const Self) f64 {
            if (self.clock == 0) return 0;
            return @as(f64, @floatFromInt(self.count)) / @as(f64, @floatFromInt(self.clock));
        }
    };
}

pub const U32Cache64 = LRUCache(u32, u32, 64);
pub const U32Cache256 = LRUCache(u32, u32, 256);
