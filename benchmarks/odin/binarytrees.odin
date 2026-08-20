// Binary Trees benchmark in Odin
// Ported from the Computer Language Benchmarks Game
// Fixed for current Odin (dev-2026): ^T pointers, :: constants, -> returns,
// new/mem.free allocation, recursive dealloc (equivalent to Zig)

package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"

TreeNode :: struct {
    left:  ^TreeNode,
    right: ^TreeNode,
}

make_tree :: proc(depth: u32, alloc: mem.Allocator) -> ^TreeNode {
    node := new(TreeNode, alloc)
    if depth > 0 {
        node.left = make_tree(depth - 1, alloc)
        node.right = make_tree(depth - 1, alloc)
    }
    return node
}

free_tree :: proc(node: ^TreeNode, alloc: mem.Allocator) {
    if node.left != nil {
        free_tree(node.left, alloc)
    }
    if node.right != nil {
        free_tree(node.right, alloc)
    }
    mem.free(node, alloc)
}

check_tree :: proc(node: ^TreeNode) -> u32 {
    if node.left == nil {
        return 1
    }
    return 1 + check_tree(node.left) + check_tree(node.right)
}

make_check :: proc(depth: u32, alloc: mem.Allocator) -> u32 {
    tree := make_tree(depth, alloc)
    result := check_tree(tree)
    free_tree(tree, alloc)
    return result
}

main :: proc() {
    alloc := context.allocator
    args := os.args

    n := u32(6)
    if len(args) > 1 {
        n = u32(strconv.parse_int(args[1]) or_else 6)
    }

    min_depth := u32(4)
    max_depth := max(min_depth + 2, n)
    stretch_depth := max_depth + 1

    stretch_check := make_check(stretch_depth, alloc)
    fmt.printfln("stretch tree of depth %d\t check: %d", stretch_depth, stretch_check)

    long_lived_tree := make_tree(max_depth, alloc)

    mmd := max_depth + min_depth
    d := min_depth
    for d < stretch_depth {
        i := u32(1) << (mmd - d)
        cs := u32(0)
        j := u32(0)
        for j < i {
            cs += make_check(d, alloc)
            j += 1
        }
        fmt.printfln("%d\t trees of depth %d\t check: %d", i, d, cs)
        d += 2
    }

    lc := check_tree(long_lived_tree)
    fmt.printfln("long lived tree of depth %d\t check: %d", max_depth, lc)

    free_tree(long_lived_tree, alloc)
}