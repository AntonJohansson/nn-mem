const std = @import("std");

const c = @cImport({
    @cInclude("raylib.h");
});

const print = std.io.getStdOut().writer().print;

const N = 16;

const State = enum {
    DrawingMemory,
    DrawingInput,
    Running,
};


var prng = std.rand.DefaultPrng.init(0);
const random = prng.random();

pub fn main() !void {
    c.InitWindow(800, 600, "mem");
    c.SetTargetFPS(60);

    var has_computed_weights = false;

    const num_numkeys = c.KEY_NINE - c.KEY_ONE;
    const num_inputs = num_numkeys;
    var selected_input: usize = 0;

    var used_memories: [num_inputs]bool = .{false}**num_inputs;
    var memories: [num_inputs][N][N]f32 = .{.{ .{-1.0}**N }**N}**num_inputs;
    var input: [N][N]f32 = .{.{-1.0}**N}**N;
    var running_state: [N][N]f32 = undefined;
    var weights: [N*N][N*N]f32 = undefined;

    var state: State = .DrawingMemory;

    while (!c.WindowShouldClose()) {
        const key: i32 = c.GetKeyPressed() - c.KEY_ONE;
        if (key >= 0 and key < num_inputs) {
            selected_input = @intCast(usize, key);
        }

        c.BeginDrawing();
        c.ClearBackground(c.WHITE);

        const width: usize = @intCast(usize, c.GetScreenWidth());
        const height: usize = @intCast(usize, c.GetScreenHeight());

        const dx: usize = width/N;
        const dy: usize = height/N;
        const margin_x = (width - N*dx)/2;
        const margin_y = (height - N*dy)/2;


        const mouse_x = c.GetMouseX() - 2*@intCast(i32, margin_x);
        const mouse_y = c.GetMouseY() - 2*@intCast(i32, margin_y);
        var mouse_i: ?usize = null;
        var mouse_j: ?usize = null;
        if (mouse_x >= 0 and mouse_x < width-2*margin_x and
            mouse_y >= 0 and mouse_y < height-2*margin_y) {
            mouse_i = @intCast(usize, mouse_x) / dx;
            mouse_j = @intCast(usize, mouse_y) / dy;
        }

        if (state == .DrawingMemory) {
            var m = &memories[selected_input];

            if (c.IsKeyPressed(c.KEY_E)) {
                state = .DrawingInput;
            }

            if (mouse_i != null and mouse_j != null) {
                if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT)) {
                    m.*[mouse_i.?][mouse_j.?] = 1;
                    used_memories[selected_input] = true;
                } else if (c.IsMouseButtonDown(c.MOUSE_BUTTON_RIGHT)) {
                    m.*[mouse_i.?][mouse_j.?] = -1;
                    used_memories[selected_input] = true;
                }
            }

            if (c.IsKeyPressed(c.KEY_C)) {
                used_memories[selected_input] = false;
                setAll(N, m, -1);
            }

            for (m.*) |*row,i| {
                for (row.*) |*cell,j| {
                    var color = c.BLUE;
                    if (mouse_i != null and mouse_j != null and
                        mouse_i.? == i and mouse_j.? == j) {
                        color = c.BLACK;
                    } else if (cell.* == 1) {
                        color = c.RED;
                    }
                    const x: i32 = @intCast(i32, margin_x) + @intCast(i32, i)*@intCast(i32, dx);
                    const y: i32 = @intCast(i32, margin_y) + @intCast(i32, j)*@intCast(i32, dy);
                    c.DrawRectangle(x, y, @intCast(i32, dx), @intCast(i32, dy), color);
                }
            }
        } else if (state == .DrawingInput) {
            var m = &input;

            if (c.IsKeyPressed(c.KEY_Q)) {
                state = .DrawingMemory;
            } else if (c.IsKeyPressed(c.KEY_E)) {
                state = .Running;
            }

            if (mouse_i != null and mouse_j != null) {
                if (c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT)) {
                    m.*[mouse_i.?][mouse_j.?] = 1;
                } else if (c.IsMouseButtonDown(c.MOUSE_BUTTON_RIGHT)) {
                    m.*[mouse_i.?][mouse_j.?] = -1;
                }
            }

            if (c.IsKeyPressed(c.KEY_C)) {
                setAll(N, m, -1);
            }

            for (m.*) |*row,i| {
                for (row.*) |*cell,j| {
                    var color = c.BLUE;
                    if (mouse_i != null and mouse_j != null and
                        mouse_i.? == i and mouse_j.? == j) {
                        color = c.GRAY;
                    } else if (cell.* == 1) {
                        color = c.GREEN;
                    }
                    const x: i32 = @intCast(i32, margin_x) + @intCast(i32, i)*@intCast(i32, dx);
                    const y: i32 = @intCast(i32, margin_y) + @intCast(i32, j)*@intCast(i32, dy);
                    c.DrawRectangle(x, y, @intCast(i32, dx), @intCast(i32, dy), color);
                }
            }
        } else if (state == .Running) {
            if (c.IsKeyPressed(c.KEY_Q)) {
                state = .DrawingInput;
                has_computed_weights = false;
            }

            if (!has_computed_weights) {
                var num_active_memories: usize = 0;
                for (weights) |*row| {
                    for (row.*) |*cell| {
                        cell.* = 0;
                    }
                }
                for (memories) |*m, i| {
                    if (used_memories[i]) {
                        num_active_memories += 1;
                        addOuterProduct(N, &weights, m, m);
                    }
                }

                for (weights) |*row| {
                    for (row.*) |*cell| {
                        cell.* *= 1.0/@intToFloat(f32, num_active_memories);
                    }
                }

                running_state = input;

                has_computed_weights = true;
            }

            update(N, &weights, &running_state);

            for (running_state) |*row,i| {
                for (row.*) |*cell,j| {
                    var color = c.BLUE;
                    if (cell.* == 1) {
                        color = c.GREEN;
                    }
                    const x: i32 = @intCast(i32, margin_x) + @intCast(i32, i)*@intCast(i32, dx);
                    const y: i32 = @intCast(i32, margin_y) + @intCast(i32, j)*@intCast(i32, dy);
                    c.DrawRectangle(x, y, @intCast(i32, dx), @intCast(i32, dy), color);
                }
            }
        }

        c.EndDrawing();
    }
    c.CloseWindow();
}

