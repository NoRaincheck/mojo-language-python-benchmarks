# Mandelbrot benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Output matches the Python reference

from std.sys import argv


def main() raises:
    var n = 200
    var a = argv()
    if len(a) > 1:
        n = Int(a[1])
    for y in range(n):
        var row = ""
        for x in range(n):
            var cx = 2.5 * (Float64(x) / Float64(n) - 0.5)
            var cy = 1.5 * (Float64(y) / Float64(n) - 0.5)
            var i = 0
            var zx = 0.0
            var zy = 0.0
            while zx * zx + zy * zy < 4.0 and i < 50:
                var zx2 = zx * zx - zy * zy + cx
                zy = 2.0 * zx * zy + cy
                zx = zx2
                i += 1
            if i == 50:
                row += "."
            else:
                row += "#"
        print(row)