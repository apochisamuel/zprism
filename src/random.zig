const std = @import("std");

pub const LCG = struct {
    state: u64,
    pub fn init(seed: u64) LCG { return LCG{ .state = seed }; }
    pub fn next(self: *LCG) u32 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return @truncate(self.state >> 33);
    }
    pub fn nextFloat(self: *LCG) f64 {
        return @as(f64, @floatFromInt(self.next())) / @as(f64, @floatFromInt(std.math.maxInt(u32)));
    }
    pub fn nextRange(self: *LCG, min: u32, max: u32) u32 {
        if (min >= max) return min;
        return min + self.next() % (max - min);
    }
};

pub const XorShift = struct {
    state: u64,
    pub fn init(seed: u64) XorShift { return XorShift{ .state = if (seed == 0) 1 else seed }; }
    pub fn next(self: *XorShift) u64 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        return self.state;
    }
    pub fn next32(self: *XorShift) u32 { return @truncate(self.next()); }
    pub fn nextFloat(self: *XorShift) f64 {
        return @as(f64, @floatFromInt(self.next32())) / @as(f64, @floatFromInt(std.math.maxInt(u32)));
    }
};

pub fn shuffle(rng: *LCG, data: []u32) void {
    if (data.len < 2) return;
    var i = data.len - 1;
    while (i > 0) : (i -= 1) {
        const j = rng.next() % @as(u32, @intCast(i + 1));
        const tmp = data[i]; data[i] = data[j]; data[j] = tmp;
    }
}

pub fn sample(rng: *LCG, population: []const u32, k: u32, output: []u32) u32 {
    if (population.len == 0 or k == 0) return 0;
    var indices: [4096]u32 = undefined;
    const n = @min(population.len, 4096);
    for (0..n) |i| indices[i] = @intCast(i);
    const m = @min(k, @as(u32, @intCast(n)));
    for (0..m) |i| {
        const j = i + rng.next() % @as(u32, @intCast(n - i));
        const tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp;
    }
    for (0..m) |i| {
        if (i < output.len) output[i] = population[indices[i]];
    }
    return m;
}

pub fn normalRandom(rng: *LCG) f64 {
    const rn1 = @max(rng.nextFloat(), 1e-10);
    const rn2 = rng.nextFloat();
    return @sqrt(-2.0 * @log(rn1)) * @cos(2.0 * std.math.pi * rn2);
}

pub fn exponentialRandom(rng: *LCG, lambda: f64) f64 {
    const u = @max(rng.nextFloat(), 1e-10);
    return -@log(u) / lambda;
}

pub fn poissonRandom(rng: *LCG, lambda: f64) u32 {
    const l = @exp(-lambda);
    var k: u32 = 0;
    var p: f64 = 1.0;
    while (true) {
        k += 1;
        p *= rng.nextFloat();
        if (p <= l) break;
    }
    return k - 1;
}

pub fn uniformInt(rng: *LCG, lo: u32, hi: u32) u32 {
    if (lo >= hi) return lo;
    return lo + rng.next() % (hi - lo);
}

pub fn bernoulli(rng: *LCG, p: f64) bool { return rng.nextFloat() < p; }

pub fn geometric(rng: *LCG, p: f64) u32 {
    if (p <= 0 or p > 1) return 0;
    var k: u32 = 0;
    while (!bernoulli(rng, p) and k < 10000) k += 1;
    return k;
}

pub fn randomWalk(rng: *LCG, steps: u32, output: []f64) u32 {
    if (steps == 0) return 0;
    output[0] = 0;
    for (1..@min(steps, @as(u32, @intCast(output.len)))) |i| {
        output[i] = output[i - 1] + normalRandom(rng);
    }
    return @min(steps, @as(u32, @intCast(output.len)));
}
