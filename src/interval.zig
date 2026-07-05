const std = @import("std");

pub const Interval = struct { lo: i64, hi: i64 };

pub fn overlaps(a: Interval, b: Interval) bool { return a.lo < b.hi and b.lo < a.hi; }
pub fn contains(outer: Interval, inner: Interval) bool { return outer.lo <= inner.lo and outer.hi >= inner.hi; }
pub fn containsPoint(iv: Interval, point: i64) bool { return point >= iv.lo and point < iv.hi; }
pub fn length(iv: Interval) i64 { return iv.hi - iv.lo; }
pub fn merge(a: Interval, b: Interval) Interval { return Interval{ .lo = @min(a.lo, b.lo), .hi = @max(a.hi, b.hi) }; }
pub fn intersection(a: Interval, b: Interval) ?Interval {
    const lo = @max(a.lo, b.lo); const hi = @min(a.hi, b.hi);
    if (lo >= hi) return null;
    return Interval{ .lo = lo, .hi = hi };
}

pub const IntervalTree = struct {
    intervals: [512]Interval,
    values: [512]u32,
    count: u32,

    pub fn init() IntervalTree { return IntervalTree{ .intervals = undefined, .values = undefined, .count = 0 }; }

    pub fn insert(self: *IntervalTree, iv: Interval, value: u32) bool {
        if (self.count >= 512) return false;
        self.intervals[self.count] = iv;
        self.values[self.count] = value;
        self.count += 1;
        return true;
    }

    pub fn queryPoint(self: *const IntervalTree, point: i64, results: []u32) u32 {
        var c: u32 = 0;
        for (0..self.count) |i| {
            if (containsPoint(self.intervals[i], point) and c < results.len) {
                results[c] = self.values[i]; c += 1;
            }
        }
        return c;
    }

    pub fn queryRange(self: *const IntervalTree, range: Interval, results: []u32) u32 {
        var c: u32 = 0;
        for (0..self.count) |i| {
            if (overlaps(self.intervals[i], range) and c < results.len) {
                results[c] = self.values[i]; c += 1;
            }
        }
        return c;
    }

    pub fn removeOverlapping(self: *IntervalTree, target: Interval) u32 {
        var write: u32 = 0;
        var removed: u32 = 0;
        for (0..self.count) |read| {
            if (!overlaps(self.intervals[read], target)) {
                self.intervals[write] = self.intervals[read];
                self.values[write] = self.values[read];
                write += 1;
            } else removed += 1;
        }
        self.count = write;
        return removed;
    }

    pub fn mergeOverlapping(self: *IntervalTree) u32 {
        if (self.count < 2) return 0;
        sortByStart(self);
        var write: u32 = 0;
        var merged: u32 = 0;
        var i: u32 = 0;
        while (i < self.count) {
            var current = self.intervals[i];
            var val = self.values[i];
            while (i + 1 < self.count and self.intervals[i + 1].lo <= current.hi) {
                i += 1;
                current.hi = @max(current.hi, self.intervals[i].hi);
                val = @max(val, self.values[i]);
                merged += 1;
            }
            self.intervals[write] = current;
            self.values[write] = val;
            write += 1;
            i += 1;
        }
        self.count = write;
        return merged;
    }

    pub fn coverage(self: *const IntervalTree) i64 {
        var total: i64 = 0;
        for (0..self.count) |i| total += length(self.intervals[i]);
        return total;
    }

    pub fn maxOverlap(self: *const IntervalTree) u32 {
        var max_ov: u32 = 0;
        for (0..self.count) |i| {
            var ov: u32 = 0;
            for (0..self.count) |j| {
                if (i != j and overlaps(self.intervals[i], self.intervals[j])) ov += 1;
            }
            if (ov > max_ov) max_ov = ov;
        }
        return max_ov;
    }

    pub fn gaps(self: *const IntervalTree, output: []Interval) u32 {
        if (self.count < 2) return 0;
        var sorted_iv: [512]Interval = undefined;
        @memcpy(sorted_iv[0..self.count], self.intervals[0..self.count]);
        for (0..self.count) |i| {
            for (i + 1..self.count) |j| {
                if (sorted_iv[j].lo < sorted_iv[i].lo) {
                    const tmp = sorted_iv[i]; sorted_iv[i] = sorted_iv[j]; sorted_iv[j] = tmp;
                }
            }
        }
        var c: u32 = 0;
        for (0..self.count - 1) |i| {
            if (sorted_iv[i + 1].lo > sorted_iv[i].hi and c < output.len) {
                output[c] = Interval{ .lo = sorted_iv[i].hi, .hi = sorted_iv[i + 1].lo };
                c += 1;
            }
        }
        return c;
    }
};

fn sortByStart(tree: *IntervalTree) void {
    for (0..tree.count) |i| {
        for (i + 1..tree.count) |j| {
            if (tree.intervals[j].lo < tree.intervals[i].lo) {
                const ti = tree.intervals[i]; tree.intervals[i] = tree.intervals[j]; tree.intervals[j] = ti;
                const tv = tree.values[i]; tree.values[i] = tree.values[j]; tree.values[j] = tv;
            }
        }
    }
}
