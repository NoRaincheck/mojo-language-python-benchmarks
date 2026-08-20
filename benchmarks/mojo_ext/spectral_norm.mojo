# Spectral Norm benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib spectral_norm.mojo -o spectral_norm.so

from std.os import abort
from std.math import sqrt as std_sqrt
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


def eval_A(i: Int, j: Int) -> Float64:
    var ij = i + j
    return Float64(ij * (ij + 1) // 2 + i + 1)


def a_sum(u: List[Float64], i: Int) -> Float64:
    var result = 0.0
    for j in range(len(u)):
        result += u[j] / eval_A(i, j)
    return result


def at_sum(u: List[Float64], i: Int) -> Float64:
    var result = 0.0
    for j in range(len(u)):
        result += u[j] / eval_A(j, i)
    return result


def multiply_AtAv(u: List[Float64]) -> List[Float64]:
    var n = len(u)
    var tmp = List[Float64]()
    for i in range(n):
        tmp.append(a_sum(u, i))
    var result = List[Float64]()
    for i in range(n):
        result.append(at_sum(tmp, i))
    return result^


def run_spectral(n: Int) -> Float64:
    var u = List[Float64]()
    for _ in range(n):
        u.append(1.0)

    var v = List[Float64]()
    for _ in range(10):
        v = multiply_AtAv(u)
        u = multiply_AtAv(v)

    var vBv = 0.0
    var vv = 0.0
    for i in range(len(u)):
        vBv += u[i] * v[i]
        vv += v[i] * v[i]

    return std_sqrt(vBv / vv)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_spectral(ni))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var iterations: Int

    def __init__(out self):
        self.iterations = 10

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        var u = List[Float64]()
        for _ in range(ni):
            u.append(1.0)

        var v = List[Float64]()
        for _ in range(self_ptr[].iterations):
            v = multiply_AtAv(u)
            u = multiply_AtAv(v)

        var vBv = 0.0
        var vv = 0.0
        for i in range(len(u)):
            vBv += u[i] * v[i]
            vv += v[i] * v[i]

        return PythonObject(std_sqrt(vBv / vv))


@export
def PyInit_spectral_norm() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("spectral_norm")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))