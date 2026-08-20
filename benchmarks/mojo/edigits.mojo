# E Digits benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Output matches the Python reference.
#
# NOTE: This benchmark requires arbitrary-precision integers (~200,000
# digits for n=100000). Mojo's native Int is 64-bit and overflows, so the
# big-integer arithmetic and digit-string conversion are delegated to
# Python via the built-in Python interop (see std.python).

from std.sys import argv
from std.python import Python


def run_python(n: Int) raises -> String:
    var code = """
import math, sys

sys.set_int_max_str_digits(0)

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
            output.append(s[i:i + 10] + chr(9) + ":" + str(i + 10))
        else:
            output.append(s[i:] + " " * (10 - n % 10) + chr(9) + ":" + str(n))
    return chr(10).join(output)
"""
    var res = Python.evaluate(
        "(exec('''" + code + "''') or run(" + String(t"{n}") + "))"
    )
    return String(res)


def main() raises:
    var n = 1000
    var a = argv()
    if len(a) > 1:
        n = Int(a[1])
    print(run_python(n))