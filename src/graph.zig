const std = @import("std");
const types = @import("types.zig");

pub const GraphNode = struct {
    id: u32, node_type: NodeType, weight: u32,
    edges_start: u32, edge_count: u32,
};
pub const GraphEdge = struct { source: u32, target: u32, weight: u32 };
pub const NodeType = enum { symbol, string, attr, reloc, event, section };

pub const DependencyGraph = struct {
    nodes: []GraphNode, node_count: u32,
    edges: []GraphEdge, edge_count: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DependencyGraph) void {
        self.allocator.free(self.nodes);
        self.allocator.free(self.edges);
    }
};

pub fn buildGraph(allocator: std.mem.Allocator, doc: *const types.Document) !DependencyGraph {
    const max_nodes = doc.symbols.count + doc.strings.count + doc.attrs.count + doc.relocs.count;
    if (max_nodes == 0) return DependencyGraph{
        .nodes = &.{}, .node_count = 0,
        .edges = &.{}, .edge_count = 0,
        .allocator = allocator,
    };

    const nodes = try allocator.alloc(GraphNode, @min(max_nodes, 4096));
    const edges = try allocator.alloc(GraphEdge, @min(max_nodes * 2, 8192));
    var nc: u32 = 0;
    var ec: u32 = 0;

    if (doc.symbols.items) |syms| {
        for (syms, 0..) |*sym, i| {
            if (nc >= nodes.len) break;
            nodes[nc] = GraphNode{
                .id = @intCast(i), .node_type = .symbol,
                .weight = sym.derived_score, .edges_start = ec, .edge_count = 0,
            };
            if (sym.name_index < doc.strings.count and ec < edges.len) {
                edges[ec] = GraphEdge{ .source = nc, .target = sym.name_index, .weight = 1 };
                ec += 1; nodes[nc].edge_count += 1;
            }
            if (sym.attr_index < doc.attrs.count and ec < edges.len) {
                edges[ec] = GraphEdge{ .source = nc, .target = sym.attr_index + doc.strings.count, .weight = 2 };
                ec += 1; nodes[nc].edge_count += 1;
            }
            nc += 1;
        }
    }

    if (doc.relocs.items) |relocs| {
        for (relocs) |*rel| {
            if (nc >= nodes.len) break;
            nodes[nc] = GraphNode{
                .id = rel.symbol_index, .node_type = .reloc,
                .weight = rel.resolved_hash, .edges_start = ec, .edge_count = 0,
            };
            if (ec < edges.len) {
                edges[ec] = GraphEdge{ .source = nc, .target = rel.symbol_index, .weight = rel.target };
                ec += 1; nodes[nc].edge_count += 1;
            }
            nc += 1;
        }
    }

    return DependencyGraph{
        .nodes = nodes[0..nc], .node_count = nc,
        .edges = edges[0..ec], .edge_count = ec,
        .allocator = allocator,
    };
}

pub fn computePageRank(graph: *const DependencyGraph, iterations: u32) f64 {
    if (graph.node_count == 0) return 0;
    var max_rank: f64 = 0;
    var ranks: [4096]f64 = undefined;
    for (0..@min(graph.node_count, 4096)) |i| {
        ranks[i] = 1.0 / @as(f64, @floatFromInt(graph.node_count));
    }
    for (0..iterations) |_| {
        var new_ranks: [4096]f64 = [_]f64{0.15 / @as(f64, @floatFromInt(graph.node_count))} ** 4096;
        for (graph.edges[0..graph.edge_count]) |*edge| {
            if (edge.source < 4096 and edge.target < 4096) {
                const src_edges = graph.nodes[edge.source].edge_count;
                if (src_edges > 0) {
                    new_ranks[edge.target] += 0.85 * ranks[edge.source] /
                        @as(f64, @floatFromInt(src_edges));
                }
            }
        }
        for (0..@min(graph.node_count, 4096)) |i| {
            ranks[i] = new_ranks[i];
            if (ranks[i] > max_rank) max_rank = ranks[i];
        }
    }
    return max_rank;
}

pub fn findConnectedComponents(graph: *const DependencyGraph) u32 {
    if (graph.node_count == 0) return 0;
    var visited = [_]bool{false} ** 4096;
    var components: u32 = 0;
    for (0..@min(graph.node_count, 4096)) |start| {
        if (visited[start]) continue;
        components += 1;
        var stack: [256]u32 = undefined;
        var sp: u32 = 0;
        stack[0] = @intCast(start);
        sp = 1;
        while (sp > 0) {
            sp -= 1;
            const node = stack[sp];
            if (node >= 4096 or visited[node]) continue;
            visited[node] = true;
            const n = &graph.nodes[node];
            for (graph.edges[n.edges_start..][0..n.edge_count]) |*edge| {
                if (edge.target < 4096 and !visited[edge.target] and sp < 255) {
                    stack[sp] = edge.target;
                    sp += 1;
                }
            }
        }
    }
    return components;
}

pub fn topologicalSort(graph: *const DependencyGraph, output: []u32) u32 {
    if (graph.node_count == 0) return 0;
    var in_degree = [_]u32{0} ** 4096;
    for (graph.edges[0..graph.edge_count]) |*edge| {
        if (edge.target < 4096) in_degree[edge.target] += 1;
    }
    var queue: [4096]u32 = undefined;
    var qfront: u32 = 0;
    var qback: u32 = 0;
    for (0..@min(graph.node_count, 4096)) |i| {
        if (in_degree[i] == 0) { queue[qback] = @intCast(i); qback += 1; }
    }
    var count: u32 = 0;
    while (qfront < qback) {
        const node = queue[qfront]; qfront += 1;
        if (count < output.len) { output[count] = node; count += 1; }
        if (node < graph.node_count) {
            const n = &graph.nodes[node];
            for (graph.edges[n.edges_start..][0..n.edge_count]) |*edge| {
                if (edge.target < 4096) {
                    in_degree[edge.target] -= 1;
                    if (in_degree[edge.target] == 0 and qback < 4096) {
                        queue[qback] = edge.target; qback += 1;
                    }
                }
            }
        }
    }
    return count;
}
