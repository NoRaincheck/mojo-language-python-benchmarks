# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/


def nsieve(n):
    count = 0
    flags = [True] * n
    for i in range(2, n):
        if flags[i]:
            count += 1
            for j in range(i << 1, n, i):
                flags[j] = False
    return count


if __name__ == '__main__':
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    for i in range(0, 3):
        count = nsieve(10000 << (n-i))
        print(f'Primes up to {10000 << (n-i):8} {count:8}')
