const std = @import("std");

pub fn gcd(a: u32, b: u32) u32 { var x = a; var y = b; while (y != 0) { const t = y; y = x % y; x = t; } return x; }
pub fn lcm(a: u32, b: u32) u32 { if (a == 0 or b == 0) return 0; return a / gcd(a, b) * b; }
pub fn isPrime(n: u32) bool { if (n < 2) return false; if (n < 4) return true; if (n % 2 == 0 or n % 3 == 0) return false; var i: u32 = 5; while (i * i <= n) { if (n % i == 0 or n % (i + 2) == 0) return false; i += 6; } return true; }
pub fn nextPrime(n: u32) u32 { var x = if (n < 2) 2 else n + 1; while (!isPrime(x)) x += 1; return x; }

pub fn factorial(n: u32) u64 { var r: u64 = 1; for (1..@min(n + 1, 21)) |i| r *= i; return r; }
pub fn binomial(n: u32, k: u32) u64 { if (k > n) return 0; if (k == 0 or k == n) return 1; var r: u64 = 1; for (0..@min(k, n - k)) |i| { r = r * (n - @as(u32, @intCast(i))) / (@as(u32, @intCast(i)) + 1); } return r; }

pub fn intPow(base: u64, exp: u32) u64 { var r: u64 = 1; var b = base; var e = exp; while (e > 0) { if (e & 1 != 0) r *%= b; b *%= b; e >>= 1; } return r; }
pub fn modPow(base: u64, exp: u64, modulus: u64) u64 { if (modulus == 0) return 0; var r: u64 = 1; var b = base % modulus; var e = exp; while (e > 0) { if (e & 1 != 0) r = r * b % modulus; b = b * b % modulus; e >>= 1; } return r; }

pub fn intSqrt(n: u64) u32 { if (n == 0) return 0; var x = n; var y = (x + 1) / 2; while (y < x) { x = y; y = (x + n / x) / 2; } return @intCast(x); }
pub fn intLog2(n: u32) u32 { if (n == 0) return 0; var r: u32 = 0; var v = n; while (v > 1) { v >>= 1; r += 1; } return r; }
pub fn nextPow2(n: u32) u32 { if (n == 0) return 1; var v = n - 1; v |= v >> 1; v |= v >> 2; v |= v >> 4; v |= v >> 8; v |= v >> 16; return v + 1; }

pub fn sieveOfEratosthenes(limit: u32, primes: []u32) u32 {
    var is_prime = [_]bool{true} ** 4096;
    const n = @min(limit, 4096);
    is_prime[0] = false; if (n > 1) is_prime[1] = false;
    var i: u32 = 2;
    while (i * i < n) : (i += 1) {
        if (is_prime[i]) { var j = i * i; while (j < n) : (j += i) is_prime[j] = false; }
    }
    var count: u32 = 0;
    for (2..n) |p| {
        if (is_prime[p] and count < primes.len) { primes[count] = @intCast(p); count += 1; }
    }
    return count;
}

pub fn primeFactors(n: u32, factors: []u32) u32 {
    var v = n; var count: u32 = 0;
    var d: u32 = 2;
    while (d * d <= v and count < factors.len) {
        while (v % d == 0) { factors[count] = d; count += 1; v /= d; if (count >= factors.len) return count; }
        d += 1;
    }
    if (v > 1 and count < factors.len) { factors[count] = v; count += 1; }
    return count;
}

pub fn eulerTotient(n: u32) u32 {
    var result = n; var v = n; var p: u32 = 2;
    while (p * p <= v) : (p += 1) {
        if (v % p == 0) { while (v % p == 0) v /= p; result -= result / p; }
    }
    if (v > 1) result -= result / v;
    return result;
}

pub fn fibonacci(n: u32) u64 {
    if (n < 2) return n;
    var a: u64 = 0; var b: u64 = 1;
    for (2..n + 1) |_| { const c = a +% b; a = b; b = c; }
    return b;
}

pub fn catalan(n: u32) u64 { return binomial(2 * n, n) / (n + 1); }

pub fn digitalRoot(n: u32) u32 { if (n == 0) return 0; return 1 + (n - 1) % 9; }
pub fn sumOfDigits(n: u32) u32 { var s: u32 = 0; var v = n; while (v > 0) { s += v % 10; v /= 10; } return s; }
pub fn reverseDigits(n: u32) u32 { var r: u32 = 0; var v = n; while (v > 0) { r = r * 10 + v % 10; v /= 10; } return r; }
pub fn isPalindrome(n: u32) bool { return n == reverseDigits(n); }

pub fn mean(data: []const u32) f64 { if (data.len == 0) return 0; var s: u64 = 0; for (data) |d| s += d; return @as(f64, @floatFromInt(s)) / @as(f64, @floatFromInt(data.len)); }
pub fn geometricMean(data: []const u32) f64 { if (data.len == 0) return 0; var log_sum: f64 = 0; for (data) |d| { if (d > 0) log_sum += @log(@as(f64, @floatFromInt(d))); } return @exp(log_sum / @as(f64, @floatFromInt(data.len))); }
pub fn harmonicMean(data: []const u32) f64 { if (data.len == 0) return 0; var recip_sum: f64 = 0; for (data) |d| { if (d > 0) recip_sum += 1.0 / @as(f64, @floatFromInt(d)); } if (recip_sum == 0) return 0; return @as(f64, @floatFromInt(data.len)) / recip_sum; }

