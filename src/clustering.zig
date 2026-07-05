const std = @import("std");
const types = @import("types.zig");

pub const Cluster = struct { centroid: u32, members: [256]u32, count: u32, variance: f64 };

pub fn kmeansCluster(scores: []const u32, k: u32, output: []Cluster, iterations: u32) u32 {
    if (scores.len == 0 or k == 0) return 0;
    const actual_k = @min(k, @as(u32, @intCast(scores.len)));
    for (0..actual_k) |i| {
        output[i] = std.mem.zeroes(Cluster);
        output[i].centroid = scores[i * scores.len / actual_k];
    }
    for (0..iterations) |_| {
        for (0..actual_k) |i| output[i].count = 0;
        for (scores) |score| {
            var best: u32 = 0;
            var best_dist: u32 = std.math.maxInt(u32);
            for (0..actual_k) |i| {
                const dist = if (score > output[i].centroid) score - output[i].centroid else output[i].centroid - score;
                if (dist < best_dist) { best_dist = dist; best = @intCast(i); }
            }
            if (output[best].count < 256) {
                output[best].members[output[best].count] = score;
                output[best].count += 1;
            }
        }
        for (0..actual_k) |i| {
            if (output[i].count > 0) {
                var sum: u64 = 0;
                for (output[i].members[0..output[i].count]) |m| sum += m;
                output[i].centroid = @intCast(sum / output[i].count);
            }
        }
    }
    for (0..actual_k) |i| {
        output[i].variance = computeClusterVariance(&output[i]);
    }
    return actual_k;
}

fn computeClusterVariance(cluster: *const Cluster) f64 {
    if (cluster.count < 2) return 0;
    const mean = @as(f64, @floatFromInt(cluster.centroid));
    var sum: f64 = 0;
    for (cluster.members[0..cluster.count]) |m| {
        const diff = @as(f64, @floatFromInt(m)) - mean;
        sum += diff * diff;
    }
    return sum / @as(f64, @floatFromInt(cluster.count));
}

pub fn silhouetteScore(clusters: []const Cluster, k: u32) f64 {
    if (k < 2) return 0;
    var total_score: f64 = 0;
    var total_points: u32 = 0;
    for (0..k) |ci| {
        for (0..clusters[ci].count) |pi| {
            const point = clusters[ci].members[pi];
            var a: f64 = 0;
            if (clusters[ci].count > 1) {
                for (0..clusters[ci].count) |pj| {
                    if (pi == pj) continue;
                    const other = clusters[ci].members[pj];
                    a += @abs(@as(f64, @floatFromInt(point)) - @as(f64, @floatFromInt(other)));
                }
                a /= @as(f64, @floatFromInt(clusters[ci].count - 1));
            }
            var min_b: f64 = std.math.inf(f64);
            for (0..k) |oi| {
                if (oi == ci or clusters[oi].count == 0) continue;
                var b: f64 = 0;
                for (0..clusters[oi].count) |oj| {
                    const other = clusters[oi].members[oj];
                    b += @abs(@as(f64, @floatFromInt(point)) - @as(f64, @floatFromInt(other)));
                }
                b /= @as(f64, @floatFromInt(clusters[oi].count));
                if (b < min_b) min_b = b;
            }
            const denom = @max(a, min_b);
            if (denom > 0) total_score += (min_b - a) / denom;
            total_points += 1;
        }
    }
    if (total_points == 0) return 0;
    return total_score / @as(f64, @floatFromInt(total_points));
}

pub fn dbscanCluster(scores: []const u32, epsilon: u32, min_pts: u32, labels: []i32) u32 {
    if (scores.len == 0) return 0;
    for (labels[0..scores.len]) |*l| l.* = -1;
    var cluster_id: i32 = 0;
    for (0..scores.len) |i| {
        if (labels[i] != -1) continue;
        var neighbors: u32 = 0;
        for (0..scores.len) |j| {
            const dist = if (scores[i] > scores[j]) scores[i] - scores[j] else scores[j] - scores[i];
            if (dist <= epsilon) neighbors += 1;
        }
        if (neighbors < min_pts) { labels[i] = -2; continue; }
        labels[i] = cluster_id;
        for (0..scores.len) |j| {
            if (labels[j] != -1 and labels[j] != -2) continue;
            const dist = if (scores[i] > scores[j]) scores[i] - scores[j] else scores[j] - scores[i];
            if (dist <= epsilon) labels[j] = cluster_id;
        }
        cluster_id += 1;
    }
    return @intCast(cluster_id);
}

pub fn elbow(scores: []const u32, max_k: u32, inertias: []f64) void {
    for (1..@min(max_k + 1, inertias.len + 1)) |k| {
        var clusters: [32]Cluster = undefined;
        _ = kmeansCluster(scores, @intCast(k), &clusters, 10);
        var inertia: f64 = 0;
        for (0..k) |i| inertia += clusters[i].variance * @as(f64, @floatFromInt(clusters[i].count));
        inertias[k - 1] = inertia;
    }
}
