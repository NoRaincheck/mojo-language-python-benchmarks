// N-body simulation benchmark in Odin
// Ported from the Computer Language Benchmarks Game
// Fixed for current Odin (dev-2026): :: constants, -> returns, math.sqrt

package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"

Body :: struct {
    x, y, z: f64,
    vx, vy, vz: f64,
    m: f64,
}

PI :: 3.14159265358979323
SOLAR_MASS :: 4.0 * PI * PI
DAYS_PER_YEAR :: 365.24

advance :: proc(dt: f64, bodies: []Body) {
    n := len(bodies)
    for i in 0 ..< n {
        b1 := bodies[i]
        for j in i + 1 ..< n {
            b2 := bodies[j]
            dx := b1.x - b2.x
            dy := b1.y - b2.y
            dz := b1.z - b2.z
            d_squared := dx * dx + dy * dy + dz * dz
            distance := math.sqrt(d_squared)
            mag := dt / (d_squared * distance)
            m2_multi_mag := b2.m * mag
            bodies[i].vx -= dx * m2_multi_mag
            bodies[i].vy -= dy * m2_multi_mag
            bodies[i].vz -= dz * m2_multi_mag
            m1_multi_mag := b1.m * mag
            bodies[j].vx += dx * m1_multi_mag
            bodies[j].vy += dy * m1_multi_mag
            bodies[j].vz += dz * m1_multi_mag
        }
        bodies[i].x += dt * bodies[i].vx
        bodies[i].y += dt * bodies[i].vy
        bodies[i].z += dt * bodies[i].vz
    }
}

report_energy :: proc(bodies: []Body) -> f64 {
    e := 0.0
    n := len(bodies)
    for i in 0 ..< n {
        b1 := bodies[i]
        e += 0.5 * b1.m * (b1.vx * b1.vx + b1.vy * b1.vy + b1.vz * b1.vz)
        for j in i + 1 ..< n {
            b2 := bodies[j]
            dx := b1.x - b2.x
            dy := b1.y - b2.y
            dz := b1.z - b2.z
            distance := math.sqrt(dx * dx + dy * dy + dz * dz)
            e -= b1.m * b2.m / distance
        }
    }
    return e
}

offset_momentum :: proc(ref_idx: int, bodies: []Body) {
    px := 0.0
    py := 0.0
    pz := 0.0
    for b in bodies {
        px -= b.vx * b.m
        py -= b.vy * b.m
        pz -= b.vz * b.m
    }
    bodies[ref_idx].vx = px / SOLAR_MASS
    bodies[ref_idx].vy = py / SOLAR_MASS
    bodies[ref_idx].vz = pz / SOLAR_MASS
}

create_bodies :: proc() -> []Body {
    bodies := make([]Body, 5)
    bodies[0] = Body{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, SOLAR_MASS}
    bodies[1] = Body{
        4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01,
        1.66007664274403694e-03 * DAYS_PER_YEAR, 7.69901118419740425e-03 * DAYS_PER_YEAR, -6.90460016972063023e-05 * DAYS_PER_YEAR,
        9.54791938424326609e-04 * SOLAR_MASS,
    }
    bodies[2] = Body{
        8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01,
        -2.76742510726862411e-03 * DAYS_PER_YEAR, 4.99852801234917238e-03 * DAYS_PER_YEAR, 2.30417297573763929e-05 * DAYS_PER_YEAR,
        2.85885980666130812e-04 * SOLAR_MASS,
    }
    bodies[3] = Body{
        1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01,
        2.96460137564761618e-03 * DAYS_PER_YEAR, 2.37847173959480950e-03 * DAYS_PER_YEAR, -2.96589568540237556e-05 * DAYS_PER_YEAR,
        4.36624404335156298e-05 * SOLAR_MASS,
    }
    bodies[4] = Body{
        1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e+01,
        2.68067772490389322e-03 * DAYS_PER_YEAR, 1.62824170038242295e-03 * DAYS_PER_YEAR, -9.51592254519715870e-05 * DAYS_PER_YEAR,
        5.15138902046611451e-05 * SOLAR_MASS,
    }
    return bodies
}

main :: proc() {
    args := os.args
    n_steps := 50000
    if len(args) > 1 {
        n_steps = strconv.parse_int(args[1]) or_else 50000
    }

    bodies := create_bodies()
    offset_momentum(0, bodies)
    _ = report_energy(bodies)
    for i in 0 ..< n_steps {
        advance(0.01, bodies)
    }
    energy := report_energy(bodies)
    fmt.printfln("%.9f", energy)
}