pub fn clamp(val: u32, lo: u32, hi: u32) u32 { return @max(lo, @min(val, hi)); }
pub fn lerp(a: f64, b: f64, t: f64) f64 { return a + (b - a) * t; }
pub fn smoothstep(edge0: f64, edge1: f64, x: f64) f64 {
    const t = @max(0.0, @min(1.0, (x - edge0) / (edge1 - edge0)));
    return t * t * (3.0 - 2.0 * t);
}

pub fn runningMedian(data: []const u32, output: []u32) u32 {
    var count: u32 = 0;
    for (0..data.len) |i| {
        if (count >= output.len) break;
        var window: [128]u32 = undefined;
        const start = if (i > 64) i - 64 else 0;
        const wlen = i - start + 1;
        @memcpy(window[0..wlen], data[start..i + 1]);
        std.sort.insertion(u32, window[0..wlen], {}, std.sort.asc(u32));
        output[count] = window[wlen / 2];
        count += 1;
    }
    return count;
}

pub fn histogram(data: []const u32, bins: u32, counts: []u32) void {
    if (data.len == 0 or bins == 0) return;
    var mx: u32 = 0;
    for (data) |d| { if (d > mx) mx = d; }
    if (mx == 0) return;
    for (data) |d| {
        const bin = d / (mx / bins + 1);
        if (bin < counts.len) counts[bin] += 1;
    }
}

pub fn percentileRank(data: []const u32, value: u32) f64 {
    if (data.len == 0) return 0;
    var below: u32 = 0;
    for (data) |d| { if (d < value) below += 1; }
    return @as(f64, @floatFromInt(below)) / @as(f64, @floatFromInt(data.len)) * 100.0;
}

pub fn iqr(data: []const u32) u32 {
    if (data.len < 4) return 0;
    var sorted: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    @memcpy(sorted[0..n], data[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    return sorted[3 * n / 4] -| sorted[n / 4];
}

pub fn mad(data: []const u32) u32 {
    if (data.len == 0) return 0;
    var sorted: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    @memcpy(sorted[0..n], data[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    const median = sorted[n / 2];
    var deviations: [4096]u32 = undefined;
    for (0..n) |i| {
        deviations[i] = if (sorted[i] > median) sorted[i] - median else median - sorted[i];
    }
    std.sort.insertion(u32, deviations[0..n], {}, std.sort.asc(u32));
    return deviations[n / 2];
}

pub fn weightedMean(values: []const u32, weights: []const u32) f64 {
    const n = @min(values.len, weights.len);
    if (n == 0) return 0;
    var sum: f64 = 0; var wsum: f64 = 0;
    for (0..n) |i| {
        sum += @as(f64, @floatFromInt(values[i])) * @as(f64, @floatFromInt(weights[i]));
        wsum += @as(f64, @floatFromInt(weights[i]));
    }
    if (wsum == 0) return 0;
    return sum / wsum;
}

pub fn trimmedMean(data: []const u32, trim_percent: u32) f64 {
    if (data.len == 0) return 0;
    var sorted: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    @memcpy(sorted[0..n], data[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    const trim = n * trim_percent / 100;
    const start = trim;
    const end = n - trim;
    if (start >= end) return @as(f64, @floatFromInt(sorted[n / 2]));
    var sum: u64 = 0;
    for (start..end) |i| sum += sorted[i];
    return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(end - start));
}

pub fn winsorize(data: []u32, percent: u32) void {
    if (data.len < 4) return;
    var sorted: [4096]u32 = undefined;
    const n = @min(data.len, 4096);
    @memcpy(sorted[0..n], data[0..n]);
    std.sort.insertion(u32, sorted[0..n], {}, std.sort.asc(u32));
    const k = n * percent / 100;
    const lo = sorted[k];
    const hi = sorted[n - 1 - k];
    for (data) |*d| {
        if (d.* < lo) d.* = lo;
        if (d.* > hi) d.* = hi;
    }
}

pub fn zScore(data: []const u32, index: usize) f64 {
    if (data.len < 2 or index >= data.len) return 0;
    const m = mean(data);
    var var_sum: f64 = 0;
    for (data) |d| { const diff = @as(f64, @floatFromInt(d)) - m; var_sum += diff * diff; }
    const sd = @sqrt(var_sum / @as(f64, @floatFromInt(data.len)));
    if (sd == 0) return 0;
    return (@as(f64, @floatFromInt(data[index])) - m) / sd;
}

pub fn cosineSimilarity(a: []const u32, b: []const u32) f64 {
    const n = @min(a.len, b.len);
    var dot: f64 = 0; var na: f64 = 0; var nb: f64 = 0;
    for (0..n) |i| {
        const fa = @as(f64, @floatFromInt(a[i]));
        const fb = @as(f64, @floatFromInt(b[i]));
        dot += fa * fb; na += fa * fa; nb += fb * fb;
    }
    const denom = @sqrt(na) * @sqrt(nb);
    if (denom == 0) return 0;
    return dot / denom;
}

pub fn jaccardIndex(a: []const u32, b: []const u32) f64 {
    var inter: u32 = 0; var union_count: u32 = 0;
    for (a) |va| {
        var found = false;
        for (b) |vb| { if (va == vb) { found = true; break; } }
        if (found) inter += 1;
        union_count += 1;
    }
    for (b) |vb| {
        var found = false;
        for (a) |va| { if (va == vb) { found = true; break; } }
        if (!found) union_count += 1;
    }
    if (union_count == 0) return 0;
    return @as(f64, @floatFromInt(inter)) / @as(f64, @floatFromInt(union_count));
}
