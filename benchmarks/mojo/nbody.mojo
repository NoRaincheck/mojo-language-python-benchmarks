# N-body simulation benchmark in Mojo
# Ported from the Computer Language Benchmarks Game
# Values and output match the fixed Zig/Odin/Python references

from std.sys import argv
from std.math import sqrt

comptime PI = 3.14159265358979323
comptime SOLAR_MASS = 4.0 * PI * PI
comptime DAYS_PER_YEAR = 365.24


struct Body:
    var x: Float64
    var y: Float64
    var z: Float64
    var vx: Float64
    var vy: Float64
    var vz: Float64
    var m: Float64


def advance(dt: Float64, bodies: Pointer[Body, MutUntrackedOrigin], n: Int):
    for i in range(n):
        var b1x = bodies[i].x
        var b1y = bodies[i].y
        var b1z = bodies[i].z
        var b1m = bodies[i].m
        for j in range(i + 1, n):
            var dx = b1x - bodies[j].x
            var dy = b1y - bodies[j].y
            var dz = b1z - bodies[j].z

            var d_squared = dx * dx + dy * dy + dz * dz
            var distance = sqrt(d_squared)

            var mag = dt / (d_squared * distance)

            var m2_multi_mag = bodies[j].m * mag
            bodies[i].vx -= dx * m2_multi_mag
            bodies[i].vy -= dy * m2_multi_mag
            bodies[i].vz -= dz * m2_multi_mag

            var m1_multi_mag = b1m * mag
            bodies[j].vx += dx * m1_multi_mag
            bodies[j].vy += dy * m1_multi_mag
            bodies[j].vz += dz * m1_multi_mag
        bodies[i].x += dt * bodies[i].vx
        bodies[i].y += dt * bodies[i].vy
        bodies[i].z += dt * bodies[i].vz


def report_energy(bodies: Pointer[Body, MutUntrackedOrigin], n: Int) -> Float64:
    var e = 0.0
    for i in range(n):
        e += 0.5 * bodies[i].m * (
            bodies[i].vx * bodies[i].vx
            + bodies[i].vy * bodies[i].vy
            + bodies[i].vz * bodies[i].vz
        )
        for j in range(i + 1, n):
            var dx = bodies[i].x - bodies[j].x
            var dy = bodies[i].y - bodies[j].y
            var dz = bodies[i].z - bodies[j].z
            var distance = sqrt(dx * dx + dy * dy + dz * dz)
            e -= bodies[i].m * bodies[j].m / distance
    return e


def offset_momentum(bodies: Pointer[Body, MutUntrackedOrigin], n: Int):
    var px = 0.0
    var py = 0.0
    var pz = 0.0
    for i in range(n):
        px -= bodies[i].vx * bodies[i].m
        py -= bodies[i].vy * bodies[i].m
        pz -= bodies[i].vz * bodies[i].m
    bodies[0].vx = px / SOLAR_MASS
    bodies[0].vy = py / SOLAR_MASS
    bodies[0].vz = pz / SOLAR_MASS


def create_bodies() raises -> Pointer[Body, MutUntrackedOrigin]:
    var bodies = alloc[Body](5)
    bodies[0].x = 0.0
    bodies[0].y = 0.0
    bodies[0].z = 0.0
    bodies[0].vx = 0.0
    bodies[0].vy = 0.0
    bodies[0].vz = 0.0
    bodies[0].m = SOLAR_MASS

    bodies[1].x = 4.84143144246472090e+00
    bodies[1].y = -1.16032004402742839e+00
    bodies[1].z = -1.03622044471123109e-01
    bodies[1].vx = 1.66007664274403694e-03 * DAYS_PER_YEAR
    bodies[1].vy = 7.69901118419740425e-03 * DAYS_PER_YEAR
    bodies[1].vz = -6.90460016972063023e-05 * DAYS_PER_YEAR
    bodies[1].m = 9.54791938424326609e-04 * SOLAR_MASS

    bodies[2].x = 8.34336671824457987e+00
    bodies[2].y = 4.12479856412430479e+00
    bodies[2].z = -4.03523417114321381e-01
    bodies[2].vx = -2.76742510726862411e-03 * DAYS_PER_YEAR
    bodies[2].vy = 4.99852801234917238e-03 * DAYS_PER_YEAR
    bodies[2].vz = 2.30417297573763929e-05 * DAYS_PER_YEAR
    bodies[2].m = 2.85885980666130812e-04 * SOLAR_MASS

    bodies[3].x = 1.28943695621391310e+01
    bodies[3].y = -1.51111514016986312e+01
    bodies[3].z = -2.23307578892655734e-01
    bodies[3].vx = 2.96460137564761618e-03 * DAYS_PER_YEAR
    bodies[3].vy = 2.37847173959480950e-03 * DAYS_PER_YEAR
    bodies[3].vz = -2.96589568540237556e-05 * DAYS_PER_YEAR
    bodies[3].m = 4.36624404335156298e-05 * SOLAR_MASS

    bodies[4].x = 1.53796971148509165e+01
    bodies[4].y = -2.59193146099879641e+01
    bodies[4].z = 1.79258772950371181e+01
    bodies[4].vx = 2.68067772490389322e-03 * DAYS_PER_YEAR
    bodies[4].vy = 1.62824170038242295e-03 * DAYS_PER_YEAR
    bodies[4].vz = -9.51592254519715870e-05 * DAYS_PER_YEAR
    bodies[4].m = 5.15138902046611451e-05 * SOLAR_MASS

    return bodies


def main() raises:
    var n_steps = 50000
    var a = argv()
    if len(a) > 1:
        n_steps = Int(a[1])

    var bodies = create_bodies()
    offset_momentum(bodies, 5)
    _ = report_energy(bodies, 5)
    for i in range(n_steps):
        advance(0.01, bodies, 5)
    var energy = report_energy(bodies, 5)
    print(energy)
    bodies.free()