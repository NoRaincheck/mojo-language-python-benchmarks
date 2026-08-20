# Binary Trees benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib binarytrees.mojo -o binarytrees.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder

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


def make_check(depth: Int) raises -> Int:
    var tree = make_tree(depth)
    var result = check_tree(tree)
    free_tree(tree)
    return result


def run_binarytrees(n: Int, min_depth: Int) raises -> String:
    var max_depth = max(min_depth + 2, n)
    var stretch_depth = max_depth + 1
    var out = List[String]()

    var stretch_check = make_check(stretch_depth)
    out.append(String(t"stretch tree of depth {stretch_depth}\t check: {stretch_check}"))

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
        out.append(String(t"{i}\t trees of depth {d}\t check: {cs}"))
        d += 2

    var lc = check_tree(long_lived_tree)
    free_tree(long_lived_tree)
    out.append(String(t"long lived tree of depth {max_depth}\t check: {lc}"))
    return "\n".join(out)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_binarytrees(ni, 4))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var min_depth: Int

    def __init__(out self):
        self.min_depth = 4

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        return PythonObject(run_binarytrees(ni, self_ptr[].min_depth))


@export
def PyInit_binarytrees() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("binarytrees")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))