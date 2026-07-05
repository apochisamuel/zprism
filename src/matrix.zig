const std = @import("std");

pub const Matrix = struct {
    data: []f64,
    rows: u32,
    cols: u32,
    
    pub fn init(allocator: std.mem.Allocator, rows: u32, cols: u32) !Matrix {
        const data = try allocator.alloc(f64, @as(usize, rows) * cols);
        @memset(data, 0);
        return Matrix{ .data = data, .rows = rows, .cols = cols };
    }
    
    pub fn deinit(self: *Matrix, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
    
    pub fn get(self: *const Matrix, row: u32, col: u32) f64 {
        if (row >= self.rows or col >= self.cols) return 0;
        return self.data[@as(usize, row) * self.cols + col];
    }
    
    pub fn set(self: *Matrix, row: u32, col: u32, val: f64) void {
        if (row >= self.rows or col >= self.cols) return;
        self.data[@as(usize, row) * self.cols + col] = val;
    }
    
    pub fn multiply(a: *const Matrix, b: *const Matrix, result: *Matrix) bool {
        if (a.cols != b.rows or result.rows != a.rows or result.cols != b.cols) return false;
        for (0..a.rows) |i| {
            for (0..b.cols) |j| {
                var sum: f64 = 0;
                for (0..a.cols) |k| {
                    sum += a.get(@intCast(i), @intCast(k)) * b.get(@intCast(k), @intCast(j));
                }
                result.set(@intCast(i), @intCast(j), sum);
            }
        }
        return true;
    }
    
    pub fn transpose(self: *const Matrix, result: *Matrix) bool {
        if (result.rows != self.cols or result.cols != self.rows) return false;
        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                result.set(@intCast(j), @intCast(i), self.get(@intCast(i), @intCast(j)));
            }
        }
        return true;
    }
    
    pub fn trace(self: *const Matrix) f64 {
        var t: f64 = 0;
        const n = @min(self.rows, self.cols);
        for (0..n) |i| t += self.get(@intCast(i), @intCast(i));
        return t;
    }
    
    pub fn frobeniusNorm(self: *const Matrix) f64 {
        var sum: f64 = 0;
        for (self.data) |v| sum += v * v;
        return @sqrt(sum);
    }
    
    pub fn scale(self: *Matrix, factor: f64) void {
        for (self.data) |*v| v.* *= factor;
    }
    
    pub fn add(a: *const Matrix, b: *const Matrix, result: *Matrix) bool {
        if (a.rows != b.rows or a.cols != b.cols) return false;
        if (result.rows != a.rows or result.cols != a.cols) return false;
        for (0..a.data.len) |i| result.data[i] = a.data[i] + b.data[i];
        return true;
    }
    
    pub fn identity(self: *Matrix) void {
        @memset(self.data, 0);
        const n = @min(self.rows, self.cols);
        for (0..n) |i| self.set(@intCast(i), @intCast(i), 1.0);
    }
    
    pub fn determinant2x2(self: *const Matrix) f64 {
        if (self.rows != 2 or self.cols != 2) return 0;
        return self.get(0, 0) * self.get(1, 1) - self.get(0, 1) * self.get(1, 0);
    }
    
    pub fn maxElement(self: *const Matrix) f64 {
        var mx: f64 = -std.math.inf(f64);
        for (self.data) |v| { if (v > mx) mx = v; }
        return mx;
    }
    
    pub fn minElement(self: *const Matrix) f64 {
        var mn: f64 = std.math.inf(f64);
        for (self.data) |v| { if (v < mn) mn = v; }
        return mn;
    }
    
    pub fn rowSum(self: *const Matrix, row: u32) f64 {
        if (row >= self.rows) return 0;
        var sum: f64 = 0;
        for (0..self.cols) |j| sum += self.get(row, @intCast(j));
        return sum;
    }
    
    pub fn colSum(self: *const Matrix, col: u32) f64 {
        if (col >= self.cols) return 0;
        var sum: f64 = 0;
        for (0..self.rows) |i| sum += self.get(@intCast(i), col);
        return sum;
    }
};

pub fn buildSimilarityMatrix(allocator: std.mem.Allocator, scores: []const u32, n: u32) !Matrix {
    var mat = try Matrix.init(allocator, n, n);
    for (0..n) |i| {
        for (0..n) |j| {
            if (i < scores.len and j < scores.len) {
                const diff = if (scores[i] > scores[j]) scores[i] - scores[j] else scores[j] - scores[i];
                const sim = 1.0 / (1.0 + @as(f64, @floatFromInt(diff)));
                mat.set(@intCast(i), @intCast(j), sim);
            }
        }
    }
    return mat;
}

pub fn computeCovariance(x: []const f64, y: []const f64) f64 {
    const n = @min(x.len, y.len);
    if (n < 2) return 0;
    var mean_x: f64 = 0; var mean_y: f64 = 0;
    for (0..n) |i| { mean_x += x[i]; mean_y += y[i]; }
    mean_x /= @as(f64, @floatFromInt(n));
    mean_y /= @as(f64, @floatFromInt(n));
    var cov: f64 = 0;
    for (0..n) |i| cov += (x[i] - mean_x) * (y[i] - mean_y);
    return cov / @as(f64, @floatFromInt(n - 1));
}
