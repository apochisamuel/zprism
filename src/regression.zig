const std = @import("std");

pub const RegressionResult = struct { slope: f64, intercept: f64, r_squared: f64, std_error: f64, p_value_approx: f64, n: u32 };

pub fn linearRegression(x: []const u32, y: []const u32) RegressionResult {
    var result = std.mem.zeroes(RegressionResult);
    const n = @min(x.len, y.len);
    if (n < 2) return result;
    result.n = @intCast(n);
    var sum_x: f64 = 0; var sum_y: f64 = 0; var sum_xy: f64 = 0;
    var sum_x2: f64 = 0; var sum_y2: f64 = 0;
    for (0..n) |i| {
        const fx = @as(f64, @floatFromInt(x[i]));
        const fy = @as(f64, @floatFromInt(y[i]));
        sum_x += fx; sum_y += fy; sum_xy += fx * fy;
        sum_x2 += fx * fx; sum_y2 += fy * fy;
    }
    const nf = @as(f64, @floatFromInt(n));
    const denom = nf * sum_x2 - sum_x * sum_x;
    if (denom == 0) return result;
    result.slope = (nf * sum_xy - sum_x * sum_y) / denom;
    result.intercept = (sum_y - result.slope * sum_x) / nf;
    
    var ss_res: f64 = 0; var ss_tot: f64 = 0;
    const mean_y = sum_y / nf;
    for (0..n) |i| {
        const fx = @as(f64, @floatFromInt(x[i]));
        const fy = @as(f64, @floatFromInt(y[i]));
        const predicted = result.slope * fx + result.intercept;
        ss_res += (fy - predicted) * (fy - predicted);
        ss_tot += (fy - mean_y) * (fy - mean_y);
    }
    result.r_squared = if (ss_tot > 0) 1.0 - ss_res / ss_tot else 0;
    result.std_error = if (n > 2) @sqrt(ss_res / @as(f64, @floatFromInt(n - 2))) else 0;
    if (result.std_error > 0 and denom > 0) {
        const t_stat = result.slope / (result.std_error / @sqrt(sum_x2 - sum_x * sum_x / nf));
        result.p_value_approx = 2.0 / (1.0 + @exp(0.7 * @abs(t_stat)));
    }
    return result;
}

pub fn polynomialFit(x: []const u32, y: []const u32, degree: u32, coeffs: []f64) void {
    if (x.len < degree + 1 or y.len < degree + 1) return;
    const n = @min(x.len, y.len);
    const d = @min(degree + 1, @as(u32, @intCast(coeffs.len)));
    var xtx: [8][8]f64 = std.mem.zeroes([8][8]f64);
    var xty: [8]f64 = std.mem.zeroes([8]f64);
    for (0..n) |idx| {
        var xi_pow: f64 = 1.0;
        const fx = @as(f64, @floatFromInt(x[idx]));
        const fy = @as(f64, @floatFromInt(y[idx]));
        for (0..d) |i| {
            xty[i] += xi_pow * fy;
            var xj_pow: f64 = 1.0;
            for (0..d) |j| {
                xtx[i][j] += xi_pow * xj_pow;
                xj_pow *= fx;
            }
            xi_pow *= fx;
        }
    }
    // Solve using Gauss elimination
    for (0..d) |pivot| {
        if (xtx[pivot][pivot] == 0) continue;
        for (pivot + 1..d) |row| {
            const factor = xtx[row][pivot] / xtx[pivot][pivot];
            for (pivot..d) |col| xtx[row][col] -= factor * xtx[pivot][col];
            xty[row] -= factor * xty[pivot];
        }
    }
    var i: usize = d;
    while (i > 0) {
        i -= 1;
        var sum: f64 = xty[i];
        for (i + 1..d) |j| sum -= xtx[i][j] * coeffs[j];
        coeffs[i] = if (xtx[i][i] != 0) sum / xtx[i][i] else 0;
    }
}

pub fn movingAverage(data: []const u32, window: u32, output: []f64) u32 {
    if (data.len == 0 or window == 0) return 0;
    var count: u32 = 0;
    for (0..data.len) |i| {
        if (count >= output.len) break;
        var sum: u64 = 0;
        var w: u32 = 0;
        const start = if (i >= window) i - window + 1 else 0;
        for (start..i + 1) |j| { sum += data[j]; w += 1; }
        output[count] = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(w));
        count += 1;
    }
    return count;
}

pub fn exponentialSmoothing(data: []const u32, alpha: f64, output: []f64) u32 {
    if (data.len == 0) return 0;
    output[0] = @as(f64, @floatFromInt(data[0]));
    for (1..@min(data.len, output.len)) |i| {
        output[i] = alpha * @as(f64, @floatFromInt(data[i])) + (1.0 - alpha) * output[i - 1];
    }
    return @intCast(@min(data.len, output.len));
}

pub fn detectAnomalies(data: []const u32, threshold: f64, anomalies: []u32) u32 {
    if (data.len < 3) return 0;
    var sum: f64 = 0;
    for (data) |d| sum += @as(f64, @floatFromInt(d));
    const mean = sum / @as(f64, @floatFromInt(data.len));
    var var_sum: f64 = 0;
    for (data) |d| {
        const diff = @as(f64, @floatFromInt(d)) - mean;
        var_sum += diff * diff;
    }
    const std_dev = @sqrt(var_sum / @as(f64, @floatFromInt(data.len)));
    var count: u32 = 0;
    for (data, 0..) |d, i| {
        if (count >= anomalies.len) break;
        const z = @abs(@as(f64, @floatFromInt(d)) - mean) / @max(std_dev, 0.001);
        if (z > threshold) { anomalies[count] = @intCast(i); count += 1; }
    }
    return count;
}

pub fn trendDecomposition(data: []const u32, trend: []f64, seasonal: []f64, residual: []f64, period: u32) void {
    const n = @min(data.len, @min(trend.len, @min(seasonal.len, residual.len)));
    if (n == 0 or period == 0) return;
    _ = movingAverage(data[0..n], period, trend[0..n]);
    for (0..n) |i| {
        seasonal[i] = @as(f64, @floatFromInt(data[i])) - trend[i];
    }
    var season_avg: [64]f64 = std.mem.zeroes([64]f64);
    var season_count: [64]u32 = std.mem.zeroes([64]u32);
    const p = @min(period, 64);
    for (0..n) |i| {
        const phase = i % p;
        season_avg[phase] += seasonal[i];
        season_count[phase] += 1;
    }
    for (0..p) |i| {
        if (season_count[i] > 0) season_avg[i] /= @as(f64, @floatFromInt(season_count[i]));
    }
    for (0..n) |i| {
        seasonal[i] = season_avg[i % p];
        residual[i] = @as(f64, @floatFromInt(data[i])) - trend[i] - seasonal[i];
    }
}
