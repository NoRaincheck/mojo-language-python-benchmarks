# NSieve (prime sieve) benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib nsieve.mojo -o nsieve.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


def pad_left(s: String, w: Int) -> String:
    var n = s.byte_length()
    if n >= w:
        return s
    var sp = ""
    for _ in range(w - n):
        sp += " "
    return sp + s


def nsieve(n: Int) -> Int:
    var count = 0
    var flags = List[Bool]()
    for _ in range(n):
        flags.append(True)
    for i in range(2, n):
        if flags[i]:
            count += 1
            var j = i << 1
            while j < n:
                flags[j] = False
                j += i
    return count


def run_nsieve(n: Int) -> String:
    var out = List[String]()
    for i in range(3):
        var size = 10000 << (n - i)
        var count = nsieve(size)
        out.append(
            "Primes up to "
            + pad_left(String(t"{size}"), 8)
            + " "
            + pad_left(String(t"{count}"), 8)
        )
    return "\n".join(out)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_nsieve(ni))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var passes: Int

    def __init__(out self):
        self.passes = 3

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        var out = List[String]()
        for i in range(self_ptr[].passes):
            var size = 10000 << (ni - i)
            var count = nsieve(size)
            out.append(
                "Primes up to "
                + pad_left(String(t"{size}"), 8)
                + " "
                + pad_left(String(t"{count}"), 8)
            )
        return PythonObject("\n".join(out))


@export
def PyInit_nsieve() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("nsieve")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))