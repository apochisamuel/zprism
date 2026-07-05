const std = @import("std");

pub const SlidingWindow = struct {
    data: [4096]u32,
    size: u32,
    pos: u32,
    count: u32,
    sum: u64,
    min_val: u32,
    max_val: u32,

    pub fn init(window_size: u32) SlidingWindow {
        return SlidingWindow{
            .data = std.mem.zeroes([4096]u32),
            .size = @min(window_size, 4096),
            .pos = 0, .count = 0, .sum = 0,
            .min_val = std.math.maxInt(u32), .max_val = 0,
        };
    }

    pub fn push(self: *SlidingWindow, val: u32) void {
        if (self.count >= self.size) {
            self.sum -= self.data[self.pos];
        }
        self.data[self.pos] = val;
        self.sum += val;
        self.pos = (self.pos + 1) % self.size;
        if (self.count < self.size) self.count += 1;
        self.updateMinMax();
    }

    fn updateMinMax(self: *SlidingWindow) void {
        self.min_val = std.math.maxInt(u32);
        self.max_val = 0;
        const start = if (self.count >= self.size) self.pos else 0;
        for (0..self.count) |i| {
            const idx = (start + i) % self.size;
            if (self.data[idx] < self.min_val) self.min_val = self.data[idx];
            if (self.data[idx] > self.max_val) self.max_val = self.data[idx];
        }
    }

    pub fn mean(self: *const SlidingWindow) f64 {
        if (self.count == 0) return 0;
        return @as(f64, @floatFromInt(self.sum)) / @as(f64, @floatFromInt(self.count));
    }

    pub fn variance(self: *const SlidingWindow) f64 {
        if (self.count < 2) return 0;
        const m = self.mean();
        var v: f64 = 0;
        const start = if (self.count >= self.size) self.pos else 0;
        for (0..self.count) |i| {
            const idx = (start + i) % self.size;
            const diff = @as(f64, @floatFromInt(self.data[idx])) - m;
            v += diff * diff;
        }
        return v / @as(f64, @floatFromInt(self.count));
    }

    pub fn stddev(self: *const SlidingWindow) f64 { return @sqrt(self.variance()); }
    pub fn range(self: *const SlidingWindow) u32 { return self.max_val -| self.min_val; }

    pub fn percentile(self: *const SlidingWindow, pct: u32) u32 {
        if (self.count == 0) return 0;
        var sorted: [4096]u32 = undefined;
        const start = if (self.count >= self.size) self.pos else 0;
        for (0..self.count) |i| sorted[i] = self.data[(start + i) % self.size];
        std.sort.insertion(u32, sorted[0..self.count], {}, std.sort.asc(u32));
        const idx = (self.count * pct) / 100;
        return sorted[@min(idx, self.count - 1)];
    }

    pub fn iqr(self: *const SlidingWindow) u32 {
        return self.percentile(75) -| self.percentile(25);
    }

    pub fn zScore(self: *const SlidingWindow, val: u32) f64 {
        const sd = self.stddev();
        if (sd == 0) return 0;
        return (@as(f64, @floatFromInt(val)) - self.mean()) / sd;
    }

    pub fn isAnomaly(self: *const SlidingWindow, val: u32, threshold: f64) bool {
        return @abs(self.zScore(val)) > threshold;
    }

    pub fn trend(self: *const SlidingWindow) f64 {
        if (self.count < 2) return 0;
        const start = if (self.count >= self.size) self.pos else 0;
        const first = @as(f64, @floatFromInt(self.data[start]));
        const last = @as(f64, @floatFromInt(self.data[(start + self.count - 1) % self.size]));
        return (last - first) / @as(f64, @floatFromInt(self.count));
    }

    pub fn autocorrelation(self: *const SlidingWindow, lag: u32) f64 {
        if (self.count <= lag) return 0;
        const m = self.mean();
        var num: f64 = 0;
        var denom: f64 = 0;
        const start = if (self.count >= self.size) self.pos else 0;
        for (0..self.count - lag) |i| {
            const xi = @as(f64, @floatFromInt(self.data[(start + i) % self.size])) - m;
            const xlag = @as(f64, @floatFromInt(self.data[(start + i + lag) % self.size])) - m;
            num += xi * xlag;
        }
        for (0..self.count) |i| {
            const xi = @as(f64, @floatFromInt(self.data[(start + i) % self.size])) - m;
            denom += xi * xi;
        }
        if (denom == 0) return 0;
        return num / denom;
    }
};

pub const ExponentialMovingAvg = struct {
    value: f64, alpha: f64, initialized: bool,
    pub fn init(alpha: f64) ExponentialMovingAvg {
        return ExponentialMovingAvg{ .value = 0, .alpha = alpha, .initialized = false };
    }
    pub fn update(self: *ExponentialMovingAvg, val: f64) f64 {
        if (!self.initialized) { self.value = val; self.initialized = true; }
        else self.value = self.alpha * val + (1.0 - self.alpha) * self.value;
        return self.value;
    }
    pub fn current(self: *const ExponentialMovingAvg) f64 { return self.value; }
};
