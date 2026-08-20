# Mandelbrot benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib mandelbrot.mojo -o mandelbrot.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


def run_mandelbrot(n: Int, max_iter: Int) -> String:
    var rows = List[String]()
    for y in range(n):
        var row = ""
        for x in range(n):
            var cx = 2.5 * (Float64(x) / Float64(n) - 0.5)
            var cy = 1.5 * (Float64(y) / Float64(n) - 0.5)
            var i = 0
            var zx = 0.0
            var zy = 0.0
            while zx * zx + zy * zy < 4.0 and i < max_iter:
                var zx2 = zx * zx - zy * zy + cx
                zy = 2.0 * zx * zy + cy
                zx = zx2
                i += 1
            if i == max_iter:
                row += "."
            else:
                row += "#"
        rows.append(row)
    return "\n".join(rows)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_mandelbrot(ni, 50))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var max_iter: Int

    def __init__(out self):
        self.max_iter = 50

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        return PythonObject(run_mandelbrot(ni, self_ptr[].max_iter))


@export
def PyInit_mandelbrot() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("mandelbrot")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))