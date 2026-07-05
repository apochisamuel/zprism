const std = @import("std");
const types = @import("types.zig");

pub const Point2D = struct { x: f64, y: f64 };

pub fn projectSymbols(doc: *const types.Document, output: []Point2D) u32 {
    if (doc.symbols.items == null) return 0;
    const syms = doc.symbols.items.?;
    var count: u32 = 0;
    for (syms) |*sym| {
        if (count >= output.len) break;
        output[count] = Point2D{
            .x = @as(f64, @floatFromInt(sym.name_index)) / @as(f64, @floatFromInt(@max(doc.strings.count, 1))),
            .y = @as(f64, @floatFromInt(sym.derived_score)) / @as(f64, @floatFromInt(@max(sym.derived_score, 1))),
        };
        count += 1;
    }
    normalizePoints(output[0..count]);
    return count;
}

fn normalizePoints(points: []Point2D) void {
    if (points.len == 0) return;
    var min_x: f64 = std.math.inf(f64);
    var max_x: f64 = -std.math.inf(f64);
    var min_y: f64 = std.math.inf(f64);
    var max_y: f64 = -std.math.inf(f64);
    for (points) |*p| {
        if (p.x < min_x) min_x = p.x; if (p.x > max_x) max_x = p.x;
        if (p.y < min_y) min_y = p.y; if (p.y > max_y) max_y = p.y;
    }
    const rx = max_x - min_x;
    const ry = max_y - min_y;
    for (points) |*p| {
        p.x = if (rx > 0) (p.x - min_x) / rx else 0.5;
        p.y = if (ry > 0) (p.y - min_y) / ry else 0.5;
    }
}

pub fn euclideanDistance(a: Point2D, b: Point2D) f64 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return @sqrt(dx * dx + dy * dy);
}

pub fn manhattanDistance(a: Point2D, b: Point2D) f64 {
    return @abs(a.x - b.x) + @abs(a.y - b.y);
}

pub fn centroid(points: []const Point2D) Point2D {
    if (points.len == 0) return Point2D{ .x = 0, .y = 0 };
    var sx: f64 = 0; var sy: f64 = 0;
    for (points) |*p| { sx += p.x; sy += p.y; }
    const n = @as(f64, @floatFromInt(points.len));
    return Point2D{ .x = sx / n, .y = sy / n };
}

pub fn convexHullArea(points: []const Point2D) f64 {
    if (points.len < 3) return 0;
    var area: f64 = 0;
    const n = points.len;
    for (0..n) |i| {
        const j = (i + 1) % n;
        area += points[i].x * points[j].y;
        area -= points[j].x * points[i].y;
    }
    return @abs(area) / 2.0;
}

pub fn nearestNeighbor(point: Point2D, candidates: []const Point2D) ?usize {
    if (candidates.len == 0) return null;
    var best: usize = 0;
    var best_dist: f64 = std.math.inf(f64);
    for (candidates, 0..) |*c, i| {
        const d = euclideanDistance(point, c.*);
        if (d < best_dist) { best_dist = d; best = i; }
    }
    return best;
}

pub fn kNearestNeighbors(point: Point2D, candidates: []const Point2D, k: u32, output: []usize) u32 {
    var distances: [4096]f64 = undefined;
    var indices: [4096]usize = undefined;
    const n = @min(candidates.len, 4096);
    for (0..n) |i| {
        distances[i] = euclideanDistance(point, candidates[i]);
        indices[i] = i;
    }
    for (0..@min(k, @as(u32, @intCast(n)))) |i| {
        for (i + 1..n) |j| {
            if (distances[j] < distances[i]) {
                const td = distances[i]; distances[i] = distances[j]; distances[j] = td;
                const ti = indices[i]; indices[i] = indices[j]; indices[j] = ti;
            }
        }
        if (i < output.len) output[i] = indices[i];
    }
    return @min(k, @as(u32, @intCast(n)));
}

pub fn spatialHash(points: []const Point2D, grid_size: f64, buckets: []u32) void {
    for (points, 0..) |*p, i| {
        const gx: u32 = @intFromFloat(p.x / grid_size);
        const gy: u32 = @intFromFloat(p.y / grid_size);
        const hash = (gx *% 73856093) ^ (gy *% 19349663);
        if (i < buckets.len) buckets[i] = hash;
    }
}

pub fn densityEstimate(points: []const Point2D, radius: f64) []f64 {
    _ = points; _ = radius;
    return &.{};
}
