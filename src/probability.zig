const std = @import("std");

pub fn normalPDF(x: f64, mean: f64, std_dev: f64) f64 {
    if (std_dev <= 0) return 0;
    const z = (x - mean) / std_dev;
    return @exp(-0.5 * z * z) / (std_dev * @sqrt(2.0 * std.math.pi));
}

pub fn normalCDF(x: f64, mean: f64, std_dev: f64) f64 {
    if (std_dev <= 0) return if (x >= mean) 1.0 else 0.0;
    return 0.5 * (1.0 + erf((x - mean) / (std_dev * @sqrt(2.0))));
}

fn erf(x: f64) f64 {
    const a1: f64 = 0.254829592; const a2: f64 = -0.284496736;
    const a3: f64 = 1.421413741; const a4: f64 = -1.453152027;
    const a5: f64 = 1.061405429; const p: f64 = 0.3275911;
    const sign: f64 = if (x < 0) -1.0 else 1.0;
    const ax = @abs(x);
    const t = 1.0 / (1.0 + p * ax);
    const y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * @exp(-ax * ax);
    return sign * y;
}

pub fn binomialPMF(n: u32, k: u32, p_val: f64) f64 {
    if (k > n) return 0;
    var coeff: f64 = 1;
    for (0..k) |i| {
        coeff *= @as(f64, @floatFromInt(n - @as(u32, @intCast(i))));
        coeff /= @as(f64, @floatFromInt(i + 1));
    }
    return coeff * std.math.pow(f64, p_val, @as(f64, @floatFromInt(k))) *
        std.math.pow(f64, 1.0 - p_val, @as(f64, @floatFromInt(n - k)));
}

pub fn poissonPMF(k: u32, lambda: f64) f64 {
    var result = @exp(-lambda);
    for (0..k) |i| result *= lambda / @as(f64, @floatFromInt(i + 1));
    return result;
}

pub fn exponentialPDF(x: f64, lambda: f64) f64 {
    if (x < 0 or lambda <= 0) return 0;
    return lambda * @exp(-lambda * x);
}

pub fn exponentialCDF(x: f64, lambda: f64) f64 {
    if (x < 0 or lambda <= 0) return 0;
    return 1.0 - @exp(-lambda * x);
}

pub fn uniformPDF(x: f64, a: f64, b: f64) f64 {
    if (b <= a) return 0;
    if (x < a or x > b) return 0;
    return 1.0 / (b - a);
}

pub fn bayesTheorem(p_a: f64, p_b_given_a: f64, p_b: f64) f64 {
    if (p_b <= 0) return 0;
    return (p_b_given_a * p_a) / p_b;
}

pub fn entropy(probs: []const f64) f64 {
    var h: f64 = 0;
    for (probs) |p| { if (p > 0) h -= p * @log2(p); }
    return h;
}

pub fn klDivergence(p: []const f64, q: []const f64) f64 {
    const n = @min(p.len, q.len);
    var kl: f64 = 0;
    for (0..n) |i| {
        if (p[i] > 0 and q[i] > 0) kl += p[i] * @log(p[i] / q[i]);
    }
    return kl;
}

pub fn jsDivergence(p: []const f64, q: []const f64) f64 {
    const n = @min(p.len, q.len);
    var m: [256]f64 = undefined;
    for (0..n) |i| m[i] = (p[i] + q[i]) / 2.0;
    return (klDivergence(p[0..n], m[0..n]) + klDivergence(q[0..n], m[0..n])) / 2.0;
}

pub fn chiSquared(observed: []const u32, expected: []const f64) f64 {
    const n = @min(observed.len, expected.len);
    var chi2: f64 = 0;
    for (0..n) |i| {
        if (expected[i] > 0) {
            const diff = @as(f64, @floatFromInt(observed[i])) - expected[i];
            chi2 += diff * diff / expected[i];
        }
    }
    return chi2;
}

pub fn covariance(x: []const f64, y: []const f64) f64 {
    const n = @min(x.len, y.len);
    if (n < 2) return 0;
    var mx: f64 = 0; var my: f64 = 0;
    for (0..n) |i| { mx += x[i]; my += y[i]; }
    mx /= @as(f64, @floatFromInt(n));
    my /= @as(f64, @floatFromInt(n));
    var cov: f64 = 0;
    for (0..n) |i| cov += (x[i] - mx) * (y[i] - my);
    return cov / @as(f64, @floatFromInt(n - 1));
}

pub fn welchTTest(x: []const f64, y: []const f64) f64 {
    if (x.len < 2 or y.len < 2) return 0;
    var mx: f64 = 0; var my: f64 = 0;
    for (x) |v| mx += v; mx /= @as(f64, @floatFromInt(x.len));
    for (y) |v| my += v; my /= @as(f64, @floatFromInt(y.len));
    var sx: f64 = 0; var sy: f64 = 0;
    for (x) |v| { const d = v - mx; sx += d * d; }
    for (y) |v| { const d = v - my; sy += d * d; }
    sx /= @as(f64, @floatFromInt(x.len - 1));
    sy /= @as(f64, @floatFromInt(y.len - 1));
    const se = @sqrt(sx / @as(f64, @floatFromInt(x.len)) + sy / @as(f64, @floatFromInt(y.len)));
    if (se == 0) return 0;
    return (mx - my) / se;
}

pub fn confidenceInterval(data: []const f64, confidence: f64) [2]f64 {
    if (data.len == 0) return .{ 0, 0 };
    var sum: f64 = 0;
    for (data) |d| sum += d;
    const mean = sum / @as(f64, @floatFromInt(data.len));
    var var_sum: f64 = 0;
    for (data) |d| { const diff = d - mean; var_sum += diff * diff; }
    const std_dev = @sqrt(var_sum / @as(f64, @floatFromInt(@max(data.len - 1, 1))));
    const z = if (confidence >= 0.99) 2.576 else if (confidence >= 0.95) 1.96 else 1.645;
    const margin = z * std_dev / @sqrt(@as(f64, @floatFromInt(data.len)));
    return .{ mean - margin, mean + margin };
}
