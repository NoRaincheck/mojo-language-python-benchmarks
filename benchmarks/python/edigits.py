# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/

import math
import sys

# set_int_max_str_digits was added in Python 3.11; ignore on older versions
if hasattr(sys, "set_int_max_str_digits"):
    sys.set_int_max_str_digits(0)

LN_TAU = math.log(math.tau)
LN_10 = math.log(float(10))


def sum_terms(a, b):
    if b == a + 1:
        return 1, b
    mid = (a + b) // 2
    p_left, q_left = sum_terms(a, mid)
    p_right, q_right = sum_terms(mid, b)
    return p_left * q_right + p_right, q_left*q_right


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


def test_k(n, k):
    if k <= 0:
        return False
    else:
        ln_k_factorial = k * (math.log(k)-1) + 0.5 * LN_TAU
        log_10_k_factorial = ln_k_factorial / LN_10
        return log_10_k_factorial >= n+50


def run(n):
    k = binary_search(n)
    p, q = sum_terms(0, k - 1)
    p += q
    answer = p * (10 ** (n - 1)) // q
    s = str(answer)
    output = []
    for i in range(0, n, 10):
        if i+10 <= n:
            output.append(f'{s[i: i + 10]}\t:{i+10}')
        else:
            output.append(f'{s[i:]}{" "*(10-n%10)}\t:{n}')
    return '\n'.join(output)


if __name__ == '__main__':
    print(run(int(sys.argv[1])))
