const std = @import("std");

pub fn lowPassFilter(input: []const f64, output: []f64, cutoff: f64) u32 {
    if (input.len == 0) return 0;
    const alpha = cutoff / (cutoff + 1.0);
    output[0] = input[0];
    for (1..@min(input.len, output.len)) |i| {
        output[i] = alpha * input[i] + (1.0 - alpha) * output[i - 1];
    }
    return @intCast(@min(input.len, output.len));
}

pub fn highPassFilter(input: []const f64, output: []f64, cutoff: f64) u32 {
    if (input.len == 0) return 0;
    const alpha = 1.0 / (cutoff + 1.0);
    output[0] = input[0];
    for (1..@min(input.len, output.len)) |i| {
        output[i] = alpha * (output[i - 1] + input[i] - input[i - 1]);
    }
    return @intCast(@min(input.len, output.len));
}

pub fn bandPassFilter(input: []const f64, output: []f64, low: f64, high: f64) u32 {
    var lp: [4096]f64 = undefined;
    const n = @min(input.len, 4096);
    _ = lowPassFilter(input[0..n], lp[0..n], high);
    return highPassFilter(lp[0..n], output[0..n], low);
}

pub fn convolve(input: []const f64, kernel: []const f64, output: []f64) u32 {
    if (input.len == 0 or kernel.len == 0) return 0;
    const out_len = @min(input.len, output.len);
    for (0..out_len) |i| {
        var sum: f64 = 0;
        for (0..kernel.len) |k| {
            if (i >= k) sum += input[i - k] * kernel[k];
        }
        output[i] = sum;
    }
    return @intCast(out_len);
}

pub fn autocorrelate(data: []const f64, output: []f64, max_lag: u32) u32 {
    const n = @min(data.len, output.len);
    for (0..@min(max_lag, @as(u32, @intCast(n)))) |lag| {
        var sum: f64 = 0;
        for (0..n - lag) |i| sum += data[i] * data[i + lag];
        output[lag] = sum / @as(f64, @floatFromInt(n));
    }
    return @min(max_lag, @as(u32, @intCast(n)));
}

pub fn peakDetect(data: []const f64, min_height: f64, peaks: []u32) u32 {
    if (data.len < 3) return 0;
    var count: u32 = 0;
    for (1..data.len - 1) |i| {
        if (data[i] > data[i - 1] and data[i] > data[i + 1] and data[i] >= min_height) {
            if (count >= peaks.len) break;
            peaks[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

pub fn zeroCrossings(data: []const f64) u32 {
    if (data.len < 2) return 0;
    var count: u32 = 0;
    for (1..data.len) |i| {
        if ((data[i] >= 0 and data[i - 1] < 0) or (data[i] < 0 and data[i - 1] >= 0))
            count += 1;
    }
    return count;
}

pub fn rms(data: []const f64) f64 {
    if (data.len == 0) return 0;
    var sum: f64 = 0;
    for (data) |d| sum += d * d;
    return @sqrt(sum / @as(f64, @floatFromInt(data.len)));
}

pub fn powerSpectrum(data: []const f64, output: []f64) u32 {
    const n = @min(data.len, output.len);
    for (0..n) |k| {
        var real: f64 = 0;
        var imag: f64 = 0;
        for (0..data.len) |t| {
            const angle = 2.0 * std.math.pi * @as(f64, @floatFromInt(k)) * @as(f64, @floatFromInt(t)) / @as(f64, @floatFromInt(data.len));
            real += data[t] * @cos(angle);
            imag -= data[t] * @sin(angle);
        }
        output[k] = real * real + imag * imag;
    }
    return @intCast(n);
}

pub fn spectralCentroid(spectrum: []const f64) f64 {
    var weighted_sum: f64 = 0;
    var total: f64 = 0;
    for (spectrum, 0..) |s, i| {
        weighted_sum += s * @as(f64, @floatFromInt(i));
        total += s;
    }
    if (total == 0) return 0;
    return weighted_sum / total;
}

pub fn spectralFlatness(spectrum: []const f64) f64 {
    if (spectrum.len == 0) return 0;
    var log_sum: f64 = 0;
    var arith_sum: f64 = 0;
    var count: u32 = 0;
    for (spectrum) |s| {
        if (s > 0) {
            log_sum += @log(s);
            arith_sum += s;
            count += 1;
        }
    }
    if (count == 0 or arith_sum == 0) return 0;
    const geo_mean = @exp(log_sum / @as(f64, @floatFromInt(count)));
    const arith_mean = arith_sum / @as(f64, @floatFromInt(count));
    return geo_mean / arith_mean;
}

pub fn downsample(input: []const f64, factor: u32, output: []f64) u32 {
    if (factor == 0) return 0;
    var count: u32 = 0;
    var i: usize = 0;
    while (i < input.len and count < output.len) {
        output[count] = input[i];
        count += 1;
        i += factor;
    }
    return count;
}

pub fn upsample(input: []const f64, factor: u32, output: []f64) u32 {
    if (factor == 0) return 0;
    var count: u32 = 0;
    for (input) |sample| {
        for (0..factor) |_| {
            if (count >= output.len) return count;
            output[count] = sample;
            count += 1;
        }
    }
    return count;
}

pub fn interpolateLinear(input: []const f64, output: []f64, target_len: u32) void {
    if (input.len < 2 or target_len < 2) return;
    const ratio = @as(f64, @floatFromInt(input.len - 1)) / @as(f64, @floatFromInt(target_len - 1));
    for (0..@min(target_len, @as(u32, @intCast(output.len)))) |i| {
        const pos = @as(f64, @floatFromInt(i)) * ratio;
        const idx: usize = @intFromFloat(pos);
        const frac = pos - @as(f64, @floatFromInt(idx));
        if (idx + 1 < input.len) {
            output[i] = input[idx] * (1.0 - frac) + input[idx + 1] * frac;
        } else {
            output[i] = input[idx];
        }
    }
}
