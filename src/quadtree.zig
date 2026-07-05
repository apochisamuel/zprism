const std = @import("std");
const geometry = @import("geometry.zig");

pub const QuadNode = struct {
    bounds: geometry.Rect,
    points: [16]geometry.Vec2,
    point_count: u32,
    children: [4]?*QuadNode,
    depth: u32,
    is_leaf: bool,
};

pub const QuadTree = struct {
    allocator: std.mem.Allocator,
    root: *QuadNode,
    total_points: u32,
    max_depth: u32,
    node_count: u32,

    pub fn init(allocator: std.mem.Allocator, bounds: geometry.Rect, max_depth: u32) !QuadTree {
        const root = try allocator.create(QuadNode);
        root.* = QuadNode{
            .bounds = bounds, .points = undefined, .point_count = 0,
            .children = .{ null, null, null, null }, .depth = 0, .is_leaf = true,
        };
        return QuadTree{
            .allocator = allocator, .root = root,
            .total_points = 0, .max_depth = max_depth, .node_count = 1,
        };
    }

    pub fn insert(self: *QuadTree, point: geometry.Vec2) !bool {
        return try self.insertNode(self.root, point);
    }

    fn insertNode(self: *QuadTree, node: *QuadNode, point: geometry.Vec2) !bool {
        if (!geometry.rectContains(node.bounds, point)) return false;
        if (node.is_leaf) {
            if (node.point_count < 16) {
                node.points[node.point_count] = point;
                node.point_count += 1;
                self.total_points += 1;
                return true;
            }
            if (node.depth >= self.max_depth) return false;
            try self.subdivide(node);
        }
        for (&node.children) |*child| {
            if (child.*) |c| {
                if (try self.insertNode(c, point)) return true;
            }
        }
        return false;
    }

    fn subdivide(self: *QuadTree, node: *QuadNode) !void {
        const hw = node.bounds.w / 2.0;
        const hh = node.bounds.h / 2.0;
        const x = node.bounds.x;
        const y = node.bounds.y;
        const rects = [4]geometry.Rect{
            .{ .x = x, .y = y, .w = hw, .h = hh },
            .{ .x = x + hw, .y = y, .w = hw, .h = hh },
            .{ .x = x, .y = y + hh, .w = hw, .h = hh },
            .{ .x = x + hw, .y = y + hh, .w = hw, .h = hh },
        };
        for (&node.children, rects) |*child, rect| {
            const c = try self.allocator.create(QuadNode);
            c.* = QuadNode{
                .bounds = rect, .points = undefined, .point_count = 0,
                .children = .{ null, null, null, null },
                .depth = node.depth + 1, .is_leaf = true,
            };
            child.* = c;
            self.node_count += 1;
        }
        node.is_leaf = false;
        const saved_points = node.points;
        const saved_count = node.point_count;
        node.point_count = 0;
        for (0..saved_count) |i| {
            for (&node.children) |*child| {
                if (child.*) |c| {
                    if (geometry.rectContains(c.bounds, saved_points[i])) {
                        c.points[c.point_count] = saved_points[i];
                        c.point_count += 1;
                        break;
                    }
                }
            }
        }
    }

    pub fn queryRange(self: *const QuadTree, range: geometry.Rect, results: []geometry.Vec2) u32 {
        return self.queryNode(self.root, range, results, 0);
    }

    fn queryNode(self: *const QuadTree, node: *const QuadNode, range: geometry.Rect, results: []geometry.Vec2, start: u32) u32 {
        _ = self;
        if (!geometry.rectOverlaps(node.bounds, range)) return start;
        var count = start;
        if (node.is_leaf) {
            for (0..node.point_count) |i| {
                if (count >= results.len) break;
                if (geometry.rectContains(range, node.points[i])) {
                    results[count] = node.points[i];
                    count += 1;
                }
            }
        } else {
            for (node.children) |child| {
                if (child) |c| count = @This().queryNode(undefined, c, range, results, count);
            }
        }
        return count;
    }

    pub fn deinit(self: *QuadTree) void {
        freeNode(self.allocator, self.root);
    }
};

fn freeNode(allocator: std.mem.Allocator, node: *QuadNode) void {
    for (&node.children) |*child| {
        if (child.*) |c| { freeNode(allocator, c); child.* = null; }
    }
    allocator.destroy(node);
}

pub fn nearestInTree(tree: *const QuadTree, target: geometry.Vec2) ?geometry.Vec2 {
    return nearestInNode(tree.root, target, null);
}

fn nearestInNode(node: *const QuadNode, target: geometry.Vec2, best: ?geometry.Vec2) ?geometry.Vec2 {
    var current_best = best;
    if (node.is_leaf) {
        for (0..node.point_count) |i| {
            const d = geometry.vec2Distance(target, node.points[i]);
            if (current_best == null or d < geometry.vec2Distance(target, current_best.?)) {
                current_best = node.points[i];
            }
        }
    } else {
        for (node.children) |child| {
            if (child) |c| current_best = nearestInNode(c, target, current_best);
        }
    }
    return current_best;
}

pub fn treeDepth(node: *const QuadNode) u32 {
    if (node.is_leaf) return node.depth;
    var max_d: u32 = 0;
    for (node.children) |child| {
        if (child) |c| {
            const d = treeDepth(c);
            if (d > max_d) max_d = d;
        }
    }
    return max_d;
}

pub fn treeBalance(node: *const QuadNode) f64 {
    if (node.is_leaf) return 1.0;
    var depths: [4]u32 = .{ 0, 0, 0, 0 };
    for (node.children, 0..) |child, i| {
        if (child) |c| depths[i] = treeDepth(c);
    }
    var mn: u32 = std.math.maxInt(u32);
    var mx: u32 = 0;
    for (depths) |d| { if (d < mn) mn = d; if (d > mx) mx = d; }
    if (mx == 0) return 1.0;
    return @as(f64, @floatFromInt(mn)) / @as(f64, @floatFromInt(mx));
}
