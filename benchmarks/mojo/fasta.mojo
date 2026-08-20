# Fasta benchmark in Mojo
# Ported from the Computer Language Benchmarks Game


@fieldwise_init
struct RNGState(Copyable, Movable):
    var seed: Int


@always_inline("nodebug")
fn lcg_next(state: inout RNGState) -> Float64:
    const ia: Int = 3877
    const ic: Int = 29573
    const im: Int = 139968
    state.seed = (state.seed * ia + ic) % im
    return Float64(state.seed) / Float64(im)


@always_inline("nodebug")
def make_cumulative(table: List[(String, Float64)]) -> (List[Float64], List[String]):
    var P = List[Float64]()
    var C = List[String]()
    var prob: Float64 = 0.0
    for (char, p) in table:
        prob += p
        P.append(prob)
        C.append(char)
    return (P, C)


@always_inline("nodebug")
def repeat_fasta(src: String, n: Int) -> String:
    const width: Int = 60
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
        output.append(s[byte=total:byte=total+take])
        total += take
    return "\n".join(output)


@always_inline("nodebug")
def random_fasta(table: List[(String, Float64)], n: Int, rng: inout RNGState) -> String:
    const width: Int = 60
    var (probs, chars) = make_cumulative(table)
    var output = List[String]()

    for j in range(n // width):
        var line = List[String]()
        for _ in range(width):
            var r = lcg_next(rng)
            # Binary search in probs
            var lo: Int = 0
            var hi = len(probs) - 1
            while lo < hi:
                var mid = (lo + hi) // 2
                if probs[mid] < r:
                    lo = mid + 1
                else:
                    hi = mid
            line.append(chars[lo])
        output.append("".join(line))

    var remainder = n % width
    if remainder > 0:
        var line = List[String]()
        for _ in range(remainder):
            var r = lcg_next(rng)
            var lo: Int = 0
            var hi = len(probs) - 1
            while lo < hi:
                var mid = (lo + hi) // 2
                if probs[mid] < r:
                    lo = mid + 1
                else:
                    hi = mid
            line.append(chars[lo])
        output.append("".join(line))

    return "\n".join(output)


def run(n: Int) raises -> String:
    var rng = RNGState(42)

    var alu = (
        "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGG"
        "GAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGA"
        "CCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAAT"
        "ACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCA"
        "GCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGG"
        "AGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCC"
        "AGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"
    )

    var iub = List[(String, Float64)]()
    iub.append(("a", 0.27))
    iub.append(("c", 0.12))
    iub.append(("g", 0.12))
    iub.append(("t", 0.27))
    for c in "BDHKMNRSVWY":
        iub.append((c, 0.02))

    var homosapiens = List[(String, Float64)]()
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


def main() raises:
    import sys
    var n = Int(sys.argv[1]) if len(sys.argv) > 1 else 1000
    print(run(n))


main()
