const std = @import("std");

pub const UnionFind = struct {
    parent: [4096]u32,
    rank: [4096]u32,
    size: [4096]u32,
    count: u32,
    components: u32,

    pub fn init(n: u32) UnionFind {
        var uf = UnionFind{
            .parent = undefined, .rank = std.mem.zeroes([4096]u32),
            .size = undefined, .count = @min(n, 4096), .components = @min(n, 4096),
        };
        for (0..uf.count) |i| { uf.parent[i] = @intCast(i); uf.size[i] = 1; }
        return uf;
    }

    pub fn find(self: *UnionFind, x: u32) u32 {
        if (x >= self.count) return x;
        var root = x;
        while (self.parent[root] != root) root = self.parent[root];
        var curr = x;
        while (curr != root) {
            const next = self.parent[curr];
            self.parent[curr] = root;
            curr = next;
        }
        return root;
    }

    pub fn unite(self: *UnionFind, x: u32, y: u32) bool {
        var rx = self.find(x);
        var ry = self.find(y);
        if (rx == ry) return false;
        if (self.rank[rx] < self.rank[ry]) { const tmp = rx; rx = ry; ry = tmp; }
        self.parent[ry] = rx;
        self.size[rx] += self.size[ry];
        if (self.rank[rx] == self.rank[ry]) self.rank[rx] += 1;
        self.components -= 1;
        return true;
    }

    pub fn connected(self: *UnionFind, x: u32, y: u32) bool { return self.find(x) == self.find(y); }
    pub fn componentSize(self: *UnionFind, x: u32) u32 { return self.size[self.find(x)]; }
    pub fn componentCount(self: *const UnionFind) u32 { return self.components; }

    pub fn largestComponent(self: *UnionFind) u32 {
        var max_size: u32 = 0;
        for (0..self.count) |i| {
            if (self.parent[i] == i and self.size[i] > max_size)
                max_size = self.size[i];
        }
        return max_size;
    }

    pub fn isolatedCount(self: *UnionFind) u32 {
        var isolated: u32 = 0;
        for (0..self.count) |i| { if (self.parent[i] == i and self.size[i] == 1) isolated += 1; }
        return isolated;
    }
};

pub fn buildFromEdges(edges: [][2]u32, n: u32) UnionFind {
    var uf = UnionFind.init(n);
    for (edges) |edge| _ = uf.unite(edge[0], edge[1]);
    return uf;
}

pub fn kruskalMST(edges: [][3]u32, n: u32, mst: [][3]u32) u32 {
    std.sort.insertion([3]u32, edges, {}, struct {
        fn lt(_: void, a: [3]u32, b: [3]u32) bool { return a[2] < b[2]; }
    }.lt);
    var uf = UnionFind.init(n);
    var count: u32 = 0;
    for (edges) |edge| {
        if (!uf.connected(edge[0], edge[1])) {
            _ = uf.unite(edge[0], edge[1]);
            if (count < mst.len) { mst[count] = edge; count += 1; }
        }
    }
    return count;
}
