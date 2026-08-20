# The Computer Language Benchmarks Game
# https://salsa.debian.org/benchmarksgame-team/benchmarksgame/


def run(n):
    # Simple Mandelbrot computation
    output = []
    for y in range(n):
        row = []
        for x in range(n):
            cx = 2.5 * (x / n - 0.5)
            cy = 1.5 * (y / n - 0.5)
            i = 0
            zx = 0.0
            zy = 0.0
            while zx * zx + zy * zy < 4.0 and i < 50:
                zx2 = zx * zx - zy * zy + cx
                zy = 2.0 * zx * zy + cy
                zx = zx2
                i += 1
            row.append('.' if i == 50 else '#')
        output.append(''.join(row))
    return '\n'.join(output)


if __name__ == '__main__':
    import sys
    print(run(int(sys.argv[1])))
