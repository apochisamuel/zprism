const std = @import("std");

pub fn haarTransform(data: []f64) void {
    var n = data.len;
    var temp: [4096]f64 = undefined;
    while (n > 1) {
        const half = n / 2;
        for (0..half) |i| {
            temp[i] = (data[2 * i] + data[2 * i + 1]) / 2.0;
            temp[half + i] = (data[2 * i] - data[2 * i + 1]) / 2.0;
        }
        @memcpy(data[0..n], temp[0..n]);
        n = half;
    }
}

pub fn inverseHaarTransform(data: []f64) void {
    var n: usize = 1;
    var temp: [4096]f64 = undefined;
    while (n * 2 <= data.len) {
        for (0..n) |i| {
            temp[2 * i] = data[i] + data[n + i];
            temp[2 * i + 1] = data[i] - data[n + i];
        }
        @memcpy(data[0..n * 2], temp[0..n * 2]);
        n *= 2;
    }
}

pub fn waveletEnergy(data: []const f64, level: u32) f64 {
    if (data.len == 0) return 0;
    const half = data.len / 2;
    if (level == 0 or half == 0) {
        var energy: f64 = 0;
        for (data) |d| energy += d * d;
        return energy;
    }
    var energy: f64 = 0;
    for (data[half..]) |d| energy += d * d;
    return energy;
}

pub fn waveletDenoise(data: []f64, threshold: f64) u32 {
    var zeroed: u32 = 0;
    for (data) |*d| {
        if (@abs(d.*) < threshold) { d.* = 0; zeroed += 1; }
    }
    return zeroed;
}

pub fn waveletCompress(data: []f64, keep_percent: f64) u32 {
    var magnitudes: [4096]f64 = undefined;
    const n = @min(data.len, 4096);
    for (0..n) |i| magnitudes[i] = @abs(data[i]);
    std.sort.insertion(f64, magnitudes[0..n], {}, struct {
        fn gt(_: void, a: f64, b: f64) bool { return a > b; }
    }.gt);
    const keep = @as(usize, @intFromFloat(@as(f64, @floatFromInt(n)) * keep_percent / 100.0));
    const threshold = if (keep < n) magnitudes[keep] else 0;
    return waveletDenoise(data, threshold);
}

pub fn multiResolution(data: []const f64, level: u32, output: []f64) void {
    const n = @min(data.len, output.len);
    @memcpy(output[0..n], data[0..n]);
    var buf: [4096]f64 = undefined;
    @memcpy(buf[0..n], data[0..n]);
    for (0..level) |_| {
        const half = n / 2;
        if (half == 0) break;
        for (0..half) |i| {
            output[i] = (buf[2 * i] + buf[2 * i + 1]) / 2.0;
        }
        @memcpy(buf[0..half], output[0..half]);
    }
}

pub fn scaleogram(data: []const f64, max_scale: u32, output: []f64) u32 {
    var pos: u32 = 0;
    for (1..max_scale + 1) |scale| {
        for (0..data.len) |i| {
            if (pos >= output.len) return pos;
            var sum: f64 = 0;
            var count: u32 = 0;
            const start = if (i >= scale) i - scale else 0;
            const end = @min(i + scale, data.len);
            for (start..end) |j| { sum += data[j]; count += 1; }
            output[pos] = if (count > 0) sum / @as(f64, @floatFromInt(count)) else 0;
            pos += 1;
        }
    }
    return pos;
}

pub fn signalToNoiseRatio(signal: []const f64, noise: []const f64) f64 {
    var signal_power: f64 = 0;
    var noise_power: f64 = 0;
    for (signal) |s| signal_power += s * s;
    for (noise) |n| noise_power += n * n;
    if (noise_power == 0) return std.math.inf(f64);
    return 10.0 * @log10(signal_power / noise_power);
}

pub fn crossCorrelation(a: []const f64, b: []const f64, lag: i32, max_lag: u32) f64 {
    _ = max_lag;
    var sum: f64 = 0;
    var count: u32 = 0;
    for (0..a.len) |i| {
        const j_signed: i64 = @as(i64, @intCast(i)) + lag;
        if (j_signed >= 0 and j_signed < b.len) {
            sum += a[i] * b[@intCast(j_signed)];
            count += 1;
        }
    }
    if (count == 0) return 0;
    return sum / @as(f64, @floatFromInt(count));
}
