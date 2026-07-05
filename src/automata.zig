const std = @import("std");

pub const State = struct { id: u32, accepting: bool, label: u32 };
pub const Transition = struct { from: u32, to: u32, symbol: u8 };

pub const DFA = struct {
    states: [256]State,
    transitions: [1024]Transition,
    state_count: u32,
    trans_count: u32,
    start_state: u32,
    current_state: u32,
    alphabet_size: u32,

    pub fn init() DFA {
        var dfa = std.mem.zeroes(DFA);
        dfa.start_state = 0;
        dfa.current_state = 0;
        return dfa;
    }

    pub fn addState(self: *DFA, accepting: bool, label: u32) u32 {
        if (self.state_count >= 256) return self.state_count;
        self.states[self.state_count] = State{ .id = self.state_count, .accepting = accepting, .label = label };
        self.state_count += 1;
        return self.state_count - 1;
    }

    pub fn addTransition(self: *DFA, from: u32, to: u32, symbol: u8) bool {
        if (self.trans_count >= 1024) return false;
        self.transitions[self.trans_count] = Transition{ .from = from, .to = to, .symbol = symbol };
        self.trans_count += 1;
        if (symbol >= self.alphabet_size) self.alphabet_size = @as(u32, symbol) + 1;
        return true;
    }

    pub fn reset(self: *DFA) void { self.current_state = self.start_state; }

    pub fn step(self: *DFA, symbol: u8) bool {
        for (self.transitions[0..self.trans_count]) |*t| {
            if (t.from == self.current_state and t.symbol == symbol) {
                self.current_state = t.to;
                return true;
            }
        }
        return false;
    }

    pub fn run(self: *DFA, input: []const u8) bool {
        self.reset();
        for (input) |ch| {
            if (!self.step(ch)) return false;
        }
        return self.isAccepting();
    }

    pub fn isAccepting(self: *const DFA) bool {
        if (self.current_state >= self.state_count) return false;
        return self.states[self.current_state].accepting;
    }

    pub fn reachableStates(self: *const DFA) u32 {
        var visited = [_]bool{false} ** 256;
        var queue: [256]u32 = undefined;
        var qfront: u32 = 0;
        var qback: u32 = 0;
        visited[self.start_state] = true;
        queue[qback] = self.start_state;
        qback += 1;
        while (qfront < qback) {
            const state = queue[qfront];
            qfront += 1;
            for (self.transitions[0..self.trans_count]) |*t| {
                if (t.from == state and t.to < 256 and !visited[t.to]) {
                    visited[t.to] = true;
                    if (qback < 256) { queue[qback] = t.to; qback += 1; }
                }
            }
        }
        var count: u32 = 0;
        for (visited[0..self.state_count]) |v| { if (v) count += 1; }
        return count;
    }

    pub fn deadStates(self: *const DFA) u32 {
        var dead: u32 = 0;
        for (0..self.state_count) |s| {
            if (self.states[s].accepting) continue;
            var has_outgoing = false;
            for (self.transitions[0..self.trans_count]) |*t| {
                if (t.from == s and t.to != s) { has_outgoing = true; break; }
            }
            if (!has_outgoing) dead += 1;
        }
        return dead;
    }

    pub fn minimize(self: *DFA) void {
        var distinguishable: [256][256]bool = std.mem.zeroes([256][256]bool);
        for (0..self.state_count) |i| {
            for (0..self.state_count) |j| {
                if (self.states[i].accepting != self.states[j].accepting) {
                    distinguishable[i][j] = true;
                    distinguishable[j][i] = true;
                }
            }
        }
        var changed = true;
        while (changed) {
            changed = false;
            for (0..self.state_count) |i| {
                for (i + 1..self.state_count) |j| {
                    if (distinguishable[i][j]) continue;
                    for (0..self.alphabet_size) |sym| {
                        const ti = self.transition(@intCast(i), @intCast(sym));
                        const tj = self.transition(@intCast(j), @intCast(sym));
                        if (ti != null and tj != null and distinguishable[ti.?][tj.?]) {
                            distinguishable[i][j] = true;
                            distinguishable[j][i] = true;
                            changed = true;
                        }
                    }
                }
            }
        }
    }

    fn transition(self: *const DFA, from: u32, symbol: u32) ?u32 {
        for (self.transitions[0..self.trans_count]) |*t| {
            if (t.from == from and t.symbol == @as(u8, @intCast(symbol))) return t.to;
        }
        return null;
    }

    pub fn complement(self: *DFA) void {
        for (0..self.state_count) |i| {
            self.states[i].accepting = !self.states[i].accepting;
        }
    }

    pub fn languageEmpty(self: *DFA) bool {
        var visited = [_]bool{false} ** 256;
        var queue: [256]u32 = undefined;
        var qfront: u32 = 0;
        var qback: u32 = 0;
        visited[self.start_state] = true;
        queue[qback] = self.start_state;
        qback += 1;
        while (qfront < qback) {
            const state = queue[qfront]; qfront += 1;
            if (self.states[state].accepting) return false;
            for (self.transitions[0..self.trans_count]) |*t| {
                if (t.from == state and t.to < 256 and !visited[t.to]) {
                    visited[t.to] = true;
                    if (qback < 256) { queue[qback] = t.to; qback += 1; }
                }
            }
        }
        return true;
    }

    pub fn transitionDensity(self: *const DFA) f64 {
        if (self.state_count == 0 or self.alphabet_size == 0) return 0;
        const max_trans = @as(u64, self.state_count) * self.alphabet_size;
        return @as(f64, @floatFromInt(self.trans_count)) / @as(f64, @floatFromInt(max_trans));
    }
};

pub fn buildFromPattern(pattern: []const u8) DFA {
    var dfa = DFA.init();
    var prev = dfa.addState(false, 0);
    dfa.start_state = prev;
    for (pattern) |ch| {
        const next = dfa.addState(false, 0);
        _ = dfa.addTransition(prev, next, ch);
        prev = next;
    }
    dfa.states[prev].accepting = true;
    return dfa;
}

pub fn productDFA(a: *const DFA, b: *const DFA) DFA {
    var result = DFA.init();
    for (0..a.state_count) |i| {
        for (0..b.state_count) |j| {
            const accepting = a.states[i].accepting and b.states[j].accepting;
            _ = result.addState(accepting, @intCast(i * 256 + j));
        }
    }
    for (a.transitions[0..a.trans_count]) |*ta| {
        for (b.transitions[0..b.trans_count]) |*tb| {
            if (ta.symbol == tb.symbol) {
                const from = ta.from * b.state_count + tb.from;
                const to = ta.to * b.state_count + tb.to;
                if (from < result.state_count and to < result.state_count) {
                    _ = result.addTransition(from, to, ta.symbol);
                }
            }
        }
    }
    return result;
}
