# NSieve (prime sieve) benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Output matches the Python reference

from std.sys import argv


def pad_left(s: String, w: Int) -> String:
    var n = s.byte_length()
    if n >= w:
        return s
    var sp = ""
    for _ in range(w - n):
        sp += " "
    return sp + s


def nsieve(n: Int) -> Int:
    var count = 0
    var flags = List[Bool]()
    for _ in range(n):
        flags.append(True)
    for i in range(2, n):
        if flags[i]:
            count += 1
            var j = i << 1
            while j < n:
                flags[j] = False
                j += i
    return count


def main() raises:
    var n = 4
    var a = argv()
    if len(a) > 1:
        n = Int(a[1])
    for i in range(3):
        var size = 10000 << (n - i)
        var count = nsieve(size)
        print(
            "Primes up to "
            + pad_left(String(t"{size}"), 8)
            + " "
            + pad_left(String(t"{count}"), 8)
        )