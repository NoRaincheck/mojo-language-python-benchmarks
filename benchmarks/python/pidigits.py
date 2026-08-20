# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
#
# Translated from Mr Ledrug's C program by Jeremy Zerfas.
# Transliterated from GMP to built-in by Isaac Gouy


class PiDigits:
    """Stateful Pi digit extractor."""
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
            output.append("".join(line) + "\t:" + str(i))
            line = []
        pd.eliminate_digit(d)
    remainder = i % 10
    if remainder != 0:
        output.append("".join(line) + " " * (10 - remainder) + "\t:" + str(i))
    return "\n".join(output)


if __name__ == '__main__':
    import sys
    print(run(int(sys.argv[1])))
