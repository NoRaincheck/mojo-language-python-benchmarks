# Binary Trees benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Rewritten for Mojo 1.0 syntax (def / Pointer / std.sys.argv)

from std.sys import argv


struct TreeNode:
    var left: Optional[Pointer[TreeNode, MutUntrackedOrigin]]
    var right: Optional[Pointer[TreeNode, MutUntrackedOrigin]]

    @staticmethod
    def alloc() raises -> Pointer[TreeNode, MutUntrackedOrigin]:
        var node = alloc[TreeNode](1)
        node[].left = None
        node[].right = None
        return node


def make_tree(depth: Int) raises -> Pointer[TreeNode, MutUntrackedOrigin]:
    var node = TreeNode.alloc()
    if depth > 0:
        node[].left = make_tree(depth - 1)
        node[].right = make_tree(depth - 1)
    return node


def free_tree(node: Pointer[TreeNode, MutUntrackedOrigin]):
    if node[].left is not None:
        free_tree(node[].left.value())
    if node[].right is not None:
        free_tree(node[].right.value())
    node.free()


def check_tree(node: Pointer[TreeNode, MutUntrackedOrigin]) -> Int:
    if node[].left is None:
        return 1
    else:
        return 1 + check_tree(node[].left.value()) + check_tree(node[].right.value())


@always_inline("nodebug")
def make_check(depth: Int) raises -> Int:
    var tree = make_tree(depth)
    var result = check_tree(tree)
    free_tree(tree)
    return result


def main() raises:
    var n = 15
    var a = argv()
    if len(a) > 1:
        n = Int(a[1])

    var min_depth = 4
    var max_depth = max(min_depth + 2, n)
    var stretch_depth = max_depth + 1

    var stretch_check = make_check(stretch_depth)
    print(t"stretch tree of depth {stretch_depth}\t check: {stretch_check}")

    var long_lived_tree = make_tree(max_depth)

    var mmd = max_depth + min_depth
    var d = min_depth
    while d < stretch_depth:
        var i = 1 << (mmd - d)
        var cs = 0
        var j = 0
        while j < i:
            cs += make_check(d)
            j += 1
        print(t"{i}\t trees of depth {d}\t check: {cs}")
        d += 2

    var lc = check_tree(long_lived_tree)
    print(t"long lived tree of depth {max_depth}\t check: {lc}")

    free_tree(long_lived_tree)