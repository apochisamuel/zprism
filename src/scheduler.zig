const std = @import("std");

pub const Priority = enum(u8) { critical = 0, high = 1, normal = 2, low = 3, idle = 4 };

pub const Task = struct {
    id: u32, priority: Priority, deadline: u64,
    estimated_cost: u32, actual_cost: u32,
    dependencies: [8]u32, dep_count: u32,
    status: TaskStatus, result: u32,
};

pub const TaskStatus = enum { pending, ready, running, complete, failed, blocked };

pub const Scheduler = struct {
    tasks: [512]Task,
    count: u32,
    clock: u64,
    completed: u32,
    failed: u32,
    total_cost: u64,

    pub fn init() Scheduler {
        return Scheduler{
            .tasks = undefined, .count = 0, .clock = 0,
            .completed = 0, .failed = 0, .total_cost = 0,
        };
    }

    pub fn addTask(self: *Scheduler, id: u32, priority: Priority, deadline: u64, cost: u32) bool {
        if (self.count >= 512) return false;
        self.tasks[self.count] = Task{
            .id = id, .priority = priority, .deadline = deadline,
            .estimated_cost = cost, .actual_cost = 0,
            .dependencies = std.mem.zeroes([8]u32), .dep_count = 0,
            .status = .pending, .result = 0,
        };
        self.count += 1;
        return true;
    }

    pub fn addDependency(self: *Scheduler, task_id: u32, dep_id: u32) bool {
        for (self.tasks[0..self.count]) |*t| {
            if (t.id == task_id and t.dep_count < 8) {
                t.dependencies[t.dep_count] = dep_id;
                t.dep_count += 1;
                return true;
            }
        }
        return false;
    }

    pub fn updateReady(self: *Scheduler) u32 {
        var updated: u32 = 0;
        for (self.tasks[0..self.count]) |*t| {
            if (t.status != .pending) continue;
            var all_done = true;
            for (t.dependencies[0..t.dep_count]) |dep_id| {
                var found = false;
                for (self.tasks[0..self.count]) |*other| {
                    if (other.id == dep_id and other.status == .complete) { found = true; break; }
                }
                if (!found) { all_done = false; break; }
            }
            if (all_done) { t.status = .ready; updated += 1; }
        }
        return updated;
    }

    pub fn scheduleNext(self: *Scheduler) ?*Task {
        _ = self.updateReady();
        var best: ?*Task = null;
        for (self.tasks[0..self.count]) |*t| {
            if (t.status != .ready) continue;
            if (best == null or @intFromEnum(t.priority) < @intFromEnum(best.?.priority) or
                (@intFromEnum(t.priority) == @intFromEnum(best.?.priority) and t.deadline < best.?.deadline))
            {
                best = t;
            }
        }
        if (best) |b| b.status = .running;
        return best;
    }

    pub fn completeTask(self: *Scheduler, task_id: u32, cost: u32) bool {
        for (self.tasks[0..self.count]) |*t| {
            if (t.id == task_id) {
                t.status = .complete;
                t.actual_cost = cost;
                self.completed += 1;
                self.total_cost += cost;
                self.clock += cost;
                return true;
            }
        }
        return false;
    }

    pub fn failTask(self: *Scheduler, task_id: u32) bool {
        for (self.tasks[0..self.count]) |*t| {
            if (t.id == task_id) { t.status = .failed; self.failed += 1; return true; }
        }
        return false;
    }

    pub fn pendingCount(self: *const Scheduler) u32 {
        var c: u32 = 0;
        for (self.tasks[0..self.count]) |*t| {
            if (t.status == .pending or t.status == .ready) c += 1;
        }
        return c;
    }

    pub fn averageCost(self: *const Scheduler) f64 {
        if (self.completed == 0) return 0;
        return @as(f64, @floatFromInt(self.total_cost)) / @as(f64, @floatFromInt(self.completed));
    }

    pub fn missedDeadlines(self: *const Scheduler) u32 {
        var missed: u32 = 0;
        for (self.tasks[0..self.count]) |*t| {
            if (t.status == .complete and self.clock > t.deadline) missed += 1;
        }
        return missed;
    }

    pub fn criticalPath(self: *const Scheduler, path: []u32) u32 {
        var count: u32 = 0;
        for (self.tasks[0..self.count]) |*t| {
            if (t.priority == .critical and count < path.len) {
                path[count] = t.id; count += 1;
            }
        }
        return count;
    }

    pub fn utilization(self: *const Scheduler) f64 {
        if (self.clock == 0) return 0;
        return @as(f64, @floatFromInt(self.total_cost)) / @as(f64, @floatFromInt(self.clock));
    }
};

pub fn runAllTasks(sched: *Scheduler) u32 {
    var rounds: u32 = 0;
    while (sched.pendingCount() > 0 and rounds < 1000) : (rounds += 1) {
        if (sched.scheduleNext()) |task| {
            _ = sched.completeTask(task.id, task.estimated_cost);
        } else break;
    }
    return rounds;
}
