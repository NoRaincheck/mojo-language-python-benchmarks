# Spectral Norm benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Output matches the Python reference (9 decimal places)

from std.sys import argv
from std.math import sqrt as std_sqrt


def fmt9(x: Float64) -> String:
    var neg = x < 0.0
    var v = x if not neg else -x
    var ip = Int(v)
    var frac = v - Float64(ip)
    var rounded = frac * 1000000000.0 + 0.5
    var dp = Int(rounded)
    if dp >= 1000000000:
        dp = 0
        ip += 1
    var fracs = String(t"{dp}")
    while fracs.byte_length() < 9:
        fracs = "0" + fracs
    var ipstr = String(t"{ip}")
    return (("-" if neg else "") + ipstr) + "." + fracs


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


def main() raises:
    var n = 100
    var a = argv()
    if len(a) > 1:
        n = Int(a[1])

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

    print(fmt9(std_sqrt(vBv / vv)))