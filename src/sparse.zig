const std = @import("std");

pub const SparseEntry = struct { row: u32, col: u32, value: f64 };

pub const SparseMatrix = struct {
    entries: []SparseEntry,
    count: u32,
    rows: u32,
    cols: u32,

    pub fn init(allocator: std.mem.Allocator, max_entries: u32) !SparseMatrix {
        return SparseMatrix{
            .entries = try allocator.alloc(SparseEntry, max_entries),
            .count = 0, .rows = 0, .cols = 0,
        };
    }

    pub fn deinit(self: *SparseMatrix, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
    }

    pub fn set(self: *SparseMatrix, row: u32, col: u32, value: f64) bool {
        for (self.entries[0..self.count]) |*e| {
            if (e.row == row and e.col == col) { e.value = value; return true; }
        }
        if (self.count >= self.entries.len) return false;
        self.entries[self.count] = SparseEntry{ .row = row, .col = col, .value = value };
        self.count += 1;
        if (row >= self.rows) self.rows = row + 1;
        if (col >= self.cols) self.cols = col + 1;
        return true;
    }

    pub fn get(self: *const SparseMatrix, row: u32, col: u32) f64 {
        for (self.entries[0..self.count]) |*e| {
            if (e.row == row and e.col == col) return e.value;
        }
        return 0;
    }

    pub fn transpose(self: *SparseMatrix) void {
        for (self.entries[0..self.count]) |*e| {
            const tmp = e.row; e.row = e.col; e.col = tmp;
        }
        const tmp = self.rows; self.rows = self.cols; self.cols = tmp;
    }

    pub fn multiply(self: *const SparseMatrix, other: *const SparseMatrix, result: *SparseMatrix) void {
        for (self.entries[0..self.count]) |*a| {
            for (other.entries[0..other.count]) |*b| {
                if (a.col == b.row) {
                    const existing = result.get(a.row, b.col);
                    _ = result.set(a.row, b.col, existing + a.value * b.value);
                }
            }
        }
    }

    pub fn norm(self: *const SparseMatrix) f64 {
        var sum: f64 = 0;
        for (self.entries[0..self.count]) |*e| sum += e.value * e.value;
        return @sqrt(sum);
    }

    pub fn density(self: *const SparseMatrix) f64 {
        if (self.rows == 0 or self.cols == 0) return 0;
        return @as(f64, @floatFromInt(self.count)) /
            (@as(f64, @floatFromInt(self.rows)) * @as(f64, @floatFromInt(self.cols)));
    }

    pub fn rowNorm(self: *const SparseMatrix, row: u32) f64 {
        var sum: f64 = 0;
        for (self.entries[0..self.count]) |*e| {
            if (e.row == row) sum += e.value * e.value;
        }
        return @sqrt(sum);
    }

    pub fn colNorm(self: *const SparseMatrix, col: u32) f64 {
        var sum: f64 = 0;
        for (self.entries[0..self.count]) |*e| {
            if (e.col == col) sum += e.value * e.value;
        }
        return @sqrt(sum);
    }

    pub fn dotProduct(self: *const SparseMatrix, row_a: u32, row_b: u32) f64 {
        var sum: f64 = 0;
        for (self.entries[0..self.count]) |*a| {
            if (a.row != row_a) continue;
            for (self.entries[0..self.count]) |*b| {
                if (b.row == row_b and b.col == a.col) sum += a.value * b.value;
            }
        }
        return sum;
    }

    pub fn cosineSimilarity(self: *const SparseMatrix, row_a: u32, row_b: u32) f64 {
        const dot = self.dotProduct(row_a, row_b);
        const na = self.rowNorm(row_a);
        const nb = self.rowNorm(row_b);
        if (na == 0 or nb == 0) return 0;
        return dot / (na * nb);
    }

    pub fn scale(self: *SparseMatrix, factor: f64) void {
        for (self.entries[0..self.count]) |*e| e.value *= factor;
    }

    pub fn add(self: *SparseMatrix, other: *const SparseMatrix) void {
        for (other.entries[0..other.count]) |*e| {
            const existing = self.get(e.row, e.col);
            _ = self.set(e.row, e.col, existing + e.value);
        }
    }

    pub fn prune(self: *SparseMatrix, threshold: f64) u32 {
        var write: u32 = 0;
        for (0..self.count) |read| {
            if (@abs(self.entries[read].value) >= threshold) {
                self.entries[write] = self.entries[read];
                write += 1;
            }
        }
        const removed = self.count - write;
        self.count = write;
        return removed;
    }

    pub fn topK(self: *const SparseMatrix, k: u32, output: []SparseEntry) u32 {
        var sorted: [4096]SparseEntry = undefined;
        const n = @min(self.count, 4096);
        @memcpy(sorted[0..n], self.entries[0..n]);
        for (0..n) |i| {
            for (i + 1..n) |j| {
                if (@abs(sorted[j].value) > @abs(sorted[i].value)) {
                    const tmp = sorted[i]; sorted[i] = sorted[j]; sorted[j] = tmp;
                }
            }
        }
        const m = @min(k, @as(u32, @intCast(n)));
        @memcpy(output[0..m], sorted[0..m]);
        return m;
    }
};

pub fn fromDense(allocator: std.mem.Allocator, data: []const f64, rows: u32, cols: u32) !SparseMatrix {
    var mat = try SparseMatrix.init(allocator, @intCast(data.len));
    for (0..rows) |r| {
        for (0..cols) |c| {
            const idx = r * cols + c;
            if (idx < data.len and data[idx] != 0) {
                _ = mat.set(@intCast(r), @intCast(c), data[idx]);
            }
        }
    }
    return mat;
}

pub fn toDense(mat: *const SparseMatrix, output: []f64, cols: u32) void {
    @memset(output, 0);
    for (mat.entries[0..mat.count]) |*e| {
        const idx = @as(usize, e.row) * cols + e.col;
        if (idx < output.len) output[idx] = e.value;
    }
}
