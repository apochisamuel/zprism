const std = @import("std");

pub const OptResult = struct { x: f64, fx: f64, iterations: u32, converged: bool };

pub fn goldenSection(f: *const fn (f64) f64, a: f64, b: f64, tol: f64, max_iter: u32) OptResult {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const resphi = 2.0 - phi;
    var lo = a; var hi = b;
    var x1 = lo + resphi * (hi - lo);
    var x2 = hi - resphi * (hi - lo);
    var f1 = f(x1); var f2 = f(x2);
    var iter: u32 = 0;
    while (iter < max_iter and @abs(hi - lo) > tol) : (iter += 1) {
        if (f1 < f2) { hi = x2; x2 = x1; f2 = f1; x1 = lo + resphi * (hi - lo); f1 = f(x1); }
        else { lo = x1; x1 = x2; f1 = f2; x2 = hi - resphi * (hi - lo); f2 = f(x2); }
    }
    const x = (lo + hi) / 2.0;
    return OptResult{ .x = x, .fx = f(x), .iterations = iter, .converged = @abs(hi - lo) <= tol };
}

pub fn bisection(f: *const fn (f64) f64, a: f64, b: f64, tol: f64, max_iter: u32) OptResult {
    var lo = a; var hi = b;
    var iter: u32 = 0;
    while (iter < max_iter and @abs(hi - lo) > tol) : (iter += 1) {
        const mid = (lo + hi) / 2.0;
        if (f(mid) * f(lo) < 0) hi = mid else lo = mid;
    }
    const x = (lo + hi) / 2.0;
    return OptResult{ .x = x, .fx = f(x), .iterations = iter, .converged = @abs(hi - lo) <= tol };
}

pub fn newtonRaphson(f: *const fn (f64) f64, df: *const fn (f64) f64, x0: f64, tol: f64, max_iter: u32) OptResult {
    var x = x0;
    var iter: u32 = 0;
    while (iter < max_iter) : (iter += 1) {
        const fx = f(x);
        const dfx = df(x);
        if (@abs(dfx) < 1e-15) break;
        const x_new = x - fx / dfx;
        if (@abs(x_new - x) < tol) return OptResult{ .x = x_new, .fx = f(x_new), .iterations = iter + 1, .converged = true };
        x = x_new;
    }
    return OptResult{ .x = x, .fx = f(x), .iterations = iter, .converged = false };
}

pub fn secantMethod(f: *const fn (f64) f64, x0: f64, x1: f64, tol: f64, max_iter: u32) OptResult {
    var xp = x0; var xc = x1;
    var fp = f(xp); var fc = f(xc);
    var iter: u32 = 0;
    while (iter < max_iter and @abs(fc) > tol) : (iter += 1) {
        if (@abs(fc - fp) < 1e-15) break;
        const x_new = xc - fc * (xc - xp) / (fc - fp);
        xp = xc; fp = fc; xc = x_new; fc = f(xc);
    }
    return OptResult{ .x = xc, .fx = fc, .iterations = iter, .converged = @abs(fc) <= tol };
}

pub fn gradientDescent(f: *const fn (f64) f64, df: *const fn (f64) f64, x0: f64, lr: f64, max_iter: u32) OptResult {
    var x = x0;
    var iter: u32 = 0;
    while (iter < max_iter) : (iter += 1) {
        const grad = df(x);
        if (@abs(grad) < 1e-10) break;
        x -= lr * grad;
    }
    return OptResult{ .x = x, .fx = f(x), .iterations = iter, .converged = iter < max_iter };
}

pub fn simpsonIntegrate(f: *const fn (f64) f64, a: f64, b: f64, n: u32) f64 {
    if (n == 0) return 0;
    const steps = if (n % 2 == 0) n else n + 1;
    const h = (b - a) / @as(f64, @floatFromInt(steps));
    var sum = f(a) + f(b);
    for (1..steps) |i| {
        const x = a + @as(f64, @floatFromInt(i)) * h;
        sum += if (i % 2 == 0) 2.0 * f(x) else 4.0 * f(x);
    }
    return sum * h / 3.0;
}

pub fn trapezoidIntegrate(f: *const fn (f64) f64, a: f64, b: f64, n: u32) f64 {
    if (n == 0) return 0;
    const h = (b - a) / @as(f64, @floatFromInt(n));
    var sum = (f(a) + f(b)) / 2.0;
    for (1..n) |i| sum += f(a + @as(f64, @floatFromInt(i)) * h);
    return sum * h;
}

pub fn rombergIntegrate(f: *const fn (f64) f64, a: f64, b: f64, order: u32) f64 {
    var R: [10][10]f64 = std.mem.zeroes([10][10]f64);
    const n = @min(order, 10);
    R[0][0] = (b - a) * (f(a) + f(b)) / 2.0;
    for (1..n) |i| {
        const h = (b - a) / @as(f64, @floatFromInt(@as(u32, 1) << @intCast(i)));
        var sum: f64 = 0;
        var k: u32 = 1;
        while (k < @as(u32, 1) << @intCast(i)) : (k += 2) {
            sum += f(a + @as(f64, @floatFromInt(k)) * h);
        }
        R[i][0] = R[i - 1][0] / 2.0 + h * sum;
        for (1..i + 1) |j| {
            const factor = @as(f64, @floatFromInt(@as(u64, 1) << @intCast(2 * j)));
            R[i][j] = (factor * R[i][j - 1] - R[i - 1][j - 1]) / (factor - 1.0);
        }
    }
    return R[n - 1][n - 1];
}

pub fn numericalDerivative(f: *const fn (f64) f64, x: f64, h: f64) f64 {
    return (f(x + h) - f(x - h)) / (2.0 * h);
}

pub fn secondDerivative(f: *const fn (f64) f64, x: f64, h: f64) f64 {
    return (f(x + h) - 2.0 * f(x) + f(x - h)) / (h * h);
}
