# E Digits benchmark as a Python-callable Mojo extension module.
# NOTE: requires arbitrary-precision integers (~200,000 digits for n=100000).
# Mojo's native Int is 64-bit and overflows, so the big-integer arithmetic and
# digit-string conversion are delegated to Python via the built-in Python
# interop (std.python). The extension still demonstrates both patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim().run(n)          - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib edigits.mojo -o edigits.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder

def _module_code() -> String:
    return """
import sys

sys.set_int_max_str_digits(0)

import math

LN_TAU = math.log(math.tau)
LN_10 = math.log(10.0)


def sum_terms(a, b):
    if b == a + 1:
        return 1, b
    mid = (a + b) // 2
    p_left, q_left = sum_terms(a, mid)
    p_right, q_right = sum_terms(mid, b)
    return p_left * q_right + p_right, q_left * q_right


def test_k(n, k):
    if k <= 0:
        return False
    ln_k_factorial = k * (math.log(k) - 1) + 0.5 * LN_TAU
    log_10_k_factorial = ln_k_factorial / LN_10
    return log_10_k_factorial >= n + 50


def binary_search(n):
    a = 0
    b = 1
    while not test_k(n, b):
        a = b
        b *= 2
    while b - a > 1:
        m = (a + b) // 2
        if test_k(n, m):
            b = m
        else:
            a = m
    return b


def run(n):
    k = binary_search(n)
    p, q = sum_terms(0, k - 1)
    p += q
    answer = p * (10 ** (n - 1)) // q
    s = str(answer)
    output = []
    for i in range(0, n, 10):
        if i + 10 <= n:
            output.append(s[i:i + 10] + "\\t:" + str(i + 10))
        else:
            output.append(s[i:] + " " * (10 - n % 10) + "\\t:" + str(n))
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
def PyInit_edigits() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("edigits")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))