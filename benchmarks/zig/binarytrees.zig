const std = @import("std");

const TreeNode = struct {
    left: ?*TreeNode = null,
    right: ?*TreeNode = null,

    fn alloc(allocator: std.mem.Allocator) !*TreeNode {
        return try allocator.create(TreeNode);
    }

    fn dealloc(self: *TreeNode, allocator: std.mem.Allocator) void {
        if (self.left) |node| {
            node.dealloc(allocator);
            allocator.destroy(node);
        }
        if (self.right) |node| {
            node.dealloc(allocator);
            allocator.destroy(node);
        }
    }
};

fn makeTree(depth: u32, allocator: std.mem.Allocator) !*TreeNode {
    if (depth > 0) {
        const node = try TreeNode.alloc(allocator);
        node.left = try makeTree(depth - 1, allocator);
        node.right = try makeTree(depth - 1, allocator);
        return node;
    } else {
        const node = try TreeNode.alloc(allocator);
        return node;
    }
}

fn checkTree(node: *TreeNode) u32 {
    if (node.left == null) {
        return 1;
    } else {
        return 1 + checkTree(node.left.?) + checkTree(node.right.?);
    }
}

fn makeCheck(depth: u32, allocator: std.mem.Allocator) !u32 {
    const tree = try makeTree(depth, allocator);
    const result = checkTree(tree);
    tree.dealloc(allocator);
    allocator.destroy(tree);
    return result;
}

pub fn main() !void {
    var allocator = std.heap.c_allocator;
    const n: u32 = 15; // Default: binarytrees benchmark arg

    const min_depth: u32 = 4;
    const max_depth: u32 = @max(min_depth + 2, n);
    const stretch_depth: u32 = max_depth + 1;

    const stretch_check = try makeCheck(stretch_depth, allocator);
    std.debug.print("stretch tree of depth {d}\t check: {d}\n", .{ stretch_depth, stretch_check });

    const long_lived_tree = try makeTree(max_depth, allocator);

    const mmd: u32 = max_depth + min_depth;
    var d: u32 = min_depth;
    while (d < stretch_depth) : (d += 2) {
        const i: u32 = @as(u32, 1) << @intCast(mmd - d);
        var cs: u32 = 0;
        var j: u32 = 0;
        while (j < i) : (j += 1) {
            cs += try makeCheck(d, allocator);
        }
        std.debug.print("{d}\t trees of depth {d}\t check: {d}\n", .{ i, d, cs });
    }

    const lc = checkTree(long_lived_tree);
    std.debug.print("long lived tree of depth {d}\t check: {d}\n", .{ max_depth, lc });

    long_lived_tree.dealloc(allocator);
    allocator.destroy(long_lived_tree);
}
