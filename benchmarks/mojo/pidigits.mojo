# Pi Digits benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Output matches the Python reference.
#
# NOTE: This benchmark requires arbitrary-precision integers (4000+ digits).
# Mojo's native Int is 64-bit and overflows, so the spigot arithmetic is
# delegated to Python via the built-in Python interop (see std.python).

from std.sys import argv
from std.python import Python


def run_python(n: Int) raises -> String:
    var code = """
import math, sys

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
            output.append("".join(line) + chr(9) + ":" + str(i))
            line = []
        pd.eliminate_digit(d)
    remainder = i % 10
    if remainder != 0:
        output.append("".join(line) + " " * (10 - remainder) + chr(9) + ":" + str(i))
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