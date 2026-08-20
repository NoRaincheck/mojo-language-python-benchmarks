const std = @import("std");

const LRUNode = struct {
    key: i32,
    value: i32,
    prev: ?*LRUNode = null,
    next: ?*LRUNode = null,
};

const LRUCache = struct {
    size: usize,
    count: usize,
    head: ?*LRUNode = null,
    tail: ?*LRUNode = null,
    lookup: std.AutoHashMap(i32, ?*LRUNode),

    fn init(capacity: usize, allocator: std.mem.Allocator) LRUCache {
        return LRUCache{
            .size = capacity,
            .count = 0,
            .head = null,
            .tail = null,
            .lookup = std.AutoHashMap(i32, ?*LRUNode).init(allocator),
        };
    }

    fn deinit(self: *LRUCache) void {
        self.lookup.deinit();
    }

    fn _allocNode(key: i32, value: i32, allocator: std.mem.Allocator) !*LRUNode {
        const node = try allocator.create(LRUNode);
        node.key = key;
        node.value = value;
        node.prev = null;
        node.next = null;
        return node;
    }

    fn _remove(self: *LRUCache, node: *LRUNode) void {
        if (self.head == node) self.head = node.next;
        if (self.tail == node) self.tail = node.prev;
        if (node.prev) |prev| prev.next = node.next;
        if (node.next) |next| next.prev = node.prev;
        node.prev = null;
        node.next = null;
    }

    fn _addToTail(self: *LRUCache, node: *LRUNode) void {
        if (self.head == null) {
            self.head = node;
            node.prev = null;
        } else if (self.tail) |tail| {
            tail.next = node;
            node.prev = tail;
        }
        self.tail = node;
        node.next = null;
    }

    fn moveToEnd(self: *LRUCache, node: *LRUNode) void {
        self._remove(node);
        self._addToTail(node);
    }

    fn get(self: *LRUCache, key: i32, _: std.mem.Allocator) i32 {
        if (self.lookup.getPtr(key)) |node_ptr| {
            const node = node_ptr.* orelse return -1;
            self.moveToEnd(node);
            return node.value;
        }
        return -1;
    }

    fn put(self: *LRUCache, key: i32, value: i32, allocator: std.mem.Allocator) !void {
        if (self.lookup.getPtr(key)) |node_ptr| {
            const node = node_ptr.* orelse return;
            node.value = value;
            self.moveToEnd(node);
            return;
        } else if (self.count == self.size) {
            if (self.head) |old| {
                _ = self.lookup.remove(old.key);
                old.key = key;
                old.value = value;
                self.moveToEnd(old);
                self.lookup.put(old.key, old) catch {};
                return;
            }
        }
        const node = try LRUCache._allocNode(key, value, allocator);
        try self.lookup.put(key, node);
        self._addToTail(node);
        self.count += 1;
    }
};

fn lcgNext(seed: *i64) i64 {
    const A: i64 = 1103515245;
    const C: i64 = 12345;
    const M: i64 = 2147483648;
    seed.* = @rem(A * seed.* + C, M);
    return seed.*;
}

pub fn main() !void {
    _ = std.heap.c_allocator;
    const allocator = std.heap.c_allocator;
    const size: usize = 100;
    const n: usize = 500000; // Default: lru benchmark args

    const mod_val = size * 10;
    var seed0: i64 = 0;
    var seed1: i64 = 1;
    var hit: usize = 0;
    var missed: usize = 0;

    var cache = LRUCache.init(size, allocator);
    defer cache.deinit();

    var i: usize = 0;
    while (i < n) : (i += 1) {
        seed0 = lcgNext(&seed0);
        const key0: i32 = @as(i32, @intCast(@rem(seed0, @as(i64, @intCast(mod_val)))));
        try cache.put(key0, key0, allocator);
        seed1 = lcgNext(&seed1);
        const key1: i32 = @as(i32, @intCast(@rem(seed1, @as(i64, @intCast(mod_val)))));
        const val = cache.get(key1, allocator);
        if (val == -1) {
            missed += 1;
        } else {
            hit += 1;
        }
    }

    std.debug.print("{d}\n{d}\n", .{ hit, missed });
}
