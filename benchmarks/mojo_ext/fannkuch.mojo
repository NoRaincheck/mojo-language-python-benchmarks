# Fannkuch Redux benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib fannkuch.mojo -o fannkuch.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


def fannkuch(perm: List[Int]) -> Int:
    var n = len(perm)
    var first = perm[0]
    if first == 0:
        return 0
    var maxflips = 0

    var p = List[Int]()
    for i in range(n):
        p.append(perm[i])

    while True:
        var flips = 0
        var q = List[Int]()
        for i in range(n):
            q.append(p[i])
        while q[0] != 0:
            var i = q[0]
            var left = 0
            var right = i
            while left < right:
                var tmp = q[left]
                q[left] = q[right]
                q[right] = tmp
                left += 1
                right -= 1
            flips += 1
        if flips > maxflips:
            maxflips = flips
        if maxflips == first:
            break

        var k = n - 2
        while k >= 0 and p[k] > p[k + 1]:
            k -= 1
        if k < 0:
            break
        var l = n - 1
        while p[l] < p[k]:
            l -= 1
        var tmp = p[k]
        p[k] = p[l]
        p[l] = tmp
        var left = k + 1
        var right = n - 1
        while left < right:
            var tmp2 = p[left]
            p[left] = p[right]
            p[right] = tmp2
            left += 1
            right -= 1

    return maxflips


def run_fannkuch(n: Int) -> Int:
    var perm = List[Int]()
    for i in range(n):
        perm.append(i)
    var maxflips = 0

    while True:
        var result = fannkuch(perm)
        if result > maxflips:
            maxflips = result

        var k = n - 2
        while k >= 0 and perm[k] > perm[k + 1]:
            k -= 1
        if k < 0:
            break
        var l = n - 1
        while perm[l] < perm[k]:
            l -= 1
        var tmp = perm[k]
        perm[k] = perm[l]
        perm[l] = tmp
        var left = k + 1
        var right = n - 1
        while left < right:
            var tmp2 = perm[left]
            perm[left] = perm[right]
            perm[right] = tmp2
            left += 1
            right -= 1

    return maxflips


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_fannkuch(ni))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var config: Int

    def __init__(out self):
        self.config = 0

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        return PythonObject(run_fannkuch(Int(py=n)))


@export
def PyInit_fannkuch() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("fannkuch")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))