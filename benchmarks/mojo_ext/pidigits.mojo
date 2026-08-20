# Pi Digits benchmark as a Python-callable Mojo extension module.
# NOTE: requires arbitrary-precision integers (4000+ digits). Mojo's native
# Int is 64-bit and overflows, so the spigot arithmetic is delegated to Python
# via the built-in Python interop (std.python). The extension still demonstrates
# both integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim().run(n)          - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib pidigits.mojo -o pidigits.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder

def _module_code() -> String:
    return """
class PiDigits:
    def __init__(self):
        self.tmp1 = 0
        self.tmp2 = 0
        self.acc = 0
        self.den = 1
        self.num = 1
        self.k = 0

    def next_term(self):
        k2 = self.k * 2 + 1
        self.acc = self.acc + self.num * 2
        self.acc = self.acc * k2
        self.den = self.den * k2
        self.num = self.num * self.k

    def extract_digit(self, nth):
        self.tmp1 = self.num * nth
        self.tmp2 = self.tmp1 + self.acc
        self.tmp1 = self.tmp2 // self.den
        return self.tmp1

    def eliminate_digit(self, d):
        self.acc = self.acc - self.den * d
        self.acc = self.acc * 10
        self.num = self.num * 10


def run(n):
    pd = PiDigits()
    i = 0
    output = []
    line = []
    while i < n:
        pd.k += 1
        pd.next_term()
        if pd.num > pd.acc:
            continue
        d = pd.extract_digit(3)
        if d != pd.extract_digit(4):
            continue
        line.append(chr(48 + d))
        i += 1
        if i % 10 == 0:
            output.append("".join(line) + "\\t:" + str(i))
            line = []
        pd.eliminate_digit(d)
    remainder = i % 10
    if remainder != 0:
        output.append("".join(line) + " " * (10 - remainder) + "\\t:" + str(i))
    return "\\n".join(output)
"""


def _get_module() raises -> PythonObject:
    return Python.evaluate(_module_code(), file=True)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return _get_module().run(ni)


struct Sim(Movable, Writable):
    var mod: PythonObject

    def __init__(out self):
        self.mod = Python.none()

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        self = Sim()
        self.mod = _get_module()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        return self_ptr[].mod.run(ni)


@export
def PyInit_pidigits() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("pidigits")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))