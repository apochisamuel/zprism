const std = @import("std");

pub const SMState = enum(u8) {
    idle = 0, parsing = 1, validating = 2, resolving = 3,
    caching = 4, error_state = 5, complete = 6, rollback = 7,
    suspended = 8, resuming = 9,
};

pub const SMEvent = enum(u8) {
    start = 0, data_ready = 1, validate_ok = 2, validate_fail = 3,
    resolve_ok = 4, resolve_fail = 5, cache_ok = 6, cache_fail = 7,
    reset = 8, pause = 9, unpause = 10, abort = 11,
};

pub const SMTransition = struct {
    from: SMState, event: SMEvent, to: SMState,
    guard: ?*const fn (*const StateMachine) bool,
    action: ?*const fn (*StateMachine) void,
};

pub const StateMachine = struct {
    current: SMState,
    transitions: [128]SMTransition,
    trans_count: u32,
    history: [256]SMState,
    history_count: u32,
    data: u64,
    error_count: u32,
    transition_count: u64,

    pub fn init() StateMachine {
        return StateMachine{
            .current = .idle,
            .transitions = undefined,
            .trans_count = 0,
            .history = undefined,
            .history_count = 0,
            .data = 0,
            .error_count = 0,
            .transition_count = 0,
        };
    }

    pub fn addTransition(self: *StateMachine, from: SMState, event: SMEvent, to: SMState) bool {
        if (self.trans_count >= 128) return false;
        self.transitions[self.trans_count] = SMTransition{
            .from = from, .event = event, .to = to,
            .guard = null, .action = null,
        };
        self.trans_count += 1;
        return true;
    }

    pub fn addGuardedTransition(self: *StateMachine, from: SMState, event: SMEvent, to: SMState,
        guard: *const fn (*const StateMachine) bool, action: *const fn (*StateMachine) void) bool {
        if (self.trans_count >= 128) return false;
        self.transitions[self.trans_count] = SMTransition{
            .from = from, .event = event, .to = to,
            .guard = guard, .action = action,
        };
        self.trans_count += 1;
        return true;
    }

    pub fn process(self: *StateMachine, event: SMEvent) bool {
        for (self.transitions[0..self.trans_count]) |*t| {
            if (t.from == self.current and t.event == event) {
                if (t.guard) |guard| { if (!guard(self)) continue; }
                if (self.history_count < 256) {
                    self.history[self.history_count] = self.current;
                    self.history_count += 1;
                }
                self.current = t.to;
                self.transition_count += 1;
                if (t.action) |action| action(self);
                return true;
            }
        }
        return false;
    }

    pub fn canProcess(self: *const StateMachine, event: SMEvent) bool {
        for (self.transitions[0..self.trans_count]) |*t| {
            if (t.from == self.current and t.event == event) {
                if (t.guard) |guard| return guard(self);
                return true;
            }
        }
        return false;
    }

    pub fn reset(self: *StateMachine) void {
        self.current = .idle;
        self.history_count = 0;
    }

    pub fn previousState(self: *const StateMachine) ?SMState {
        if (self.history_count == 0) return null;
        return self.history[self.history_count - 1];
    }

    pub fn stateTime(self: *const StateMachine, state: SMState) u32 {
        var count: u32 = 0;
        for (self.history[0..self.history_count]) |s| { if (s == state) count += 1; }
        if (self.current == state) count += 1;
        return count;
    }

    pub fn isTerminal(self: *const StateMachine) bool {
        return self.current == .complete or self.current == .error_state;
    }

    pub fn availableEvents(self: *const StateMachine, output: []SMEvent) u32 {
        var count: u32 = 0;
        for (self.transitions[0..self.trans_count]) |*t| {
            if (t.from == self.current) {
                var dup = false;
                for (output[0..count]) |e| { if (e == t.event) { dup = true; break; } }
                if (!dup and count < output.len) { output[count] = t.event; count += 1; }
            }
        }
        return count;
    }
};

pub fn buildParserSM() StateMachine {
    var sm = StateMachine.init();
    _ = sm.addTransition(.idle, .start, .parsing);
    _ = sm.addTransition(.parsing, .data_ready, .validating);
    _ = sm.addTransition(.validating, .validate_ok, .resolving);
    _ = sm.addTransition(.validating, .validate_fail, .rollback);
    _ = sm.addTransition(.rollback, .reset, .resolving);
    _ = sm.addTransition(.resolving, .resolve_ok, .caching);
    _ = sm.addTransition(.resolving, .resolve_fail, .error_state);
    _ = sm.addTransition(.caching, .cache_ok, .complete);
    _ = sm.addTransition(.caching, .cache_fail, .error_state);
    _ = sm.addTransition(.parsing, .abort, .error_state);
    _ = sm.addTransition(.idle, .pause, .suspended);
    _ = sm.addTransition(.suspended, .unpause, .idle);
    return sm;
}

pub fn simulateSM(sm: *StateMachine, events: []const SMEvent) u32 {
    var processed: u32 = 0;
    for (events) |event| {
        if (sm.process(event)) processed += 1;
        if (sm.isTerminal()) break;
    }
    return processed;
}

pub fn smComplexity(sm: *const StateMachine) u32 {
    var states_used: u32 = 0;
    var seen = [_]bool{false} ** 16;
    for (sm.transitions[0..sm.trans_count]) |*t| {
        if (@intFromEnum(t.from) < 16 and !seen[@intFromEnum(t.from)]) {
            seen[@intFromEnum(t.from)] = true; states_used += 1;
        }
        if (@intFromEnum(t.to) < 16 and !seen[@intFromEnum(t.to)]) {
            seen[@intFromEnum(t.to)] = true; states_used += 1;
        }
    }
    return states_used * sm.trans_count;
}
