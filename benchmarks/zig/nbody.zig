const std = @import("std");

const Body = struct {
    x: f64 = 0.0, y: f64 = 0.0, z: f64 = 0.0,
    vx: f64 = 0.0, vy: f64 = 0.0, vz: f64 = 0.0,
    m: f64 = 0.0,
};

const PI: f64 = 3.14159265358979323;
const SOLAR_MASS: f64 = 4.0 * PI * PI;
const DAYS_PER_YEAR: f64 = 365.24;

fn advance(dt: f64, bodies: []Body) void {
    const n = bodies.len;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const b1 = bodies[i];
        var j: usize = i + 1;
        while (j < n) : (j += 1) {
            const b2 = bodies[j];
            const dx = b1.x - b2.x;
            const dy = b1.y - b2.y;
            const dz = b1.z - b2.z;
            const d_squared = dx * dx + dy * dy + dz * dz;
            const distance = std.math.pow(f64, d_squared, 0.5);
            const mag = dt / (d_squared * distance);
            const m2_multi_mag = b2.m * mag;
            bodies[i].vx -= dx * m2_multi_mag;
            bodies[i].vy -= dy * m2_multi_mag;
            bodies[i].vz -= dz * m2_multi_mag;
            const m1_multi_mag = b1.m * mag;
            bodies[j].vx += dx * m1_multi_mag;
            bodies[j].vy += dy * m1_multi_mag;
            bodies[j].vz += dz * m1_multi_mag;
        }
        bodies[i].x += dt * bodies[i].vx;
        bodies[i].y += dt * bodies[i].vy;
        bodies[i].z += dt * bodies[i].vz;
    }
}

fn report_energy(bodies: []const Body) f64 {
    var e: f64 = 0.0;
    const n = bodies.len;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const b1 = bodies[i];
        e += 0.5 * b1.m * (b1.vx * b1.vx + b1.vy * b1.vy + b1.vz * b1.vz);
        var j: usize = i + 1;
        while (j < n) : (j += 1) {
            const b2 = bodies[j];
            const dx = b1.x - b2.x;
            const dy = b1.y - b2.y;
            const dz = b1.z - b2.z;
            const distance = std.math.pow(f64, dx * dx + dy * dy + dz * dz, 0.5);
            e -= b1.m * b2.m / distance;
        }
    }
    return e;
}

fn offset_momentum(ref_idx: usize, bodies: []Body) void {
    var px: f64 = 0.0;
    var py: f64 = 0.0;
    var pz: f64 = 0.0;
    for (bodies) |b| {
        px -= b.vx * b.m;
        py -= b.vy * b.m;
        pz -= b.vz * b.m;
    }
    bodies[ref_idx].vx = px / SOLAR_MASS;
    bodies[ref_idx].vy = py / SOLAR_MASS;
    bodies[ref_idx].vz = pz / SOLAR_MASS;
}

pub fn main() void {
    const n_steps: usize = 50000;

    var bodies: [5]Body = .{
        .{ .m = SOLAR_MASS }, // sun
        .{ .x = 4.84143144246472090e+00, .y = -1.16032004402742839e+00, .z = -1.03622044471123109e-01,
           .vx = 1.66007664274403694e-03 * DAYS_PER_YEAR, .vy = 7.69901118419740425e-03 * DAYS_PER_YEAR, .vz = -6.90460016972063023e-05 * DAYS_PER_YEAR,
           .m = 9.54791938424326609e-04 * SOLAR_MASS }, // jupiter
        .{ .x = 8.34336671824457987e+00, .y = 4.12479856412430479e+00, .z = -4.03523417114321381e-01,
           .vx = -2.76742510726862411e-03 * DAYS_PER_YEAR, .vy = 4.99852801234917238e-03 * DAYS_PER_YEAR, .vz = 2.30417297573763929e-05 * DAYS_PER_YEAR,
           .m = 2.85885980666130812e-04 * SOLAR_MASS }, // saturn
        .{ .x = 1.28943695621391310e+01, .y = -1.51111514016986312e+01, .z = -2.23307578892655734e-01,
           .vx = 2.96460137564761618e-03 * DAYS_PER_YEAR, .vy = 2.37847173959480950e-03 * DAYS_PER_YEAR, .vz = -2.96589568540237556e-05 * DAYS_PER_YEAR,
           .m = 4.36624404335156298e-05 * SOLAR_MASS }, // uranus
        .{ .x = 1.53796971148509165e+01, .y = -2.59193146099879641e+01, .z = 1.79258772950371181e+01,
           .vx = 2.68067772490389322e-03 * DAYS_PER_YEAR, .vy = 1.62824170038242295e-03 * DAYS_PER_YEAR, .vz = -9.51592254519715870e-05 * DAYS_PER_YEAR,
           .m = 5.15138902046611451e-05 * SOLAR_MASS }, // neptune
    };

    offset_momentum(0, &bodies);
    _ = report_energy(&bodies);
    var i: usize = 0;
    while (i < n_steps) : (i += 1) {
        advance(0.01, &bodies);
    }
    const energy = report_energy(&bodies);
    std.debug.print("{d}\n", .{energy});
}
