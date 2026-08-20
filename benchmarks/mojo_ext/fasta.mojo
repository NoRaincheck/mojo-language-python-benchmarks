# Fasta benchmark as a Python-callable Mojo extension module.
# Exposes two integration patterns:
#   1. compute(n)            - PythonObject boundary ("python objects")
#   2. Sim(n).run(n)         - native Mojo struct exposed to Python ("native objects")
# Built with: mojo build --emit shared-lib fasta.mojo -o fasta.so

from std.os import abort
from std.python import Python, PythonObject
from std.python.bindings import PythonModuleBuilder


struct RNGState:
    var seed: Int

    def __init__(out self, seed: Int):
        self.seed = seed


def lcg_next(mut state: RNGState) -> Float64:
    var ia: Int = 3877
    var ic: Int = 29573
    var im: Int = 139968
    state.seed = (state.seed * ia + ic) % im
    return Float64(state.seed) / Float64(im)


def pick_char(probs: List[Float64], chars: List[String], r: Float64) -> String:
    var lo: Int = 0
    var hi = len(probs) - 1
    while lo < hi:
        var mid = (lo + hi) // 2
        if probs[mid] < r:
            lo = mid + 1
        else:
            hi = mid
    return chars[lo]


def repeat_fasta(src: String, n: Int) -> String:
    var width: Int = 60
    var r = src.byte_length()
    var repeats = n // r + 2
    var s = src
    for _ in range(repeats - 1):
        s += src
    var output = List[String]()
    var total: Int = 0
    while total < n:
        var remaining = n - total
        var take = min(width, remaining)
        output.append(String(s[byte=total:total + take]))
        total += take
    return "\n".join(output)


def random_fasta(table: List[Tuple[String, Float64]], n: Int, mut rng: RNGState) -> String:
    var width: Int = 60
    var probs = List[Float64]()
    var chars = List[String]()
    var prob: Float64 = 0.0
    for (char, p) in table:
        prob += p
        probs.append(prob)
        chars.append(char)
    var output = List[String]()

    for j in range(n // width):
        var line = List[String]()
        for _ in range(width):
            line.append(pick_char(probs, chars, lcg_next(rng)))
        output.append("".join(line))

    var remainder = n % width
    if remainder > 0:
        var line = List[String]()
        for _ in range(remainder):
            line.append(pick_char(probs, chars, lcg_next(rng)))
        output.append("".join(line))

    return "\n".join(output)


def run_fasta(n: Int, seed: Int) raises -> String:
    var rng = RNGState(seed)

    var alu = (
        "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
        "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
        "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
        "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
        "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
        "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
        "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
    )

    var iub = List[Tuple[String, Float64]]()
    iub.append(("a", 0.27))
    iub.append(("c", 0.12))
    iub.append(("g", 0.12))
    iub.append(("t", 0.27))
    for c in "BDHKMNRSVWY":
        iub.append((String(c), 0.02))

    var homosapiens = List[Tuple[String, Float64]]()
    homosapiens.append(("a", 0.3029549426680))
    homosapiens.append(("c", 0.1979883004921))
    homosapiens.append(("g", 0.1975473066391))
    homosapiens.append(("t", 0.3015094502008))

    var output = List[String]()
    output.append(">ONE Homo sapiens alu")
    output.append(repeat_fasta(alu, n * 2))
    output.append(">TWO IUB ambiguity codes")
    output.append(random_fasta(iub, n * 3, rng))
    output.append(">THREE Homo sapiens frequency")
    output.append(random_fasta(homosapiens, n * 5, rng))

    return "\n".join(output)


def compute(n: PythonObject) raises -> PythonObject:
    var ni = Int(py=n)
    return PythonObject(run_fasta(ni, 42))


@fieldwise_init
struct Sim(Defaultable, Movable, Writable):
    var seed: Int

    def __init__(out self):
        self.seed = 42

    @staticmethod
    def py_init(out self: Sim, args: PythonObject, kwargs: PythonObject) raises:
        if len(args) > 0:
            self = Sim(Int(py=args[0]))
        else:
            self = Sim()

    @staticmethod
    def run(self_ptr: Pointer[Sim, MutAnyOrigin], n: PythonObject) raises -> PythonObject:
        var ni = Int(py=n)
        return PythonObject(run_fasta(ni, self_ptr[].seed))


@export
def PyInit_fasta() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("fasta")
        m.def_function[compute]("compute")
        _ = (
            m.add_type[Sim]("Sim")
            .def_py_init[Sim.py_init]()
            .def_method[Sim.run]("run")
        )
        return m.finalize()
    except e:
        abort(String("failed to create module: ", e))