fn update(comptime n: usize, weights: *[n*n][n*n]f32, state: *[n][n]f32) void {
    const i = random.int(usize) % n;
    const j = random.int(usize) % n;
    const index = i*n + j;
    const w = weights.*[index];
    const v = matAsVec(n, state);
    state[i][j] = if (dot(n*n,w,v) < 0) -1 else 1;
}

fn dot(comptime n: usize, a: [n]f32, b: [n]f32) f32 {
    var d: f32 = 0;
    for (a) |_,k| {
        d += a[k]*b[k];
    }
    return d;
}

fn computeWeights(comptime n: usize, weights: *[n*n][n*n]f32, memories: [][n][n]f32) void {
    setAll(weights.len, &weights, 0);
    for (memories) |*m| {
        addOuterProduct(m.len, &weights, m, m);
    }
    scaleAll(weights.len, &weights, 1.0/@intToFloat(f32, memories.len));
}

fn setAll(comptime n: usize, mat: *[n][n]f32, value: f32) void {
    for (mat.*) |*row| {
        for (row.*) |*cell| {
            cell.* = value;
        }
    }
}

fn scaleAll(comptime n: usize, mat: *[n][n]f32, value: f32) void {
    for (mat.*) |*row| {
        for (row.*) |*cell| {
            cell.* *= value;
        }
    }
}

fn addOuterProduct(comptime n: usize, result: *[n*n][n*n]f32, a: *[n][n]f32, b: *[n][n]f32) void {
    const va = matAsVec(n, a);
    const vb = matAsVec(n, b);
    for (va) |vi,i| {
        for (vb) |vj,j| {
            result[i][j] += if (i != j) vi*vj else 0;
        }
    }
}

fn matAsVec(comptime n: usize, m: *[n][n]f32) [n*n]f32 {
    return @ptrCast(*[n*n]f32, m).*;
}
