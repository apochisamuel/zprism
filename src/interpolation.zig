const std = @import("std");

pub fn linearInterpolate(x: []const f64, y: []const f64, target: f64) f64 {
    if (x.len < 2 or y.len < 2) return 0;
    const n = @min(x.len, y.len);
    if (target <= x[0]) return y[0];
    if (target >= x[n - 1]) return y[n - 1];
    for (0..n - 1) |i| {
        if (target >= x[i] and target <= x[i + 1]) {
            const t = (target - x[i]) / (x[i + 1] - x[i]);
            return y[i] + t * (y[i + 1] - y[i]);
        }
    }
    return y[n - 1];
}

pub fn cubicInterpolate(y0: f64, y1: f64, y2: f64, y3: f64, t: f64) f64 {
    const a0 = y3 - y2 - y0 + y1;
    const a1 = y0 - y1 - a0;
    const a2 = y2 - y0;
    const a3 = y1;
    return a0 * t * t * t + a1 * t * t + a2 * t + a3;
}

pub fn lagrangeInterpolate(x: []const f64, y: []const f64, target: f64) f64 {
    const n = @min(x.len, y.len);
    var result: f64 = 0;
    for (0..n) |i| {
        var term: f64 = y[i];
        for (0..n) |j| {
            if (i != j) {
                if (x[i] != x[j]) term *= (target - x[j]) / (x[i] - x[j]);
            }
        }
        result += term;
    }
    return result;
}

pub fn newtonDividedDiff(x: []const f64, y: []const f64, coeffs: []f64) u32 {
    const n = @min(x.len, @min(y.len, coeffs.len));
    if (n == 0) return 0;
    var table: [64][64]f64 = std.mem.zeroes([64][64]f64);
    const m = @min(n, 64);
    for (0..m) |i| table[i][0] = y[i];
    for (1..m) |j| {
        for (0..m - j) |i| {
            if (x[i + j] != x[i]) table[i][j] = (table[i + 1][j - 1] - table[i][j - 1]) / (x[i + j] - x[i]);
        }
    }
    for (0..m) |i| coeffs[i] = table[0][i];
    return @intCast(m);
}

pub fn splineInterpolate(x: []const f64, y: []const f64, target: f64, output: []f64) u32 {
    const n = @min(x.len, y.len);
    if (n < 3) return 0;
    var count: u32 = 0;
    const steps = @min(output.len, 1000);
    const range = x[n - 1] - x[0];
    if (range <= 0) return 0;
    for (0..steps) |s| {
        const t = x[0] + range * @as(f64, @floatFromInt(s)) / @as(f64, @floatFromInt(steps));
        output[count] = linearInterpolate(x, y, t);
        count += 1;
        _ = target;
    }
    return count;
}

pub fn barycentricWeights(x: []const f64, weights: []f64) void {
    const n = @min(x.len, weights.len);
    for (0..n) |i| {
        weights[i] = 1.0;
        for (0..n) |j| {
            if (i != j and x[i] != x[j]) weights[i] /= (x[i] - x[j]);
        }
    }
}

pub fn barycentricInterpolate(x: []const f64, y: []const f64, weights: []const f64, target: f64) f64 {
    const n = @min(x.len, @min(y.len, weights.len));
    var num: f64 = 0;
    var den: f64 = 0;
    for (0..n) |i| {
        if (target == x[i]) return y[i];
        const w = weights[i] / (target - x[i]);
        num += w * y[i];
        den += w;
    }
    if (den == 0) return 0;
    return num / den;
}

pub fn hermiteInterpolate(y0: f64, y1: f64, dy0: f64, dy1: f64, t: f64) f64 {
    const t2 = t * t;
    const t3 = t2 * t;
    const h00 = 2.0 * t3 - 3.0 * t2 + 1.0;
    const h10 = t3 - 2.0 * t2 + t;
    const h01 = -2.0 * t3 + 3.0 * t2;
    const h11 = t3 - t2;
    return h00 * y0 + h10 * dy0 + h01 * y1 + h11 * dy1;
}

pub fn bezierCurve(p0: f64, p1: f64, p2: f64, p3: f64, t: f64) f64 {
    const u = 1.0 - t;
    return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
}

pub fn catmullRom(p0: f64, p1: f64, p2: f64, p3: f64, t: f64) f64 {
    const t2 = t * t;
    const t3 = t2 * t;
    return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
}

pub fn resample(input: []const f64, output: []f64) void {
    if (input.len == 0 or output.len == 0) return;
    if (input.len == output.len) { @memcpy(output, input); return; }
    const ratio = @as(f64, @floatFromInt(input.len - 1)) / @as(f64, @floatFromInt(@max(output.len - 1, 1)));
    for (0..output.len) |i| {
        const pos = @as(f64, @floatFromInt(i)) * ratio;
        const idx: usize = @intFromFloat(@min(pos, @as(f64, @floatFromInt(input.len - 1))));
        const frac = pos - @as(f64, @floatFromInt(idx));
        if (idx + 1 < input.len) output[i] = input[idx] * (1.0 - frac) + input[idx + 1] * frac
        else output[i] = input[idx];
    }
}
