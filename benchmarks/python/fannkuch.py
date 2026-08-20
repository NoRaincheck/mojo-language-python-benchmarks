# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/


def run(n):
    perm = list(range(n))
    maxflips = 0
    while True:
        result = fannkuch(perm)
        if result > maxflips:
            maxflips = result
        # Next permutation
        k = n - 2
        while k >= 0 and perm[k] > perm[k + 1]:
            k -= 1
        if k < 0:
            break
        l = n - 1
        while perm[l] < perm[k]:
            l -= 1
        perm[k], perm[l] = perm[l], perm[k]
        perm[k + 1:] = perm[k + 1:][::-1]
    return maxflips


def fannkuch(perm):
    n = len(perm)
    first = perm[0]
    if first == 0:
        return 0
    maxflips = 0
    p = list(perm)
    while True:
        flips = 0
        q = p[:]
        while q[0] != 0:
            i = q[0]
            q[: i + 1] = q[: i + 1][::-1]
            flips += 1
        if flips > maxflips:
            maxflips = flips
        if maxflips == first:
            break
        k = n - 2
        while k >= 0 and p[k] > p[k + 1]:
            k -= 1
        if k < 0:
            break
        l = n - 1
        while p[l] < p[k]:
            l -= 1
        p[k], p[l] = p[l], p[k]
        p[k + 1:] = p[k + 1:][::-1]
    return maxflips


if __name__ == '__main__':
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    print(run(n))
